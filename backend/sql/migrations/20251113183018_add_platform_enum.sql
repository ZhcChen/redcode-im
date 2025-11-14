-- 添加平台枚举约束
-- 将 platform 字段规范化为具体的操作系统平台

-- 1. 添加 CHECK 约束，限制 platform 字段只能是指定的值
ALTER TABLE app_versions
ADD CONSTRAINT app_versions_platform_check
CHECK (platform IN ('windows', 'macos', 'ios', 'android', 'linux'));

-- 2. 添加注释说明
COMMENT ON COLUMN app_versions.platform IS '支持平台: windows(Windows桌面), macos(macOS桌面), ios(iOS移动端), android(Android移动端), linux(Linux桌面)';

-- 3. 更新现有数据（如果有的话）
-- 注意: 需要根据实际情况手动调整现有数据
-- UPDATE app_versions SET platform = 'windows' WHERE platform = 'desktop' AND ...;
-- UPDATE app_versions SET platform = 'android' WHERE platform = 'frontend' AND ...;
