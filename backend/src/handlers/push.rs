use axum::{
    extract::{Extension, Path, State},
    response::Json,
};
use serde::{Deserialize, Serialize};

use crate::database::push_device_store::PushDeviceStore;
use crate::error::AppError;
use crate::models::{convert::string_to_uuid, Claims};
use crate::AppState;

#[derive(Debug, Deserialize)]
pub struct RegisterPushDeviceRequest {
    pub device_id: String,
    pub platform: String,
    pub channel: String,
    pub device_token: String,
}

#[derive(Debug, Serialize)]
pub struct RegisterPushDeviceResponse {
    pub success: bool,
    pub message: String,
    pub device_id: String,
}

pub async fn register_device(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<RegisterPushDeviceRequest>,
) -> Result<Json<RegisterPushDeviceResponse>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let device_id = req.device_id.trim();
    if device_id.is_empty() || device_id.len() > 128 {
        return Err(AppError::ValidationError("device_id 无效".to_string()));
    }

    let device_token = req.device_token.trim();
    if device_token.is_empty() || device_token.len() > 4096 {
        return Err(AppError::ValidationError("device_token 无效".to_string()));
    }

    let platform = req.platform.trim().to_lowercase();
    if platform.is_empty() || platform.len() > 32 {
        return Err(AppError::ValidationError("platform 无效".to_string()));
    }

    let channel = req.channel.trim().to_lowercase();
    if channel.is_empty() || channel.len() > 32 {
        return Err(AppError::ValidationError("channel 无效".to_string()));
    }

    let store = PushDeviceStore::new(state.database.pool());
    let _ = store
        .upsert_device(user_id, &platform, &channel, device_id, device_token)
        .await?;

    Ok(Json(RegisterPushDeviceResponse {
        success: true,
        message: "设备已注册".to_string(),
        device_id: device_id.to_string(),
    }))
}

#[derive(Debug, Serialize)]
pub struct UnregisterPushDeviceResponse {
    pub success: bool,
    pub message: String,
}

pub async fn unregister_device(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(device_id): Path<String>,
) -> Result<Json<UnregisterPushDeviceResponse>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let trimmed = device_id.trim();
    if trimmed.is_empty() || trimmed.len() > 128 {
        return Err(AppError::ValidationError("device_id 无效".to_string()));
    }

    let store = PushDeviceStore::new(state.database.pool());
    let deleted = store.deactivate_device(user_id, trimmed).await?;

    Ok(Json(UnregisterPushDeviceResponse {
        success: true,
        message: if deleted {
            "设备已注销".to_string()
        } else {
            "设备不存在或已注销".to_string()
        },
    }))
}
