CREATE TABLE IF NOT EXISTS message_parts (
    id UUID PRIMARY KEY,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    position SMALLINT NOT NULL,
    part_type SMALLINT NOT NULL,
    text_content TEXT,
    attachment_key TEXT,
    attachment_name TEXT,
    attachment_mime TEXT,
    attachment_size BIGINT,
    width INTEGER,
    height INTEGER,
    duration_ms INTEGER,
    thumbnail_key TEXT,
    extra JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_message_parts_message_id_position
    ON message_parts (message_id, position);
