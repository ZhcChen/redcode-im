use crate::database::models::{AppVersion, HotUpdate, HotUpdateEvent, Platform};
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
            "SELECT id, platform, version, build_number, channel, download_key, download_url, app_store_url, file_size, checksum, signature, release_notes, mandatory, is_active, created_at, updated_at, released_at, created_by, updated_by FROM app_versions WHERE id = $1",
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
                download_key, download_url, app_store_url, file_size, checksum, signature,
                release_notes, mandatory, is_active, released_at,
                created_at, updated_at, created_by, updated_by
            )
            VALUES (
                $1, $2, $3, $4,
                $5, $6, $7, $8, $9, $10,
                $11, $12, $13, $14,
                NOW(), NOW(), $15, $15
            )
            RETURNING id, platform, version, build_number, channel,
                      download_key, download_url, app_store_url, file_size, checksum, signature,
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
        .bind(&version.app_store_url)
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
                app_store_url = COALESCE($4, app_store_url),
                file_size = COALESCE($5, file_size),
                checksum = COALESCE($6, checksum),
                signature = COALESCE($7, signature),
                release_notes = COALESCE($8, release_notes),
                mandatory = COALESCE($9, mandatory),
                is_active = COALESCE($10, is_active),
                released_at = COALESCE($11, released_at),
                updated_at = NOW(),
                updated_by = $12
            WHERE id = $1
            RETURNING id, platform, version, build_number, channel,
                      download_key, download_url, app_store_url, file_size, checksum, signature,
                      release_notes, mandatory, is_active,
                      created_at, updated_at, released_at, created_by, updated_by
            "#,
        )
        .bind(id)
        .bind(update.download_key.as_ref())
        .bind(update.download_url.as_ref())
        .bind(update.app_store_url.as_ref())
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
        platform: Platform,
        channel: Option<&str>,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<AppVersion>, Error> {
        let mut builder = QueryBuilder::new(
            "SELECT id, platform, version, build_number, channel, download_key, download_url, app_store_url, file_size, checksum, signature, release_notes, mandatory, is_active, created_at, updated_at, released_at, created_by, updated_by FROM app_versions WHERE platform = ",
        );
        builder.push_bind(platform.as_str());
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
        platform: Platform,
        channel: &str,
    ) -> Result<Option<AppVersion>, Error> {
        let record = query_as::<_, AppVersion>(
            r#"
            SELECT id, platform, version, build_number, channel, download_key, download_url, app_store_url, file_size, checksum, signature, release_notes, mandatory, is_active, created_at, updated_at, released_at, created_by, updated_by
            FROM app_versions
            WHERE platform = $1 AND channel = $2 AND is_active = TRUE
            ORDER BY released_at DESC NULLS LAST, created_at DESC
            LIMIT 1
            "#,
        )
        .bind(platform.as_str())
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
            RETURNING id, platform, version, build_number, channel, download_key, download_url, app_store_url, file_size, checksum, signature, release_notes, mandatory, is_active, created_at, updated_at, released_at, created_by, updated_by
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
        platform: Platform,
        channel: Option<&str>,
    ) -> Result<i64, Error> {
        let query = if let Some(channel) = channel {
            sqlx::query_scalar(
                "SELECT COUNT(*) FROM app_versions WHERE platform = $1 AND channel = $2",
            )
            .bind(platform.as_str())
            .bind(channel)
        } else {
            sqlx::query_scalar("SELECT COUNT(*) FROM app_versions WHERE platform = $1")
                .bind(platform.as_str())
        };

        let total: i64 = query.fetch_one(&self.database.pool).await?;
        Ok(total)
    }
}

#[derive(Debug, Clone)]
pub struct AppVersionInsert {
    pub platform: Platform,
    pub version: String,
    pub build_number: i32,
    pub channel: String,
    pub download_key: String,
    pub download_url: Option<String>,
    pub app_store_url: Option<String>,
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
    pub app_store_url: Option<String>,
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
    platform: Platform,
    channel: &str,
    version: &str,
) -> Result<bool, Error> {
    let exists: bool = query_scalar(
        "SELECT EXISTS(SELECT 1 FROM app_versions WHERE platform = $1 AND channel = $2 AND version = $3)",
    )
    .bind(platform.as_str())
    .bind(channel)
    .bind(version)
    .fetch_one(&db.pool)
    .await?;

    Ok(exists)
}

