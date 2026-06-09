use crate::database::models::ObjectStorageConfigRecord;
use crate::database::Database;
use sqlx::{query_as, Error, Postgres, Transaction};

#[derive(Debug, Clone)]
pub struct CreateObjectStorageConfigVersionInput {
    pub provider: String,
    pub endpoint: Option<String>,
    pub region: String,
    pub encrypted_key_id: Option<String>,
    pub encrypted_application_key: Option<String>,
    pub private_bucket: String,
    pub public_bucket: Option<String>,
    pub public_base_url: Option<String>,
    pub upload_url_ttl_seconds: i32,
    pub download_url_ttl_seconds: i32,
    pub version: i32,
    pub status: String,
    pub rollback_source_version: Option<i32>,
    pub change_note: Option<String>,
    pub created_by: Option<String>,
    pub applied_by: Option<String>,
    pub activated_at: Option<chrono::DateTime<chrono::Utc>>,
    pub previous_active_version: Option<i32>,
    pub previous_active_next_status: Option<String>,
}

#[derive(Clone)]
pub struct ObjectStorageConfigStore {
    database: Database,
}

impl ObjectStorageConfigStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    pub async fn get_active(&self) -> Result<Option<ObjectStorageConfigRecord>, Error> {
        query_as::<_, ObjectStorageConfigRecord>(
            r#"
            SELECT id, provider, endpoint, region, encrypted_key_id, encrypted_application_key,
                   private_bucket, public_bucket, public_base_url,
                   upload_url_ttl_seconds, download_url_ttl_seconds,
                   version, status, rollback_source_version, change_note,
                   created_by, applied_by, activated_at, created_at, updated_at
            FROM object_storage_configs
            WHERE status = 'active'
            ORDER BY version DESC
            LIMIT 1
            "#,
        )
        .fetch_optional(&self.database.pool)
        .await
    }

    pub async fn get_latest_version(&self) -> Result<i32, Error> {
        let value =
            sqlx::query_scalar::<_, Option<i32>>("SELECT MAX(version) FROM object_storage_configs")
                .fetch_one(&self.database.pool)
                .await?;

        Ok(value.unwrap_or(0))
    }

    pub async fn get_by_version(
        &self,
        version: i32,
    ) -> Result<Option<ObjectStorageConfigRecord>, Error> {
        query_as::<_, ObjectStorageConfigRecord>(
            r#"
            SELECT id, provider, endpoint, region, encrypted_key_id, encrypted_application_key,
                   private_bucket, public_bucket, public_base_url,
                   upload_url_ttl_seconds, download_url_ttl_seconds,
                   version, status, rollback_source_version, change_note,
                   created_by, applied_by, activated_at, created_at, updated_at
            FROM object_storage_configs
            WHERE version = $1
            LIMIT 1
            "#,
        )
        .bind(version)
        .fetch_optional(&self.database.pool)
        .await
    }

    pub async fn list_history(&self) -> Result<Vec<ObjectStorageConfigRecord>, Error> {
        query_as::<_, ObjectStorageConfigRecord>(
            r#"
            SELECT id, provider, endpoint, region, encrypted_key_id, encrypted_application_key,
                   private_bucket, public_bucket, public_base_url,
                   upload_url_ttl_seconds, download_url_ttl_seconds,
                   version, status, rollback_source_version, change_note,
                   created_by, applied_by, activated_at, created_at, updated_at
            FROM object_storage_configs
            ORDER BY version DESC
            "#,
        )
        .fetch_all(&self.database.pool)
        .await
    }

    pub async fn create_version(
        &self,
        input: CreateObjectStorageConfigVersionInput,
    ) -> Result<ObjectStorageConfigRecord, Error> {
        let mut tx = self.database.pool.begin().await?;

        if let (Some(previous_active_version), Some(previous_active_next_status)) = (
            input.previous_active_version,
            input.previous_active_next_status.as_deref(),
        ) {
            sqlx::query(
                r#"
                UPDATE object_storage_configs
                SET status = $2,
                    updated_at = NOW()
                WHERE version = $1
                "#,
            )
            .bind(previous_active_version)
            .bind(previous_active_next_status)
            .execute(&mut *tx)
            .await?;
        }

        let record = insert_version_tx(&mut tx, input).await?;
        tx.commit().await?;
        Ok(record)
    }
}

async fn insert_version_tx(
    tx: &mut Transaction<'_, Postgres>,
    input: CreateObjectStorageConfigVersionInput,
) -> Result<ObjectStorageConfigRecord, Error> {
    query_as::<_, ObjectStorageConfigRecord>(
        r#"
        INSERT INTO object_storage_configs (
            provider,
            endpoint,
            region,
            encrypted_key_id,
            encrypted_application_key,
            private_bucket,
            public_bucket,
            public_base_url,
            upload_url_ttl_seconds,
            download_url_ttl_seconds,
            version,
            status,
            rollback_source_version,
            change_note,
            created_by,
            applied_by,
            activated_at
        )
        VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8,
            $9, $10, $11, $12, $13, $14, $15, $16, $17
        )
        RETURNING id, provider, endpoint, region, encrypted_key_id, encrypted_application_key,
                  private_bucket, public_bucket, public_base_url,
                  upload_url_ttl_seconds, download_url_ttl_seconds,
                  version, status, rollback_source_version, change_note,
                  created_by, applied_by, activated_at, created_at, updated_at
        "#,
    )
    .bind(input.provider)
    .bind(input.endpoint)
    .bind(input.region)
    .bind(input.encrypted_key_id)
    .bind(input.encrypted_application_key)
    .bind(input.private_bucket)
    .bind(input.public_bucket)
    .bind(input.public_base_url)
    .bind(input.upload_url_ttl_seconds)
    .bind(input.download_url_ttl_seconds)
    .bind(input.version)
    .bind(input.status)
    .bind(input.rollback_source_version)
    .bind(input.change_note)
    .bind(input.created_by)
    .bind(input.applied_by)
    .bind(input.activated_at)
    .fetch_one(&mut **tx)
    .await
}
