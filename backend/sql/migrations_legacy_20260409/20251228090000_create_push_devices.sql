-- 20251228090000_create_push_devices.sql
-- 创建 Push 设备表（Push Devices）
--
-- 设计目标：
-- 1) 记录用户的设备 token（FCM/APNs），用于离线推送
-- 2) 支持 token 刷新、账号切换、设备注销（is_active）
-- 3) 不使用 PostgreSQL ENUM，平台与通道均用 TEXT

CREATE TABLE IF NOT EXISTS push_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 关联用户
    user_id UUID NOT NULL
        REFERENCES users(id) ON DELETE CASCADE,

    -- 设备平台（android/ios/web 等，使用 TEXT 保持兼容性）
    platform TEXT NOT NULL,

    -- 推送通道（fcm/apns 等，使用 TEXT 保持兼容性）
    channel TEXT NOT NULL,

    -- 设备标识（客户端生成并持久化的稳定 ID，用于 token 刷新和账号切换）
    device_id TEXT NOT NULL,

    -- 设备 token（FCM token / APNs device token）
    device_token TEXT NOT NULL,

    -- 是否启用（注销/登出时置为 false，便于审计与复用）
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    -- 设备最近一次上报时间
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT push_devices_unique_device_id UNIQUE (device_id),
    CONSTRAINT push_devices_unique_device_token UNIQUE (device_token)
);

CREATE INDEX IF NOT EXISTS idx_push_devices_user_active
    ON push_devices(user_id)
    WHERE is_active IS TRUE;

CREATE INDEX IF NOT EXISTS idx_push_devices_channel_active
    ON push_devices(channel)
    WHERE is_active IS TRUE;

COMMENT ON TABLE push_devices IS 'Push 设备表，记录用户设备 token（FCM/APNs）用于离线推送';
COMMENT ON COLUMN push_devices.device_id IS '客户端生成的稳定设备 ID，用于 token 刷新/账号切换';
COMMENT ON COLUMN push_devices.device_token IS '设备 token（FCM/APNs）';
COMMENT ON COLUMN push_devices.is_active IS '是否启用：false 表示已注销/登出';
