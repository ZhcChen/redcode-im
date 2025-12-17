#!/bin/bash
# 验证 sql/base.sql 文件的完整性（历史脚本，保留以兼容旧流程）

echo "========================================="
echo "验证 sql/base.sql 文件完整性"
echo "========================================="
echo ""

# 检查文件是否存在
if [ ! -f "sql/base.sql" ]; then
    echo "❌ 错误：sql/base.sql 文件不存在！"
    exit 1
fi

echo "✅ 文件存在：sql/base.sql"
echo ""

# 检查文件行数
line_count=$(wc -l < sql/base.sql)
echo "📊 文件行数：$line_count 行"
echo ""

# 检查关键表是否存在
echo "🔍 检查关键表定义："
tables=(
    "admin_users"
    "users"
    "permissions"
    "roles"
    "rooms"
    "messages"
    "ipinfo_tokens"
    "user_geolocations"
    "user_login_history"
    "emoji_packs"
    "hot_update_events"
)

for table in "${tables[@]}"; do
    if grep -q "CREATE TABLE.*$table" sql/base.sql; then
        echo "  ✅ $table"
    else
        echo "  ❌ $table (缺失)"
    fi
done

echo ""

# 检查关键插入语句
echo "🔍 检查关键数据插入："
inserts=(
    "INSERT INTO permissions"
    "INSERT INTO roles"
    "INSERT INTO admin_users"
)

for insert in "${inserts[@]}"; do
    if grep -q "$insert" sql/base.sql; then
        echo "  ✅ $insert"
    else
        echo "  ❌ $insert (缺失)"
    fi
done

echo ""

# 检查事务控制
echo "🔍 检查事务控制："
if grep -q "BEGIN;" sql/base.sql; then
    echo "  ✅ 事务开始 (BEGIN)"
else
    echo "  ❌ 事务开始 (缺失)"
fi

if grep -q "COMMIT;" sql/base.sql; then
    echo "  ✅ 事务提交 (COMMIT)"
else
    echo "  ❌ 事务提交 (缺失)"
fi

echo ""

# 检查默认管理员账号
echo "🔍 检查默认管理员账号："
if grep -q "username.*admin" sql/base.sql; then
    echo "  ✅ 默认管理员账号："
    echo "     用户名：admin"
    echo "     邮箱：admin@redcode-im.com"
    echo "     密码：admin123"
else
    echo "  ❌ 默认管理员账号 (缺失)"
fi

echo ""

# 检查备份文件
echo "📋 相关文件："
echo "  📄 sql/base.sql - 主文件"
echo "  📄 sql/base.sql.backup.20251201_151535 - 历史备份文件"
echo ""

# 总结
echo "========================================="
echo "✅ 验证完成！"
echo "========================================="
echo ""
echo "📌 使用方法："
echo "  1. 创建数据库："
echo "     createdb -h localhost -U postgres redcode_im"
echo ""
echo "  2. 初始化数据："
echo "     psql -h localhost -U postgres -d redcode_im -f sql/base.sql"
echo ""
echo "  3. 登录管理后台："
echo "     用户名：admin"
echo "     密码：admin123"
echo ""
echo "⚠️  注意：首次登录后请立即修改默认密码！"
