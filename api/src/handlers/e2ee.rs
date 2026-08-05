use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
};
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use chrono::{DateTime, Duration, Utc};
use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use uuid::Uuid;

use crate::database::e2ee_control_store::{
    ControlMessageRecord, E2eeControlStore, RoomEpochRecord, SubmitControlMessageInput,
};
use crate::database::e2ee_key_store::{E2eeKeyStore, OneTimePreKeyInsert, SignedPreKeyInsert};
use crate::database::e2ee_mls_store::{
    ClaimedKeyPackage, E2eeDeviceRecord, E2eeMlsStore, NewKeyPackage, RegisterDeviceInput,
    MAX_AVAILABLE_KEY_PACKAGES_PER_DEVICE,
};
use crate::database::friend_store::FriendStore;
use crate::database::room_store::RoomStore;
use crate::error::AppError;
use crate::models::{convert::string_to_uuid, Claims};
use crate::services::e2ee_envelope::{
    validate_envelope, EncryptedContentType, EncryptionMetadata, EncryptionProtocol,
    PROTOCOL_VERSION,
};
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

const MLS_PROTOCOL_VERSION: i16 = 1;
const MAX_KEY_PACKAGES_PER_REQUEST: usize = 100;
const MAX_KEY_PACKAGE_LIFETIME_DAYS: i64 = 30;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RegisterMlsDeviceRequest {
    pub device_id: Uuid,
    pub device_label: String,
    pub root_public_key: String,
    pub root_fingerprint: String,
    pub credential: String,
    pub credential_fingerprint: String,
    pub approval_public_key: String,
    pub protocol_version: i16,
}

