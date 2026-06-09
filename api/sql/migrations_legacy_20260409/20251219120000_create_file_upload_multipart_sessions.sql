-- 20251219120000_create_file_upload_multipart_sessions.sql
-- 创建大文件分片直传会话表（COS Multipart Upload）
--
-- 设计目标：
-- 1) 文件数据始终由前端直传到 COS，后端仅管理 multipart 会话（init/签名/完成/中止）；
-- 2) 支持断点续传：前端每完成一个 part 后上报 ETag，后端记录已完成分片；
-- 3) 与 file_upload_records（hash 去重/清理）解耦：multipart 会话可独立存在，完成后可按 object_key 标记 file_upload_records=completed。

CREATE TABLE IF NOT EXISTS file_upload_multipart_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- 关联存储提供商
    storage_provider_id UUID NOT NULL
        REFERENCES storage_providers(id) ON DELETE RESTRICT,

    -- 对象键（最终合并后的 object key）
    object_key TEXT NOT NULL,

    -- COS 返回的 upload_id（用于上传分片与完成合并）
    upload_id TEXT NOT NULL,

    -- 创建者（与 JWT claims.sub 一致；可能是 user 或 admin_user）
    creator_id UUID NOT NULL,
    creator_is_admin BOOLEAN NOT NULL DEFAULT FALSE,

    -- 文件元信息（可选，便于排障与策略判断）
    file_size BIGINT,
    content_type TEXT,

    -- 分片策略（由后端确定并返回给前端）
    part_size INTEGER NOT NULL,
    total_parts INTEGER NOT NULL,

    -- 已上传分片（JSON 对象：{ "1": "<etag>", "2": "<etag>" ... }）
    uploaded_parts JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- 会话状态：0=initiated,1=completed,2=aborted
    status SMALLINT NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_file_upload_multipart_sessions_creator
    ON file_upload_multipart_sessions(creator_id, creator_is_admin);

CREATE INDEX IF NOT EXISTS idx_file_upload_multipart_sessions_status_updated
    ON file_upload_multipart_sessions(status, updated_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_file_upload_multipart_sessions_unique_upload
    ON file_upload_multipart_sessions(storage_provider_id, object_key, upload_id);

