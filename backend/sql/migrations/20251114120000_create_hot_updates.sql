-- 创建热更新补丁表，覆盖 Flutter(Android/iOS) 端的版本增量包
CREATE TABLE IF NOT EXISTS hot_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL,
    -- 绑定的基线整包版本 ID
    app_version_id UUID NOT NULL REFERENCES app_versions(id) ON DELETE CASCADE,
    patch_version TEXT NOT NULL,
    channel TEXT NOT NULL DEFAULT 'stable',
    download_key TEXT NOT NULL,
    download_url TEXT,
    file_size BIGINT,
    checksum TEXT,
    signature TEXT,
    rollout_percentage INTEGER NOT NULL DEFAULT 100 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),
    mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    released_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_hot_updates_unique
    ON hot_updates(app_version_id, patch_version);

CREATE INDEX IF NOT EXISTS idx_hot_updates_lookup
    ON hot_updates(platform, channel, is_active, released_at DESC NULLS LAST);
