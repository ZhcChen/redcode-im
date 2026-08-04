CREATE TABLE e2ee_account_identities (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    root_public_key BYTEA NOT NULL,
    root_fingerprint BYTEA NOT NULL,
    protocol_version SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT e2ee_account_identities_root_key_size
        CHECK (octet_length(root_public_key) BETWEEN 1 AND 4096),
    CONSTRAINT e2ee_account_identities_fingerprint_size
        CHECK (octet_length(root_fingerprint) BETWEEN 16 AND 128),
    CONSTRAINT e2ee_account_identities_protocol_version
        CHECK (protocol_version > 0)
);

CREATE TABLE e2ee_devices (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_label VARCHAR(128) NOT NULL,
    credential BYTEA NOT NULL,
    credential_fingerprint BYTEA NOT NULL,
    protocol_version SMALLINT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending_approval',
    approved_by_device_id UUID REFERENCES e2ee_devices(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT e2ee_devices_label_not_blank CHECK (btrim(device_label) <> ''),
    CONSTRAINT e2ee_devices_credential_size
        CHECK (octet_length(credential) BETWEEN 1 AND 65536),
    CONSTRAINT e2ee_devices_fingerprint_size
        CHECK (octet_length(credential_fingerprint) BETWEEN 16 AND 128),
    CONSTRAINT e2ee_devices_protocol_version CHECK (protocol_version > 0),
    CONSTRAINT e2ee_devices_status
        CHECK (status IN ('pending_approval', 'active', 'revoked')),
    CONSTRAINT e2ee_devices_approval_state CHECK (
        (status = 'pending_approval' AND approved_at IS NULL AND revoked_at IS NULL)
        OR (status = 'active' AND approved_at IS NOT NULL AND revoked_at IS NULL)
        OR (status = 'revoked' AND revoked_at IS NOT NULL)
    ),
    UNIQUE (user_id, credential_fingerprint)
);

CREATE INDEX idx_e2ee_devices_user_status
    ON e2ee_devices(user_id, status, created_at);

CREATE TABLE e2ee_key_packages (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES e2ee_devices(id) ON DELETE CASCADE,
    package_ref BYTEA NOT NULL UNIQUE,
    key_package BYTEA NOT NULL,
    protocol_version SMALLINT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    consumed_by_device_id UUID REFERENCES e2ee_devices(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT e2ee_key_packages_ref_size
        CHECK (octet_length(package_ref) BETWEEN 16 AND 128),
    CONSTRAINT e2ee_key_packages_payload_size
        CHECK (octet_length(key_package) BETWEEN 1 AND 1048576),
    CONSTRAINT e2ee_key_packages_protocol_version CHECK (protocol_version > 0),
    CONSTRAINT e2ee_key_packages_expiry CHECK (expires_at > created_at),
    CONSTRAINT e2ee_key_packages_consumption CHECK (
        (consumed_at IS NULL AND consumed_by_device_id IS NULL)
        OR (consumed_at IS NOT NULL AND consumed_by_device_id IS NOT NULL)
    )
);

CREATE INDEX idx_e2ee_key_packages_available
    ON e2ee_key_packages(device_id, expires_at, created_at)
    WHERE consumed_at IS NULL;

CREATE TABLE e2ee_room_epochs (
    room_id UUID PRIMARY KEY REFERENCES rooms(id) ON DELETE CASCADE,
    membership_revision BIGINT NOT NULL DEFAULT 1,
    active_epoch BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT 'preparing',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT e2ee_room_epochs_membership_revision CHECK (membership_revision > 0),
    CONSTRAINT e2ee_room_epochs_active_epoch CHECK (active_epoch >= 0),
    CONSTRAINT e2ee_room_epochs_status
        CHECK (status IN ('preparing', 'active', 'rekey_required'))
);

CREATE TABLE e2ee_control_messages (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    epoch BIGINT NOT NULL,
    membership_revision BIGINT NOT NULL,
    sender_device_id UUID NOT NULL REFERENCES e2ee_devices(id) ON DELETE RESTRICT,
    recipient_device_id UUID REFERENCES e2ee_devices(id) ON DELETE CASCADE,
    content_type VARCHAR(16) NOT NULL,
    envelope BYTEA NOT NULL,
    idempotency_key UUID NOT NULL,
    sequence_no BIGINT GENERATED ALWAYS AS IDENTITY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT e2ee_control_messages_epoch CHECK (epoch > 0),
    CONSTRAINT e2ee_control_messages_membership_revision CHECK (membership_revision > 0),
    CONSTRAINT e2ee_control_messages_content_type
        CHECK (content_type IN ('commit', 'welcome')),
    CONSTRAINT e2ee_control_messages_envelope_size
        CHECK (octet_length(envelope) BETWEEN 12 AND 16777227),
    UNIQUE (room_id, idempotency_key),
    UNIQUE (room_id, sequence_no)
);

CREATE INDEX idx_e2ee_control_messages_room_epoch
    ON e2ee_control_messages(room_id, epoch, sequence_no);
CREATE INDEX idx_e2ee_control_messages_recipient
    ON e2ee_control_messages(recipient_device_id, sequence_no)
    WHERE recipient_device_id IS NOT NULL;

CREATE TABLE e2ee_control_receipts (
    control_message_id UUID NOT NULL REFERENCES e2ee_control_messages(id) ON DELETE CASCADE,
    recipient_device_id UUID NOT NULL REFERENCES e2ee_devices(id) ON DELETE CASCADE,
    delivered_at TIMESTAMPTZ,
    consumed_at TIMESTAMPTZ,
    PRIMARY KEY (control_message_id, recipient_device_id),
    CONSTRAINT e2ee_control_receipts_order CHECK (
        consumed_at IS NULL OR (delivered_at IS NOT NULL AND consumed_at >= delivered_at)
    )
);

CREATE INDEX idx_e2ee_control_receipts_pending
    ON e2ee_control_receipts(recipient_device_id, control_message_id)
    WHERE consumed_at IS NULL;

COMMENT ON TABLE e2ee_account_identities IS '账号根身份公开材料；私钥仅保存在客户端';
COMMENT ON TABLE e2ee_devices IS 'MLS 设备凭据与批准/撤销状态';
COMMENT ON TABLE e2ee_key_packages IS 'OpenMLS KeyPackage 公开材料与一次性消费状态';
COMMENT ON TABLE e2ee_room_epochs IS '房间成员修订与当前 MLS epoch';
COMMENT ON TABLE e2ee_control_messages IS 'Welcome/Commit 控制消息有序队列';
COMMENT ON TABLE e2ee_control_receipts IS '设备对控制消息的投递与幂等消费状态';
