-- 20260115170000_create_e2ee_key_tables.sql
-- 创建 E2EE 密钥相关表（Identity Key / Signed Pre-Key / One-Time Pre-Key）
--
-- 设计原则：
-- 1) 仅存储公钥/预密钥等公开材料，私钥永不上传
-- 2) 支持多设备：同一 user_id 可存在多个 device_id
-- 3) 不使用 PostgreSQL ENUM（保持兼容性与可演进性）

-- 用户身份公钥（每设备一份）
CREATE TABLE IF NOT EXISTS e2ee_identity_keys (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    public_key BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT e2ee_identity_keys_pkey PRIMARY KEY (user_id, device_id),
    CONSTRAINT e2ee_identity_keys_device_id_len CHECK (
        char_length(device_id) > 0 AND char_length(device_id) <= 128
    )
);

CREATE INDEX IF NOT EXISTS idx_e2ee_identity_keys_user
    ON e2ee_identity_keys(user_id);

-- 签名预密钥（每设备可存在多个，按 key_id 区分，带过期时间）
CREATE TABLE IF NOT EXISTS e2ee_signed_pre_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    key_id INTEGER NOT NULL,
    public_key BYTEA NOT NULL,
    signature BYTEA NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT e2ee_signed_pre_keys_unique UNIQUE (user_id, device_id, key_id),
    CONSTRAINT e2ee_signed_pre_keys_device_id_len CHECK (
        char_length(device_id) > 0 AND char_length(device_id) <= 128
    )
);

CREATE INDEX IF NOT EXISTS idx_e2ee_signed_pre_keys_user_device_expires
    ON e2ee_signed_pre_keys(user_id, device_id, expires_at);

-- 一次性预密钥（每设备可存在多个，服务器会在发起会话时原子“取用”）
CREATE TABLE IF NOT EXISTS e2ee_one_time_pre_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    key_id INTEGER NOT NULL,
    public_key BYTEA NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT FALSE,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT e2ee_one_time_pre_keys_unique UNIQUE (user_id, device_id, key_id),
    CONSTRAINT e2ee_one_time_pre_keys_device_id_len CHECK (
        char_length(device_id) > 0 AND char_length(device_id) <= 128
    )
);

CREATE INDEX IF NOT EXISTS idx_e2ee_one_time_pre_keys_unused
    ON e2ee_one_time_pre_keys(user_id, device_id, created_at)
    WHERE is_used IS FALSE;

COMMENT ON TABLE e2ee_identity_keys IS 'E2EE 身份公钥表（按 user_id + device_id 维度）';
COMMENT ON TABLE e2ee_signed_pre_keys IS 'E2EE 签名预密钥表（按 user_id + device_id 维度，支持轮换）';
COMMENT ON TABLE e2ee_one_time_pre_keys IS 'E2EE 一次性预密钥表（按 user_id + device_id 维度，取用后标记 is_used）';

