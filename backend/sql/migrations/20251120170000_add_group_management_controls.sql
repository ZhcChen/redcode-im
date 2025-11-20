-- 添加群全体禁言字段
ALTER TABLE group_settings
    ADD COLUMN IF NOT EXISTS global_mute_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS global_mute_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS global_mute_reason TEXT,
    ADD COLUMN IF NOT EXISTS global_mute_set_by UUID REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_group_settings_global_mute ON group_settings(global_mute_enabled);
