-- 清空所有表数据（保留表结构）
-- 仅清理用户业务数据，保留系统配置

-- 开始事务
BEGIN;

-- 禁用外键检查（某些情况下可能有循环引用）
SET session_replication_role = replica;

-- 按外键依赖顺序清空表
TRUNCATE TABLE IF EXISTS message_parts CASCADE;
TRUNCATE TABLE IF EXISTS message_reads CASCADE;
TRUNCATE TABLE IF EXISTS group_operation_logs CASCADE;
TRUNCATE TABLE IF EXISTS group_mutes CASCADE;
TRUNCATE TABLE IF EXISTS group_admins CASCADE;
TRUNCATE TABLE IF EXISTS group_invitations CASCADE;
TRUNCATE TABLE IF EXISTS join_requests CASCADE;
TRUNCATE TABLE IF EXISTS group_rules CASCADE;
TRUNCATE TABLE IF EXISTS group_announcements CASCADE;
TRUNCATE TABLE IF EXISTS group_settings CASCADE;
TRUNCATE TABLE IF EXISTS room_members CASCADE;
TRUNCATE TABLE IF EXISTS user_room_pins CASCADE;
TRUNCATE TABLE IF EXISTS room_pins CASCADE;
TRUNCATE TABLE IF EXISTS messages CASCADE;
TRUNCATE TABLE IF EXISTS user_friend_remarks CASCADE;
TRUNCATE TABLE IF EXISTS friend_requests CASCADE;
TRUNCATE TABLE IF EXISTS friendships CASCADE;
TRUNCATE TABLE IF EXISTS user_roles CASCADE;
TRUNCATE TABLE IF EXISTS user_login_history CASCADE;
TRUNCATE TABLE IF EXISTS feedbacks CASCADE;
TRUNCATE TABLE IF EXISTS rooms CASCADE;
TRUNCATE TABLE IF EXISTS users CASCADE;

-- 重新启用外键检查
SET session_replication_role = DEFAULT;

-- 提交事务
COMMIT;

-- 输出结果
SELECT 'All user data truncated successfully!' AS status;
