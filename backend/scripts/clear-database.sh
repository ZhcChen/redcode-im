#!/bin/bash
# 清空数据库所有表数据（保留表结构）

set -e

DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-redcode_im}
DB_USER=${DB_USER:-postgres}

echo "正在清空数据库表数据..."
echo "数据库: $DB_NAME"
echo ""

# 执行清空脚本
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f scripts/truncate-all-data.sql

echo ""
echo "✅ 数据库表数据清空完成！"
echo ""
echo "注意："
echo "- 仅清空了用户业务数据（users, rooms, messages 等）"
echo "- 保留了系统配置数据（admin_users, storage_providers 等）"
echo "- 所有表结构保持不变"
