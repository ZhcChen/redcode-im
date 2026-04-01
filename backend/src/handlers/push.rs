use axum::{
    extract::{Extension, Path, State},
    response::Json,
};
use serde::{Deserialize, Serialize};

use crate::database::push_device_store::PushDeviceStore;
use crate::error::AppError;
use crate::i18n::locale::normalize_locale_tag;
use crate::models::{convert::string_to_uuid, Claims};
use crate::AppState;

#[derive(Debug, Deserialize)]
pub struct RegisterPushDeviceRequest {
    pub device_id: String,
    pub platform: String,
    pub channel: String,
    pub device_token: String,
    pub locale: Option<String>,
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
    let user_id = string_to_uuid(&claims.sub).map_err(|_| {
        AppError::InvalidToken(String::new()).with_message_key("auth.token_subject_invalid")
    })?;

    let device_id = req.device_id.trim();
    if device_id.is_empty() || device_id.len() > 128 {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("push.device_id_invalid")
        );
    }

    let device_token = req.device_token.trim();
    if device_token.is_empty() || device_token.len() > 4096 {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("push.device_token_invalid")
        );
    }

    let platform = req.platform.trim().to_lowercase();
    if platform.is_empty() || platform.len() > 32 {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("push.platform_invalid")
        );
    }

    let channel = req.channel.trim().to_lowercase();
    if channel.is_empty() || channel.len() > 32 {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("push.channel_invalid")
        );
    }

    let locale = normalize_locale_tag(req.locale.as_deref());

    let store = PushDeviceStore::new(state.database.pool());
    let _ = store
        .upsert_device(
            user_id,
            &locale,
            &platform,
            &channel,
            device_id,
            device_token,
        )
        .await?;

    Ok(Json(RegisterPushDeviceResponse {
        success: true,
        message: "ok".to_string(),
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
    let user_id = string_to_uuid(&claims.sub).map_err(|_| {
        AppError::InvalidToken(String::new()).with_message_key("auth.token_subject_invalid")
    })?;

    let trimmed = device_id.trim();
    if trimmed.is_empty() || trimmed.len() > 128 {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("push.device_id_invalid")
        );
    }

    let store = PushDeviceStore::new(state.database.pool());
    let _deleted = store.deactivate_device(user_id, trimmed).await?;

    Ok(Json(UnregisterPushDeviceResponse {
        success: true,
        message: "ok".to_string(),
    }))
}
