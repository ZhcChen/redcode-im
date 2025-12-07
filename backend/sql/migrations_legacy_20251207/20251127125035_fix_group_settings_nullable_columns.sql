-- 修复 group_settings 表中可空列的问题
-- 这些列存在但可能有 NULL 值，代码期望非空

-- 确保 group_settings 表有所有必需的列
ALTER TABLE group_settings
    ADD COLUMN IF NOT EXISTS join_approval_required BOOLEAN,
    ADD COLUMN IF NOT EXISTS member_can_invite BOOLEAN,
    ADD COLUMN IF NOT EXISTS member_can_add_friends BOOLEAN,
    ADD COLUMN IF NOT EXISTS require_admin_to_add_friends BOOLEAN,
    ADD COLUMN IF NOT EXISTS max_members INTEGER;

-- 更新所有 NULL 值为默认值
UPDATE group_settings SET join_approval_required = FALSE WHERE join_approval_required IS NULL;
UPDATE group_settings SET member_can_invite = TRUE WHERE member_can_invite IS NULL;
UPDATE group_settings SET member_can_add_friends = TRUE WHERE member_can_add_friends IS NULL;
UPDATE group_settings SET require_admin_to_add_friends = FALSE WHERE require_admin_to_add_friends IS NULL;
UPDATE group_settings SET max_members = 500 WHERE max_members IS NULL;

-- 设置 NOT NULL 约束和默认值
ALTER TABLE group_settings
    ALTER COLUMN join_approval_required SET NOT NULL,
    ALTER COLUMN join_approval_required SET DEFAULT FALSE,
    ALTER COLUMN member_can_invite SET NOT NULL,
    ALTER COLUMN member_can_invite SET DEFAULT TRUE,
    ALTER COLUMN member_can_add_friends SET NOT NULL,
    ALTER COLUMN member_can_add_friends SET DEFAULT TRUE,
    ALTER COLUMN require_admin_to_add_friends SET NOT NULL,
    ALTER COLUMN require_admin_to_add_friends SET DEFAULT FALSE,
    ALTER COLUMN max_members SET NOT NULL,
    ALTER COLUMN max_members SET DEFAULT 500;
