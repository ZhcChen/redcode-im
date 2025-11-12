-- 增量脚本：创建用户房间置顶表
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

-- 好友备注表
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
