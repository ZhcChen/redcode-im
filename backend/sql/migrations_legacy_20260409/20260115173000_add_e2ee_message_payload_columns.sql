-- 20260115173000_add_e2ee_message_payload_columns.sql
-- 为消息表增加 E2EE 加密载荷字段（ciphertext + metadata）
--
-- 说明：
-- - content 仍保留用于兼容旧客户端/列表摘要（加密消息可写入占位摘要）
-- - encrypted_content / encryption_metadata 用于端到端加密消息的透传与离线存储

ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS encrypted_content BYTEA;

ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS encryption_metadata JSONB;

COMMENT ON COLUMN messages.encrypted_content IS 'E2EE 密文载荷（服务端不解密，仅存储与透传）';
COMMENT ON COLUMN messages.encryption_metadata IS 'E2EE 元数据（JSON），如算法/版本/iv/counter 等';

