-- 全量结构与基础数据初始化脚本
-- 说明：
--  1. 使用整数字段表示业务状态，具体取值由应用代码维护并校验。
--  2. 本脚本可在空库上直接执行，初始化当前功能所需的全部表结构和基础数据。
--  3. 各表的 updated_at 字段由应用层负责赋值，数据库不再通过触发器自动维护。

BEGIN;

-- ===== 管理后台用户体系（最底层，被其他表引用）=====

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

-- ===== 权限与角色体系 =====

-- 权限表
CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 角色表
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_system BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 角色权限关联表
CREATE TABLE IF NOT EXISTS role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(role_id, permission_id)
);

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(100),
    avatar_url TEXT,
    avatar_object_key TEXT,
    status SMALLINT NOT NULL DEFAULT 0,            -- 0=active,1=inactive,2=banned
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users(deleted_at);
-- 支持搜索接口对 username/email/nickname 的模糊匹配（LOWER(...) LIKE）
CREATE INDEX IF NOT EXISTS idx_users_username_lower ON users ((LOWER(username)));
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users ((LOWER(email)));
CREATE INDEX IF NOT EXISTS idx_users_nickname_lower ON users ((LOWER(COALESCE(nickname, ''))));

-- 版本管理表（在数据清理时保留）
CREATE TABLE IF NOT EXISTS app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL,
    version TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    channel TEXT NOT NULL DEFAULT 'stable',
    download_key TEXT NOT NULL,
    download_url TEXT,
    file_size BIGINT,
    checksum TEXT,
    signature TEXT,
    release_notes TEXT,
    mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    released_at TIMESTAMPTZ,
    created_by UUID,
    updated_by UUID,
    CONSTRAINT app_versions_platform_check
        CHECK (platform IN ('windows', 'macos', 'ios', 'android', 'linux'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_app_versions_unique
    ON app_versions(platform, channel, version);

CREATE INDEX IF NOT EXISTS idx_app_versions_list
    ON app_versions(platform, is_active, released_at DESC);

COMMENT ON COLUMN app_versions.platform IS
    '支持平台: windows(Windows桌面), macos(macOS桌面), ios(iOS移动端), android(Android移动端), linux(Linux桌面)';

-- 文档表
CREATE TABLE IF NOT EXISTS app_documents (
    key TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_app_documents_updated_at
    ON app_documents(updated_at DESC);

-- 验证码配置
CREATE TABLE IF NOT EXISTS captcha_settings (
    key TEXT PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    captcha_code TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    require_captcha_for_login BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL
);

-- 通用设置表
CREATE TABLE IF NOT EXISTS general_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL
);

-- 文件上传提供商配置表（在数据清理时保留）
CREATE TABLE IF NOT EXISTS storage_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_type SMALLINT NOT NULL DEFAULT 1,  -- 0=unknown, 1=tencent_cos, 2=aliyun_oss, 3=aws_s3, 4=minio
    name VARCHAR(100) NOT NULL,                 -- 提供商名称（用于显示）
    secret_id TEXT NOT NULL,                    -- 密钥ID（Access Key ID）
    secret_key TEXT NOT NULL,                   -- 密钥Key（Secret Access Key）
    region VARCHAR(50) NOT NULL,                 -- 地域（如 ap-beijing）
    endpoint TEXT NOT NULL,                      -- 端点域名（如 cos.ap-beijing.myqcloud.com）
    bucket_name VARCHAR(100),                    -- 存储桶名称（可选，某些场景需要）
    is_active BOOLEAN NOT NULL DEFAULT FALSE,    -- 是否启用
    is_default BOOLEAN NOT NULL DEFAULT FALSE,   -- 是否为默认提供商
    description TEXT,                           -- 描述信息
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_storage_providers_type ON storage_providers(provider_type);
CREATE INDEX IF NOT EXISTS idx_storage_providers_active ON storage_providers(is_active);
CREATE INDEX IF NOT EXISTS idx_storage_providers_default ON storage_providers(is_default);

-- 确保只有一个默认提供商
CREATE UNIQUE INDEX IF NOT EXISTS idx_storage_providers_unique_default
    ON storage_providers(is_default)
    WHERE is_default = TRUE;

-- 用户角色关联表
CREATE TABLE IF NOT EXISTS user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, role_id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);

-- 索引
CREATE INDEX IF NOT EXISTS idx_permissions_code ON permissions(code);
CREATE INDEX IF NOT EXISTS idx_roles_code ON roles(code);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id ON role_permissions(permission_id);

-- 更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_permissions_updated_at
    BEFORE UPDATE ON permissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_roles_updated_at
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===== 业务数据表 =====

-- 房间表
CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    avatar_url TEXT,
    avatar_object_key TEXT,
    room_type SMALLINT NOT NULL DEFAULT 1,         -- 0=private,1=group,2=public,3=favorite
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_rooms_owner_id ON rooms(owner_id);
CREATE INDEX IF NOT EXISTS idx_rooms_type ON rooms(room_type);
CREATE INDEX IF NOT EXISTS idx_rooms_deleted_at ON rooms(deleted_at);

-- 消息表
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    message_type SMALLINT NOT NULL DEFAULT 0,      -- 0=text,1=image,2=file,3=system
    quoted_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
    forward_from_message_id UUID,
    forward_from_room_id UUID,
    forward_from_sender_id UUID,
    forward_from_sender_username TEXT,
    forward_from_sender_nickname TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_messages_room_id ON messages(room_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_messages_deleted_at ON messages(deleted_at);
CREATE INDEX IF NOT EXISTS idx_messages_room_created_at
    ON messages(room_id, created_at)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_messages_quoted_message_id ON messages(quoted_message_id);
CREATE INDEX IF NOT EXISTS idx_messages_forward_from_message
    ON messages(forward_from_message_id)
    WHERE forward_from_message_id IS NOT NULL;

-- 房间置顶表（支持每个房间多条消息置顶）
CREATE TABLE IF NOT EXISTS room_pins (
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    pinned_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT room_pins_pkey PRIMARY KEY (room_id, message_id)
);

CREATE INDEX IF NOT EXISTS idx_room_pins_message_id ON room_pins(message_id);

-- 房间成员表
CREATE TABLE IF NOT EXISTS room_members (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role SMALLINT NOT NULL DEFAULT 2,              -- 0=owner,1=admin,2=member
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_read_at TIMESTAMPTZ,
    last_read_message_id UUID REFERENCES messages(id),
    notification_settings INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_room_members_room_id ON room_members(room_id);
CREATE INDEX IF NOT EXISTS idx_room_members_user_id ON room_members(user_id);
CREATE INDEX IF NOT EXISTS idx_room_members_role ON room_members(role);
CREATE INDEX IF NOT EXISTS idx_room_members_deleted_at ON room_members(deleted_at);
CREATE INDEX IF NOT EXISTS idx_room_members_last_read_at ON room_members(last_read_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_room_members_unique_active
    ON room_members(room_id, user_id)
    WHERE deleted_at IS NULL;
-- 常用过滤为 user_id 且仅取未删除成员
CREATE INDEX IF NOT EXISTS idx_room_members_user_active
    ON room_members(user_id)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_room_members_notification_settings
    ON room_members(notification_settings);
COMMENT ON COLUMN room_members.notification_settings IS '通知设置：0=全部通知，1=仅@通知，2=完全静音';

-- 消息已读表
CREATE TABLE IF NOT EXISTS message_reads (
    id UUID PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_message_reads_message_id ON message_reads(message_id);
CREATE INDEX IF NOT EXISTS idx_message_reads_user_id ON message_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_message_reads_room_id ON message_reads(room_id);
CREATE INDEX IF NOT EXISTS idx_message_reads_read_at ON message_reads(read_at);
CREATE INDEX IF NOT EXISTS idx_message_reads_user_room ON message_reads(user_id, room_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_reads_unique_message_user
    ON message_reads(message_id, user_id);
CREATE INDEX IF NOT EXISTS idx_message_reads_room_user_message
    ON message_reads(room_id, user_id, message_id);
-- 加速 "按 message_id 查询已读用户并按 read_at 排序" 的路径
CREATE INDEX IF NOT EXISTS idx_message_reads_message_read_at
    ON message_reads(message_id, read_at);

-- 消息分片表
CREATE TABLE IF NOT EXISTS message_parts (
    id UUID PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    position SMALLINT NOT NULL,
    part_type SMALLINT NOT NULL,
    text_content TEXT,
    attachment_key TEXT,
    attachment_name TEXT,
    attachment_mime TEXT,
    attachment_size BIGINT,
    width INTEGER,
    height INTEGER,
    duration_ms INTEGER,
    thumbnail_key TEXT,
    extra JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_message_parts_message_id_position
    ON message_parts(message_id, position);

-- 好友请求表
CREATE TABLE IF NOT EXISTS friend_requests (
    id UUID PRIMARY KEY,
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status SMALLINT NOT NULL DEFAULT 0,            -- 0=pending,1=accepted,2=declined
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    UNIQUE (requester_id, addressee_id),
    CHECK (requester_id <> addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_addressee ON friend_requests(addressee_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_requester ON friend_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_status ON friend_requests(status);
-- 加速按方向+状态的列表与分页
CREATE INDEX IF NOT EXISTS idx_friend_requests_req_status_created
    ON friend_requests(requester_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_friend_requests_add_status_created
    ON friend_requests(addressee_id, status, created_at DESC);

-- 好友关系表
CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY,
    user_a_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_a_id, user_b_id),
    CHECK (user_a_id <> user_b_id AND user_a_id::text < user_b_id::text)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user_a ON friendships(user_a_id);
CREATE INDEX IF NOT EXISTS idx_friendships_user_b ON friendships(user_b_id);

-- 好友备注表（按用户维度存储）
CREATE TABLE IF NOT EXISTS user_friend_remarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    remark TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, friend_user_id),
    CHECK (user_id <> friend_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_friend_remarks_user_id
    ON user_friend_remarks(user_id)
    WHERE remark <> '';

-- 用户反馈表
CREATE TABLE IF NOT EXISTS feedbacks (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact TEXT,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feedbacks_user_id ON feedbacks(user_id);
CREATE INDEX IF NOT EXISTS idx_feedbacks_created_at
    ON feedbacks(created_at DESC);

-- ===== 群聊管理扩展 =====

CREATE TABLE IF NOT EXISTS group_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    join_approval_required BOOLEAN NOT NULL DEFAULT FALSE,
    member_can_invite BOOLEAN NOT NULL DEFAULT TRUE,
    member_can_add_friends BOOLEAN NOT NULL DEFAULT TRUE,
    require_admin_to_add_friends BOOLEAN NOT NULL DEFAULT FALSE,
    max_members INTEGER NOT NULL DEFAULT 500,
    global_mute_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    global_mute_until TIMESTAMPTZ,
    global_mute_reason TEXT,
    global_mute_set_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(room_id)
);

CREATE TABLE IF NOT EXISTS group_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    publisher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_pinned BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS group_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    applicant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT,
    status INTEGER NOT NULL DEFAULT 0,
    reviewer_id UUID REFERENCES users(id),
    review_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    UNIQUE(room_id, applicant_id)
);

CREATE TABLE IF NOT EXISTS group_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT,
    status INTEGER NOT NULL DEFAULT 0,
    invited_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days'),
    UNIQUE(room_id, invitee_id)
);

CREATE TABLE IF NOT EXISTS group_admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    admin_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    appointed_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'admin',
    permissions TEXT[],
    appointed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(room_id, admin_id)
);

CREATE TABLE IF NOT EXISTS group_operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    operator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES users(id),
    operation_type VARCHAR(50) NOT NULL,
    operation_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS group_mutes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    muted_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT,
    mute_duration_hours INTEGER DEFAULT 24,
    muted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    unmuted_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(room_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_settings_room_id ON group_settings(room_id);
CREATE INDEX IF NOT EXISTS idx_group_announcements_room_id ON group_announcements(room_id);
CREATE INDEX IF NOT EXISTS idx_group_announcements_pinned ON group_announcements(is_pinned);
CREATE INDEX IF NOT EXISTS idx_group_rules_room_id ON group_rules(room_id);
CREATE INDEX IF NOT EXISTS idx_group_rules_active ON group_rules(is_active);
CREATE INDEX IF NOT EXISTS idx_join_requests_room_id ON join_requests(room_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_status ON join_requests(status);
CREATE INDEX IF NOT EXISTS idx_group_invitations_room_id ON group_invitations(room_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_status ON group_invitations(status);
CREATE INDEX IF NOT EXISTS idx_group_settings_global_mute ON group_settings(global_mute_enabled);
CREATE INDEX IF NOT EXISTS idx_group_admins_room_id ON group_admins(room_id);
CREATE INDEX IF NOT EXISTS idx_group_admins_admin_id ON group_admins(admin_id);
CREATE INDEX IF NOT EXISTS idx_group_operation_logs_room_id ON group_operation_logs(room_id);
CREATE INDEX IF NOT EXISTS idx_group_operation_logs_created_at ON group_operation_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_group_mutes_room_id ON group_mutes(room_id);
CREATE INDEX IF NOT EXISTS idx_group_mutes_user_id ON group_mutes(user_id);
CREATE INDEX IF NOT EXISTS idx_group_mutes_active ON group_mutes(is_active);

CREATE TRIGGER update_group_settings_updated_at
    BEFORE UPDATE ON group_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_announcements_updated_at
    BEFORE UPDATE ON group_announcements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_rules_updated_at
    BEFORE UPDATE ON group_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 用户房间置顶表 (用于用户级别的聊天置顶功能)
CREATE TABLE IF NOT EXISTS user_room_pins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notification_settings JSONB,
    UNIQUE(user_id, room_id)
);

CREATE INDEX IF NOT EXISTS idx_user_room_pins_user_id ON user_room_pins(user_id);
CREATE INDEX IF NOT EXISTS idx_user_room_pins_room_id ON user_room_pins(room_id);
CREATE INDEX IF NOT EXISTS idx_user_room_pins_pinned_at ON user_room_pins(pinned_at);

-- ===== 管理后台用户体系（续）=====

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

CREATE INDEX IF NOT EXISTS idx_admin_login_history_admin_user_id ON admin_login_history(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_login_history_login_at ON admin_login_history(login_at);

-- 管理员操作日志表
CREATE TABLE IF NOT EXISTS admin_operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    operation VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_operation_logs_admin_user_id ON admin_operation_logs(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_operation_logs_created_at ON admin_operation_logs(created_at);

-- ===== 从迁移文件合并的额外表 =====

-- ipinfo.io API Token 池管理表
CREATE TABLE IF NOT EXISTS ipinfo_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE, -- Token 名称/标识
    token VARCHAR(200) NOT NULL UNIQUE, -- API Token
    monthly_limit INTEGER NOT NULL DEFAULT 50000, -- 月额度限制
    used_count INTEGER NOT NULL DEFAULT 0, -- 已使用次数
    reset_date DATE NOT NULL DEFAULT CURRENT_DATE, -- 重置日期（每月1号）
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'exhausted')),
    last_used_at TIMESTAMPTZ, -- 最后使用时间
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ipinfo_tokens_status ON ipinfo_tokens(status);
CREATE INDEX IF NOT EXISTS idx_ipinfo_tokens_reset_date ON ipinfo_tokens(reset_date);
CREATE INDEX IF NOT EXISTS idx_ipinfo_tokens_last_used_at ON ipinfo_tokens(last_used_at);

-- 用户地理位置表（每个用户一条最新记录）
CREATE TABLE IF NOT EXISTS user_geolocations (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    country VARCHAR(100),
    region VARCHAR(100),
    city VARCHAR(100),
    isp VARCHAR(200),
    timezone VARCHAR(50),
    zip_code VARCHAR(20),
    geolocation_source VARCHAR(50) DEFAULT 'ipinfo', -- 数据来源
    hostname TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_geolocations_ip ON user_geolocations(ip_address);
CREATE INDEX IF NOT EXISTS idx_user_geolocations_country ON user_geolocations(country);
CREATE INDEX IF NOT EXISTS idx_user_geolocations_updated_at ON user_geolocations(updated_at);
CREATE INDEX IF NOT EXISTS idx_user_geolocations_city ON user_geolocations(city);

COMMENT ON COLUMN user_geolocations.hostname IS '主机名，从ipinfo.io获取';

-- 用户登录历史表（用于审计和安全分析）
CREATE TABLE IF NOT EXISTS user_login_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    user_agent TEXT,
    login_method VARCHAR(50) NOT NULL DEFAULT 'websocket', -- websocket, api, etc.
    login_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    logout_at TIMESTAMPTZ,
    session_duration INTERVAL GENERATED ALWAYS AS (logout_at - login_at) STORED,
    success BOOLEAN NOT NULL DEFAULT TRUE,
    failure_reason TEXT,
    device_info JSONB, -- 存储设备信息，如操作系统、浏览器等
    location_info JSONB -- 存储地理位置信息（可选，通过IP解析获得）
);

CREATE INDEX IF NOT EXISTS idx_user_login_history_user_id ON user_login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_user_login_history_login_at ON user_login_history(login_at);
CREATE INDEX IF NOT EXISTS idx_user_login_history_ip_address ON user_login_history(ip_address);
CREATE INDEX IF NOT EXISTS idx_user_login_history_success ON user_login_history(success);
CREATE INDEX IF NOT EXISTS idx_user_login_history_logout_at ON user_login_history(logout_at) WHERE logout_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_login_history_user_login_at
    ON user_login_history(user_id, login_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_login_history_ip_login_at
    ON user_login_history(ip_address, login_at DESC);

-- 用户心跳记录表（记录用户在线状态和IP变化）
CREATE TABLE IF NOT EXISTS user_heartbeat_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET NOT NULL,
    user_agent TEXT,
    connection_id TEXT NOT NULL, -- WebSocket连接ID
    heartbeat_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    node_id VARCHAR(100), -- 节点ID（用于分布式部署）
    device_info JSONB
);

CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_user_id ON user_heartbeat_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_heartbeat_at ON user_heartbeat_logs(heartbeat_at);
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_ip_address ON user_heartbeat_logs(ip_address);
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_connection_id ON user_heartbeat_logs(connection_id);
CREATE INDEX IF NOT EXISTS idx_user_heartbeat_logs_user_heartbeat_at
    ON user_heartbeat_logs(user_id, heartbeat_at DESC);

-- 表情包表
CREATE TABLE IF NOT EXISTS emoji_packs (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    icon_url TEXT,
    description TEXT,
    pack_type SMALLINT NOT NULL DEFAULT 0,  -- 0=单个, 1=套件
    parent_id UUID REFERENCES emoji_packs(id) ON DELETE CASCADE,
    is_active SMALLINT NOT NULL DEFAULT 1,  -- 0=inactive, 1=active
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 表情项表
CREATE TABLE IF NOT EXISTS emoji_items (
    id UUID PRIMARY KEY,
    pack_id UUID NOT NULL REFERENCES emoji_packs(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    name VARCHAR(100),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 用户表情包关联表
CREATE TABLE IF NOT EXISTS user_emoji_packs (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pack_id UUID NOT NULL REFERENCES emoji_packs(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, pack_id)
);

CREATE INDEX IF NOT EXISTS idx_emoji_packs_is_active ON emoji_packs(is_active);
CREATE INDEX IF NOT EXISTS idx_emoji_packs_pack_type ON emoji_packs(pack_type);
CREATE INDEX IF NOT EXISTS idx_emoji_packs_parent_id ON emoji_packs(parent_id);
CREATE INDEX IF NOT EXISTS idx_emoji_items_pack_id ON emoji_items(pack_id);
CREATE INDEX IF NOT EXISTS idx_emoji_items_sort_order ON emoji_items(pack_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_user_emoji_packs_user_id ON user_emoji_packs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_emoji_packs_pack_id ON user_emoji_packs(pack_id);

-- 热更新补丁表（Flutter/移动端增量包）
CREATE TABLE IF NOT EXISTS hot_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL,
    app_version_id UUID NOT NULL REFERENCES app_versions(id) ON DELETE CASCADE,
    patch_version TEXT NOT NULL,
    channel TEXT NOT NULL DEFAULT 'stable',
    download_key TEXT NOT NULL,
    download_url TEXT,
    file_size BIGINT,
    checksum TEXT,
    signature TEXT,
    rollout_percentage INTEGER NOT NULL DEFAULT 100 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),
    mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    released_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_hot_updates_unique
    ON hot_updates(app_version_id, patch_version);

CREATE INDEX IF NOT EXISTS idx_hot_updates_lookup
    ON hot_updates(platform, channel, is_active, released_at DESC NULLS LAST);

-- 热更新事件表
CREATE TABLE IF NOT EXISTS hot_update_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL,
    channel TEXT,
    base_version TEXT NOT NULL,
    patch_version TEXT NOT NULL,
    event_type TEXT NOT NULL,
    client_id TEXT,
    message TEXT,
    client_type TEXT,
    os_version TEXT,
    os_arch TEXT,
    app_arch TEXT,
    build_number INTEGER,
    trigger_source TEXT,
    network_type TEXT,
    device_info TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hot_update_events_created_at
    ON hot_update_events (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_hot_update_events_client_type
    ON hot_update_events (client_type);

CREATE INDEX IF NOT EXISTS idx_hot_update_events_platform_client_type
    ON hot_update_events (platform, client_type);

CREATE INDEX IF NOT EXISTS idx_hot_update_events_os_version
    ON hot_update_events (os_version);

COMMENT ON COLUMN hot_update_events.client_type IS '客户端类型：desktop（桌面端）或frontend（移动端）';
COMMENT ON COLUMN hot_update_events.os_version IS '操作系统版本，如：Windows 11, iOS 17.1, Android 13';
COMMENT ON COLUMN hot_update_events.os_arch IS '操作系统架构：x64, arm64, arm等';
COMMENT ON COLUMN hot_update_events.app_arch IS '应用架构：x64, arm64, arm等';
COMMENT ON COLUMN hot_update_events.build_number IS '构建号';
COMMENT ON COLUMN hot_update_events.trigger_source IS '触发来源：manual（手动）、auto（自动）、notification（通知）';
COMMENT ON COLUMN hot_update_events.network_type IS '网络类型：wifi, cellular, ethernet, unknown';
COMMENT ON COLUMN hot_update_events.device_info IS '设备详细信息摘要，如：platform:Win32,lang:zh-CN,cookies:true';

-- 创建清理过期数据的函数
CREATE OR REPLACE FUNCTION cleanup_old_user_logs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- 删除1年前的用户登录历史
    DELETE FROM user_login_history
    WHERE login_at < NOW() - INTERVAL '1 year';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- 删除3个月前的用户心跳记录
    DELETE FROM user_heartbeat_logs
    WHERE heartbeat_at < NOW() - INTERVAL '3 months';

    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_user_logs() IS '清理过期用户日志数据，保留最近1年的登录历史和3个月的心跳记录。建议设置为定时任务每月执行一次。';
COMMENT ON TABLE user_login_history IS '用户登录历史记录，用于审计和安全分析';
COMMENT ON TABLE user_heartbeat_logs IS '用户心跳记录，用于跟踪用户在线状态和IP变化';

-- ===== 插入初始数据 =====

-- 插入默认权限
INSERT INTO permissions (name, code, description) VALUES
('用户管理', 'user:manage', '管理用户账户'),
('角色管理', 'role:manage', '管理系统角色和权限'),
('群组管理', 'group:manage', '管理群组和群成员'),
('消息管理', 'message:manage', '管理聊天消息'),
('文件管理', 'file:manage', '管理文件上传和存储'),
('系统设置', 'system:settings', '管理系统配置'),
('数据分析', 'data:analysis', '查看系统数据和分析报告'),
('日志审计', 'log:audit', '查看系统日志和操作审计')
ON CONFLICT (code) DO NOTHING;

-- 插入默认角色
INSERT INTO roles (name, code, description, is_system) VALUES
('超级管理员', 'super_admin', '拥有所有权限的超级管理员', true),
('管理员', 'admin', '普通管理员，拥有大部分权限', true),
('运营人员', 'operator', '负责日常运营和用户管理', true)
ON CONFLICT (code) DO NOTHING;

-- 为超级管理员分配所有权限
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'super_admin'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 为管理员分配除超级权限外的所有权限
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'admin'
AND p.code != 'user:manage'  -- 管理员不能管理用户账户
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 为运营人员分配基础权限
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'operator'
AND p.code IN ('user:manage', 'group:manage', 'data:analysis')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- 插入默认管理员用户
-- 警告：生产环境请务必修改默认密码！
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
    '$2b$12$gi6TX7ecBwv3Uv/Hz8n2tO5.GWDA1jV7l.OvUY5b6W5El5O5jJ9v6',
    '系统管理员',
    0, -- AdminUserStatus::Active
    false,
    CURRENT_TIMESTAMP
) ON CONFLICT (username) DO NOTHING;

-- 为默认管理员分配超级管理员角色
INSERT INTO admin_user_roles (
    admin_user_id,
    role_id,
    assigned_by,
    assigned_at
)
SELECT
    au.id as admin_user_id,
    r.id as role_id,
    au.id as assigned_by, -- 自我分配
    CURRENT_TIMESTAMP as assigned_at
FROM admin_users au
INNER JOIN roles r ON r.code = 'super_admin'
WHERE au.username = 'admin'
AND NOT EXISTS (
    SELECT 1 FROM admin_user_roles aur
    WHERE aur.admin_user_id = au.id
    AND aur.role_id = r.id
)
ON CONFLICT (admin_user_id, role_id) DO NOTHING;

-- 插入默认通用设置
INSERT INTO general_settings (key, value, description) VALUES
    ('app_name', 'Redcode IM', '应用名称')
ON CONFLICT (key) DO NOTHING;

-- 插入IP地理位置解析功能开关（默认关闭）
INSERT INTO general_settings (key, value, description) VALUES
    ('ip_geolocation_enabled', '0', '是否启用IP地址地理位置解析功能（0=关闭，1=开启）')
ON CONFLICT (key) DO NOTHING;

-- ===== 用户账号限制设置 =====

-- 创建用户账号限制设置表
CREATE TABLE IF NOT EXISTS user_account_limit_settings (
    id INTEGER PRIMARY KEY DEFAULT 1, -- 固定ID为1，只有一条记录
    enable_phone_validation BOOLEAN NOT NULL DEFAULT FALSE,
    enable_email_validation BOOLEAN NOT NULL DEFAULT FALSE,
    enable_length_validation BOOLEAN NOT NULL DEFAULT FALSE,
    min_length INTEGER NOT NULL DEFAULT 3,
    max_length INTEGER NOT NULL DEFAULT 20,
    enable_alphanumeric_validation BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL
);

-- 说明：id 已是 PRIMARY KEY（固定为 1），无需额外 UNIQUE 约束；
-- Postgres 15 不支持 `ADD CONSTRAINT IF NOT EXISTS` 语法，避免初始化失败。

-- 插入默认配置
INSERT INTO user_account_limit_settings (id, enable_phone_validation, enable_email_validation, enable_length_validation, min_length, max_length, enable_alphanumeric_validation, updated_at)
VALUES (1, TRUE, FALSE, FALSE, 3, 20, FALSE, NOW())
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- 输出完成信息
SELECT 'Database initialization completed successfully!' AS status;
