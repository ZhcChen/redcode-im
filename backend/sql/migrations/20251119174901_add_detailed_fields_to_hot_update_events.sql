-- 为 hot_update_events 表添加详细的客户端信息字段
-- 支持区分桌面端/移动端，记录操作系统、架构、网络等详细信息

ALTER TABLE hot_update_events
ADD COLUMN IF NOT EXISTS client_type TEXT,
ADD COLUMN IF NOT EXISTS os_version TEXT,
ADD COLUMN IF NOT EXISTS os_arch TEXT,
ADD COLUMN IF NOT EXISTS app_arch TEXT,
ADD COLUMN IF NOT EXISTS build_number INTEGER,
ADD COLUMN IF NOT EXISTS trigger_source TEXT,
ADD COLUMN IF NOT EXISTS network_type TEXT,
ADD COLUMN IF NOT EXISTS device_info TEXT;

-- 添加新字段的索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_hot_update_events_client_type
    ON hot_update_events (client_type);

CREATE INDEX IF NOT EXISTS idx_hot_update_events_platform_client_type
    ON hot_update_events (platform, client_type);

CREATE INDEX IF NOT EXISTS idx_hot_update_events_os_version
    ON hot_update_events (os_version);

-- 添加注释说明各个字段的用途
COMMENT ON COLUMN hot_update_events.client_type IS '客户端类型：desktop（桌面端）或frontend（移动端）';
COMMENT ON COLUMN hot_update_events.os_version IS '操作系统版本，如：Windows 11, iOS 17.1, Android 13';
COMMENT ON COLUMN hot_update_events.os_arch IS '操作系统架构：x64, arm64, arm等';
COMMENT ON COLUMN hot_update_events.app_arch IS '应用架构：x64, arm64, arm等';
COMMENT ON COLUMN hot_update_events.build_number IS '构建号';
COMMENT ON COLUMN hot_update_events.trigger_source IS '触发来源：manual（手动）、auto（自动）、notification（通知）';
COMMENT ON COLUMN hot_update_events.network_type IS '网络类型：wifi, cellular, ethernet, unknown';
COMMENT ON COLUMN hot_update_events.device_info IS '设备详细信息摘要，如：platform:Win32,lang:zh-CN,cookies:true';
