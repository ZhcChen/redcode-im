use chrono::{DateTime, Utc};
use sqlx::{query_as, PgPool};
use uuid::Uuid;

use crate::database::Database;
use crate::error::AppError;

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct QrLoginSessionRecord {
    pub id: Uuid,
    pub qr_token: Uuid,
    pub user_id: Option<Uuid>,
    pub status: String,
    pub login_code: Option<String>,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub confirmed_at: Option<DateTime<Utc>>,
    pub cancelled_at: Option<DateTime<Utc>>,
}

#[derive(Clone)]
pub struct QrLoginStore {
    database: Database,
}

impl QrLoginStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    fn pool(&self) -> &PgPool {
        &self.database.pool
    }

    /// 创建扫码会话，返回 (qr_token, expires_at)。
    pub async fn create(&self, ttl_minutes: i64) -> Result<(Uuid, DateTime<Utc>), AppError> {
        let qr_token = Uuid::new_v4();
        let expires_at = Utc::now() + chrono::Duration::minutes(ttl_minutes);

        sqlx::query(
            "INSERT INTO qr_login_sessions (qr_token, status, expires_at)
             VALUES ($1, 'pending', $2)",
        )
        .bind(qr_token)
        .bind(expires_at)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok((qr_token, expires_at))
    }

    pub async fn get(&self, qr_token: Uuid) -> Result<Option<QrLoginSessionRecord>, AppError> {
        let record = query_as::<_, QrLoginSessionRecord>(
            r#"
            SELECT id, qr_token, user_id, status, login_code, expires_at,
                   created_at, confirmed_at, cancelled_at
            FROM qr_login_sessions
            WHERE qr_token = $1
            "#,
        )
        .bind(qr_token)
        .fetch_optional(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(record)
    }

    /// 手机端确认：写入 user_id 与一次性登录码（即 refresh token）。
    pub async fn confirm(
        &self,
        qr_token: Uuid,
        user_id: Uuid,
        login_code: &str,
    ) -> Result<bool, AppError> {
        let result = sqlx::query(
            "UPDATE qr_login_sessions
             SET status = 'confirmed', user_id = $2, login_code = $3,
                 confirmed_at = NOW()
             WHERE qr_token = $1 AND status = 'pending' AND expires_at > NOW()",
        )
        .bind(qr_token)
        .bind(user_id)
        .bind(login_code)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }

    /// PC 端一次性取走登录码；返回后 login_code 置空。
    pub async fn consume_login_code(&self, qr_token: Uuid) -> Result<Option<String>, AppError> {
        let row: Option<(Option<String>,)> = sqlx::query_as(
            "SELECT login_code FROM qr_login_sessions
             WHERE qr_token = $1 AND status = 'confirmed' AND login_code IS NOT NULL",
        )
        .bind(qr_token)
        .fetch_optional(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        let code = row.and_then(|r| r.0);
        if code.is_some() {
            sqlx::query(
                "UPDATE qr_login_sessions SET login_code = NULL WHERE qr_token = $1",
            )
            .bind(qr_token)
            .execute(self.pool())
            .await
            .map_err(|e| AppError::DatabaseError(e))?;
        }

        Ok(code)
    }

    pub async fn cancel(&self, qr_token: Uuid) -> Result<bool, AppError> {
        let result = sqlx::query(
            "UPDATE qr_login_sessions
             SET status = 'cancelled', cancelled_at = NOW()
             WHERE qr_token = $1 AND status = 'pending'",
        )
        .bind(qr_token)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }

    /// 惰性标记过期（轮询时调用）。
    pub async fn mark_expired_if_needed(&self, qr_token: Uuid) -> Result<(), AppError> {
        sqlx::query(
            "UPDATE qr_login_sessions SET status = 'expired'
             WHERE qr_token = $1 AND status = 'pending' AND expires_at <= NOW()",
        )
        .bind(qr_token)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;
        Ok(())
    }
}
