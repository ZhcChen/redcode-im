-- 群聊管理功能扩展
-- 20251107170000_group_management_features.sql

-- 1. 群聊设置表
CREATE TABLE IF NOT EXISTS group_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    join_approval_required BOOLEAN DEFAULT FALSE,        -- 需要管理员审批才能加入
    member_can_invite BOOLEAN DEFAULT TRUE,             -- 成员可以邀请新成员
    member_can_add_friends BOOLEAN DEFAULT TRUE,        -- 成员可以添加好友
    require_admin_to_add_friends BOOLEAN DEFAULT FALSE, -- 需要管理员同意才能添加好友
    max_members INTEGER DEFAULT 500,                   -- 最大成员数量
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(room_id)
);

-- 2. 群公告表
CREATE TABLE IF NOT EXISTS group_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    publisher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_pinned BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. 群规表
CREATE TABLE IF NOT EXISTS group_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. 入群申请表
CREATE TABLE IF NOT EXISTS join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    applicant_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT,
    status INTEGER NOT NULL DEFAULT 0,               -- 0=pending,1=approved,2=rejected
    reviewer_id UUID REFERENCES users(id),           -- 审批人
    review_message TEXT,                             -- 审批留言
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(room_id, applicant_id)
);

-- 5. 群聊邀请记录表
CREATE TABLE IF NOT EXISTS group_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT,
    status INTEGER NOT NULL DEFAULT 0,               -- 0=pending,1=accepted,2=declined,3=expired
    invited_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days'),
    UNIQUE(room_id, invitee_id)
);

-- 6. 群聊管理员记录表
CREATE TABLE IF NOT EXISTS group_admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    admin_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    appointed_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'admin',       -- admin, deputy_admin
    permissions TEXT[],                               -- 权限列表数组
    appointed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(room_id, admin_id)
);

-- 7. 群聊成员操作日志表
CREATE TABLE IF NOT EXISTS group_operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    operator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES users(id),        -- 操作目标用户（如果适用）
    operation_type VARCHAR(50) NOT NULL,             -- 操作类型：add_member, remove_member, promote_admin, etc.
    operation_data JSONB,                            -- 操作详细信息
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 8. 群聊禁言表
CREATE TABLE IF NOT EXISTS group_mutes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    muted_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT,
    mute_duration_hours INTEGER DEFAULT 24,          -- 禁言时长（小时）
    muted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    unmuted_at TIMESTAMP WITH TIME ZONE,             -- 解禁时间（如果提前解禁）
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(room_id, user_id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_group_settings_room_id ON group_settings(room_id);
CREATE INDEX IF NOT EXISTS idx_group_announcements_room_id ON group_announcements(room_id);
CREATE INDEX IF NOT EXISTS idx_group_announcements_pinned ON group_announcements(is_pinned);
CREATE INDEX IF NOT EXISTS idx_group_rules_room_id ON group_rules(room_id);
CREATE INDEX IF NOT EXISTS idx_group_rules_active ON group_rules(is_active);
CREATE INDEX IF NOT EXISTS idx_join_requests_room_id ON join_requests(room_id);
CREATE INDEX IF NOT EXISTS idx_join_requests_status ON join_requests(status);
CREATE INDEX IF NOT EXISTS idx_group_invitations_room_id ON group_invitations(room_id);
CREATE INDEX IF NOT EXISTS idx_group_invitations_status ON group_invitations(status);
CREATE INDEX IF NOT EXISTS idx_group_admins_room_id ON group_admins(room_id);
CREATE INDEX IF NOT EXISTS idx_group_admins_admin_id ON group_admins(admin_id);
CREATE INDEX IF NOT EXISTS idx_group_operation_logs_room_id ON group_operation_logs(room_id);
CREATE INDEX IF NOT EXISTS idx_group_operation_logs_created_at ON group_operation_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_group_mutes_room_id ON group_mutes(room_id);
CREATE INDEX IF NOT EXISTS idx_group_mutes_user_id ON group_mutes(user_id);
CREATE INDEX IF NOT EXISTS idx_group_mutes_active ON group_mutes(is_active);

-- 创建更新时间触发器
CREATE TRIGGER update_group_settings_updated_at
    BEFORE UPDATE ON group_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_announcements_updated_at
    BEFORE UPDATE ON group_announcements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_rules_updated_at
    BEFORE UPDATE ON group_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 插入默认群聊设置（为现有群组）
INSERT INTO group_settings (room_id)
SELECT id FROM rooms
WHERE room_type = 1 AND deleted_at IS NULL
ON CONFLICT (room_id) DO NOTHING;

-- 创建视图：群聊详细信息视图
CREATE OR REPLACE VIEW group_detail_view AS
SELECT
    r.id,
    r.name,
    r.description,
    r.avatar_url,
    r.room_type,
    r.owner_id,
    r.created_at,
    r.updated_at,
    gs.join_approval_required,
    gs.member_can_invite,
    gs.member_can_add_friends,
    gs.require_admin_to_add_friends,
    gs.max_members,
    (SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = r.id AND rm.deleted_at IS NULL) as current_member_count,
    (SELECT COUNT(*) FROM group_announcements ga WHERE ga.room_id = r.id) as announcement_count,
    (SELECT COUNT(*) FROM join_requests jr WHERE jr.room_id = r.id AND jr.status = 0) as pending_request_count
FROM rooms r
LEFT JOIN group_settings gs ON r.id = gs.room_id
WHERE r.room_type = 1 AND r.deleted_at IS NULL;