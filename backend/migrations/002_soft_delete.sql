-- 为所有核心表添加软删除支持

-- users 表新增 deleted_at 字段
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users(deleted_at);

-- rooms 表新增 deleted_at 字段
ALTER TABLE rooms
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_rooms_deleted_at ON rooms(deleted_at);

-- messages 表新增 deleted_at 字段
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_messages_deleted_at ON messages(deleted_at);
CREATE INDEX IF NOT EXISTS idx_messages_room_created_at ON messages(room_id, created_at) WHERE deleted_at IS NULL;

-- room_members 表新增 deleted_at 字段
ALTER TABLE room_members
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_room_members_deleted_at ON room_members(deleted_at);

-- 将原有唯一约束替换为仅针对未删除记录的唯一索引
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'room_members_room_id_user_id_key'
    ) THEN
        ALTER TABLE room_members DROP CONSTRAINT room_members_room_id_user_id_key;
    END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_room_members_unique_active
    ON room_members(room_id, user_id)
    WHERE deleted_at IS NULL;
