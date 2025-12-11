-- 20251211120000_create_file_upload_records.sql
-- 创建统一的文件上传记录表，用于管理通过对象存储（当前为腾讯云 COS）直传的文件
-- 功能：
-- 1. 按 hash + size 去重，支持在不同用户/终端间复用同一个 object_key
-- 2. 记录上传状态（上传中/已完成/失败/已删除），避免复用尚未上传完成的文件
-- 3. 为后续空间统计、清理任务提供基础数据

-- 文件上传记录表
CREATE TABLE IF NOT EXISTS file_upload_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 关联存储提供商（目前主要是腾讯云 COS）
    storage_provider_id UUID NOT NULL
        REFERENCES storage_providers(id) ON DELETE RESTRICT,

    -- 对象在 COS 中的存储路径（object key），例如 avatars/...、message_attachments/...
    object_key TEXT NOT NULL,

    -- 哈希算法：1=md5, 2=sha256（预留扩展）
    hash_alg SMALLINT NOT NULL DEFAULT 1,

    -- 文件哈希值（客户端计算并上报，十六进制字符串）
    hash_value TEXT NOT NULL,

    -- 文件大小（字节），用于进一步校验去重
    file_size BIGINT,

    -- 精确 MIME 类型，例如 image/png、video/mp4
    content_type TEXT,

    -- 上传状态：
    -- 0 = 上传中/待确认（已生成直传签名，COS 上传尚未确认成功）
    -- 1 = 上传完成（可被复用）
    -- 2 = 上传失败
    -- 3 = 已删除（COS 中的对象已被清理，不再允许复用）
    status SMALLINT NOT NULL DEFAULT 0,

    -- 首次被标记为“上传完成”的时间
    uploaded_at TIMESTAMPTZ,

    -- 最近一次状态变更时间（包括创建、完成、失败、删除）
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 记录创建时间（通常在生成直传签名时插入）
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 最近一次错误信息（可选，用于记录上传失败原因）
    last_error TEXT
);

-- 同一存储提供商下，一个 object_key 只对应一条记录
CREATE UNIQUE INDEX IF NOT EXISTS idx_file_upload_records_provider_key
    ON file_upload_records(storage_provider_id, object_key);

-- 按 hash + size + 状态 查询可复用文件（仅 status=1 的记录允许复用）
CREATE INDEX IF NOT EXISTS idx_file_upload_records_hash_completed
    ON file_upload_records(hash_alg, hash_value, file_size, status);

-- 按创建时间扫描，便于统计和过期清理
CREATE INDEX IF NOT EXISTS idx_file_upload_records_created_at
    ON file_upload_records(created_at);

