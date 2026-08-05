ALTER TABLE message_attachment_commits
    ADD COLUMN expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
    ADD COLUMN confirmed_at TIMESTAMPTZ;

CREATE INDEX idx_message_attachment_commits_active
    ON message_attachment_commits (object_key, expires_at, confirmed_at);
