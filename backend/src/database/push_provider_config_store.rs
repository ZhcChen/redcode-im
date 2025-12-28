use crate::database::models::PushProviderConfig;
use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

pub struct PushProviderConfigStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> PushProviderConfigStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn list_configs(&self) -> Result<Vec<PushProviderConfig>, sqlx::Error> {
        let rows = sqlx::query_as::<_, PushProviderConfig>(
            r#"
            SELECT id, provider, platform, enabled, config_public, secret_ciphertext, secret_fingerprint,
                   created_at, updated_at, updated_by
            FROM push_provider_configs
            ORDER BY provider ASC, platform ASC
            "#,
        )
        .fetch_all(self.pool)
        .await?;

        Ok(rows)
    }

    pub async fn get_config(
        &self,
        provider: &str,
        platform: &str,
    ) -> Result<Option<PushProviderConfig>, sqlx::Error> {
        let row = sqlx::query_as::<_, PushProviderConfig>(
            r#"
            SELECT id, provider, platform, enabled, config_public, secret_ciphertext, secret_fingerprint,
                   created_at, updated_at, updated_by
            FROM push_provider_configs
            WHERE provider = $1 AND platform = $2
            LIMIT 1
            "#,
        )
        .bind(provider)
        .bind(platform)
        .fetch_optional(self.pool)
        .await?;

        Ok(row)
    }

    pub async fn upsert_config(
        &self,
        provider: &str,
        platform: &str,
        enabled: bool,
        config_public: Value,
        secret_ciphertext: Option<String>,
        secret_fingerprint: Option<String>,
        updated_by: Option<Uuid>,
    ) -> Result<PushProviderConfig, sqlx::Error> {
        let row = sqlx::query_as::<_, PushProviderConfig>(
            r#"
            INSERT INTO push_provider_configs (
                id, provider, platform, enabled, config_public,
                secret_ciphertext, secret_fingerprint,
                created_at, updated_at, updated_by
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW(), $8)
            ON CONFLICT (provider, platform) DO UPDATE SET
                enabled = EXCLUDED.enabled,
                config_public = EXCLUDED.config_public,
                secret_ciphertext = COALESCE(EXCLUDED.secret_ciphertext, push_provider_configs.secret_ciphertext),
                secret_fingerprint = COALESCE(EXCLUDED.secret_fingerprint, push_provider_configs.secret_fingerprint),
                updated_at = NOW(),
                updated_by = EXCLUDED.updated_by
            RETURNING id, provider, platform, enabled, config_public, secret_ciphertext, secret_fingerprint,
                      created_at, updated_at, updated_by
            "#,
        )
        .bind(crate::id::generate())
        .bind(provider)
        .bind(platform)
        .bind(enabled)
        .bind(config_public)
        .bind(secret_ciphertext)
        .bind(secret_fingerprint)
        .bind(updated_by)
        .fetch_one(self.pool)
        .await?;

        Ok(row)
    }
}

