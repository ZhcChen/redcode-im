use crate::database::models::FileUploadMultipartSession;
use crate::database::Database;
use sqlx::{query_as, Error};
use uuid::Uuid;

/// 分片上传会话存储（对象存储 Multipart Upload）
#[derive(Clone)]
pub struct FileUploadMultipartStore {
    database: Database,
}

impl FileUploadMultipartStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    pub fn pool(&self) -> &sqlx::PgPool {
        &self.database.pool
    }

    #[allow(clippy::too_many_arguments)]
    pub async fn create_session(
        &self,
        storage_provider_id: &Uuid,
        object_key: &str,
        upload_id: &str,
        creator_id: &Uuid,
        creator_is_admin: bool,
        file_size: Option<i64>,
        content_type: Option<&str>,
        part_size: i32,
        total_parts: i32,
    ) -> Result<FileUploadMultipartSession, Error> {
        query_as::<_, FileUploadMultipartSession>(
            r#"
            INSERT INTO file_upload_multipart_sessions (
                storage_provider_id,
                object_key,
                upload_id,
                creator_id,
                creator_is_admin,
                file_size,
                content_type,
                part_size,
                total_parts,
                uploaded_parts,
                status,
                created_at,
                updated_at,
                completed_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, '{}'::jsonb, 0, NOW(), NOW(), NULL)
            RETURNING id, storage_provider_id, object_key, upload_id, creator_id, creator_is_admin,
                      file_size, content_type, part_size, total_parts, uploaded_parts, status,
                      created_at, updated_at, completed_at
            "#,
        )
        .bind(storage_provider_id)
        .bind(object_key)
        .bind(upload_id)
        .bind(creator_id)
        .bind(creator_is_admin)
        .bind(file_size)
        .bind(content_type)
        .bind(part_size)
        .bind(total_parts)
        .fetch_one(self.pool())
        .await
    }

    pub async fn get_session(
        &self,
        session_id: &Uuid,
    ) -> Result<Option<FileUploadMultipartSession>, Error> {
        query_as::<_, FileUploadMultipartSession>(
            r#"
            SELECT id, storage_provider_id, object_key, upload_id, creator_id, creator_is_admin,
                   file_size, content_type, part_size, total_parts, uploaded_parts, status,
                   created_at, updated_at, completed_at
            FROM file_upload_multipart_sessions
            WHERE id = $1
            LIMIT 1
            "#,
        )
        .bind(session_id)
        .fetch_optional(self.pool())
        .await
    }

    pub async fn upsert_part_etag(
        &self,
        session_id: &Uuid,
        part_number: i32,
        etag: &str,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_multipart_sessions
            SET uploaded_parts = COALESCE(uploaded_parts, '{}'::jsonb)
                || jsonb_build_object($2::text, $3),
                updated_at = NOW()
            WHERE id = $1
              AND status = 0
            "#,
        )
        .bind(session_id)
        .bind(part_number)
        .bind(etag)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn mark_completed(
        &self,
        session_id: &Uuid,
        uploaded_parts: Option<&serde_json::Value>,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_multipart_sessions
            SET status = 1,
                uploaded_parts = COALESCE($2, uploaded_parts),
                completed_at = COALESCE(completed_at, NOW()),
                updated_at = NOW()
            WHERE id = $1
              AND status = 0
            "#,
        )
        .bind(session_id)
        .bind(uploaded_parts)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn mark_aborted(&self, session_id: &Uuid) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_multipart_sessions
            SET status = 2,
                updated_at = NOW()
            WHERE id = $1
              AND status = 0
            "#,
        )
        .bind(session_id)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }
}
