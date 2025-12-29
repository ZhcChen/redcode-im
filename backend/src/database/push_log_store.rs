use chrono::{DateTime, Utc};
use serde_json::Value;
use sqlx::{FromRow, PgPool, Postgres, QueryBuilder};
use uuid::Uuid;

#[derive(Debug, Clone, Default)]
pub struct PushLogQueryParams {
    pub push_id: Option<Uuid>,
    pub user_id: Option<Uuid>,
    pub device_id: Option<String>,
    pub platform: Option<String>,
    pub channel: Option<String>,
    pub provider: Option<String>,
    pub event_type: Option<String>,
    pub success: Option<bool>,
    pub room_id: Option<Uuid>,
    pub message_id: Option<Uuid>,
    pub request_id: Option<Uuid>,
    pub keyword: Option<String>,
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Clone, FromRow)]
pub struct PushLogEntry {
    pub id: Uuid,
    pub push_id: Uuid,
    pub user_id: Uuid,
    pub username: Option<String>,
    pub nickname: Option<String>,
    pub device_id: String,
    pub platform: String,
    pub channel: String,
    pub provider: String,
    pub event_type: String,
    pub room_id: Option<Uuid>,
    pub message_id: Option<Uuid>,
    pub request_id: Option<Uuid>,
    pub title: Option<String>,
    pub body: Option<String>,
    pub data: Value,
    pub attempt: i32,
    pub success: bool,
    pub error: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct PushLogQueryResult {
    pub logs: Vec<PushLogEntry>,
    pub total: i64,
    pub limit: i64,
    pub offset: i64,
}

pub struct PushLogStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> PushLogStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn query(
        &self,
        params: &PushLogQueryParams,
    ) -> Result<PushLogQueryResult, sqlx::Error> {
        let limit = params.limit.unwrap_or(50).max(1).min(500);
        let offset = params.offset.unwrap_or(0).max(0);

        let total = self.count_logs(params).await?;
        let logs = self.list_logs(params, limit, offset).await?;

        Ok(PushLogQueryResult {
            logs,
            total,
            limit,
            offset,
        })
    }

    pub async fn cleanup(&self, retention_days: i64) -> Result<u64, sqlx::Error> {
        let result = sqlx::query(
            r#"
            DELETE FROM push_logs
            WHERE created_at < NOW() - make_interval(days => $1)
            "#,
        )
        .bind(retention_days as i32)
        .execute(self.pool)
        .await?;

        Ok(result.rows_affected())
    }

    pub async fn insert_log(
        &self,
        push_id: Uuid,
        user_id: Uuid,
        device_id: &str,
        platform: &str,
        channel: &str,
        provider: &str,
        event_type: &str,
        room_id: Option<Uuid>,
        message_id: Option<Uuid>,
        request_id: Option<Uuid>,
        title: Option<&str>,
        body: Option<&str>,
        data: &Value,
        attempt: i32,
        success: bool,
        error: Option<&str>,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            INSERT INTO push_logs (
                id,
                push_id,
                user_id,
                device_id,
                platform,
                channel,
                provider,
                event_type,
                room_id,
                message_id,
                request_id,
                title,
                body,
                data,
                attempt,
                success,
                error,
                created_at
            ) VALUES (
                $1,
                $2,
                $3,
                $4,
                $5,
                $6,
                $7,
                $8,
                $9,
                $10,
                $11,
                $12,
                $13,
                $14,
                $15,
                $16,
                $17,
                NOW()
            )
            "#,
        )
        .bind(crate::id::generate())
        .bind(push_id)
        .bind(user_id)
        .bind(device_id)
        .bind(platform)
        .bind(channel)
        .bind(provider)
        .bind(event_type)
        .bind(room_id)
        .bind(message_id)
        .bind(request_id)
        .bind(title)
        .bind(body)
        .bind(data)
        .bind(attempt)
        .bind(success)
        .bind(error)
        .execute(self.pool)
        .await?;

