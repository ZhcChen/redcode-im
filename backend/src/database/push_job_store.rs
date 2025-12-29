use chrono::{DateTime, Utc};
use serde_json::Value;
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

const STATUS_PENDING: i16 = 0;
const STATUS_DONE: i16 = 1;
const STATUS_FAILED: i16 = 2;
const STATUS_RETRY: i16 = 3;

#[derive(Debug, Clone, FromRow)]
pub struct PushJobRecord {
    pub id: Uuid,
    pub job_type: String,
    pub payload: Value,
    pub status: i16,
    pub attempts: i32,
    pub next_run_at: DateTime<Utc>,
    pub last_error: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

pub struct PushJobStore<'a> {
    pool: &'a PgPool,
}

impl<'a> PushJobStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn enqueue(
        &self,
        job_type: &str,
        payload: &Value,
        next_run_at: DateTime<Utc>,
    ) -> Result<Uuid, sqlx::Error> {
        sqlx::query_scalar::<_, Uuid>(
            r#"
            INSERT INTO push_job_queue (job_type, payload, next_run_at)
            VALUES ($1, $2, $3)
            RETURNING id
            "#,
        )
        .bind(job_type)
        .bind(payload)
        .bind(next_run_at)
        .fetch_one(self.pool)
        .await
    }

    /// 认领（加锁）一批 due job，并将 next_run_at 延长为“租约”，避免多节点重复处理
    pub async fn claim_due_jobs(
        &self,
        limit: i64,
        lease_seconds: i64,
    ) -> Result<Vec<PushJobRecord>, sqlx::Error> {
        sqlx::query_as::<_, PushJobRecord>(
            r#"
            WITH picked AS (
                SELECT id
                FROM push_job_queue
                WHERE status IN (0, 3)
                  AND next_run_at <= NOW()
                ORDER BY next_run_at ASC, created_at ASC
                LIMIT $1
                FOR UPDATE SKIP LOCKED
            )
            UPDATE push_job_queue t
            SET next_run_at = NOW() + ($2 || ' seconds')::interval,
                updated_at = NOW()
            FROM picked
            WHERE t.id = picked.id
            RETURNING t.id, t.job_type, t.payload, t.status, t.attempts, t.next_run_at, t.last_error,
                      t.created_at, t.updated_at
            "#,
        )
        .bind(limit)
        .bind(lease_seconds)
        .fetch_all(self.pool)
        .await
    }

    pub async fn mark_done(&self, job_id: &Uuid) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            r#"
            UPDATE push_job_queue
            SET status = $2,
                last_error = NULL,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(job_id)
        .bind(STATUS_DONE)
        .execute(self.pool)
        .await?;
        Ok(result.rows_affected() > 0)
    }

    pub async fn mark_retry(
        &self,
        job_id: &Uuid,
        error: &str,
        next_run_at: DateTime<Utc>,
    ) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            r#"
            UPDATE push_job_queue
            SET status = $2,
                attempts = attempts + 1,
                last_error = $3,
                next_run_at = $4,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(job_id)
        .bind(STATUS_RETRY)
        .bind(error)
        .bind(next_run_at)
        .execute(self.pool)
        .await?;
        Ok(result.rows_affected() > 0)
    }

    pub async fn mark_failed(&self, job_id: &Uuid, error: &str) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            r#"
            UPDATE push_job_queue
            SET status = $2,
                attempts = attempts + 1,
                last_error = $3,
                updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(job_id)
        .bind(STATUS_FAILED)
        .bind(error)
        .execute(self.pool)
        .await?;
        Ok(result.rows_affected() > 0)
    }

    pub fn is_done_status(status: i16) -> bool {
        status == STATUS_DONE
    }

    pub fn is_retryable_status(status: i16) -> bool {
        status == STATUS_PENDING || status == STATUS_RETRY
    }
}

