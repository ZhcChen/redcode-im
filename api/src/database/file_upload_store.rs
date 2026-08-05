use crate::database::models::FileUploadRecord;
use crate::database::Database;
use sqlx::{query_as, Error};
use uuid::Uuid;

/// 文件上传记录存储
///
/// 目前主要用于管理通过对象存储直传的文件：
/// - 按 hash + size 去重，复用已上传完成的 object_key
/// - 记录上传状态，避免复用尚未完成上传的文件
#[derive(Clone)]
pub struct FileUploadStore {
    database: Database,
}

impl FileUploadStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    pub fn pool(&self) -> &sqlx::PgPool {
        &self.database.pool
    }

    /// 根据 object_key 获取记录（不限定状态）
    pub async fn get_by_key(
        &self,
        storage_provider_id: &Uuid,
        object_key: &str,
    ) -> Result<Option<FileUploadRecord>, Error> {
        query_as::<_, FileUploadRecord>(
            r#"
            SELECT id, storage_provider_id, object_key, hash_alg, hash_value,
                   file_size, content_type, status, uploaded_at,
                   updated_at, created_at, last_error
            FROM file_upload_records
            WHERE storage_provider_id = $1
              AND object_key = $2
            LIMIT 1
            "#,
        )
        .bind(storage_provider_id)
        .bind(object_key)
        .fetch_optional(self.pool())
        .await
    }

    pub async fn has_completed_by_key(
        &self,
        storage_provider_id: &Uuid,
        object_key: &str,
    ) -> Result<bool, Error> {
        let exists: Option<(i32,)> = sqlx::query_as(
            r#"
            SELECT 1
            FROM file_upload_records
            WHERE storage_provider_id = $1
              AND object_key = $2
              AND status = 1
            LIMIT 1
            "#,
        )
        .bind(storage_provider_id)
        .bind(object_key)
        .fetch_optional(self.pool())
        .await?;

        Ok(exists.is_some())
    }

    /// 查找已完成上传、且匹配指定 hash 和文件大小的记录
    ///
    /// 如果提供前缀，则仅匹配 object_key 以该前缀开头的记录
    pub async fn find_completed_by_hash(
        &self,
        storage_provider_id: &Uuid,
        hash_alg: i16,
        hash_value: &str,
        file_size: i64,
        object_key_prefix: Option<&str>,
    ) -> Result<Option<FileUploadRecord>, Error> {
        let pool = &self.database.pool;

        if let Some(prefix) = object_key_prefix {
            query_as::<_, FileUploadRecord>(
                r#"
                SELECT r.id, r.storage_provider_id, r.object_key, r.hash_alg, r.hash_value,
                       r.file_size, r.content_type, r.status, r.uploaded_at,
                       r.updated_at, r.created_at, r.last_error
                FROM file_upload_records r
                JOIN file_upload_audit_tasks a
                  ON a.storage_provider_id = r.storage_provider_id
                 AND a.object_key = r.object_key
                WHERE r.storage_provider_id = $1
                  AND r.hash_alg = $2
                  AND r.hash_value = $3
                  AND r.file_size = $4
                  AND r.status = 1
                  AND a.status = 1
                  AND r.object_key LIKE $5 || '%'
                ORDER BY r.uploaded_at DESC NULLS LAST, r.created_at DESC
                LIMIT 1
                "#,
            )
            .bind(storage_provider_id)
            .bind(hash_alg)
            .bind(hash_value)
            .bind(file_size)
            .bind(prefix)
            .fetch_optional(pool)
            .await
        } else {
            query_as::<_, FileUploadRecord>(
                r#"
                SELECT r.id, r.storage_provider_id, r.object_key, r.hash_alg, r.hash_value,
                       r.file_size, r.content_type, r.status, r.uploaded_at,
                       r.updated_at, r.created_at, r.last_error
                FROM file_upload_records r
                JOIN file_upload_audit_tasks a
                  ON a.storage_provider_id = r.storage_provider_id
                 AND a.object_key = r.object_key
                WHERE r.storage_provider_id = $1
                  AND r.hash_alg = $2
                  AND r.hash_value = $3
                  AND r.file_size = $4
                  AND r.status = 1
                  AND a.status = 1
                ORDER BY r.uploaded_at DESC NULLS LAST, r.created_at DESC
                LIMIT 1
                "#,
            )
            .bind(storage_provider_id)
            .bind(hash_alg)
            .bind(hash_value)
            .bind(file_size)
            .fetch_optional(pool)
            .await
        }
    }

    /// 创建一条“上传中”的记录（status=0）
    pub async fn create_pending_record(
        &self,
        storage_provider_id: &Uuid,
        object_key: &str,
        hash_alg: i16,
        hash_value: &str,
        file_size: Option<i64>,
        content_type: Option<&str>,
    ) -> Result<FileUploadRecord, Error> {
        let pool = &self.database.pool;

        query_as::<_, FileUploadRecord>(
            r#"
            INSERT INTO file_upload_records (
                storage_provider_id,
                object_key,
                hash_alg,
                hash_value,
                file_size,
                content_type,
                status,
                uploaded_at,
                updated_at,
                created_at,
                last_error
            )
            VALUES ($1, $2, $3, $4, $5, $6, 0, NULL, NOW(), NOW(), NULL)
            ON CONFLICT (storage_provider_id, object_key) DO UPDATE
            SET hash_alg = EXCLUDED.hash_alg,
                hash_value = EXCLUDED.hash_value,
                file_size = EXCLUDED.file_size,
                content_type = EXCLUDED.content_type,
                status = EXCLUDED.status,
                updated_at = NOW()
            RETURNING id, storage_provider_id, object_key, hash_alg, hash_value,
                      file_size, content_type, status, uploaded_at,
                      updated_at, created_at, last_error
            "#,
        )
        .bind(storage_provider_id)
        .bind(object_key)
        .bind(hash_alg)
        .bind(hash_value)
        .bind(file_size)
        .bind(content_type)
        .fetch_one(pool)
        .await
    }

    /// 将指定 object_key 标记为“上传完成”（status = 1）
    ///
    /// 返回值表示是否有记录被更新（若不存在记录则返回 false，不视为致命错误）
    pub async fn mark_completed_by_key(
        &self,
        storage_provider_id: &Uuid,
        object_key: &str,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_records
            SET status = 1,
                uploaded_at = COALESCE(uploaded_at, NOW()),
                updated_at = NOW(),
                last_error = NULL
            WHERE storage_provider_id = $1
              AND object_key = $2
              AND status <> 3
            "#,
        )
        .bind(storage_provider_id)
        .bind(object_key)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 将指定 object_key 标记为“上传失败”（status = 2）
    pub async fn mark_failed_by_key(
        &self,
        storage_provider_id: &Uuid,
        object_key: &str,
        last_error: Option<&str>,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_records
            SET status = 2,
                updated_at = NOW(),
                last_error = $3
            WHERE storage_provider_id = $1
              AND object_key = $2
              AND status <> 3
            "#,
        )
        .bind(storage_provider_id)
        .bind(object_key)
        .bind(last_error)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 将指定 object_key 标记为“已删除”（status = 3）
    pub async fn mark_deleted_by_key(
        &self,
        storage_provider_id: &Uuid,
        object_key: &str,
        last_error: Option<&str>,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_records
            SET status = 3,
                updated_at = NOW(),
                last_error = $3
            WHERE storage_provider_id = $1
              AND object_key = $2
            "#,
        )
        .bind(storage_provider_id)
        .bind(object_key)
        .bind(last_error)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 判断 object_key 是否仍被业务数据引用
    pub async fn is_object_key_referenced(&self, object_key: &str) -> Result<bool, Error> {
        let exists: Option<(i32,)> = sqlx::query_as(
            r#"
	            SELECT 1
	            WHERE
	                EXISTS (SELECT 1 FROM users WHERE avatar_object_key = $1 LIMIT 1)
	                OR EXISTS (SELECT 1 FROM rooms WHERE avatar_object_key = $1 LIMIT 1)
	                OR EXISTS (SELECT 1 FROM emoji_packs WHERE icon_object_key = $1 LIMIT 1)
	                OR EXISTS (SELECT 1 FROM emoji_items WHERE image_object_key = $1 LIMIT 1)
	                OR EXISTS (SELECT 1 FROM app_versions WHERE download_key = $1 LIMIT 1)
	                OR EXISTS (SELECT 1 FROM hot_updates WHERE download_key = $1 LIMIT 1)
	                OR EXISTS (SELECT 1 FROM report_attachments WHERE object_key = $1 LIMIT 1)
	                OR EXISTS (SELECT 1 FROM message_attachment_commits WHERE object_key = $1 LIMIT 1)
	                OR EXISTS (
	                    SELECT 1
	                    FROM message_parts mp
	                    JOIN messages m ON m.id = mp.message_id
                    WHERE m.deleted_at IS NULL
                      AND (mp.attachment_key = $1 OR mp.thumbnail_key = $1)
                    LIMIT 1
                )
            LIMIT 1
            "#,
        )
        .bind(object_key)
        .fetch_optional(self.pool())
        .await?;

        Ok(exists.is_some())
    }

    /// 批量拉取“上传中且已超时”的记录（status=0）
    pub async fn list_stale_pending_records(
        &self,
        cutoff: chrono::DateTime<chrono::Utc>,
        limit: i64,
    ) -> Result<Vec<FileUploadRecord>, Error> {
        query_as::<_, FileUploadRecord>(
            r#"
            SELECT id, storage_provider_id, object_key, hash_alg, hash_value,
                   file_size, content_type, status, uploaded_at,
                   updated_at, created_at, last_error
            FROM file_upload_records
            WHERE status = 0
              AND created_at < $1
            ORDER BY created_at ASC
            LIMIT $2
            "#,
        )
        .bind(cutoff)
        .bind(limit)
        .fetch_all(self.pool())
        .await
    }

    /// 批量拉取“已完成但可能已无引用”的旧记录（status=1）
    pub async fn list_old_completed_records(
        &self,
        cutoff: chrono::DateTime<chrono::Utc>,
        limit: i64,
    ) -> Result<Vec<FileUploadRecord>, Error> {
        query_as::<_, FileUploadRecord>(
            r#"
            SELECT id, storage_provider_id, object_key, hash_alg, hash_value,
                   file_size, content_type, status, uploaded_at,
                   updated_at, created_at, last_error
            FROM file_upload_records
            WHERE status = 1
              AND COALESCE(uploaded_at, created_at) < $1
            ORDER BY COALESCE(uploaded_at, created_at) ASC
            LIMIT $2
            "#,
        )
        .bind(cutoff)
        .bind(limit)
        .fetch_all(self.pool())
        .await
    }
}