#[derive(Debug, Clone)]
pub struct HotUpdateInsert {
    pub platform: Platform,
    pub app_version_id: Uuid,
    pub patch_version: String,
    pub channel: String,
    pub download_key: String,
    pub download_url: Option<String>,
    pub file_size: Option<i64>,
    pub checksum: Option<String>,
    pub signature: Option<String>,
    pub rollout_percentage: i32,
    pub mandatory: bool,
    pub description: Option<String>,
    pub released_at: Option<DateTime<Utc>>,
    pub operator: Option<Uuid>,
}

#[derive(Debug, Clone, Default)]
pub struct HotUpdateUpdate {
    pub patch_version: Option<String>,
    pub channel: Option<String>,
    pub download_key: Option<String>,
    pub download_url: Option<String>,
    pub file_size: Option<i64>,
    pub checksum: Option<String>,
    pub signature: Option<String>,
    pub rollout_percentage: Option<i32>,
    pub mandatory: Option<bool>,
    pub description: Option<String>,
    pub is_active: Option<bool>,
    pub released_at: Option<DateTime<Utc>>,
    pub operator: Option<Uuid>,
}

#[derive(Debug, Clone)]
pub struct HotUpdateEventInsert {
    pub platform: Platform,
    pub channel: Option<String>,
    pub base_version: String,
    pub patch_version: String,
    pub event_type: String,
    pub client_id: Option<String>,
    pub message: Option<String>,
    // 新增的详细字段
    pub client_type: Option<String>,
    pub os_version: Option<String>,
    pub os_arch: Option<String>,
    pub app_arch: Option<String>,
    pub build_number: Option<i32>,
    pub trigger_source: Option<String>,
    pub network_type: Option<String>,
    pub device_info: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct HotUpdateEventQueryParams<'a> {
    pub platform: Option<Platform>,
    pub channel: Option<&'a str>,
    pub event_type: Option<&'a str>,
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub limit: i64,
    pub offset: i64,
}

