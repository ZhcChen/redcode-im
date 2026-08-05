-- U6：Admin E2EE 启用门禁（R12/R13）
-- 1. 设备能力字段：认证设备注册时上报平台/版本/构建号，readiness 据此计算覆盖。
ALTER TABLE e2ee_devices
    ADD COLUMN client_platform VARCHAR(32),
    ADD COLUMN client_version VARCHAR(64),
    ADD COLUMN client_build VARCHAR(128);

ALTER TABLE e2ee_devices
    ADD CONSTRAINT e2ee_devices_client_platform
        CHECK (client_platform IS NULL OR client_platform IN ('android', 'ios', 'h5', 'desktop'));

ALTER TABLE e2ee_devices
    ADD CONSTRAINT e2ee_devices_client_version_blank
        CHECK (client_version IS NULL OR btrim(client_version) <> '');

-- 2. 单行门禁状态：plaintext -> prepare -> active；readiness 带 revision 与计算时间。
CREATE TABLE e2ee_runtime_gate (
    id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    state VARCHAR(32) NOT NULL DEFAULT 'plaintext',
    readiness_revision BIGINT NOT NULL DEFAULT 0,
    readiness_computed_at TIMESTAMPTZ,
    min_client_versions JSONB NOT NULL DEFAULT '{}'::jsonb,
    required_coverage_percent SMALLINT NOT NULL DEFAULT 100,
    key_package_low_watermark INTEGER NOT NULL DEFAULT 10,
    security_review_approved BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID,
    CONSTRAINT e2ee_runtime_gate_state
        CHECK (state IN ('plaintext', 'prepare', 'active')),
    CONSTRAINT e2ee_runtime_gate_coverage
        CHECK (required_coverage_percent BETWEEN 1 AND 100),
    CONSTRAINT e2ee_runtime_gate_low_watermark
        CHECK (key_package_low_watermark >= 0)
);

INSERT INTO e2ee_runtime_gate (id, min_client_versions)
VALUES (
    1,
    '{"android":"0.1.0","ios":"0.1.0","h5":"0.1.0","desktop":"0.1.0"}'::jsonb
);

CREATE INDEX idx_e2ee_devices_active_capabilities
    ON e2ee_devices(user_id, status, client_platform, client_version)
    WHERE status = 'active';

COMMENT ON TABLE e2ee_runtime_gate IS
    'E2EE 启用门禁单行状态：prepare 预检、active 原子启用、回滚不删历史密文';
