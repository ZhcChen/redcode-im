ALTER TABLE messages
    ADD COLUMN encrypted_idempotency_key UUID;

CREATE UNIQUE INDEX idx_messages_encrypted_idempotency
    ON messages(room_id, sender_id, encrypted_idempotency_key)
    WHERE encrypted_idempotency_key IS NOT NULL;

COMMENT ON COLUMN messages.encrypted_idempotency_key IS
    '加密消息客户端幂等键；仅用于防止发送重试产生重复持久化';
