-- 20251228110000_create_push_provider_configs.sql
-- Push 平台配置表（由管理后台维护），用于存储 FCM/APNs 等第三方推送凭据与开关。
--
-- 约束：
-- 1) 不使用 PostgreSQL ENUM（provider/platform 均使用 TEXT）
-- 2) 敏感信息必须加密存储（secret_ciphertext），后台仅返回脱敏信息

CREATE TABLE IF NOT EXISTS push_provider_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 推送平台（fcm/apns/...）
    provider TEXT NOT NULL,

    -- 适用平台（android/ios/all/...）
    platform TEXT NOT NULL DEFAULT 'all',

    -- 是否启用该平台配置
    enabled BOOLEAN NOT NULL DEFAULT FALSE,

    -- 可公开展示的配置（非敏感）
    config_public JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- 敏感配置（加密后存储，例如 service account JSON / APNs 私钥）
    secret_ciphertext TEXT,

    -- 敏感配置指纹（sha256 hex），用于后台展示与排查，不可逆
    secret_fingerprint TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL,

    CONSTRAINT push_provider_configs_unique UNIQUE (provider, platform)
);

CREATE INDEX IF NOT EXISTS idx_push_provider_configs_provider
    ON push_provider_configs(provider);

CREATE INDEX IF NOT EXISTS idx_push_provider_configs_enabled
    ON push_provider_configs(enabled);

COMMENT ON TABLE push_provider_configs IS 'Push 平台配置（FCM/APNs 等），由管理后台维护；敏感信息加密存储';
COMMENT ON COLUMN push_provider_configs.secret_ciphertext IS '敏感配置（加密后的密文，base64 字符串）';
COMMENT ON COLUMN push_provider_configs.secret_fingerprint IS '敏感配置指纹（sha256 hex，不可逆）';