impl VersionStore {
    pub async fn create_hot_update(&self, insert: &HotUpdateInsert) -> Result<HotUpdate, Error> {
        let record = query_as::<_, HotUpdate>(
            r#"
            INSERT INTO hot_updates (
                platform, app_version_id, patch_version, channel,
                download_key, download_url, file_size, checksum, signature,
                rollout_percentage, mandatory, description, released_at,
                created_at, updated_at, is_active, created_by, updated_by
            )
            VALUES (
                $1, $2, $3, $4,
                $5, $6, $7, $8, $9,
                $10, $11, $12, $13,
                NOW(), NOW(), TRUE, $14, $14
            )
            RETURNING id, platform, app_version_id, patch_version, channel,
                      download_key, download_url, file_size, checksum, signature,
                      rollout_percentage, mandatory, description, is_active,
                      released_at, created_at, updated_at, created_by, updated_by
            "#,
        )
        .bind(insert.platform.as_str())
        .bind(insert.app_version_id)
        .bind(&insert.patch_version)
        .bind(&insert.channel)
        .bind(&insert.download_key)
        .bind(&insert.download_url)
        .bind(insert.file_size)
        .bind(&insert.checksum)
        .bind(&insert.signature)
        .bind(insert.rollout_percentage)
        .bind(insert.mandatory)
        .bind(&insert.description)
        .bind(insert.released_at)
        .bind(insert.operator)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn update_hot_update(
        &self,
        id: Uuid,
        update: &HotUpdateUpdate,
    ) -> Result<Option<HotUpdate>, Error> {
        let record = query_as::<_, HotUpdate>(
            r#"
            UPDATE hot_updates SET
                patch_version = COALESCE($2, patch_version),
                channel = COALESCE($3, channel),
                download_key = COALESCE($4, download_key),
                download_url = COALESCE($5, download_url),
                file_size = COALESCE($6, file_size),
                checksum = COALESCE($7, checksum),
                signature = COALESCE($8, signature),
                rollout_percentage = COALESCE($9, rollout_percentage),
                mandatory = COALESCE($10, mandatory),
                description = COALESCE($11, description),
                is_active = COALESCE($12, is_active),
                released_at = COALESCE($13, released_at),
                updated_at = NOW(),
                updated_by = $14
            WHERE id = $1
            RETURNING id, platform, app_version_id, patch_version, channel,
                      download_key, download_url, file_size, checksum, signature,
                      rollout_percentage, mandatory, description, is_active,
                      released_at, created_at, updated_at, created_by, updated_by
            "#,
        )
        .bind(id)
        .bind(update.patch_version.as_ref())
        .bind(update.channel.as_ref())
        .bind(update.download_key.as_ref())
        .bind(update.download_url.as_ref())
        .bind(update.file_size)
        .bind(update.checksum.as_ref())
        .bind(update.signature.as_ref())
        .bind(update.rollout_percentage)
        .bind(update.mandatory)
        .bind(update.description.as_ref())
        .bind(update.is_active)
        .bind(update.released_at)
        .bind(update.operator)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn get_hot_update(&self, id: Uuid) -> Result<Option<HotUpdate>, Error> {
        let record = query_as::<_, HotUpdate>(
            r#"
            SELECT id, platform, app_version_id, patch_version, channel,
                   download_key, download_url, file_size, checksum, signature,
                   rollout_percentage, mandatory, description, is_active,
                   released_at, created_at, updated_at, created_by, updated_by
            FROM hot_updates
            WHERE id = $1
            "#,
        )
        .bind(id)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(record)
    }

    pub async fn delete_hot_update(&self, id: Uuid) -> Result<bool, Error> {
        let affected = sqlx::query("DELETE FROM hot_updates WHERE id = $1")
            .bind(id)
            .execute(&self.database.pool)
            .await?
            .rows_affected();

        Ok(affected > 0)
    }

    pub async fn insert_hot_update_event(
        &self,
        insert: &HotUpdateEventInsert,
    ) -> Result<(), Error> {
        sqlx::query(
            r#"
            INSERT INTO hot_update_events (
                platform, channel, base_version, patch_version,
                event_type, client_id, message,
                client_type, os_version, os_arch, app_arch,
                build_number, trigger_source, network_type, device_info
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
            "#,
        )
        .bind(insert.platform.as_str())
        .bind(insert.channel.as_deref())
        .bind(&insert.base_version)
        .bind(&insert.patch_version)
        .bind(&insert.event_type)
        .bind(insert.client_id.as_deref())
        .bind(insert.message.as_deref())
        .bind(insert.client_type.as_deref())
        .bind(insert.os_version.as_deref())
        .bind(insert.os_arch.as_deref())
        .bind(insert.app_arch.as_deref())
        .bind(insert.build_number)
        .bind(insert.trigger_source.as_deref())
        .bind(insert.network_type.as_deref())
        .bind(insert.device_info.as_deref())
        .execute(&self.database.pool)
        .await?;

        Ok(())
    }

    pub async fn list_hot_update_events(
        &self,
        params: &HotUpdateEventQueryParams<'_>,
    ) -> Result<Vec<HotUpdateEvent>, Error> {
        let mut builder = QueryBuilder::new(
            "SELECT id, platform, channel, base_version, patch_version, event_type, client_id, message, created_at, client_type, os_version, os_arch, app_arch, build_number, trigger_source, network_type, device_info FROM hot_update_events WHERE 1=1",
        );
        if let Some(platform) = params.platform {
            builder
                .push(" AND platform = ")
                .push_bind(platform.as_str());
        }
        if let Some(channel) = params.channel {
            builder.push(" AND channel = ").push_bind(channel);
        }
        if let Some(event_type) = params.event_type {
            builder.push(" AND event_type = ").push_bind(event_type);
        }
        if let Some(start) = params.start_time {
            builder.push(" AND created_at >= ").push_bind(start);
        }
        if let Some(end) = params.end_time {
            builder.push(" AND created_at <= ").push_bind(end);
        }
        builder
            .push(" ORDER BY created_at DESC LIMIT ")
            .push_bind(params.limit)
            .push(" OFFSET ")
            .push_bind(params.offset);

        let query = builder.build_query_as::<HotUpdateEvent>();
        let records = query.fetch_all(&self.database.pool).await?;
        Ok(records)
    }

    pub async fn count_hot_update_events(
        &self,
        params: &HotUpdateEventQueryParams<'_>,
    ) -> Result<i64, Error> {
        let mut builder = QueryBuilder::new("SELECT COUNT(*) FROM hot_update_events WHERE 1=1");
        if let Some(platform) = params.platform {
            builder
                .push(" AND platform = ")
                .push_bind(platform.as_str());
        }
        if let Some(channel) = params.channel {
            builder.push(" AND channel = ").push_bind(channel);
        }
        if let Some(event_type) = params.event_type {
            builder.push(" AND event_type = ").push_bind(event_type);
        }
        if let Some(start) = params.start_time {
            builder.push(" AND created_at >= ").push_bind(start);
        }
        if let Some(end) = params.end_time {
            builder.push(" AND created_at <= ").push_bind(end);
        }

        let query = builder.build_query_scalar();
        let total: i64 = query.fetch_one(&self.database.pool).await?;
        Ok(total)
    }

    pub async fn list_hot_updates(
        &self,
        platform: Option<Platform>,
        channel: Option<&str>,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<HotUpdate>, Error> {
        let mut builder = QueryBuilder::new(
            "SELECT id, platform, app_version_id, patch_version, channel, download_key, download_url, file_size, checksum, signature, rollout_percentage, mandatory, description, is_active, released_at, created_at, updated_at, created_by, updated_by FROM hot_updates WHERE 1=1",
        );
        if let Some(platform) = platform {
            builder.push(" AND platform = ");
            builder.push_bind(platform.as_str());
        }
        if let Some(channel) = channel {
            builder.push(" AND channel = ");
            builder.push_bind(channel);
        }
        builder.push(" ORDER BY released_at DESC NULLS LAST, created_at DESC LIMIT ");
        builder.push_bind(limit);
        builder.push(" OFFSET ");
        builder.push_bind(offset);

        let query = builder.build_query_as::<HotUpdate>();
        let records = query.fetch_all(&self.database.pool).await?;
        Ok(records)
    }

    pub async fn count_hot_updates(
        &self,
        platform: Option<Platform>,
        channel: Option<&str>,
    ) -> Result<i64, Error> {
        let mut builder = QueryBuilder::new("SELECT COUNT(*) FROM hot_updates WHERE 1=1");
        if let Some(platform) = platform {
            builder.push(" AND platform = ");
            builder.push_bind(platform.as_str());
        }
        if let Some(channel) = channel {
            builder.push(" AND channel = ");
            builder.push_bind(channel);
        }
        let query = builder.build_query_scalar();
        let total: i64 = query.fetch_one(&self.database.pool).await?;
        Ok(total)
    }

    pub async fn find_active_hot_updates(
        &self,
        platform: Platform,
        channel: &str,
        current_version: &str,
    ) -> Result<Vec<HotUpdate>, Error> {
        let records = query_as::<_, HotUpdate>(
            r#"
            SELECT hu.id, hu.platform, hu.app_version_id, hu.patch_version, hu.channel,
                   hu.download_key, hu.download_url, hu.file_size, hu.checksum, hu.signature,
                   hu.rollout_percentage, hu.mandatory, hu.description, hu.is_active,
                   hu.released_at, hu.created_at, hu.updated_at, hu.created_by, hu.updated_by
            FROM hot_updates hu
            JOIN app_versions av ON av.id = hu.app_version_id
            WHERE hu.platform = $1
              AND hu.channel = $2
              AND av.version = $3
              AND av.is_active = TRUE
              AND hu.is_active = TRUE
            ORDER BY hu.released_at DESC NULLS LAST, hu.created_at DESC
            "#,
        )
        .bind(platform.as_str())
        .bind(channel)
        .bind(current_version)
        .fetch_all(&self.database.pool)
        .await?;

        Ok(records)
    }
}
