-- 消息转发/置顶功能所需的结构调整

BEGIN;

ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS forward_from_message_id UUID,
    ADD COLUMN IF NOT EXISTS forward_from_room_id UUID,
    ADD COLUMN IF NOT EXISTS forward_from_sender_id UUID,
    ADD COLUMN IF NOT EXISTS forward_from_sender_username TEXT,
    ADD COLUMN IF NOT EXISTS forward_from_sender_nickname TEXT;

CREATE INDEX IF NOT EXISTS idx_messages_forward_from_message
    ON messages(forward_from_message_id)
    WHERE forward_from_message_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS room_pins (
    room_id UUID PRIMARY KEY REFERENCES rooms(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    pinned_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_room_pins_message_id ON room_pins(message_id);

COMMIT;
