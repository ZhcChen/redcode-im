-- 创建管理后台用户表
-- 分离管理后台用户和普通用户，避免账号体系混乱

BEGIN;

-- 管理后台用户表
CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(100),
    avatar_url TEXT,
    status SMALLINT NOT NULL DEFAULT 0,                    -- 0=active,1=inactive,2=banned,3=locked
    last_login_at TIMESTAMPTZ,
    login_attempts SMALLINT NOT NULL DEFAULT 0,           -- 登录失败次数
    locked_until TIMESTAMPTZ,                              -- 账户锁定到期时间
    require_password_change BOOLEAN NOT NULL DEFAULT FALSE,-- 是否需要强制修改密码
    password_changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),-- 密码最后修改时间
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_admin_users_username ON admin_users(username);
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON admin_users(email);
CREATE INDEX IF NOT EXISTS idx_admin_users_status ON admin_users(status);
CREATE INDEX IF NOT EXISTS idx_admin_users_deleted_at ON admin_users(deleted_at);
CREATE INDEX IF NOT EXISTS idx_admin_users_locked_until ON admin_users(locked_until);
CREATE INDEX IF NOT EXISTS idx_admin_users_last_login_at ON admin_users(last_login_at);

-- 支持搜索接口对 username/email/nickname 的模糊匹配
CREATE INDEX IF NOT EXISTS idx_admin_users_username_lower ON admin_users ((LOWER(username)));
CREATE INDEX IF NOT EXISTS idx_admin_users_email_lower ON admin_users ((LOWER(email)));
CREATE INDEX IF NOT EXISTS idx_admin_users_nickname_lower ON admin_users ((LOWER(COALESCE(nickname, ''))));

-- 管理员角色关联表（复用现有的 roles 和 permissions 表）
CREATE TABLE IF NOT EXISTS admin_user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES admin_users(id),          -- 只能由管理员分配
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(admin_user_id, role_id)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_admin_user_roles_admin_user_id ON admin_user_roles(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_user_roles_role_id ON admin_user_roles(role_id);

-- 管理员登录历史表（用于审计）
CREATE TABLE IF NOT EXISTS admin_login_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
    ip_address INET,
    user_agent TEXT,
    login_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    logout_at TIMESTAMPTZ,
    success BOOLEAN NOT NULL DEFAULT TRUE,
    failure_reason TEXT
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_admin_login_history_admin_user_id ON admin_login_history(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_login_history_login_at ON admin_login_history(login_at);
CREATE INDEX IF NOT EXISTS idx_admin_login_history_ip_address ON admin_login_history(ip_address);

-- 管理员操作日志表（用于审计）
CREATE TABLE IF NOT EXISTS admin_operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    operation VARCHAR(100) NOT NULL,                      -- 操作类型，如 create_user, update_role 等
    resource_type VARCHAR(50),                            -- 资源类型，如 user, role, permission 等
    resource_id UUID,                                     -- 资源ID
    details JSONB,                                        -- 操作详情
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_admin_operation_logs_admin_user_id ON admin_operation_logs(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_operation_logs_operation ON admin_operation_logs(operation);
CREATE INDEX IF NOT EXISTS idx_admin_operation_logs_created_at ON admin_operation_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_operation_logs_resource_type_id ON admin_operation_logs(resource_type, resource_id);

COMMIT;
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
