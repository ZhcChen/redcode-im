use crate::database::models::PushDevice;
use sqlx::PgPool;
use uuid::Uuid;

pub struct PushDeviceStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> PushDeviceStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn upsert_device(
        &self,
        user_id: Uuid,
        platform: &str,
        channel: &str,
        device_id: &str,
        device_token: &str,
    ) -> Result<PushDevice, sqlx::Error> {
        let insert_result = sqlx::query_as::<_, PushDevice>(
            r#"
            INSERT INTO push_devices (
                id,
                user_id,
                platform,
                channel,
                device_id,
                device_token,
                is_active,
                last_seen_at,
                created_at,
                updated_at
            )
            VALUES (
                $1,
                $2,
                $3,
                $4,
                $5,
                $6,
                TRUE,
                NOW(),
                NOW(),
                NOW()
            )
            ON CONFLICT (device_id) DO UPDATE
            SET user_id = EXCLUDED.user_id,
                platform = EXCLUDED.platform,
                channel = EXCLUDED.channel,
                device_token = EXCLUDED.device_token,
                is_active = TRUE,
                last_seen_at = NOW(),
                updated_at = NOW()
            RETURNING id, user_id, platform, channel, device_id, device_token, is_active, last_seen_at, created_at, updated_at
            "#,
        )
        .bind(crate::id::generate())
        .bind(user_id)
        .bind(platform)
        .bind(channel)
        .bind(device_id)
        .bind(device_token)
        .fetch_one(self.pool)
        .await;

        match insert_result {
            Ok(device) => Ok(device),
            Err(e) => {
                // 处理 token 唯一约束冲突：当 token 被复用/刷新时，优先按 token 绑定到当前用户与 device_id
                let updated = sqlx::query_as::<_, PushDevice>(
                    r#"
                    UPDATE push_devices
                    SET user_id = $1,
                        platform = $2,
                        channel = $3,
                        device_id = $4,
                        is_active = TRUE,
                        last_seen_at = NOW(),
                        updated_at = NOW()
                    WHERE device_token = $5
                    RETURNING id, user_id, platform, channel, device_id, device_token, is_active, last_seen_at, created_at, updated_at
                    "#,
                )
                .bind(user_id)
                .bind(platform)
                .bind(channel)
                .bind(device_id)
                .bind(device_token)
                .fetch_optional(self.pool)
                .await?;

                if let Some(device) = updated {
                    return Ok(device);
                }

                Err(e)
            }
        }
    }

    pub async fn deactivate_device(
        &self,
        user_id: Uuid,
        device_id: &str,
    ) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            r#"
            UPDATE push_devices
            SET is_active = FALSE,
                updated_at = NOW()
            WHERE user_id = $1 AND device_id = $2 AND is_active IS TRUE
            "#,
        )
        .bind(user_id)
        .bind(device_id)
        .execute(self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn list_active_devices_for_users(
        &self,
        user_ids: &[Uuid],
    ) -> Result<Vec<PushDevice>, sqlx::Error> {
        if user_ids.is_empty() {
            return Ok(Vec::new());
        }

        let devices = sqlx::query_as::<_, PushDevice>(
            r#"
            SELECT id, user_id, platform, channel, device_id, device_token, is_active, last_seen_at, created_at, updated_at
            FROM push_devices
            WHERE user_id = ANY($1) AND is_active IS TRUE
            ORDER BY last_seen_at DESC
            "#,
        )
        .bind(user_ids)
        .fetch_all(self.pool)
        .await?;

        Ok(devices)
    }
}
