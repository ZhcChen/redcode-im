-- 修复房间类型字段与消息已读唯一约束
BEGIN;

-- 房间表增加 room_type 字段并确保约束
ALTER TABLE rooms
    ADD COLUMN IF NOT EXISTS room_type SMALLINT;

ALTER TABLE rooms
    ALTER COLUMN room_type SET DEFAULT 1;

UPDATE rooms
SET room_type = 1
WHERE room_type IS NULL;

ALTER TABLE rooms
    ALTER COLUMN room_type SET NOT NULL;

-- 确保房间类型索引存在
CREATE INDEX IF NOT EXISTS idx_rooms_type ON rooms(room_type);

-- 消息已读去重，避免唯一索引创建失败
DELETE FROM message_reads a
USING message_reads b
WHERE a.ctid < b.ctid
  AND a.message_id = b.message_id
  AND a.user_id = b.user_id;

-- 为消息已读表添加唯一索引，匹配应用侧 ON CONFLICT 语句
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_reads_unique_message_user
    ON message_reads(message_id, user_id);

COMMIT;
