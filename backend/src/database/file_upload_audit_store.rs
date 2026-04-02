use crate::database::models::FileUploadAuditTask;
use crate::database::Database;
use chrono::{DateTime, Utc};
use sqlx::{query_as, Error, Postgres, QueryBuilder};
use uuid::Uuid;

/// 文件内容审核任务存储（队列 + 记录）
#[derive(Clone)]
pub struct FileUploadAuditStore {
    database: Database,
}

impl FileUploadAuditStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    pub fn pool(&self) -> &sqlx::PgPool {
        &self.database.pool
    }

    pub async fn get_task_by_id(
        &self,
        task_id: &Uuid,
    ) -> Result<Option<FileUploadAuditTask>, Error> {
        query_as::<_, FileUploadAuditTask>(
            r#"
            SELECT id, storage_provider_id, object_key, scene, media_kind,
                   content_type, file_size, status, vendor_job_id, result,
                   rejected_reason, attempts, next_run_at, last_error,
                   audited_at, created_at, updated_at
            FROM file_upload_audit_tasks
            WHERE id = $1
            "#,
        )
        .bind(task_id)
        .fetch_optional(self.pool())
        .await
    }

    pub async fn list_tasks(
        &self,
        storage_provider_id: Option<Uuid>,
        status: Option<i16>,
        scene: Option<&str>,
        media_kind: Option<&str>,
        keyword: Option<&str>,
        start_time: Option<DateTime<Utc>>,
        end_time: Option<DateTime<Utc>>,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<FileUploadAuditTask>, Error> {
        let mut builder: QueryBuilder<Postgres> = QueryBuilder::new(
            r#"
            SELECT id, storage_provider_id, object_key, scene, media_kind,
                   content_type, file_size, status, vendor_job_id, result,
                   rejected_reason, attempts, next_run_at, last_error,
                   audited_at, created_at, updated_at
            FROM file_upload_audit_tasks
            WHERE 1=1
            "#,
        );

        if let Some(provider_id) = storage_provider_id {
            builder.push(" AND storage_provider_id = ");
            builder.push_bind(provider_id);
        }

        if let Some(status) = status {
            builder.push(" AND status = ");
            builder.push_bind(status);
        }

        if let Some(scene) = scene {
            let scene = scene.trim();
            if !scene.is_empty() {
                builder.push(" AND scene = ");
                builder.push_bind(scene);
            }
        }

        if let Some(media_kind) = media_kind {
            let media_kind = media_kind.trim();
            if !media_kind.is_empty() {
                builder.push(" AND media_kind = ");
                builder.push_bind(media_kind);
            }
        }

        if let Some(keyword) = keyword {
            let keyword = keyword.trim();
            if !keyword.is_empty() {
                builder.push(" AND object_key ILIKE ");
                builder.push_bind(format!("%{}%", keyword));
            }
        }

        if let Some(start_time) = start_time {
            builder.push(" AND created_at >= ");
            builder.push_bind(start_time);
        }

        if let Some(end_time) = end_time {
            builder.push(" AND created_at <= ");
            builder.push_bind(end_time);
        }

        builder.push(" ORDER BY created_at DESC");
        builder.push(" LIMIT ");
        builder.push_bind(limit.max(1).min(500));
        builder.push(" OFFSET ");
        builder.push_bind(offset.max(0));

        builder
            .build_query_as::<FileUploadAuditTask>()
            .fetch_all(self.pool())
            .await
    }

    pub async fn count_tasks(
        &self,
        storage_provider_id: Option<Uuid>,
        status: Option<i16>,
        scene: Option<&str>,
        media_kind: Option<&str>,
        keyword: Option<&str>,
        start_time: Option<DateTime<Utc>>,
        end_time: Option<DateTime<Utc>>,
    ) -> Result<i64, Error> {
        let mut builder: QueryBuilder<Postgres> =
            QueryBuilder::new("SELECT COUNT(*)::bigint FROM file_upload_audit_tasks WHERE 1=1");

        if let Some(provider_id) = storage_provider_id {
            builder.push(" AND storage_provider_id = ");
            builder.push_bind(provider_id);
        }

        if let Some(status) = status {
            builder.push(" AND status = ");
            builder.push_bind(status);
        }

        if let Some(scene) = scene {
            let scene = scene.trim();
            if !scene.is_empty() {
                builder.push(" AND scene = ");
                builder.push_bind(scene);
            }
        }

        if let Some(media_kind) = media_kind {
            let media_kind = media_kind.trim();
            if !media_kind.is_empty() {
                builder.push(" AND media_kind = ");
                builder.push_bind(media_kind);
            }
        }

        if let Some(keyword) = keyword {
            let keyword = keyword.trim();
            if !keyword.is_empty() {
                builder.push(" AND object_key ILIKE ");
                builder.push_bind(format!("%{}%", keyword));
            }
        }

        if let Some(start_time) = start_time {
            builder.push(" AND created_at >= ");
            builder.push_bind(start_time);
        }

        if let Some(end_time) = end_time {
            builder.push(" AND created_at <= ");
            builder.push_bind(end_time);
        }

        let count: i64 = builder
            .build_query_scalar::<i64>()
            .fetch_one(self.pool())
            .await?;
        Ok(count)
    }

    /// 手动重新入队：清空 vendor_job_id/错误信息，并把 next_run_at 设为 NOW()
    pub async fn requeue_task(&self, task_id: &Uuid) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_audit_tasks
            SET status = 0,
                vendor_job_id = NULL,
                last_error = NULL,
                rejected_reason = NULL,
                audited_at = NULL,
                attempts = 0,
                next_run_at = NOW(),
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(task_id)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 创建或更新审核任务（同一 provider + object_key 仅一条记录）
    pub async fn upsert_task(
        &self,
        storage_provider_id: &Uuid,
        object_key: &str,
        scene: &str,
        media_kind: &str,
        content_type: Option<&str>,
        file_size: Option<i64>,
    ) -> Result<FileUploadAuditTask, Error> {
        query_as::<_, FileUploadAuditTask>(
            r#"
            INSERT INTO file_upload_audit_tasks (
                storage_provider_id,
                object_key,
                scene,
                media_kind,
                content_type,
                file_size,
                status,
                next_run_at,
                updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, 0, NOW(), NOW())
            ON CONFLICT (storage_provider_id, object_key) DO UPDATE
            SET scene = EXCLUDED.scene,
                media_kind = CASE
                    WHEN file_upload_audit_tasks.media_kind = 'unknown' AND EXCLUDED.media_kind <> 'unknown'
                        THEN EXCLUDED.media_kind
                    ELSE file_upload_audit_tasks.media_kind
                END,
                content_type = COALESCE(file_upload_audit_tasks.content_type, EXCLUDED.content_type),
                file_size = COALESCE(file_upload_audit_tasks.file_size, EXCLUDED.file_size),
                updated_at = NOW()
            RETURNING id, storage_provider_id, object_key, scene, media_kind,
                      content_type, file_size, status, vendor_job_id, result,
                      rejected_reason, attempts, next_run_at, last_error,
                      audited_at, created_at, updated_at
            "#,
        )
        .bind(storage_provider_id)
        .bind(object_key)
        .bind(scene)
        .bind(media_kind)
        .bind(content_type)
        .bind(file_size)
        .fetch_one(self.pool())
        .await
    }

    /// 认领（加锁）并延长 next_run_at 作为“租约”，避免多节点重复处理
    pub async fn claim_due_tasks(
        &self,
        limit: i64,
        lease_seconds: i64,
    ) -> Result<Vec<FileUploadAuditTask>, Error> {
        query_as::<_, FileUploadAuditTask>(
            r#"
            WITH picked AS (
                SELECT id
                FROM file_upload_audit_tasks
                WHERE status IN (0, 3)
                  AND next_run_at <= NOW()
                ORDER BY next_run_at ASC, created_at ASC
                LIMIT $1
                FOR UPDATE SKIP LOCKED
            )
            UPDATE file_upload_audit_tasks t
            SET next_run_at = NOW() + ($2 || ' seconds')::interval,
                updated_at = NOW()
            FROM picked
            WHERE t.id = picked.id
            RETURNING t.id, t.storage_provider_id, t.object_key, t.scene, t.media_kind,
                      t.content_type, t.file_size, t.status, t.vendor_job_id, t.result,
                      t.rejected_reason, t.attempts, t.next_run_at, t.last_error,
                      t.audited_at, t.created_at, t.updated_at
            "#,
        )
        .bind(limit)
        .bind(lease_seconds)
        .fetch_all(self.pool())
        .await
    }

    /// 尝试认领单个任务（用于触发即时处理）
    pub async fn claim_task_by_id(
        &self,
        task_id: &Uuid,
        lease_seconds: i64,
    ) -> Result<Option<FileUploadAuditTask>, Error> {
        query_as::<_, FileUploadAuditTask>(
            r#"
            WITH picked AS (
                SELECT id
                FROM file_upload_audit_tasks
                WHERE id = $1
                FOR UPDATE SKIP LOCKED
            )
            UPDATE file_upload_audit_tasks t
            SET next_run_at = NOW() + ($2 || ' seconds')::interval,
                updated_at = NOW()
            FROM picked
            WHERE t.id = picked.id
            RETURNING t.id, t.storage_provider_id, t.object_key, t.scene, t.media_kind,
                      t.content_type, t.file_size, t.status, t.vendor_job_id, t.result,
                      t.rejected_reason, t.attempts, t.next_run_at, t.last_error,
                      t.audited_at, t.created_at, t.updated_at
            "#,
        )
        .bind(task_id)
        .bind(lease_seconds)
        .fetch_optional(self.pool())
        .await
    }

    pub async fn mark_submitted(
        &self,
        task_id: &Uuid,
        vendor_job_id: &str,
        next_run_at: chrono::DateTime<chrono::Utc>,
        result: serde_json::Value,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_audit_tasks
            SET status = 0,
                vendor_job_id = $2,
                result = COALESCE(result, '{}'::jsonb) || $3::jsonb,
                next_run_at = $4,
                last_error = NULL,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(task_id)
        .bind(vendor_job_id)
        .bind(result)
        .bind(next_run_at)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn mark_approved(
        &self,
        task_id: &Uuid,
        audited_at: chrono::DateTime<chrono::Utc>,
        result: serde_json::Value,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_audit_tasks
            SET status = 1,
                result = COALESCE(result, '{}'::jsonb) || $2::jsonb,
                rejected_reason = NULL,
                last_error = NULL,
                audited_at = $3,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(task_id)
        .bind(result)
        .bind(audited_at)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn mark_rejected(
        &self,
        task_id: &Uuid,
        rejected_reason: &str,
        audited_at: chrono::DateTime<chrono::Utc>,
        result: serde_json::Value,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_audit_tasks
            SET status = 2,
                result = COALESCE(result, '{}'::jsonb) || $2::jsonb,
                rejected_reason = $3,
                last_error = NULL,
                audited_at = $4,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(task_id)
        .bind(result)
        .bind(rejected_reason)
        .bind(audited_at)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn mark_retry(
        &self,
        task_id: &Uuid,
        last_error: &str,
        next_run_at: chrono::DateTime<chrono::Utc>,
        result: serde_json::Value,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_audit_tasks
            SET status = 3,
                attempts = attempts + 1,
                result = COALESCE(result, '{}'::jsonb) || $4::jsonb,
                last_error = $2,
                next_run_at = $3,
                updated_at = NOW()
            WHERE id = $1
              AND status <> 4
            "#,
        )
        .bind(task_id)
        .bind(last_error)
        .bind(next_run_at)
        .bind(result)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn mark_failed(
        &self,
        task_id: &Uuid,
        last_error: &str,
        result: serde_json::Value,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_audit_tasks
            SET status = 4,
                result = COALESCE(result, '{}'::jsonb) || $3::jsonb,
                last_error = $2,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(task_id)
        .bind(last_error)
        .bind(result)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn set_next_run_at(
        &self,
        task_id: &Uuid,
        next_run_at: chrono::DateTime<chrono::Utc>,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            r#"
            UPDATE file_upload_audit_tasks
            SET next_run_at = $2,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(task_id)
        .bind(next_run_at)
        .execute(self.pool())
        .await?;

        Ok(result.rows_affected() > 0)
    }
}
