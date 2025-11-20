-- 迁移管理员用户数据
-- 将现有具有管理员角色的用户从 users 表迁移到 admin_users 表

BEGIN;

-- 创建默认管理员用户（如果不存在）
INSERT INTO admin_users (
    username,
    email,
    password_hash,
    nickname,
    status,
    require_password_change,
    password_changed_at
) VALUES (
    'admin',
    'admin@redcode-im.com',
    -- 密码: admin123 (bcrypt hash)
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeUQK8QYj2KQgFJqO',
    '系统管理员',
    0, -- AdminUserStatus::Active
    false,
    CURRENT_TIMESTAMP
) ON CONFLICT (username) DO NOTHING;

-- 将具有管理员角色的用户迁移到 admin_users 表
-- 注意：这是一个基础迁移，实际迁移逻辑可能需要根据具体情况调整
INSERT INTO admin_users (
    username,
    email,
    password_hash,
    nickname,
    avatar_url,
    status,
    require_password_change,
    password_changed_at
)
SELECT
    u.username,
    u.email,
    u.password_hash,
    u.nickname,
    u.avatar_url,
    CASE
        WHEN u.status = 0 THEN 0 -- Active
        WHEN u.status = 1 THEN 1 -- Inactive
        WHEN u.status = 2 THEN 2 -- Banned
        ELSE 0 -- Default to Active
    END as status,
    false as require_password_change,
    CURRENT_TIMESTAMP as password_changed_at
FROM users u
INNER JOIN user_roles ur ON u.id = ur.user_id
INNER JOIN roles r ON ur.role_id = r.id
WHERE r.code IN ('super_admin', 'admin', 'administrator')
  AND u.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM admin_users au WHERE au.username = u.username
  );

-- 将迁移的用户的角色关系复制到 admin_user_roles 表
INSERT INTO admin_user_roles (
    admin_user_id,
    role_id,
    assigned_by,
    assigned_at
)
SELECT
    au.id as admin_user_id,
    ur.role_id,
    ur.assigned_by,
    ur.assigned_at
FROM admin_users au
INNER JOIN users u ON au.username = u.username
INNER JOIN user_roles ur ON u.id = ur.user_id
WHERE au.created_at >= CURRENT_TIMESTAMP - INTERVAL '1 minute' -- 只处理刚迁移的用户
  AND NOT EXISTS (
      SELECT 1 FROM admin_user_roles aur WHERE aur.admin_user_id = au.id AND aur.role_id = ur.role_id
  );

COMMIT;

-- 回滚脚本（如果需要）
-- 注意：这个回滚脚本是不可逆的，因为无法确定哪些数据是迁移产生的
-- 在生产环境中执行前，请务必备份数据

/*
-- ROLLBACK (谨慎使用，只在开发环境测试)
BEGIN;
-- 删除迁移产生的管理员用户（除了默认管理员）
DELETE FROM admin_user_roles WHERE admin_user_id IN (
    SELECT id FROM admin_users WHERE username != 'admin'
);
DELETE FROM admin_users WHERE username != 'admin';
COMMIT;
*/
