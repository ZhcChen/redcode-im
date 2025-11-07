-- 创建权限管理相关表
-- 20251107160000_create_permissions_and_roles.sql

-- 创建权限表
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建角色表
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_system BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 创建角色权限关联表
CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, permission_id)
);

-- 创建用户角色关联表
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES users(id),
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, role_id)
);

-- 插入基础权限
INSERT INTO permissions (name, code, description) VALUES
('查看用户', 'user:view', '查看用户列表和详情'),
('创建用户', 'user:create', '创建新用户'),
('更新用户', 'user:update', '更新用户信息'),
('删除用户', 'user:delete', '删除用户'),
('查看角色', 'role:view', '查看角色列表和权限'),
('创建角色', 'role:create', '创建新角色'),
('更新角色', 'role:update', '更新角色信息和权限'),
('删除角色', 'role:delete', '删除角色'),
('系统监控', 'system:monitor', '查看系统监控数据'),
('系统统计', 'system:stats', '查看系统统计信息'),
('设置管理', 'settings:manage', '管理系统设置'),
('文件查看', 'file:view', '查看文件列表和统计'),
('文件管理', 'file:manage', '管理文件（删除等操作）'),
('存储管理', 'storage:manage', '管理存储提供商和设置')
ON CONFLICT (code) DO NOTHING;

-- 插入系统角色
INSERT INTO roles (name, code, description, is_system) VALUES
('超级管理员', 'super_admin', '拥有所有权限的超级管理员', TRUE),
('管理员', 'admin', '拥有大部分管理权限的管理员', TRUE),
('审计员', 'auditor', '只能查看数据，不能修改', TRUE),
('普通用户', 'user', '普通用户角色', TRUE)
ON CONFLICT (code) DO NOTHING;

-- 为超级管理员角色分配所有权限
INSERT INTO role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM roles WHERE code = 'super_admin'),
    id
FROM permissions
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 为管理员角色分配大部分权限（除了角色管理和用户删除）
INSERT INTO role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM roles WHERE code = 'admin'),
    id
FROM permissions
WHERE code NOT IN ('user:delete', 'role:create', 'role:update', 'role:delete')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 为审计员角色分配查看权限
INSERT INTO role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM roles WHERE code = 'auditor'),
    id
FROM permissions
WHERE code IN ('user:view', 'role:view', 'system:monitor', 'system:stats', 'file:view')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_permissions_code ON permissions(code);
CREATE INDEX IF NOT EXISTS idx_roles_code ON roles(code);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id ON role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);

-- 创建更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_permissions_updated_at
    BEFORE UPDATE ON permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();