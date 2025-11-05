use crate::database::models::AppVersion;
use crate::database::Database;
use chrono::{DateTime, Utc};
use sqlx::{query_as, query_scalar, Error, QueryBuilder};
use uuid::Uuid;

#[derive(Clone)]
pub struct VersionStore {
    database: Database,
}

impl VersionStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    pub async fn get_version(&self, id: Uuid) -> Result<Option<AppVersion>, Error> {
        let record = query_as::<_, AppVersion>(
            "SELECT id, platform, version, build_number, channel, download_key, download_url, file_size, checksum, signature, release_notes, mandatory, is_active, created_at, updated_at, released_at, created_by, updated_by FROM app_versions WHERE id = $1",
        )
        .bind(id)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn create_version(&self, version: &AppVersionInsert) -> Result<AppVersion, Error> {
        let record = query_as::<_, AppVersion>(
            r#"
            INSERT INTO app_versions (
                platform, version, build_number, channel,
                download_key, download_url, file_size, checksum, signature,
                release_notes, mandatory, is_active, released_at,
                created_at, updated_at, created_by, updated_by
            )
            VALUES (
                $1, $2, $3, $4,
                $5, $6, $7, $8, $9,
                $10, $11, $12, $13,
                NOW(), NOW(), $14, $14
            )
            RETURNING id, platform, version, build_number, channel,
                      download_key, download_url, file_size, checksum, signature,
                      release_notes, mandatory, is_active,
                      created_at, updated_at, released_at, created_by, updated_by
            "#,
        )
        .bind(&version.platform)
        .bind(&version.version)
        .bind(version.build_number)
        .bind(&version.channel)
        .bind(&version.download_key)
        .bind(&version.download_url)
        .bind(version.file_size)
        .bind(&version.checksum)
        .bind(&version.signature)
        .bind(&version.release_notes)
        .bind(version.mandatory)
        .bind(version.is_active)
        .bind(version.released_at)
        .bind(version.operator)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn update_version(
        &self,
        id: Uuid,
        update: &AppVersionUpdate,
    ) -> Result<Option<AppVersion>, Error> {
        let record = query_as::<_, AppVersion>(
            r#"
            UPDATE app_versions SET
                download_key = COALESCE($2, download_key),
                download_url = COALESCE($3, download_url),
                file_size = COALESCE($4, file_size),
                checksum = COALESCE($5, checksum),
                signature = COALESCE($6, signature),
                release_notes = COALESCE($7, release_notes),
                mandatory = COALESCE($8, mandatory),
                is_active = COALESCE($9, is_active),
                released_at = COALESCE($10, released_at),
                updated_at = NOW(),
                updated_by = $11
            WHERE id = $1
            RETURNING id, platform, version, build_number, channel,
                      download_key, download_url, file_size, checksum, signature,
                      release_notes, mandatory, is_active,
                      created_at, updated_at, released_at, created_by, updated_by
            "#,
        )
        .bind(id)
        .bind(update.download_key.as_ref())
        .bind(update.download_url.as_ref())
        .bind(update.file_size)
        .bind(update.checksum.as_ref())
        .bind(update.signature.as_ref())
        .bind(update.release_notes.as_ref())
        .bind(update.mandatory)
        .bind(update.is_active)
        .bind(update.released_at)
        .bind(update.operator)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn list_versions(
        &self,
        platform: &str,
        channel: Option<&str>,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<AppVersion>, Error> {
        let mut builder = QueryBuilder::new(
            "SELECT id, platform, version, build_number, channel, download_key, download_url, file_size, checksum, signature, release_notes, mandatory, is_active, created_at, updated_at, released_at, created_by, updated_by FROM app_versions WHERE platform = ",
        );
        builder.push_bind(platform);
        if let Some(channel) = channel {
            builder.push(" AND channel = ");
            builder.push_bind(channel);
        }
        builder.push(" ORDER BY build_number DESC, created_at DESC LIMIT ");
        builder.push_bind(limit);
        builder.push(" OFFSET ");
        builder.push_bind(offset);

        let query = builder.build_query_as::<AppVersion>();
        let records = query.fetch_all(&self.database.pool).await?;
        Ok(records)
    }

    pub async fn find_latest_active(
        &self,
        platform: &str,
        channel: &str,
    ) -> Result<Option<AppVersion>, Error> {
        let record = query_as::<_, AppVersion>(
            r#"
            SELECT id, platform, version, build_number, channel, download_key, download_url, file_size, checksum, signature, release_notes, mandatory, is_active, created_at, updated_at, released_at, created_by, updated_by
            FROM app_versions
            WHERE platform = $1 AND channel = $2 AND is_active = TRUE
            ORDER BY released_at DESC NULLS LAST, created_at DESC
            LIMIT 1
            "#,
        )
        .bind(platform)
        .bind(channel)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn deactivate_version(
        &self,
        id: Uuid,
        operator: Option<Uuid>,
    ) -> Result<Option<AppVersion>, Error> {
        let record = query_as::<_, AppVersion>(
            r#"
            UPDATE app_versions SET
                is_active = FALSE,
                updated_at = NOW(),
                updated_by = $2
            WHERE id = $1
            RETURNING id, platform, version, build_number, channel, download_key, download_url, file_size, checksum, signature, release_notes, mandatory, is_active, created_at, updated_at, released_at, created_by, updated_by
            "#,
        )
        .bind(id)
        .bind(operator)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn delete_version(&self, id: Uuid) -> Result<bool, Error> {
        let affected = sqlx::query("DELETE FROM app_versions WHERE id = $1")
            .bind(id)
            .execute(&self.database.pool)
            .await?
            .rows_affected();

        Ok(affected > 0)
    }

    pub async fn count_versions(
        &self,
        platform: &str,
        channel: Option<&str>,
    ) -> Result<i64, Error> {
        let query = if let Some(channel) = channel {
            sqlx::query_scalar(
                "SELECT COUNT(*) FROM app_versions WHERE platform = $1 AND channel = $2",
            )
            .bind(platform)
            .bind(channel)
        } else {
            sqlx::query_scalar("SELECT COUNT(*) FROM app_versions WHERE platform = $1")
                .bind(platform)
        };

        let total: i64 = query.fetch_one(&self.database.pool).await?;
        Ok(total)
    }
}

#[derive(Debug, Clone)]
pub struct AppVersionInsert {
    pub platform: String,
    pub version: String,
    pub build_number: i32,
    pub channel: String,
    pub download_key: String,
    pub download_url: Option<String>,
    pub file_size: Option<i64>,
    pub checksum: Option<String>,
    pub signature: Option<String>,
    pub release_notes: Option<String>,
    pub mandatory: bool,
    pub is_active: bool,
    pub released_at: Option<DateTime<Utc>>,
    pub operator: Option<Uuid>,
}

#[derive(Debug, Clone, Default)]
pub struct AppVersionUpdate {
    pub download_key: Option<String>,
    pub download_url: Option<String>,
    pub file_size: Option<i64>,
    pub checksum: Option<String>,
    pub signature: Option<String>,
    pub release_notes: Option<String>,
    pub mandatory: Option<bool>,
    pub is_active: Option<bool>,
    pub released_at: Option<DateTime<Utc>>,
    pub operator: Option<Uuid>,
}

pub async fn version_exists(
    db: &Database,
    platform: &str,
    channel: &str,
    version: &str,
) -> Result<bool, Error> {
    let exists: bool = query_scalar(
        "SELECT EXISTS(SELECT 1 FROM app_versions WHERE platform = $1 AND channel = $2 AND version = $3)",
    )
    .bind(platform)
    .bind(channel)
    .bind(version)
    .fetch_one(&db.pool)
    .await?;

    Ok(exists)
}
