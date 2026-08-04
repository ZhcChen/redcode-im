ALTER TABLE e2ee_devices
    ADD COLUMN approval_public_key BYTEA;

ALTER TABLE e2ee_devices
    ADD CONSTRAINT e2ee_devices_approval_public_key_size
        CHECK (approval_public_key IS NULL OR octet_length(approval_public_key) = 32);

COMMENT ON COLUMN e2ee_devices.approval_public_key IS
    '设备批准 proof 使用的 Ed25519 公钥；仅用于设备信任授权，不是 MLS 私钥';
