-- 添加登录/注册验证码开关字段
ALTER TABLE captcha_settings
ADD COLUMN IF NOT EXISTS require_captcha_for_login BOOLEAN NOT NULL DEFAULT FALSE;

-- 更新现有记录的默认值
UPDATE captcha_settings
SET require_captcha_for_login = FALSE
WHERE require_captcha_for_login IS NULL;

