#!/bin/bash
# 将所有迁移文件合并到 sql/base.sql 中（历史工具，通常仅在重大结构调整时使用）

set -e

echo "========================================="
echo "合并迁移文件到 sql/base.sql"
echo "========================================="
echo ""

# 备份原文件
BACKUP_FILE="sql/base.sql.backup.$(date +%Y%m%d_%H%M%S)"
cp "sql/base.sql" "$BACKUP_FILE"
echo "✅ 已备份原文件到: $BACKUP_FILE"
echo ""

# 创建临时文件
TEMP_FILE="/tmp/base.sql.merged"
cp "sql/base.sql" "$TEMP_FILE"

# 在 COMMIT 前插入迁移内容
# 找到最后一个 INSERT 语句的位置
LAST_INSERT_LINE=$(grep -n "INSERT INTO" "$TEMP_FILE" | tail -1 | cut -d: -f1)

if [ -z "$LAST_INSERT_LINE" ]; then
    echo "❌ 未找到 INSERT 语句，无法确定插入位置"
    exit 1
fi

echo "📍 最后一条 INSERT 语句在第 $LAST_INSERT_LINE 行"
echo ""

# 创建临时文件存储迁移内容
MIGRATION_CONTENT="/tmp/migrations_content.sql"
echo "-- ========================================" > "$MIGRATION_CONTENT"
echo "-- 合并的迁移文件内容" >> "$MIGRATION_CONTENT"
echo "-- 生成时间: $(date)" >> "$MIGRATION_CONTENT"
echo "-- ========================================" >> "$MIGRATION_CONTENT"
echo "" >> "$MIGRATION_CONTENT"

shopt -s nullglob

# 按时间顺序读取迁移文件（仅处理当前 migrations 目录下的增量脚本）
echo "📋 正在合并迁移文件："
for file in sql/migrations/*.sql; do
    filename=$(basename "$file")
    echo "  📄 $filename"

    # 跳过已知的全表重建迁移
    if [[ "$filename" == *"20251120105305_migrate_admin_users"* ]]; then
        echo "    ⏭️  跳过（已在base.sql中）"
        continue
    fi

    # 跳过外键修复迁移（已在base.sql中）
    if [[ "$filename" == *"20251201123000_fix_storage_providers"* ]]; then
        echo "    ⏭️  跳过（已在base.sql中）"
        continue
    fi

    # 跳过表结构修复迁移
    if [[ "$filename" == *"20251127125035_fix_group_settings"* ]]; then
        echo "    ⏭️  跳过（已在base.sql中）"
        continue
    fi

    # 跳过已包含的迁移
    if [[ "$filename" == *"20251120105125_create_admin_users_table"* ]]; then
        echo "    ⏭️  跳过（已在base.sql中）"
        continue
    fi

    echo "    ✅ 添加内容" >> "$MIGRATION_CONTENT"
    echo "" >> "$MIGRATION_CONTENT"

    # 读取迁移文件内容，跳过 BEGIN/COMMIT
    sed -n '/^BEGIN;$/,/^COMMIT;$/p' "$file" | \
        grep -v "^BEGIN;$" | \
        grep -v "^COMMIT;$" \
        >> "$MIGRATION_CONTENT" || true

    echo "" >> "$MIGRATION_CONTENT"
done

echo ""
echo "🔧 开始合并..."

# 删除旧的 COMMIT 和之后的语句
sed -i "${LAST_INSERT_LINE},\$d" "$TEMP_FILE"

# 添加迁移内容
cat "$MIGRATION_CONTENT" >> "$TEMP_FILE"

# 重新添加 COMMIT 和完成信息
echo "" >> "$TEMP_FILE"
echo "COMMIT;" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"
echo "-- 输出完成信息" >> "$TEMP_FILE"
echo "SELECT 'Database initialization completed successfully!' AS status;" >> "$TEMP_FILE"

# 替换原文件
mv "$TEMP_FILE" "sql/base.sql"

# 清理临时文件
rm -f "$MIGRATION_CONTENT"

echo "✅ 合并完成！"
echo ""

echo "========================================="
echo "✅ 合并完成！"
echo "========================================="
echo ""
echo "📌 使用方法："
echo "  1. 重新初始化数据库："
echo "     psql -h localhost -U postgres -d redcode_im -f sql/base.sql"
echo ""
echo "  2. 如果有问题，可以使用备份恢复："
echo "     cp $BACKUP_FILE sql/base.sql"
echo ""
echo "⚠️  注意：合并后的 base.sql 包含所有迁移内容，"
echo "   现在可以用于完整的数据库初始化！"
