-- 默认关闭邮箱注册/登录兼容链路，并把新环境的用户注册主线切到普通账号密码。

INSERT INTO public.general_settings (key, value, description, updated_at, updated_by)
VALUES ('auth_email_enabled', '0', '是否启用邮箱注册/登录兼容能力（0=关闭，1=开启）', NOW(), NULL)
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.user_account_limit_settings (
    id,
    enable_phone_validation,
    enable_email_validation,
    enable_length_validation,
    min_length,
    max_length,
    enable_alphanumeric_validation,
    updated_at,
    updated_by
)
VALUES (1, FALSE, FALSE, TRUE, 3, 20, FALSE, NOW(), NULL)
ON CONFLICT (id) DO NOTHING;

UPDATE public.user_account_limit_settings
SET
    enable_phone_validation = FALSE,
    enable_email_validation = FALSE,
    enable_length_validation = TRUE,
    min_length = 3,
    max_length = 20,
    enable_alphanumeric_validation = FALSE,
    updated_at = NOW(),
    updated_by = NULL
WHERE id = 1
  AND enable_phone_validation = TRUE
  AND enable_email_validation = FALSE
  AND enable_length_validation = FALSE
  AND min_length = 3
  AND max_length = 20
  AND enable_alphanumeric_validation = FALSE;
