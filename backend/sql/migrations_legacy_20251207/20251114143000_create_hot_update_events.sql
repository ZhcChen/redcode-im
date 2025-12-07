CREATE TABLE IF NOT EXISTS hot_update_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL,
    channel TEXT,
    base_version TEXT NOT NULL,
    patch_version TEXT NOT NULL,
    event_type TEXT NOT NULL,
    client_id TEXT,
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hot_update_events_created_at
    ON hot_update_events (created_at DESC);
