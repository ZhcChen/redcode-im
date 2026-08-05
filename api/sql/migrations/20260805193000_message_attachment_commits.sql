CREATE TABLE message_attachment_commits (
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    object_key TEXT NOT NULL,
    uploaded_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_size BIGINT,
    committed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (room_id, object_key)
);

CREATE INDEX idx_message_attachment_commits_uploaded_by
    ON message_attachment_commits (uploaded_by, committed_at DESC);
