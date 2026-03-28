use axum::{
    extract::{Extension, Path, State},
    response::Json,
};
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::e2ee_key_store::{E2eeKeyStore, OneTimePreKeyInsert, SignedPreKeyInsert};
use crate::error::AppError;
use crate::models::{convert::string_to_uuid, Claims};
use crate::AppState;

#[derive(Debug, Deserialize)]
pub struct SignedPreKeyUpload {
    pub key_id: i32,
    pub public_key: String,
    pub signature: String,
}

#[derive(Debug, Deserialize)]
pub struct OneTimePreKeyUpload {
    pub key_id: i32,
    pub public_key: String,
}

/// 上传某个设备的 E2EE 预密钥包（Identity Key + Signed Pre-Key + One-Time Pre-Keys）。
///
/// 注意：本接口仅存储公钥/预密钥等公开材料，私钥永不上传。
#[derive(Debug, Deserialize)]
pub struct UploadKeyBundleRequest {
    pub device_id: String,
    /// base64（标准编码）
    pub identity_key: String,
    pub signed_pre_key: SignedPreKeyUpload,
    pub one_time_pre_keys: Vec<OneTimePreKeyUpload>,
}

#[derive(Debug, Serialize)]
pub struct UploadKeyBundleResponse {
    pub success: bool,
    pub message: String,
    pub device_id: String,
    pub one_time_pre_keys_saved: usize,
}

pub async fn upload_key_bundle(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<UploadKeyBundleRequest>,
) -> Result<Json<UploadKeyBundleResponse>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let device_id = req.device_id.trim();
    if device_id.is_empty() || device_id.len() > 128 {
        return Err(AppError::ValidationError("device_id 无效".to_string()));
    }

    let identity_key = decode_b64(&req.identity_key, "identity_key")?;
    if identity_key.len() != 32 {
        return Err(AppError::ValidationError(
            "identity_key 长度应为 32 字节".to_string(),
        ));
    }

    if req.signed_pre_key.key_id <= 0 {
        return Err(AppError::ValidationError(
            "signed_pre_key.key_id 无效".to_string(),
        ));
    }

    let signed_public_key =
        decode_b64(&req.signed_pre_key.public_key, "signed_pre_key.public_key")?;
    if signed_public_key.len() != 32 {
        return Err(AppError::ValidationError(
            "signed_pre_key.public_key 长度应为 32 字节".to_string(),
        ));
    }

    let signed_signature = decode_b64(&req.signed_pre_key.signature, "signed_pre_key.signature")?;
    if signed_signature.len() != 64 {
        return Err(AppError::ValidationError(
            "signed_pre_key.signature 长度应为 64 字节".to_string(),
        ));
    }

    if req.one_time_pre_keys.len() > 200 {
        return Err(AppError::ValidationError(
            "one_time_pre_keys 数量过多（最大 200）".to_string(),
        ));
    }

    let mut one_time_keys = Vec::with_capacity(req.one_time_pre_keys.len());
    for item in req.one_time_pre_keys {
        if item.key_id <= 0 {
            return Err(AppError::ValidationError(
                "one_time_pre_keys.key_id 无效".to_string(),
            ));
        }
        let public_key = decode_b64(&item.public_key, "one_time_pre_keys.public_key")?;
        if public_key.len() != 32 {
            return Err(AppError::ValidationError(
                "one_time_pre_keys.public_key 长度应为 32 字节".to_string(),
            ));
        }
        one_time_keys.push(OneTimePreKeyInsert {
            key_id: item.key_id,
            public_key,
        });
    }

    // Signed Pre-Key 默认 7 天过期（后续可按产品策略调整/支持客户端传入 expires_at）
    let expires_at = Utc::now() + Duration::days(7);

    let store = E2eeKeyStore::new(state.database.pool());
    store
        .save_key_bundle(
            user_id,
            device_id,
            identity_key,
            SignedPreKeyInsert {
                key_id: req.signed_pre_key.key_id,
                public_key: signed_public_key,
                signature: signed_signature,
                expires_at,
            },
            one_time_keys.clone(),
        )
        .await?;

    Ok(Json(UploadKeyBundleResponse {
        success: true,
        message: "密钥上传成功".to_string(),
        device_id: device_id.to_string(),
        one_time_pre_keys_saved: one_time_keys.len(),
    }))
}

#[derive(Debug, Serialize)]
pub struct SignedPreKeyResponse {
    pub key_id: i32,
    pub public_key: String,
    pub signature: String,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct OneTimePreKeyResponse {
    pub key_id: i32,
    pub public_key: String,
}

#[derive(Debug, Serialize)]
pub struct DeviceKeyBundle {
    pub device_id: String,
    pub identity_key: String,
    pub signed_pre_key: SignedPreKeyResponse,
    pub one_time_pre_key: Option<OneTimePreKeyResponse>,
    pub one_time_pre_key_remaining: i64,
}

#[derive(Debug, Serialize)]
pub struct KeyBundlesResponse {
    pub user_id: Uuid,
    pub devices: Vec<DeviceKeyBundle>,
}

/// 获取目标用户的 Key Bundle 列表（多设备）。
///
/// - 会对每个 device “原子取用”一个 One-Time Pre-Key（如存在）
/// - 若目标用户未初始化 E2EE，则返回 404
pub async fn get_key_bundles(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
    Path(target_user_id): Path<Uuid>,
) -> Result<Json<KeyBundlesResponse>, AppError> {
    let store = E2eeKeyStore::new(state.database.pool());
    let device_ids = store.list_device_ids(target_user_id).await?;

    if device_ids.is_empty() {
        return Err(AppError::NotFound("目标用户未初始化 E2EE".to_string()));
    }

    let mut bundles = Vec::with_capacity(device_ids.len());
    for device_id in device_ids {
        let identity_key = store
            .get_identity_key(target_user_id, &device_id)
            .await?
            .ok_or_else(|| AppError::NotFound("identity_key 不存在".to_string()))?;

        let signed = store
            .get_latest_active_signed_pre_key(target_user_id, &device_id)
            .await?
            .ok_or_else(|| AppError::NotFound("signed_pre_key 不存在或已过期".to_string()))?;

        let one_time = store
            .take_one_time_pre_key(target_user_id, &device_id)
            .await?;

        let remaining = store
            .count_unused_one_time_pre_keys(target_user_id, &device_id)
            .await?;

        bundles.push(DeviceKeyBundle {
            device_id: device_id.clone(),
            identity_key: BASE64_STANDARD.encode(&identity_key),
            signed_pre_key: SignedPreKeyResponse {
                key_id: signed.key_id,
                public_key: BASE64_STANDARD.encode(&signed.public_key),
                signature: BASE64_STANDARD.encode(&signed.signature),
                expires_at: signed.expires_at,
            },
            one_time_pre_key: one_time.map(|k| OneTimePreKeyResponse {
                key_id: k.key_id,
                public_key: BASE64_STANDARD.encode(&k.public_key),
            }),
            one_time_pre_key_remaining: remaining,
        });
    }

    Ok(Json(KeyBundlesResponse {
        user_id: target_user_id,
        devices: bundles,
    }))
}

fn decode_b64(value: &str, field: &str) -> Result<Vec<u8>, AppError> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(AppError::ValidationError(format!("{} 不能为空", field)));
    }
    BASE64_STANDARD
        .decode(trimmed)
        .map_err(|_| AppError::ValidationError(format!("{} base64 解码失败", field)))
}
