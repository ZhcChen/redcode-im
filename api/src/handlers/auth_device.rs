use axum::{
    extract::{Path, State},
    Extension, Json,
};
use serde::Serialize;
use uuid::Uuid;

use crate::database::user_device_store::{UserDeviceRecord, UserDeviceStore};
use crate::error::AppError;
use crate::models::{Claims, convert::string_to_uuid};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UserDeviceInfo {
    pub device_id: String,
    pub device_name: String,
    pub platform: String,
    pub last_seen_at: String,
    pub created_at: String,
    pub revoked_at: Option<String>,
    pub is_current: bool,
}

fn to_info(record: &UserDeviceRecord, current_device_id: Option<&str>) -> UserDeviceInfo {
    UserDeviceInfo {
        device_id: record.id.to_string(),
        device_name: record.device_name.clone(),
        platform: record.platform.clone(),
        last_seen_at: record.last_seen_at.to_rfc3339(),
        created_at: record.created_at.to_rfc3339(),
        revoked_at: record.revoked_at.map(|v| v.to_rfc3339()),
        is_current: current_device_id == Some(record.id.to_string().as_str()),
    }
}

/// GET /auth/devices
pub async fn list_devices(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<UserDeviceInfo>>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = UserDeviceStore::new(state.database.clone());
    let records = store.list_devices(user_id).await?;
    let items = records
        .iter()
        .map(|r| to_info(r, claims.device_id.as_deref()))
        .collect();

    Ok(Json(items))
}

/// POST /auth/devices/{device_id}/revoke
pub async fn revoke_device(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Path(device_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = UserDeviceStore::new(state.database.clone());
    let revoked = store.revoke_device(user_id, device_id).await?;
    if !revoked {
        return Err(AppError::NotFound("设备不存在或已撤销".to_string()));
    }

    // 撤销该设备所有刷新令牌：删除 auth:refresh:by-device:{device_id} 集合及其成员
    let mut conn = state.redis.get_cache_connection();
    {
        let set_key = format!("auth:refresh:by-device:{device_id}");
        let tokens: Vec<String> = redis::cmd("SMEMBERS")
            .arg(&set_key)
            .query_async(&mut conn)
            .await
            .unwrap_or_default();
        for token in &tokens {
            let _: redis::RedisResult<()> = redis::cmd("DEL")
                .arg(format!("auth:refresh:{token}"))
                .query_async(&mut conn)
                .await;
        }
        let _: redis::RedisResult<()> =
            redis::cmd("DEL").arg(&set_key).query_async(&mut conn).await;
    }

    Ok(Json(serde_json::json!({ "success": true })))
}
