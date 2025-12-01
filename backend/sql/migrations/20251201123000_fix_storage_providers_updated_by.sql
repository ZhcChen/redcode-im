-- 修复 storage_providers 表的 updated_by 外键约束
-- 数据清理后，storage_providers.updated_by 引用了已删除的 users 表数据
-- 解决方案：将 updated_by 改为引用 admin_users 表

-- 删除旧的外键约束
ALTER TABLE storage_providers DROP CONSTRAINT IF EXISTS storage_providers_updated_by_fkey;

-- 添加新的外键约束，引用 admin_users 表
ALTER TABLE storage_providers
ADD CONSTRAINT storage_providers_updated_by_fkey
FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 同样修复其他引用 users 表的配置表
-- 1. app_documents
ALTER TABLE app_documents DROP CONSTRAINT IF EXISTS app_documents_updated_by_fkey;
ALTER TABLE app_documents
ADD CONSTRAINT app_documents_updated_by_fkey
FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 2. general_settings
ALTER TABLE general_settings DROP CONSTRAINT IF EXISTS general_settings_updated_by_fkey;
ALTER TABLE general_settings
ADD CONSTRAINT general_settings_updated_by_fkey
FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE SET NULL;

-- 3. captcha_settings
ALTER TABLE captcha_settings DROP CONSTRAINT IF EXISTS captcha_settings_updated_by_fkey;
ALTER TABLE captcha_settings
ADD CONSTRAINT captcha_settings_updated_by_fkey
FOREIGN KEY (updated_by) REFERENCES admin_users(id) ON DELETE SET NULL;

COMMENT ON COLUMN storage_providers.updated_by IS '更新者管理员ID（引用 admin_users 表）';
COMMENT ON COLUMN app_documents.updated_by IS '更新者管理员ID（引用 admin_users 表）';
COMMENT ON COLUMN general_settings.updated_by IS '更新者管理员ID（引用 admin_users 表）';
COMMENT ON COLUMN captcha_settings.updated_by IS '更新者管理员ID（引用 admin_users 表）';
