-- 20251227021700_add_message_edited_at.sql
-- 为消息添加 edited_at 字段，支持消息编辑功能

ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

COMMENT ON COLUMN messages.edited_at IS '消息编辑时间，NULL 表示未编辑过';

CREATE INDEX IF NOT EXISTS idx_messages_edited_at
    ON messages(edited_at)
    WHERE edited_at IS NOT NULL;

