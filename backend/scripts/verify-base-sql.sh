#!/bin/bash
set -euo pipefail

BASE_SQL="sql/base.sql"
ACTIVE_MIGRATIONS=(
  "sql/migrations/20260410093000_remove_default_admin_seed.sql"
  "sql/migrations/20260413153000_add_object_storage_configs.sql"
)
SQL_README="sql/README.md"
MIGRATIONS_README="sql/migrations/README.md"
DATABASE_MANIFEST="src/database/mod.rs"
MIGRATION_SMOKE_TEST="tests/database_migration_smoke.rs"
LEGACY_DIR="sql/migrations_legacy_20260409"

pass() {
    echo "  ✅ $1"
}

fail() {
    echo "  ❌ $1"
    return 1
}

check_file() {
    local path="$1"
    local label="$2"
    if [ -f "$path" ]; then
        pass "$label"
    else
        fail "${label}（缺失: ${path}）"
    fi
}

check_dir() {
    local path="$1"
    local label="$2"
    if [ -d "$path" ]; then
        pass "$label"
    else
        fail "${label}（缺失: ${path}）"
    fi
}

check_pattern() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if rg -q "$pattern" "$file"; then
        pass "$label"
    else
        fail "${label}（未命中: ${pattern}）"
    fi
}

echo "========================================="
echo "验证 SQL 基线 / 迁移链一致性"
echo "========================================="
echo ""

echo "📋 核心文件："
check_file "$BASE_SQL" "base.sql 基线文件"
for migration in "${ACTIVE_MIGRATIONS[@]}"; do
    check_file "$migration" "active migration：$(basename "$migration")"
done
check_file "$SQL_README" "sql/README.md"
check_file "$MIGRATIONS_README" "sql/migrations/README.md"
check_file "$DATABASE_MANIFEST" "Database::MIGRATIONS manifest"
check_file "$MIGRATION_SMOKE_TEST" "database migration smoke test"
check_dir "$LEGACY_DIR" "legacy 迁移归档目录"
echo ""

echo "🔍 base.sql 关键 schema 标记："
check_pattern "$BASE_SQL" "CREATE TABLE public\\.admin_users" "admin_users 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.messages" "messages 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.storage_providers" "storage_providers 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.push_devices" "push_devices 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.user_oauth_accounts" "user_oauth_accounts 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.e2ee_identity_keys" "e2ee_identity_keys 表"
check_pattern "$BASE_SQL" "CREATE VIEW public\\.group_detail_view" "group_detail_view 视图"
check_pattern "$BASE_SQL" "edited_at timestamp with time zone" "messages.edited_at 列"
check_pattern "$BASE_SQL" "encrypted_content bytea" "messages.encrypted_content 列"
check_pattern "$BASE_SQL" "encryption_metadata jsonb" "messages.encryption_metadata 列"
check_pattern "$BASE_SQL" "app_store_url text" "app_versions.app_store_url 列"
echo ""

echo "🔍 活跃迁移链与文档口径："
check_pattern "$DATABASE_MANIFEST" "const BASE_MIGRATION_NAME: &str = \"base\\.sql\";" "manifest 引用 base.sql"
check_pattern "$DATABASE_MANIFEST" "20260410093000_remove_default_admin_seed\\.sql" "manifest 引用移除默认管理员迁移"
check_pattern "$DATABASE_MANIFEST" "20260413153000_add_object_storage_configs\\.sql" "manifest 引用对象存储配置迁移"
check_pattern "$MIGRATIONS_README" "20260410093000_remove_default_admin_seed\\.sql" "migrations README 说明移除默认管理员迁移"
check_pattern "$MIGRATIONS_README" "20260413153000_add_object_storage_configs\\.sql" "migrations README 说明对象存储配置迁移"
check_pattern "$SQL_README" "运行时 bootstrap 初始化流程" "sql README 说明首管走 bootstrap"
check_pattern "$MIGRATION_SMOKE_TEST" "object_storage_configs" "migration smoke 覆盖对象存储配置表"
check_pattern "$MIGRATION_SMOKE_TEST" "checksum_mismatch_is_rejected" "migration smoke 覆盖 checksum 校验"
echo ""

legacy_count=$(find "$LEGACY_DIR" -maxdepth 1 -type f -name '*.sql' | wc -l | tr -d ' ')
echo "📦 legacy 归档文件数：${legacy_count}"
echo ""

echo "📌 当前口径："
echo "  - 默认执行入口是 backend 启动时的 Database::migrate"
echo "  - 当前有效链路 = base.sql + sql/migrations/20260410093000_remove_default_admin_seed.sql + sql/migrations/20260413153000_add_object_storage_configs.sql"
echo "  - 首个超级管理员由运行时 bootstrap 初始化，不依赖静态默认账号"
echo "  - 对象存储运行时配置版本表由增量迁移创建，不直接写入 base.sql"
echo "  - legacy 目录仅用于审计/回溯，不参与默认执行入口"
echo ""

echo "🧪 推荐验证："
echo "  1. cargo test --test database_migration_smoke"
echo "  2. cargo test"
echo ""

echo "========================================="
echo "✅ 验证完成"
echo "========================================="
