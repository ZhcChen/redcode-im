CREATE TABLE app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL, -- frontend / desktop
    version TEXT NOT NULL,
    build_number INTEGER NOT NULL,
    channel TEXT NOT NULL DEFAULT 'stable',
    download_key TEXT NOT NULL,
    download_url TEXT,
    file_size BIGINT,
    checksum TEXT,
    signature TEXT,
    release_notes TEXT,
    mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    released_at TIMESTAMP WITH TIME ZONE,
    created_by UUID,
    updated_by UUID
);

CREATE UNIQUE INDEX app_versions_platform_version_idx
    ON app_versions(platform, version, channel);

CREATE INDEX app_versions_platform_active_idx
    ON app_versions(platform, is_active, released_at);
