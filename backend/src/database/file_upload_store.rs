use crate::database::models::FileUploadRecord;
use crate::database::Database;
use sqlx::{query_as, Error};
use uuid::Uuid;

/// 文件上传记录存储
///
/// 目前主要用于管理通过对象存储（腾讯云 COS）直传的文件：
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
                SELECT id, storage_provider_id, object_key, hash_alg, hash_value,
                       file_size, content_type, status, uploaded_at,
                       updated_at, created_at, last_error
                FROM file_upload_records
                WHERE storage_provider_id = $1
                  AND hash_alg = $2
                  AND hash_value = $3
                  AND file_size = $4
                  AND status = 1
                  AND object_key LIKE $5 || '%'
                ORDER BY uploaded_at DESC NULLS LAST, created_at DESC
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
                SELECT id, storage_provider_id, object_key, hash_alg, hash_value,
                       file_size, content_type, status, uploaded_at,
                       updated_at, created_at, last_error
                FROM file_upload_records
                WHERE storage_provider_id = $1
                  AND hash_alg = $2
                  AND hash_value = $3
                  AND file_size = $4
                  AND status = 1
                ORDER BY uploaded_at DESC NULLS LAST, created_at DESC
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
        let pool = &self.database.pool;

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
        .execute(pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }
}
