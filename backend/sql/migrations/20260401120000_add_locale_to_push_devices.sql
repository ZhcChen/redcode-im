-- 20260401120000_add_locale_to_push_devices.sql
-- 为 push_devices 增加 locale，用于按设备语言生成离线推送文案

ALTER TABLE push_devices
    ADD COLUMN IF NOT EXISTS locale TEXT NOT NULL DEFAULT 'zh-CN';

UPDATE push_devices
SET locale = 'zh-CN'
WHERE locale IS NULL OR BTRIM(locale) = '';

COMMENT ON COLUMN push_devices.locale IS '设备语言偏好（zh-CN/en-US），用于按设备生成推送文案';
