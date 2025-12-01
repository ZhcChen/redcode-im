#!/bin/bash
# 修复 storage_providers 等表的外键约束问题
# 数据清理后，这些表引用了已删除的 users 表，需要改为引用 admin_users 表

set -e

DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-redcode_im}
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-123456}

echo "正在修复 storage_providers 等表的外键约束..."

# 执行修复 SQL
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
-- 修复 storage_providers 表的 updated_by 外键约束
ALTER TABLE storage_providers DROP CONSTRAINT IF EXISTS storage_providers_updated_by_fkey;
ALTER TABLE storage_providers
ADD CONSTRAINT storage_providers_updated_by_fkey
FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 修复 app_documents 表
ALTER TABLE app_documents DROP CONSTRAINT IF EXISTS app_documents_updated_by_fkey;
ALTER TABLE app_documents
ADD CONSTRAINT app_documents_updated_by_fkey
FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 修复 general_settings 表
ALTER TABLE general_settings DROP CONSTRAINT IF EXISTS general_settings_updated_by_fkey;
ALTER TABLE general_settings
ADD CONSTRAINT general_settings_updated_by_fkey
FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 修复 captcha_settings 表
ALTER TABLE captcha_settings DROP CONSTRAINT IF EXISTS captcha_settings_updated_by_fkey;
ALTER TABLE captcha_settings
ADD CONSTRAINT captcha_settings_updated_by_fkey
FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 修复 group_settings 表（如果也存在同样问题）
ALTER TABLE group_settings DROP CONSTRAINT IF EXISTS group_settings_global_mute_set_by_fkey;
ALTER TABLE group_settings
ADD CONSTRAINT group_settings_global_mute_set_by_fkey
FOREIGN KEY (global_mute_set_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 修复 group_announcements 表
ALTER TABLE group_announcements DROP CONSTRAINT IF EXISTS group_announcements_publisher_id_fkey;
ALTER TABLE group_announcements
ADD CONSTRAINT group_announcements_publisher_id_fkey
FOREIGN KEY (publisher_id) REFERENCES users(id) ON DELETE CASCADE;

-- 修复 group_rules 表
ALTER TABLE group_rules DROP CONSTRAINT IF EXISTS group_rules_creator_id_fkey;
ALTER TABLE group_rules
ADD CONSTRAINT group_rules_creator_id_fkey
FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE;

-- 修复 join_requests 表
ALTER TABLE join_requests DROP CONSTRAINT IF EXISTS join_requests_reviewer_id_fkey;
ALTER TABLE join_requests
ADD CONSTRAINT join_requests_reviewer_id_fkey
FOREIGN KEY (reviewer_id) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 修复 group_invitations 表（这个可能不需要改，因为它是用户操作）

-- 修复 group_admins 表
ALTER TABLE group_admins DROP CONSTRAINT IF EXISTS group_admins_appointed_by_fkey;
ALTER TABLE group_admins
ADD CONSTRAINT group_admins_appointed_by_fkey
FOREIGN KEY (appointed_by) REFERENCES users(id) ON DELETE CASCADE;

-- 修复 group_operation_logs 表
ALTER TABLE group_operation_logs DROP CONSTRAINT IF EXISTS group_operation_logs_operator_id_fkey;
ALTER TABLE group_operation_logs
ADD CONSTRAINT group_operation_logs_operator_id_fkey
FOREIGN KEY (operator_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE group_operation_logs DROP CONSTRAINT IF EXISTS group_operation_logs_target_user_id_fkey;
ALTER TABLE group_operation_logs
ADD CONSTRAINT group_operation_logs_target_user_id_fkey
FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE SET NULL;

-- 修复 group_mutes 表
ALTER TABLE group_mutes DROP CONSTRAINT IF EXISTS group_mutes_muted_by_fkey;
ALTER TABLE group_mutes
ADD CONSTRAINT group_mutes_muted_by_fkey
FOREIGN KEY (muted_by) REFERENCES users(id) ON DELETE CASCADE;

-- 修复 user_roles 表
ALTER TABLE user_roles DROP CONSTRAINT IF EXISTS user_roles_assigned_by_fkey;
ALTER TABLE user_roles
ADD CONSTRAINT user_roles_assigned_by_fkey
FOREIGN KEY (assigned_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 修复 permissions/roles 表（这些是系统配置，应该不清理，但可能也被 users.id 引用）

-- 更新表注释
COMMENT ON COLUMN storage_providers.updated_by IS '更新者管理员ID（引用 admin_users 表）';
COMMENT ON COLUMN app_documents.updated_by IS '更新者管理员ID（引用 admin_users 表）';
COMMENT ON COLUMN general_settings.updated_by IS '更新者管理员ID（引用 admin_users 表）';
COMMENT ON COLUMN captcha_settings.updated_by IS '更新者管理员ID（引用 admin_users 表）';

SELECT '外键约束修复完成' AS status;
EOF

echo "✅ 外键约束修复完成！"
echo ""
echo "现在您可以重新启动后端服务并测试添加存储提供商功能了。"
echo ""
echo "如果遇到问题，请检查："
echo "1. 确保 PostgreSQL 服务正在运行"
echo "2. 确保数据库连接参数正确"
echo "3. 查看后端日志获取更详细的错误信息"
