use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

pub struct PushLogStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> PushLogStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
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
}