        Ok(())
    }

    async fn list_logs(
        &self,
        params: &PushLogQueryParams,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<PushLogEntry>, sqlx::Error> {
        let mut builder: QueryBuilder<Postgres> = QueryBuilder::new(
            r#"
            SELECT
                pl.id,
                pl.push_id,
                pl.user_id,
                u.username,
                u.nickname,
                pl.device_id,
                pl.platform,
                pl.channel,
                pl.provider,
                pl.event_type,
                pl.room_id,
                pl.message_id,
                pl.request_id,
                pl.title,
                pl.body,
                pl.data,
                pl.attempt,
                pl.success,
                pl.error,
                pl.created_at
            FROM push_logs pl
            LEFT JOIN users u ON u.id = pl.user_id
            WHERE 1=1
            "#,
        );

        apply_push_log_filters(&mut builder, params);

        builder.push(" ORDER BY pl.created_at DESC, pl.attempt DESC");
        builder.push(" LIMIT ");
        builder.push_bind(limit.max(1).min(500));
        builder.push(" OFFSET ");
        builder.push_bind(offset.max(0));

        builder
            .build_query_as::<PushLogEntry>()
            .fetch_all(self.pool)
            .await
    }

    async fn count_logs(&self, params: &PushLogQueryParams) -> Result<i64, sqlx::Error> {
        let mut builder: QueryBuilder<Postgres> = QueryBuilder::new(
            r#"
            SELECT COUNT(*)::bigint
            FROM push_logs pl
            LEFT JOIN users u ON u.id = pl.user_id
            WHERE 1=1
            "#,
        );

        apply_push_log_filters(&mut builder, params);

        builder
            .build_query_scalar::<i64>()
            .fetch_one(self.pool)
            .await
    }
}

fn apply_push_log_filters(builder: &mut QueryBuilder<Postgres>, params: &PushLogQueryParams) {
    if let Some(push_id) = params.push_id {
        builder.push(" AND pl.push_id = ");
        builder.push_bind(push_id);
    }

    if let Some(user_id) = params.user_id {
        builder.push(" AND pl.user_id = ");
        builder.push_bind(user_id);
    }

    if let Some(room_id) = params.room_id {
        builder.push(" AND pl.room_id = ");
        builder.push_bind(room_id);
    }

    if let Some(message_id) = params.message_id {
        builder.push(" AND pl.message_id = ");
        builder.push_bind(message_id);
    }

    if let Some(request_id) = params.request_id {
        builder.push(" AND pl.request_id = ");
        builder.push_bind(request_id);
    }

    if let Some(ref platform) = params.platform {
        let platform = platform.trim();
        if !platform.is_empty() {
            builder.push(" AND pl.platform = ");
            builder.push_bind(platform.to_string());
        }
    }

    if let Some(ref channel) = params.channel {
        let channel = channel.trim();
        if !channel.is_empty() {
            builder.push(" AND pl.channel = ");
            builder.push_bind(channel.to_string());
        }
    }

    if let Some(ref provider) = params.provider {
        let provider = provider.trim();
        if !provider.is_empty() {
            builder.push(" AND pl.provider = ");
            builder.push_bind(provider.to_string());
        }
    }

    if let Some(ref event_type) = params.event_type {
        let event_type = event_type.trim();
        if !event_type.is_empty() {
            builder.push(" AND pl.event_type = ");
            builder.push_bind(event_type.to_string());
        }
    }

    if let Some(success) = params.success {
        builder.push(" AND pl.success = ");
        builder.push_bind(success);
    }

    if let Some(start_time) = params.start_time {
        builder.push(" AND pl.created_at >= ");
        builder.push_bind(start_time);
    }

    if let Some(end_time) = params.end_time {
        builder.push(" AND pl.created_at <= ");
        builder.push_bind(end_time);
    }

    if let Some(ref device_id) = params.device_id {
        let device_id = device_id.trim();
        if !device_id.is_empty() {
            builder.push(" AND pl.device_id ILIKE ");
            builder.push_bind(format!("%{}%", device_id));
        }
    }

    if let Some(ref keyword) = params.keyword {
        let keyword = keyword.trim();
        if !keyword.is_empty() {
            let pattern = format!("%{}%", keyword);
            builder.push(" AND (");
            builder.push(" pl.device_id ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR pl.event_type ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR pl.provider ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR pl.channel ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR pl.platform ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR pl.title ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR pl.body ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR pl.error ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR u.username ILIKE ");
            builder.push_bind(pattern.clone());
            builder.push(" OR u.nickname ILIKE ");
            builder.push_bind(pattern);
            builder.push(")");
        }
    }
}
