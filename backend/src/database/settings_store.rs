use crate::database::models::{CaptchaSettingRecord, GeneralSettingRecord};
use crate::database::Database;
use sqlx::{query_as, Error};
use uuid::Uuid;

const CAPTCHA_SETTING_KEY: &str = "default";
const APP_NAME_KEY: &str = "app_name";

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
            SELECT key, enabled, captcha_code, description, updated_at, updated_by
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
        updated_by: Option<Uuid>,
    ) -> Result<CaptchaSettingRecord, Error> {
        let record = query_as::<_, CaptchaSettingRecord>(
            r#"
            INSERT INTO captcha_settings (key, enabled, captcha_code, description, updated_at, updated_by)
            VALUES ($1, $2, $3, $4, NOW(), $5)
            ON CONFLICT (key) DO UPDATE SET
                enabled = EXCLUDED.enabled,
                captcha_code = EXCLUDED.captcha_code,
                description = EXCLUDED.description,
                updated_at = NOW(),
                updated_by = EXCLUDED.updated_by
            RETURNING key, enabled, captcha_code, description, updated_at, updated_by
            "#,
        )
        .bind(CAPTCHA_SETTING_KEY)
        .bind(enabled)
        .bind(captcha_code)
        .bind(description)
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
            INSERT INTO captcha_settings (key, enabled, captcha_code, description, updated_at)
            VALUES ($1, FALSE, '', '', NOW())
            RETURNING key, enabled, captcha_code, description, updated_at, updated_by
            "#,
        )
        .bind(CAPTCHA_SETTING_KEY)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(record)
    }

    // ===== 通用设置相关方法 =====

    pub async fn get_general_setting(&self, key: &str) -> Result<Option<GeneralSettingRecord>, Error> {
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
}
