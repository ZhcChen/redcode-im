-- 创建用户账号限制设置表

CREATE TABLE user_account_limit_settings (
    id INTEGER PRIMARY KEY DEFAULT 1, -- 固定ID为1，只有一条记录
    enable_phone_validation BOOLEAN NOT NULL DEFAULT FALSE,
    enable_email_validation BOOLEAN NOT NULL DEFAULT FALSE,
    enable_length_validation BOOLEAN NOT NULL DEFAULT FALSE,
    min_length INTEGER NOT NULL DEFAULT 3,
    max_length INTEGER NOT NULL DEFAULT 20,
    enable_alphanumeric_validation BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES admin_users(id) ON DELETE SET NULL
);

-- 插入默认配置
INSERT INTO user_account_limit_settings (id, enable_phone_validation, enable_email_validation, enable_length_validation, min_length, max_length, enable_alphanumeric_validation, updated_at)
VALUES (1, FALSE, FALSE, FALSE, 3, 20, FALSE, NOW());

-- 创建唯一约束，确保只有一条记录
ALTER TABLE user_account_limit_settings ADD CONSTRAINT user_account_limit_settings_id_unique UNIQUE (id);
