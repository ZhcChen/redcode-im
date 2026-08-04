use chrono::{DateTime, Utc};
use sqlx::{query_as, FromRow, PgPool};
use uuid::Uuid;

use crate::database::Database;
use crate::error::AppError;

#[derive(Debug, Clone, FromRow)]
pub struct UserDeviceRecord {
    pub id: Uuid,
    pub user_id: Uuid,
    pub device_name: String,
    pub platform: String,
    pub last_seen_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub revoked_at: Option<DateTime<Utc>>,
}

#[derive(Clone)]
pub struct UserDeviceStore {
    database: Database,
}

impl UserDeviceStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    fn pool(&self) -> &PgPool {
        &self.database.pool
    }

    /// 登记设备（按 user_id + device_id 幂等更新最后活跃时间）。
    pub async fn upsert_device(
        &self,
        user_id: Uuid,
        device_id: &str,
        device_name: Option<&str>,
        platform: Option<&str>,
    ) -> Result<(), AppError> {
        let device_uuid = Uuid::parse_str(device_id)
            .map_err(|e| AppError::ValidationError(format!("无效的设备ID: {}", e)))?;

        let name = device_name
            .map(|v| v.trim().to_string())
            .filter(|v| !v.is_empty())
            .unwrap_or_else(|| "unknown".to_string());
        let platform_value = platform
            .map(|v| v.trim().to_string())
            .filter(|v| !v.is_empty())
            .unwrap_or_else(|| "unknown".to_string());

        sqlx::query(
            "INSERT INTO user_devices (id, user_id, device_name, platform, last_seen_at)
             VALUES ($1, $2, $3, $4, NOW())
             ON CONFLICT (id) DO UPDATE
                SET device_name = EXCLUDED.device_name,
                    platform = EXCLUDED.platform,
                    last_seen_at = NOW(),
                    revoked_at = NULL
             WHERE user_devices.user_id = $2",
        )
        .bind(device_uuid)
        .bind(user_id)
        .bind(name)
        .bind(platform_value)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(())
    }

    /// 列出当前用户全部设备（含已撤销，按最近活跃倒序）。
    pub async fn list_devices(&self, user_id: Uuid) -> Result<Vec<UserDeviceRecord>, AppError> {
        let rows = query_as::<_, UserDeviceRecord>(
            r#"
            SELECT id, user_id, device_name, platform, last_seen_at, created_at, revoked_at
            FROM user_devices
            WHERE user_id = $1
            ORDER BY last_seen_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(rows)
    }

    /// 撤销设备（幂等）。
    pub async fn revoke_device(&self, user_id: Uuid, device_id: Uuid) -> Result<bool, AppError> {
        let result = sqlx::query(
            "UPDATE user_devices SET revoked_at = NOW()
             WHERE user_id = $1 AND id = $2 AND revoked_at IS NULL",
        )
        .bind(user_id)
        .bind(device_id)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }
}