#[derive(Debug, Serialize)]
pub struct MlsDeviceResponse {
    pub id: Uuid,
    pub device_label: String,
    pub protocol_version: i16,
    pub credential_fingerprint: String,
    pub status: String,
    pub approved_by_device_id: Option<Uuid>,
    pub approved_at: Option<DateTime<Utc>>,
    pub revoked_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl From<E2eeDeviceRecord> for MlsDeviceResponse {
    fn from(value: E2eeDeviceRecord) -> Self {
        Self {
            id: value.id,
            device_label: value.device_label,
            protocol_version: value.protocol_version,
            credential_fingerprint: BASE64_STANDARD.encode(value.credential_fingerprint),
            status: value.status,
            approved_by_device_id: value.approved_by_device_id,
            approved_at: value.approved_at,
            revoked_at: value.revoked_at,
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct MlsAccountIdentityResponse {
    pub user_id: Uuid,
    pub root_public_key: String,
    pub root_fingerprint: String,
    pub protocol_version: i16,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

pub async fn get_mls_account_identity(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(target_user_id): Path<Uuid>,
) -> Result<Json<MlsAccountIdentityResponse>, AppError> {
    let current_user_id = claims_user_id(&claims)?;
    let room_store = RoomStore::new(state.database.pool());
    let is_friend = FriendStore::new(state.database.clone())
        .are_already_friends(current_user_id, target_user_id)
        .await?;
    let shares_room = room_store
        .share_room_with(current_user_id, target_user_id)
        .await?;
    if current_user_id != target_user_id && !is_friend && !shares_room {
        return Err(AppError::NotFound("E2EE 账号根身份不存在".to_string()));
    }

    let identity = E2eeMlsStore::new(state.database.pool())
        .get_account_identity(target_user_id)
        .await?
        .ok_or_else(|| AppError::NotFound("E2EE 账号根身份不存在".to_string()))?;
    Ok(Json(MlsAccountIdentityResponse {
        user_id: identity.user_id,
        root_public_key: BASE64_STANDARD.encode(identity.root_public_key),
        root_fingerprint: BASE64_STANDARD.encode(identity.root_fingerprint),
        protocol_version: identity.protocol_version,
        created_at: identity.created_at,
        updated_at: identity.updated_at,
    }))
}

#[derive(Debug, Serialize)]
pub struct MlsPeerDeviceResponse {
    pub id: Uuid,
    pub protocol_version: i16,
    pub credential_fingerprint: String,
}

pub async fn list_mls_peer_devices(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(target_user_id): Path<Uuid>,
) -> Result<Json<Vec<MlsPeerDeviceResponse>>, AppError> {
    let current_user_id = claims_user_id(&claims)?;
    if current_user_id != target_user_id
        && !FriendStore::new(state.database.clone())
            .are_already_friends(current_user_id, target_user_id)
            .await?
    {
        return Err(AppError::NotFound("E2EE 设备不存在".to_string()));
    }

    let devices = E2eeMlsStore::new(state.database.pool())
        .list_active_devices(target_user_id)
        .await?
        .into_iter()
        .map(|device| MlsPeerDeviceResponse {
            id: device.id,
            protocol_version: device.protocol_version,
            credential_fingerprint: BASE64_STANDARD.encode(device.credential_fingerprint),
        })
        .collect();
    Ok(Json(devices))
}

#[derive(Debug, Serialize)]
pub struct RoomMemberDevicesResponse {
    pub user_id: Uuid,
    pub devices: Vec<MlsPeerDeviceResponse>,
}

/// 返回房间当前成员的 active E2EE 设备，供客户端做 MLS leaf 差集收敛。
pub async fn list_room_member_devices(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<Vec<RoomMemberDevicesResponse>>, AppError> {
    let viewer_user_id = claims_user_id(&claims)?;
    let rows = E2eeMlsStore::new(state.database.pool())
        .list_room_member_devices(room_id, viewer_user_id)
        .await?;
    let is_member = RoomStore::new(state.database.pool())
        .is_user_in_room(room_id, viewer_user_id)
        .await?;
    if !is_member {
        return Err(AppError::Forbidden(
            "不是当前房间成员，无法查看 E2EE 设备".to_string(),
        ));
    }
    let mut grouped: BTreeMap<Uuid, Vec<MlsPeerDeviceResponse>> = BTreeMap::new();
    for row in rows {
        let devices = grouped.entry(row.user_id).or_default();
        if let Some(device_id) = row.device_id {
            devices.push(MlsPeerDeviceResponse {
                id: device_id,
                protocol_version: row.protocol_version.unwrap_or_default(),
                credential_fingerprint: BASE64_STANDARD.encode(
                    row.credential_fingerprint.unwrap_or_default(),
                ),
            });
        }
    }
    let result = grouped
        .into_iter()
        .map(|(user_id, devices)| RoomMemberDevicesResponse { user_id, devices })
        .collect();
    Ok(Json(result))
}

pub async fn register_mls_device(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<RegisterMlsDeviceRequest>,
) -> Result<Json<MlsDeviceResponse>, AppError> {
    let user_id = claims_user_id(&claims)?;
    let label = req.device_label.trim();
    if label.is_empty() || label.len() > 128 {
        return Err(AppError::ValidationError("device_label 无效".to_string()));
    }
    require_protocol_version(req.protocol_version)?;
    let root_public_key = decode_b64_range(&req.root_public_key, "root_public_key", 1, 4096)?;
    let root_fingerprint = decode_b64_range(&req.root_fingerprint, "root_fingerprint", 16, 128)?;
    let credential = decode_b64_range(&req.credential, "credential", 1, 65_536)?;
    let credential_fingerprint = decode_b64_range(
        &req.credential_fingerprint,
        "credential_fingerprint",
        16,
        128,
    )?;
    let approval_public_key =
        decode_b64_range(&req.approval_public_key, "approval_public_key", 32, 32)?;
    VerifyingKey::from_bytes(
        approval_public_key
            .as_slice()
            .try_into()
            .map_err(|_| AppError::ValidationError("approval_public_key 无效".to_string()))?,
    )
    .map_err(|_| {
        AppError::ValidationError("approval_public_key 不是有效 Ed25519 公钥".to_string())
    })?;

    let record = E2eeMlsStore::new(state.database.pool())
        .register_device(
            user_id,
            RegisterDeviceInput {
                device_id: req.device_id,
                device_label: label.to_string(),
                root_public_key,
                root_fingerprint,
                credential,
                credential_fingerprint,
                approval_public_key,
                protocol_version: req.protocol_version,
            },
        )
        .await?;
    Ok(Json(record.into()))
}

pub async fn list_mls_devices(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<MlsDeviceResponse>>, AppError> {
    let devices = E2eeMlsStore::new(state.database.pool())
        .list_devices(claims_user_id(&claims)?)
        .await?
        .into_iter()
        .map(Into::into)
        .collect();
    Ok(Json(devices))
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ApproveMlsDeviceRequest {
    pub approver_device_id: Uuid,
    pub signature: String,
}

pub async fn approve_mls_device(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(target_device_id): Path<Uuid>,
    Json(req): Json<ApproveMlsDeviceRequest>,
) -> Result<Json<MlsDeviceResponse>, AppError> {
    let user_id = claims_user_id(&claims)?;
    if req.approver_device_id == target_device_id {
        return Err(AppError::ValidationError("设备不能批准自身".to_string()));
    }
    let store = E2eeMlsStore::new(state.database.pool());
    let approver = store.get_device(user_id, req.approver_device_id).await?;
    if approver.status != "active" {
        return Err(AppError::Forbidden(
            "只有可信设备可以批准新设备".to_string(),
        ));
    }
    let target = store.get_device(user_id, target_device_id).await?;
    if target.status == "active" {
        // 重复批准幂等返回当前状态，客户端重试不被误判为冲突。
        return Ok(Json(target.into()));
    }
    if target.status != "pending_approval" {
        return Err(AppError::MessageRuntimeConflict(
            "目标设备不处于待批准状态".to_string(),
        ));
    }
    let public_key = approver.approval_public_key.ok_or_else(|| {
        AppError::MessageRuntimeConflict("批准设备缺少签名公钥，需要重新登记设备".to_string())
    })?;
    let signature = decode_b64_range(&req.signature, "signature", 64, 64)?;
    verify_device_approval(
        &public_key,
        &signature,
        &device_approval_payload(
            user_id,
            req.approver_device_id,
            target_device_id,
            target.protocol_version,
            &target.credential_fingerprint,
        ),
    )?;

    Ok(Json(
        store
            .approve_device(user_id, req.approver_device_id, target_device_id)
            .await?
            .into(),
    ))
}

pub async fn revoke_mls_device(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(device_id): Path<Uuid>,
) -> Result<Json<MlsDeviceResponse>, AppError> {
    let device = E2eeMlsStore::new(state.database.pool())
        .revoke_device(claims_user_id(&claims)?, device_id)
        .await?;
    Ok(Json(device.into()))
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PublishMlsKeyPackagesRequest {
    pub packages: Vec<MlsKeyPackageUpload>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MlsKeyPackageUpload {
    pub id: Uuid,
    pub package_ref: String,
    pub key_package: String,
    pub protocol_version: i16,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct PublishMlsKeyPackagesResponse {
    pub inserted: usize,
}

pub async fn publish_mls_key_packages(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(device_id): Path<Uuid>,
    Json(req): Json<PublishMlsKeyPackagesRequest>,
) -> Result<Json<PublishMlsKeyPackagesResponse>, AppError> {
    if req.packages.is_empty() || req.packages.len() > MAX_KEY_PACKAGES_PER_REQUEST {
        return Err(AppError::ValidationError(format!(
            "packages 数量必须在 1 到 {MAX_KEY_PACKAGES_PER_REQUEST} 之间"
        )));
    }
    let now = Utc::now();
    let latest_expiry = now + Duration::days(MAX_KEY_PACKAGE_LIFETIME_DAYS);
    let mut packages = Vec::with_capacity(req.packages.len());
    for package in req.packages {
        require_protocol_version(package.protocol_version)?;
        if package.expires_at <= now || package.expires_at > latest_expiry {
            return Err(AppError::ValidationError(
                "expires_at 必须在未来 30 天内".to_string(),
            ));
        }
        packages.push(NewKeyPackage {
            id: package.id,
            package_ref: decode_b64_range(&package.package_ref, "package_ref", 16, 128)?,
            key_package: decode_b64_range(&package.key_package, "key_package", 1, 1_048_576)?,
            protocol_version: package.protocol_version,
            expires_at: package.expires_at,
        });
    }
    let user_id = claims_user_id(&claims)?;
    enforce_e2ee_rate_limit(
        &state,
        &format!("rl:e2ee:key-package:publish:{user_id}:{device_id}"),
        60,
        60,
        "KeyPackage 发布过于频繁：每分钟最多 60 次",
    )
    .await?;
    let inserted = E2eeMlsStore::new(state.database.pool())
        .publish_key_packages(user_id, device_id, &packages)
        .await?;
    Ok(Json(PublishMlsKeyPackagesResponse { inserted }))
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct KeyPackageInventoryResponse {
    pub available: i64,
    pub max_available: i64,
}

/// 查询可信设备当前可用 KeyPackage 库存，供客户端低水位补充决策。
pub async fn get_mls_key_package_inventory(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(device_id): Path<Uuid>,
) -> Result<Json<KeyPackageInventoryResponse>, AppError> {
    let user_id = claims_user_id(&claims)?;
    let available = E2eeMlsStore::new(state.database.pool())
        .count_available_key_packages(user_id, device_id)
        .await?;
    Ok(Json(KeyPackageInventoryResponse {
        available,
        max_available: MAX_AVAILABLE_KEY_PACKAGES_PER_DEVICE,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ClaimMlsKeyPackageRequest {
    pub room_id: Uuid,
    pub consumer_device_id: Uuid,
}

#[derive(Debug, Serialize)]
pub struct ClaimedMlsKeyPackageResponse {
    pub id: Uuid,
    pub device_id: Uuid,
    pub package_ref: String,
    pub key_package: String,
    pub protocol_version: i16,
    pub expires_at: DateTime<Utc>,
}

impl From<ClaimedKeyPackage> for ClaimedMlsKeyPackageResponse {
    fn from(value: ClaimedKeyPackage) -> Self {
        Self {
            id: value.id,
            device_id: value.device_id,
            package_ref: BASE64_STANDARD.encode(value.package_ref),
            key_package: BASE64_STANDARD.encode(value.key_package),
            protocol_version: value.protocol_version,
            expires_at: value.expires_at,
        }
    }
}

pub async fn claim_mls_key_package(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(target_device_id): Path<Uuid>,
    Json(req): Json<ClaimMlsKeyPackageRequest>,
) -> Result<Json<ClaimedMlsKeyPackageResponse>, AppError> {
    let user_id = claims_user_id(&claims)?;
    enforce_e2ee_rate_limit(
        &state,
        &format!("rl:e2ee:key-package:claim:{user_id}"),
        120,
        60,
        "KeyPackage 领取过于频繁：每分钟最多 120 次",
    )
    .await?;
    let package = E2eeMlsStore::new(state.database.pool())
        .take_key_package_for_room(
            req.room_id,
            user_id,
            target_device_id,
            req.consumer_device_id,
        )
        .await?
        .ok_or_else(|| AppError::NotFound("没有可领取的 KeyPackage".to_string()))?;
    Ok(Json(package.into()))
}

pub fn device_approval_payload(
    user_id: Uuid,
    approver_device_id: Uuid,
    target_device_id: Uuid,
    protocol_version: i16,
    target_credential_fingerprint: &[u8],
) -> Vec<u8> {
    let mut payload = b"redcode-im/e2ee/device-approval/v1\0".to_vec();
    payload.extend_from_slice(user_id.as_bytes());
    payload.extend_from_slice(approver_device_id.as_bytes());
    payload.extend_from_slice(target_device_id.as_bytes());
    payload.extend_from_slice(&protocol_version.to_be_bytes());
    payload.extend_from_slice(&(target_credential_fingerprint.len() as u16).to_be_bytes());
    payload.extend_from_slice(target_credential_fingerprint);
    payload
}

fn verify_device_approval(
    public_key: &[u8],
    signature: &[u8],
    payload: &[u8],
) -> Result<(), AppError> {
    let verifying_key = VerifyingKey::from_bytes(
        public_key
            .try_into()
            .map_err(|_| AppError::Forbidden("设备批准签名公钥无效".to_string()))?,
    )
    .map_err(|_| AppError::Forbidden("设备批准签名公钥无效".to_string()))?;
    let signature = Signature::from_slice(signature)
        .map_err(|_| AppError::Forbidden("设备批准签名无效".to_string()))?;
    verifying_key
        .verify(payload, &signature)
        .map_err(|_| AppError::Forbidden("设备批准签名验证失败".to_string()))
}

fn claims_user_id(claims: &Claims) -> Result<Uuid, AppError> {
    string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {e}")))
}

fn require_protocol_version(version: i16) -> Result<(), AppError> {
    if version == MLS_PROTOCOL_VERSION {
        Ok(())
    } else {
        Err(AppError::ValidationError(
            "仅支持 MLS protocol_version=1".to_string(),
        ))
    }
}

fn decode_b64_range(value: &str, field: &str, min: usize, max: usize) -> Result<Vec<u8>, AppError> {
    let decoded = decode_b64(value, field)?;
    if decoded.len() < min || decoded.len() > max {
        return Err(AppError::ValidationError(format!(
            "{field} 解码后长度必须在 {min} 到 {max} 字节之间"
        )));
    }
    Ok(decoded)
}

async fn enforce_e2ee_rate_limit(
    state: &AppState,
    key: &str,
    max_requests: i64,
    window_seconds: i64,
    message: &str,
) -> Result<(), AppError> {
    let mut connection = state.redis.get_session_connection();
    let count: i64 = redis::cmd("INCR")
        .arg(key)
        .query_async(&mut connection)
        .await
        .map_err(|_| AppError::CacheError("E2EE 限流计数失败".to_string()))?;
    if count == 1 {
        let _: () = redis::cmd("EXPIRE")
            .arg(key)
            .arg(window_seconds)
            .query_async(&mut connection)
            .await
            .map_err(|_| AppError::CacheError("E2EE 限流窗口设置失败".to_string()))?;
    }
    if count > max_requests {
        return Err(AppError::RateLimitExceeded(message.to_string()));
    }
    Ok(())
}

#[derive(Debug, Serialize)]
pub struct RoomEpochResponse {
    pub room_id: Uuid,
    pub membership_revision: i64,
    pub active_epoch: i64,
    pub status: String,
    pub updated_at: DateTime<Utc>,
}

impl From<RoomEpochRecord> for RoomEpochResponse {
    fn from(value: RoomEpochRecord) -> Self {
        Self {
            room_id: value.room_id,
            membership_revision: value.membership_revision,
            active_epoch: value.active_epoch,
            status: value.status,
            updated_at: value.updated_at,
        }
    }
}

pub async fn get_mls_room_epoch(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<RoomEpochResponse>, AppError> {
    let epoch = E2eeControlStore::new(state.database.pool())
        .get_room_epoch(room_id, claims_user_id(&claims)?)
        .await?;
    Ok(Json(epoch.into()))
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SubmitMlsControlMessageRequest {
    pub id: Uuid,
    pub epoch: i64,
    pub membership_revision: i64,
    pub sender_device_id: Uuid,
    pub recipient_device_id: Option<Uuid>,
    pub content_type: MlsControlContentType,
    pub envelope: String,
    pub idempotency_key: Uuid,
}

#[derive(Debug, Clone, Copy, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MlsControlContentType {
    Commit,
    Welcome,
}

impl MlsControlContentType {
    fn as_str(self) -> &'static str {
        match self {
            Self::Commit => "commit",
            Self::Welcome => "welcome",
        }
    }

    fn envelope_type(self) -> EncryptedContentType {
        match self {
            Self::Commit => EncryptedContentType::Commit,
            Self::Welcome => EncryptedContentType::Welcome,
        }
    }
}

#[derive(Debug, Serialize)]
pub struct MlsControlMessageResponse {
    pub id: Uuid,
    pub room_id: Uuid,
    pub epoch: i64,
    pub membership_revision: i64,
    pub sender_device_id: Uuid,
    pub recipient_device_id: Option<Uuid>,
    pub content_type: String,
    pub envelope: String,
    pub idempotency_key: Uuid,
    pub sequence_no: i64,
    pub created_at: DateTime<Utc>,
}

impl From<ControlMessageRecord> for MlsControlMessageResponse {
    fn from(value: ControlMessageRecord) -> Self {
        Self {
            id: value.id,
            room_id: value.room_id,
            epoch: value.epoch,
            membership_revision: value.membership_revision,
            sender_device_id: value.sender_device_id,
            recipient_device_id: value.recipient_device_id,
            content_type: value.content_type,
            envelope: BASE64_STANDARD.encode(value.envelope),
            idempotency_key: value.idempotency_key,
            sequence_no: value.sequence_no,
            created_at: value.created_at,
        }
    }
}

pub async fn submit_mls_control_message(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(req): Json<SubmitMlsControlMessageRequest>,
) -> Result<Json<MlsControlMessageResponse>, AppError> {
    if req.id.is_nil() || req.idempotency_key.is_nil() {
        return Err(AppError::ValidationError(
            "id 和 idempotency_key 不能是 nil UUID".to_string(),
        ));
    }
    if req.epoch <= 0 || req.membership_revision <= 0 {
        return Err(AppError::ValidationError(
            "epoch 和 membership_revision 必须大于 0".to_string(),
        ));
    }
    match req.content_type {
        MlsControlContentType::Commit if req.recipient_device_id.is_some() => {
            return Err(AppError::ValidationError(
                "Commit 必须广播，不能指定 recipient_device_id".to_string(),
            ))
        }
        MlsControlContentType::Welcome if req.recipient_device_id.is_none() => {
            return Err(AppError::ValidationError(
                "Welcome 必须指定 recipient_device_id".to_string(),
            ))
        }
        _ => {}
    }
    let envelope = decode_b64_range(
        &req.envelope,
        "envelope",
        12,
        crate::services::e2ee_envelope::MAX_PAYLOAD_BYTES + 11,
    )?;
    let epoch = u64::try_from(req.epoch)
        .map_err(|_| AppError::ValidationError("epoch 无效".to_string()))?;
    validate_envelope(
        &envelope,
        &EncryptionMetadata {
            protocol: EncryptionProtocol::Mls,
            version: PROTOCOL_VERSION,
            epoch,
            sender_device_id: req.sender_device_id,
            content_type: req.content_type.envelope_type(),
            control_message_id: Some(req.id),
        },
    )
    .map_err(|message| AppError::ValidationError(message.to_string()))?;

    let record = E2eeControlStore::new(state.database.pool())
        .submit_control_message(
            room_id,
            claims_user_id(&claims)?,
            SubmitControlMessageInput {
                id: req.id,
                epoch: req.epoch,
                membership_revision: req.membership_revision,
                sender_device_id: req.sender_device_id,
                recipient_device_id: req.recipient_device_id,
                content_type: req.content_type.as_str().to_string(),
                envelope,
                idempotency_key: req.idempotency_key,
            },
        )
        .await?;
    Ok(Json(record.into()))
}

#[derive(Debug, Deserialize)]
pub struct ListMlsControlMessagesQuery {
    pub device_id: Uuid,
    #[serde(default)]
    pub after_sequence: i64,
    pub limit: Option<i64>,
}

pub async fn list_mls_control_messages(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Query(query): Query<ListMlsControlMessagesQuery>,
) -> Result<Json<Vec<MlsControlMessageResponse>>, AppError> {
    if query.after_sequence < 0 {
        return Err(AppError::ValidationError(
            "after_sequence 不能小于 0".to_string(),
        ));
    }
    let limit = query.limit.unwrap_or(50);
    if !(1..=100).contains(&limit) {
        return Err(AppError::ValidationError(
            "limit 必须在 1 到 100 之间".to_string(),
        ));
    }
    let messages = E2eeControlStore::new(state.database.pool())
        .list_control_messages(
            room_id,
            claims_user_id(&claims)?,
            query.device_id,
            query.after_sequence,
            limit,
        )
        .await?
        .into_iter()
        .map(Into::into)
        .collect();
    Ok(Json(messages))
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ConsumeMlsControlMessageRequest {
    pub device_id: Uuid,
}

#[derive(Debug, Serialize)]
pub struct ConsumeMlsControlMessageResponse {
    pub consumed: bool,
}

pub async fn consume_mls_control_message(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, message_id)): Path<(Uuid, Uuid)>,
    Json(req): Json<ConsumeMlsControlMessageRequest>,
) -> Result<Json<ConsumeMlsControlMessageResponse>, AppError> {
    E2eeControlStore::new(state.database.pool())
        .consume_control_message(room_id, claims_user_id(&claims)?, req.device_id, message_id)
        .await?;
    Ok(Json(ConsumeMlsControlMessageResponse { consumed: true }))
}
