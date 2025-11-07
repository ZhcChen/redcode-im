-- 添加聊天免打扰功能
-- 为room_members表添加notification_settings字段

BEGIN;

-- 添加通知设置字段
ALTER TABLE room_members ADD COLUMN IF NOT EXISTS notification_settings INTEGER NOT NULL DEFAULT 0;

-- 字段说明：
-- 0 = 接收所有通知（默认）
-- 1 = 只接收@通知
-- 2 = 完全静音（免打扰）

-- 为新字段创建索引
CREATE INDEX IF NOT EXISTS idx_room_members_notification_settings ON room_members(notification_settings);

-- 更新现有记录的默认值
UPDATE room_members SET notification_settings = 0 WHERE notification_settings IS NULL;

COMMENT ON COLUMN room_members.notification_settings IS '通知设置：0=全部通知，1=仅@通知，2=完全静音';

COMMIT;