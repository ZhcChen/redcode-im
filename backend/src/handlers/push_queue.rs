use axum::{extract::State, response::Json};
use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::FromRow;

use crate::error::AppError;
use crate::AppState;

#[derive(Debug, Serialize)]
pub struct PushJobQueueStatsResponse {
    pub pending: i64,
    pub retry: i64,
    pub done: i64,
    pub failed: i64,
    pub due: i64,
    pub next_run_at: Option<String>,
    pub oldest_created_at: Option<String>,
}

#[derive(Debug, FromRow)]
struct PushJobQueueStatsRow {
    pending: Option<i64>,
    retry: Option<i64>,
    done: Option<i64>,
    failed: Option<i64>,
    due: Option<i64>,
    next_run_at: Option<DateTime<Utc>>,
    oldest_created_at: Option<DateTime<Utc>>,
}

pub async fn get_push_job_queue_stats(
    State(state): State<AppState>,
) -> Result<Json<PushJobQueueStatsResponse>, AppError> {
    // status：0=pending, 1=done, 2=failed, 3=retry
    let row: PushJobQueueStatsRow = sqlx::query_as(
        r#"
        SELECT
            SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) AS pending,
            SUM(CASE WHEN status = 3 THEN 1 ELSE 0 END) AS retry,
            SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS done,
            SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) AS failed,
            SUM(CASE WHEN status IN (0, 3) AND next_run_at <= NOW() THEN 1 ELSE 0 END) AS due,
            MIN(CASE WHEN status IN (0, 3) THEN next_run_at ELSE NULL END) AS next_run_at,
            MIN(created_at) AS oldest_created_at
        FROM push_job_queue
        "#,
    )
    .fetch_one(state.database.pool())
    .await
    .map_err(AppError::DatabaseError)?;

    Ok(Json(PushJobQueueStatsResponse {
        pending: row.pending.unwrap_or(0),
        retry: row.retry.unwrap_or(0),
        done: row.done.unwrap_or(0),
        failed: row.failed.unwrap_or(0),
        due: row.due.unwrap_or(0),
        next_run_at: row.next_run_at.map(|v| v.to_rfc3339()),
        oldest_created_at: row.oldest_created_at.map(|v| v.to_rfc3339()),
    }))
}
