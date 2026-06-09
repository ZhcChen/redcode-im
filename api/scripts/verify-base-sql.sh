#!/bin/bash
set -euo pipefail

BASE_SQL="sql/base.sql"
SQL_README="sql/README.md"
MIGRATIONS_README="sql/migrations/README.md"
DATABASE_MANIFEST="src/database/mod.rs"
MIGRATION_SMOKE_TEST="tests/database_migration_smoke.rs"

pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; return 1; }
check_file() { if [ -f "$1" ]; then pass "$2"; else fail "$2（缺失: $1）"; fi; }
check_pattern() { if rg -q "$2" "$1"; then pass "$3"; else fail "$3（未命中: $2）"; fi; }

echo "========================================="
echo "验证 SQL 基线一致性（整合后单一基线）"
echo "========================================="
echo ""

echo "📋 核心文件："
check_file "$BASE_SQL" "base.sql 基线文件"
check_file "$SQL_README" "sql/README.md"
check_file "$MIGRATIONS_README" "sql/migrations/README.md"
check_file "$DATABASE_MANIFEST" "Database::MIGRATIONS manifest"
check_file "$MIGRATION_SMOKE_TEST" "database migration smoke test"
echo ""

echo "🔍 base.sql 关键 schema 标记："
check_pattern "$BASE_SQL" "CREATE TABLE public\\.admin_users" "admin_users 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.messages" "messages 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.storage_providers" "storage_providers 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.object_storage_configs" "object_storage_configs 表（已整合）"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.push_devices" "push_devices 表"
check_pattern "$BASE_SQL" "CREATE TABLE public\\.e2ee_identity_keys" "e2ee_identity_keys 表"
check_pattern "$BASE_SQL" "CREATE VIEW public\\.group_detail_view" "group_detail_view 视图"
check_pattern "$BASE_SQL" "edited_at timestamp with time zone" "messages.edited_at 列"
check_pattern "$BASE_SQL" "encrypted_content bytea" "messages.encrypted_content 列"
check_pattern "$BASE_SQL" "encryption_metadata jsonb" "messages.encryption_metadata 列"
check_pattern "$BASE_SQL" "app_store_url text" "app_versions.app_store_url 列"
echo ""

echo "🔍 整合后口径与反向断言："
check_pattern "$DATABASE_MANIFEST" "const BASE_MIGRATION_NAME: &str = \"base\\.sql\";" "manifest 引用 base.sql"
check_pattern "$MIGRATION_SMOKE_TEST" "object_storage_configs" "migration smoke 覆盖对象存储配置表"
check_pattern "$MIGRATION_SMOKE_TEST" "checksum_mismatch_is_rejected" "migration smoke 覆盖 checksum 校验"
if ls sql/migrations/*.sql >/dev/null 2>&1; then
    fail "sql/migrations/ 不应再有 *.sql（历史增量已整合进 base.sql）"
else
    pass "sql/migrations/ 无残留增量迁移"
fi
if [ -d sql/migrations_legacy_20260409 ]; then
    fail "legacy 归档目录应已删除"
else
    pass "无 legacy 归档目录"
fi
if rg -q "20260410093000|20260413153000|20260430120000" "$DATABASE_MANIFEST"; then
    fail "manifest 仍引用已折叠的历史迁移名"
else
    pass "manifest 已无历史增量迁移引用"
fi
echo ""

echo "📌 当前口径："
echo "  - 默认执行入口：api 启动时 Database::migrate（MIGRATIONS = [base.sql]）"
echo "  - 2026-06-09 整合重置：历史增量迁移已折叠进 base.sql（schema 等价已验证）"
echo "  - 首个超级管理员由运行时 bootstrap 初始化，base.sql 不含默认管理员 seed"
echo "  - 后续数据库变更从 sql/migrations/ 追加增量（additive-only，由 make migration.guard 强制）"
echo ""

echo "🧪 推荐验证："
echo "  1. make api.test.integration（含 database_migration_smoke）"
echo "  2. make migration.guard"
echo ""

echo "========================================="
echo "✅ 验证完成"
echo "========================================="
