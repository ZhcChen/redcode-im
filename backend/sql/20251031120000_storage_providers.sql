-- 文件上传提供商配置表
-- 说明：支持多个文件上传提供商（如腾讯云COS、阿里云OSS等）的配置管理
-- 使用整数类型存储提供商类型，由应用代码维护枚举值

CREATE TABLE IF NOT EXISTS storage_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_type SMALLINT NOT NULL DEFAULT 1,  -- 0=unknown, 1=tencent_cos, 2=aliyun_oss, 3=aws_s3, 4=minio
    name VARCHAR(100) NOT NULL,                 -- 提供商名称（用于显示）
    secret_id TEXT NOT NULL,                    -- 密钥ID（Access Key ID）
    secret_key TEXT NOT NULL,                   -- 密钥Key（Secret Access Key）
    region VARCHAR(50) NOT NULL,                 -- 地域（如 ap-beijing）
    endpoint TEXT NOT NULL,                      -- 端点域名（如 cos.ap-beijing.myqcloud.com）
    bucket_name VARCHAR(100),                    -- 存储桶名称（可选，某些场景需要）
    is_active BOOLEAN NOT NULL DEFAULT FALSE,    -- 是否启用
    is_default BOOLEAN NOT NULL DEFAULT FALSE,   -- 是否为默认提供商
    description TEXT,                           -- 描述信息
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_storage_providers_type ON storage_providers(provider_type);
CREATE INDEX IF NOT EXISTS idx_storage_providers_active ON storage_providers(is_active);
CREATE INDEX IF NOT EXISTS idx_storage_providers_default ON storage_providers(is_default);

-- 确保只有一个默认提供商
CREATE UNIQUE INDEX IF NOT EXISTS idx_storage_providers_unique_default
    ON storage_providers(is_default)
    WHERE is_default = TRUE;

