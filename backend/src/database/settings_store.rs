use crate::database::models::{CaptchaSettingRecord, GeneralSettingRecord, UserAccountLimitRecord};
use crate::database::Database;
use sqlx::{query_as, Error};
use uuid::Uuid;

const CAPTCHA_SETTING_KEY: &str = "default";
const APP_NAME_KEY: &str = "app_name";
const USER_ACCOUNT_LIMIT_ID: i32 = 1;

#[derive(Clone)]
pub struct SettingsStore {
    database: Database,
}

impl SettingsStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    pub async fn get_captcha_setting(&self) -> Result<CaptchaSettingRecord, Error> {
        let record = query_as::<_, CaptchaSettingRecord>(
            r#"
            SELECT key, enabled, captcha_code, description, require_captcha_for_login, updated_at, updated_by
            FROM captcha_settings
            WHERE key = $1
            "#,
        )
        .bind(CAPTCHA_SETTING_KEY)
        .fetch_optional(&self.database.pool)
        .await?;

        match record {
            Some(setting) => Ok(setting),
            None => self.create_default_setting().await,
        }
    }

    pub async fn upsert_captcha_setting(
        &self,
        enabled: bool,
        captcha_code: &str,
        description: &str,
        require_captcha_for_login: bool,
        updated_by: Option<Uuid>,
    ) -> Result<CaptchaSettingRecord, Error> {
        let record = query_as::<_, CaptchaSettingRecord>(
            r#"
            INSERT INTO captcha_settings (key, enabled, captcha_code, description, require_captcha_for_login, updated_at, updated_by)
            VALUES ($1, $2, $3, $4, $5, NOW(), $6)
            ON CONFLICT (key) DO UPDATE SET
                enabled = EXCLUDED.enabled,
                captcha_code = EXCLUDED.captcha_code,
                description = EXCLUDED.description,
                require_captcha_for_login = EXCLUDED.require_captcha_for_login,
                updated_at = NOW(),
                updated_by = EXCLUDED.updated_by
            RETURNING key, enabled, captcha_code, description, require_captcha_for_login, updated_at, updated_by
            "#,
        )
        .bind(CAPTCHA_SETTING_KEY)
        .bind(enabled)
        .bind(captcha_code)
        .bind(description)
        .bind(require_captcha_for_login)
        .bind(updated_by)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn is_universal_captcha_code(&self, input: &str) -> Result<bool, Error> {
        let trimmed = input.trim();
        if trimmed.is_empty() {
            return Ok(false);
        }
        let setting = self.get_captcha_setting().await?;
        Ok(setting.enabled
            && !setting.captcha_code.trim().is_empty()
            && setting.captcha_code.trim().eq_ignore_ascii_case(trimmed))
    }

    async fn create_default_setting(&self) -> Result<CaptchaSettingRecord, Error> {
        let record = query_as::<_, CaptchaSettingRecord>(
            r#"
            INSERT INTO captcha_settings (key, enabled, captcha_code, description, require_captcha_for_login, updated_at)
            VALUES ($1, FALSE, '', '', FALSE, NOW())
            RETURNING key, enabled, captcha_code, description, require_captcha_for_login, updated_at, updated_by
            "#,
        )
        .bind(CAPTCHA_SETTING_KEY)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(record)
    }

    /// 检查是否开启验证码登录；邮箱注册不需要验证码。
    pub async fn require_captcha_for_login(&self) -> Result<bool, Error> {
        let setting = self.get_captcha_setting().await?;
        Ok(setting.require_captcha_for_login)
    }

    // ===== 通用设置相关方法 =====

    pub async fn get_general_setting(
        &self,
        key: &str,
    ) -> Result<Option<GeneralSettingRecord>, Error> {
        query_as::<_, GeneralSettingRecord>(
            r#"
            SELECT key, value, description, updated_at, updated_by
            FROM general_settings
            WHERE key = $1
            "#,
        )
        .bind(key)
        .fetch_optional(&self.database.pool)
        .await
    }

    pub async fn get_app_name(&self) -> Result<String, Error> {
        let record = self.get_general_setting(APP_NAME_KEY).await?;
        Ok(record
            .map(|r| r.value)
            .unwrap_or_else(|| "Redcode IM".to_string()))
    }

    pub async fn upsert_general_setting(
        &self,
        key: &str,
        value: &str,
        description: &str,
        updated_by: Option<Uuid>,
    ) -> Result<GeneralSettingRecord, Error> {
        let record = query_as::<_, GeneralSettingRecord>(
            r#"
            INSERT INTO general_settings (key, value, description, updated_at, updated_by)
            VALUES ($1, $2, $3, NOW(), $4)
            ON CONFLICT (key) DO UPDATE SET
                value = EXCLUDED.value,
                description = EXCLUDED.description,
                updated_at = NOW(),
                updated_by = EXCLUDED.updated_by
            RETURNING key, value, description, updated_at, updated_by
            "#,
        )
        .bind(key)
        .bind(value)
        .bind(description)
        .bind(updated_by)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(record)
    }

    // ===== 用户账号限制设置相关方法 =====

    pub async fn get_user_account_limit_setting(&self) -> Result<UserAccountLimitRecord, Error> {
        let record = query_as::<_, UserAccountLimitRecord>(
            r#"
            SELECT id, enable_phone_validation, enable_email_validation, enable_length_validation,
                   min_length, max_length, enable_alphanumeric_validation, updated_at, updated_by
            FROM user_account_limit_settings
            WHERE id = $1
            "#,
        )
        .bind(USER_ACCOUNT_LIMIT_ID)
        .fetch_optional(&self.database.pool)
        .await?;

        match record {
            Some(setting) => Ok(setting),
            None => self.create_default_user_account_limit_setting().await,
        }
    }

    pub async fn update_user_account_limit_setting(
        &self,
        enable_phone_validation: bool,
        enable_email_validation: bool,
        enable_length_validation: bool,
        min_length: i32,
        max_length: i32,
        enable_alphanumeric_validation: bool,
        updated_by: Option<Uuid>,
    ) -> Result<UserAccountLimitRecord, Error> {
        let record = query_as::<_, UserAccountLimitRecord>(
            r#"
            INSERT INTO user_account_limit_settings (id, enable_phone_validation, enable_email_validation,
                                                    enable_length_validation, min_length, max_length,
                                                    enable_alphanumeric_validation, updated_at, updated_by)
            VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), $8)
            ON CONFLICT (id) DO UPDATE SET
                enable_phone_validation = EXCLUDED.enable_phone_validation,
                enable_email_validation = EXCLUDED.enable_email_validation,
                enable_length_validation = EXCLUDED.enable_length_validation,
                min_length = EXCLUDED.min_length,
                max_length = EXCLUDED.max_length,
                enable_alphanumeric_validation = EXCLUDED.enable_alphanumeric_validation,
                updated_at = NOW(),
                updated_by = EXCLUDED.updated_by
            RETURNING id, enable_phone_validation, enable_email_validation, enable_length_validation,
                      min_length, max_length, enable_alphanumeric_validation, updated_at, updated_by
            "#,
        )
        .bind(USER_ACCOUNT_LIMIT_ID)
        .bind(enable_phone_validation)
        .bind(enable_email_validation)
        .bind(enable_length_validation)
        .bind(min_length)
        .bind(max_length)
        .bind(enable_alphanumeric_validation)
        .bind(updated_by)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(record)
    }

    async fn create_default_user_account_limit_setting(
        &self,
    ) -> Result<UserAccountLimitRecord, Error> {
        let record = query_as::<_, UserAccountLimitRecord>(
            r#"
            INSERT INTO user_account_limit_settings (id, enable_phone_validation, enable_email_validation,
                                                    enable_length_validation, min_length, max_length,
                                                    enable_alphanumeric_validation, updated_at)
            VALUES ($1, TRUE, FALSE, FALSE, 3, 20, FALSE, NOW())
            RETURNING id, enable_phone_validation, enable_email_validation, enable_length_validation,
                      min_length, max_length, enable_alphanumeric_validation, updated_at, updated_by
            "#,
        )
        .bind(USER_ACCOUNT_LIMIT_ID)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(record)
    }
}
