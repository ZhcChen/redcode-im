-- 20251228130000_create_push_logs.sql
-- Push 发送日志（用于可观测性、排障与重试分析）
--
-- 设计目标：
-- 1) 记录每次 push 发送到具体设备的结果（success/failed + error）
-- 2) 支持按 push_id 追踪一次“通知事件”的全链路发送情况
-- 3) 不使用 PostgreSQL ENUM，状态字段使用 TEXT/BOOLEAN

CREATE TABLE IF NOT EXISTS push_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 一次通知事件的追踪 ID（同一事件可对应多个设备发送记录）
    push_id UUID NOT NULL,

    -- 目标用户
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- 目标设备（对应 push_devices.device_id）
    device_id TEXT NOT NULL,
    platform TEXT NOT NULL,
    channel TEXT NOT NULL,
    provider TEXT NOT NULL,

    -- 事件维度（message/friend_request/group_event/...）
    event_type TEXT NOT NULL,
    room_id UUID NULL,
    message_id UUID NULL,
    request_id UUID NULL,

    title TEXT NULL,
    body TEXT NULL,
    data JSONB NOT NULL DEFAULT '{}'::jsonb,

    attempt INT NOT NULL,
    success BOOLEAN NOT NULL,
    error TEXT NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_push_logs_push_id
    ON push_logs(push_id);

CREATE INDEX IF NOT EXISTS idx_push_logs_user_created
    ON push_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_push_logs_success_created
    ON push_logs(success, created_at DESC);

COMMENT ON TABLE push_logs IS 'Push 发送日志：按设备记录 push 发送结果，用于追踪、排障与重试分析';
COMMENT ON COLUMN push_logs.push_id IS '一次通知事件的追踪 ID，同一事件可能对多个设备产生多条日志';
COMMENT ON COLUMN push_logs.event_type IS '通知事件类型：message/friend_request/group_event/...';

