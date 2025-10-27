-- 全量结构与基础数据初始化脚本
-- 说明：
--  1. 使用整数字段表示业务状态，具体取值由应用代码维护并校验。
--  2. 本脚本可在空库上直接执行，初始化当前功能所需的全部表结构和基础数据。
--  3. 各表的 updated_at 字段由应用层负责赋值，数据库不再通过触发器自动维护。

BEGIN;

-- 用户表
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nickname VARCHAR(100),
    avatar_url TEXT,
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

-- 房间表
CREATE TABLE IF NOT EXISTS rooms (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    avatar_url TEXT,
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

-- 房间成员表
CREATE TABLE IF NOT EXISTS room_members (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role SMALLINT NOT NULL DEFAULT 2,              -- 0=owner,1=admin,2=member
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_read_at TIMESTAMPTZ,
    last_read_message_id UUID REFERENCES messages(id)
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
-- 加速 “按 message_id 查询已读用户并按 read_at 排序” 的路径
CREATE INDEX IF NOT EXISTS idx_message_reads_message_read_at
    ON message_reads(message_id, read_at);

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

-- 文档表
CREATE TABLE IF NOT EXISTS app_documents (
    key TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_app_documents_updated_at
    ON app_documents(updated_at DESC);

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

-- 验证码配置
CREATE TABLE IF NOT EXISTS captcha_settings (
    key TEXT PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    captcha_code TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL DEFAULT '',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);

-- 基础数据
INSERT INTO users (id, username, email, password_hash, nickname, status)
VALUES (
    '0192c3a0-0000-7000-8000-000000000000',
    'system',
    'system@redcode-im.local',
    '$2a$12$system_user_placeholder',
    '系统用户',
    0
)
ON CONFLICT (username) DO NOTHING;

INSERT INTO users (id, username, email, password_hash, nickname, status)
VALUES (
    '0192c3a0-0000-7000-8000-000000000001',
    'alice',
    'alice@redcode-im.local',
    '$2b$12$T4mF9KMrEeRJB7bGupbfses73VrjBkLLa0YMffgOf2VLwqWAcY9Ti',
    'Alice 管理员',
    0
)
ON CONFLICT (username) DO NOTHING;

INSERT INTO app_documents (key, title, content)
VALUES (
    'privacy_policy',
    '隐私政策',
    '<p>隐私政策内容尚未配置。</p>'
)
ON CONFLICT (key) DO NOTHING;

INSERT INTO captcha_settings (key, enabled, captcha_code, description)
VALUES (
    'default',
    TRUE,
    '666666',
    ''
)
ON CONFLICT (key) DO NOTHING;

COMMIT;
