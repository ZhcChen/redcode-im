use crate::database::file_upload_audit_store::FileUploadAuditStore;
use crate::database::file_upload_multipart_store::FileUploadMultipartStore;
use crate::database::file_upload_store::FileUploadStore;
use crate::database::models::{Platform, StorageProviderType};
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::version_store::{
    version_exists, HotUpdateEventInsert, HotUpdateUpdate, VersionStore,
};
use crate::error::AppError;
use crate::models::convert::{
    api_create_hot_update_to_db, api_create_version_to_db, api_update_hot_update_to_db,
    api_update_version_to_db, db_app_version_to_api, db_hot_update_events_to_api_list,
    db_hot_update_to_api, db_hot_updates_to_api_list, db_versions_to_api_list,
};
use crate::models::{
    Claims, CreateAppVersionRequest, CreateHotUpdateRequest, HotUpdateEventListQuery,
    HotUpdateEventListResponse, HotUpdateEventReport, HotUpdateQuery, HotUpdateResponse,
    LatestVersionQuery, LatestVersionResponse, ListAppVersionsQuery, ListHotUpdatesQuery,
    UpdateAppVersionRequest, UpdateHotUpdateRequest,
};
use crate::services::multipart_upload;
use crate::storage;
use crate::storage::DirectUploadSignature;
use crate::AppState;
use axum::{
    extract::{Extension, Path, Query, State},
    Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::collections::{hash_map::DefaultHasher, BTreeMap};
use std::hash::Hasher;
use tracing::info;
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct VersionUploadSignatureRequest {
    pub platform: String,
    #[serde(default = "default_channel")]
    pub channel: String,
    pub filename: Option<String>,
    /// 文件大小（字节，可选，便于后续按 hash + size 去重）
    #[serde(default)]
    pub file_size: Option<i64>,
    /// 文件哈希值（由前端计算并上报，十六进制字符串）
    #[serde(default)]
    pub hash_value: Option<String>,
    /// 哈希算法：1=md5, 2=sha256；缺省视为 1
    #[serde(default)]
    pub hash_alg: Option<i16>,
}

#[derive(Debug, Serialize)]
pub struct VersionUploadSignatureResponse {
    pub success: bool,
    pub message: String,
    pub key: Option<String>,
    pub signature: Option<DirectUploadSignature>,
}

#[derive(Debug, Deserialize)]
pub struct VersionMultipartInitiateRequest {
    pub platform: String,
    #[serde(default = "default_channel")]
    pub channel: String,
    pub filename: Option<String>,
    /// 文件大小（字节，必填；用于分片规划与校验）
    pub file_size: i64,
    /// 文件哈希值（由前端计算并上报，十六进制字符串）
    #[serde(default)]
    pub hash_value: Option<String>,
    /// 哈希算法：1=md5, 2=sha256；缺省视为 1
    #[serde(default)]
    pub hash_alg: Option<i16>,
    /// 可选：内容类型（用于初始化分片会话时写入 Content-Type）
    #[serde(default)]
    pub content_type: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct VersionMultipartInitiateResponse {
    pub success: bool,
    pub message: String,
    pub key: Option<String>,
    pub session_id: Option<String>,
    pub part_size: Option<i32>,
    pub total_parts: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct AppVersionListResponse {
    pub total: i64,
    pub items: Vec<crate::models::AppVersionInfo>,
}

fn default_channel() -> String {
    "stable".to_string()
}

const SUPPORTED_VERSION_PLATFORMS: &str = "windows, macos, ios, android, linux";

fn version_validation_error(message_key: &'static str) -> AppError {
    AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn version_validation_error_with_params(
    message_key: &'static str,
    params: crate::i18n::message::MessageParams,
) -> AppError {
    AppError::ValidationError(String::new()).with_message_key_and_params(message_key, Some(params))
}

fn version_not_found_error(message_key: &'static str) -> AppError {
    AppError::NotFound(String::new()).with_message_key(message_key)
}

fn version_platform_params(platform: impl Into<String>) -> crate::i18n::message::MessageParams {
    BTreeMap::from([
        ("platform".to_string(), platform.into()),
        (
            "supported_platforms".to_string(),
            SUPPORTED_VERSION_PLATFORMS.to_string(),
        ),
    ])
}

fn parse_required_version_platform(platform: &str) -> Result<Platform, AppError> {
    let trimmed = platform.trim();
    if trimmed.is_empty() {
        return Err(version_validation_error("version.platform_required"));
    }

    Platform::from_str(trimmed).ok_or_else(|| {
        version_validation_error_with_params(
            "version.platform_unsupported",
            version_platform_params(trimmed.to_string()),
        )
    })
}

#[derive(Debug, Serialize)]
pub struct HotUpdateListResponse {
    pub total: i64,
    pub items: Vec<crate::models::HotUpdateInfo>,
}

#[derive(Debug, Deserialize)]
pub struct LatestVersionDownloadParams {
    pub platform: String,
    #[serde(default = "default_channel")]
    pub channel: String,
    pub expires_in_seconds: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct LatestVersionDownloadResponse {
    pub success: bool,
    pub message: String,
    pub version: Option<crate::models::AppVersionInfo>,
    pub download_url: Option<String>,
}

pub async fn generate_version_upload_signature(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<VersionUploadSignatureRequest>,
) -> Result<Json<VersionUploadSignatureResponse>, AppError> {
    let _ = claims; // currently no role check

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    // 如果前端提供了 hash 和 size，优先尝试复用已上传完成的安装包
    if let (Some(ref hash_value), Some(file_size)) = (&req.hash_value, req.file_size) {
        if file_size > 0 {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store = FileUploadStore::new(state.database.clone());
            if let Some(existing) = upload_store
                .find_completed_by_hash(&provider.id, hash_alg, hash_value, file_size, None)
                .await
                .map_err(AppError::from)?
            {
                if !storage_service.file_exists(&existing.object_key).await? {
                    let _ = upload_store
                        .mark_deleted_by_key(
                            &provider.id,
                            &existing.object_key,
                            Some("对象不存在，已标记为删除"),
                        )
                        .await;
                } else {
                    info!(
                        "复用已上传的安装包: key={}, hash_alg={}, hash_value={}",
                        existing.object_key, hash_alg, hash_value
                    );

                    return Ok(Json(VersionUploadSignatureResponse {
                        success: true,
                        message: "复用已上传的安装包，未生成新的直传签名".to_string(),
                        key: Some(existing.object_key),
                        signature: None,
                    }));
                }
            }
        }
    }

    let key =
        build_release_object_key(&req.platform, req.channel.as_str(), req.filename.as_deref());

    // 记录“上传中”的文件记录
    if let (Some(ref hash_value), Some(file_size)) = (&req.hash_value, req.file_size) {
        if file_size > 0 {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store = FileUploadStore::new(state.database.clone());
            let _ = upload_store
                .create_pending_record(
                    &provider.id,
                    &key,
                    hash_alg,
                    hash_value,
                    Some(file_size),
                    None,
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    let signature = storage_service
        .generate_direct_upload_signature(&key, None)
        .await?;

    info!("前端获取直传参数 key: {}", key);

    Ok(Json(VersionUploadSignatureResponse {
        success: true,
        message: "生成安装包直传签名成功".to_string(),
        key: Some(key),
        signature: Some(signature),
    }))
}

/// 初始化安装包大文件分片直传会话（COS Multipart Upload）
pub async fn initiate_version_multipart_upload(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<VersionMultipartInitiateRequest>,
) -> Result<Json<VersionMultipartInitiateResponse>, AppError> {
    let file_size = req.file_size;
    let (part_size, total_parts) = multipart_upload::plan_multipart_upload(file_size)?;

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    // 如果前端提供了 hash 和 size，优先尝试复用已上传完成的安装包
    if let Some(ref hash_value) = req.hash_value {
        let hash_value_trimmed = hash_value.trim();
        if !hash_value_trimmed.is_empty() {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store = FileUploadStore::new(state.database.clone());
            if let Some(existing) = upload_store
                .find_completed_by_hash(&provider.id, hash_alg, hash_value_trimmed, file_size, None)
                .await
                .map_err(AppError::from)?
            {
                if !storage_service.file_exists(&existing.object_key).await? {
                    let _ = upload_store
                        .mark_deleted_by_key(
                            &provider.id,
                            &existing.object_key,
                            Some("对象不存在，已标记为删除"),
                        )
                        .await;
                } else {
                    info!(
                        "复用已上传的安装包（分片直传 initiate）：key={}, hash_alg={}, hash_value={}",
                        existing.object_key, hash_alg, hash_value_trimmed
                    );

                    return Ok(Json(VersionMultipartInitiateResponse {
                        success: true,
                        message: "复用已上传的安装包，无需重新上传".to_string(),
                        key: Some(existing.object_key),
                        session_id: None,
                        part_size: None,
                        total_parts: None,
                    }));
                }
            }
        }
    }

    let key =
        build_release_object_key(&req.platform, req.channel.as_str(), req.filename.as_deref());

    // 如果有 hash 信息，则记录一条“上传中”的文件记录
    if let Some(ref hash_value) = req.hash_value {
        let hash_value_trimmed = hash_value.trim();
        if !hash_value_trimmed.is_empty() {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store = FileUploadStore::new(state.database.clone());
            let _ = upload_store
                .create_pending_record(
                    &provider.id,
                    &key,
                    hash_alg,
                    hash_value_trimmed,
                    Some(file_size),
                    None,
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    let content_type = req
        .content_type
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty());

    let upload_id = storage_service
        .initiate_multipart_upload(&key, content_type)
        .await?;

    let store = FileUploadMultipartStore::new(state.database.clone());
    let creator_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let session = match store
        .create_session(
            &provider.id,
            &key,
            &upload_id,
            &creator_id,
            claims.is_admin,
            Some(file_size),
            content_type,
            part_size,
            total_parts,
        )
        .await
    {
        Ok(session) => session,
        Err(e) => {
            // 尝试回滚 COS multipart 会话，避免遗留分片
            let _ = storage_service
                .abort_multipart_upload(&key, &upload_id)
                .await;
            return Err(AppError::InternalError(format!("创建分片会话失败: {}", e)));
        }
    };

    Ok(Json(VersionMultipartInitiateResponse {
        success: true,
        message: "初始化分片上传会话成功".to_string(),
        key: Some(key),
        session_id: Some(session.id.to_string()),
        part_size: Some(part_size),
        total_parts: Some(total_parts),
    }))
}

pub async fn create_app_version(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<CreateAppVersionRequest>,
) -> Result<Json<crate::models::AppVersionInfo>, AppError> {
    validate_version_payload(&req)?;

    let platform = Platform::from_str(req.platform.trim()).ok_or_else(|| {
        AppError::ValidationError(format!(
            "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
            req.platform
        ))
    })?;
    let channel_trimmed = req.channel.trim();
    let version_trimmed = req.version.trim();

    if version_exists(&state.database, platform, channel_trimmed, version_trimmed).await? {
        return Err(AppError::ValidationError(
            "该平台该渠道的版本已存在".to_string(),
        ));
    }

    let operator = Some(Uuid::parse_str(&claims.sub).unwrap_or(Uuid::nil()));
    let store = VersionStore::new(state.database.clone());

    let insert = api_create_version_to_db(&req, operator)?;
    let created = store.create_version(&insert).await?;

    // 标记安装包文件已上传完成（如果之前通过直传签名创建了记录）
    if !req.download_key.trim().is_empty() {
        let provider = load_default_storage_provider(&state).await?;
        let storage_service = storage::create_storage_service(&provider)?;
        match storage_service.head_object(req.download_key.trim()).await {
            Ok(head) => {
                if let Some(expected_size) = req.file_size {
                    if let Some(actual_size) = head.content_length {
                        if actual_size != expected_size as u64 {
                            return Err(AppError::ValidationError(format!(
                                "安装包大小校验失败：期望 {} 字节，实际 {} 字节",
                                expected_size, actual_size
                            )));
                        }
                    }
                }
            }
            Err(AppError::NotFound(_)) => {
                return Err(AppError::ValidationError(
                    "对象存储中未找到安装包，请先完成上传".to_string(),
                ));
            }
            Err(AppError::ValidationError(_)) => {
                if !storage_service.file_exists(req.download_key.trim()).await? {
                    return Err(AppError::ValidationError(
                        "对象存储中未找到安装包，请先完成上传".to_string(),
                    ));
                }
            }
            Err(e) => return Err(e),
        }
        let upload_store = FileUploadStore::new(state.database.clone());
        let _ = upload_store
            .mark_completed_by_key(&provider.id, req.download_key.trim())
            .await
            .map_err(AppError::from)?;

        // 写入内容审核任务（异步队列；违规会删除对象并记录原因）
        let record = upload_store
            .get_by_key(&provider.id, req.download_key.trim())
            .await
            .map_err(AppError::from)?;
        let audit_store = FileUploadAuditStore::new(state.database.clone());
        let content_type = record.as_ref().and_then(|r| r.content_type.as_deref());
        let file_size = record.as_ref().and_then(|r| r.file_size).or(req.file_size);
        let _ = audit_store
            .upsert_task(
                &provider.id,
                req.download_key.trim(),
                "version",
                "document",
                content_type,
                file_size,
            )
            .await
            .map_err(AppError::from)?;
    }

    Ok(Json(db_app_version_to_api(&created)))
}

pub async fn update_app_version(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<String>,
    Json(req): Json<UpdateAppVersionRequest>,
) -> Result<Json<crate::models::AppVersionInfo>, AppError> {
    let version_id =
        Uuid::parse_str(&id).map_err(|_| AppError::ValidationError("无效的版本 ID".to_string()))?;

    let operator = Some(Uuid::parse_str(&claims.sub).unwrap_or(Uuid::nil()));
    let store = VersionStore::new(state.database.clone());

    let update = api_update_version_to_db(&req, operator);
    let updated = store
        .update_version(version_id, &update)
        .await?
        .ok_or_else(|| AppError::NotFound("版本记录不存在".to_string()))?;

    // 若更新了 download_key，则同步标记 file_upload_records 完成并写入审核任务
    if let Some(download_key) = req.download_key.as_deref() {
        let download_key = download_key.trim();
        if !download_key.is_empty() {
            let provider = load_default_storage_provider(&state).await?;
            let storage_service = storage::create_storage_service(&provider)?;
            match storage_service.head_object(download_key).await {
                Ok(head) => {
                    if let Some(expected_size) = req.file_size {
                        if let Some(actual_size) = head.content_length {
                            if actual_size != expected_size as u64 {
                                return Err(AppError::ValidationError(format!(
                                    "安装包大小校验失败：期望 {} 字节，实际 {} 字节",
                                    expected_size, actual_size
                                )));
                            }
                        }
                    }
                }
                Err(AppError::NotFound(_)) => {
                    return Err(AppError::ValidationError(
                        "对象存储中未找到安装包，请先完成上传".to_string(),
                    ));
                }
                Err(AppError::ValidationError(_)) => {
                    if !storage_service.file_exists(download_key).await? {
                        return Err(AppError::ValidationError(
                            "对象存储中未找到安装包，请先完成上传".to_string(),
                        ));
                    }
                }
                Err(e) => return Err(e),
            }

            let upload_store = FileUploadStore::new(state.database.clone());
            let _ = upload_store
                .mark_completed_by_key(&provider.id, download_key)
                .await
                .map_err(AppError::from)?;

            let record = upload_store
                .get_by_key(&provider.id, download_key)
                .await
                .map_err(AppError::from)?;
            let audit_store = FileUploadAuditStore::new(state.database.clone());
            let content_type = record.as_ref().and_then(|r| r.content_type.as_deref());
            let file_size = record.as_ref().and_then(|r| r.file_size).or(req.file_size);
            let _ = audit_store
                .upsert_task(
                    &provider.id,
                    download_key,
                    "version",
                    "document",
                    content_type,
                    file_size,
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    Ok(Json(db_app_version_to_api(&updated)))
}

pub async fn list_app_versions(
    State(state): State<AppState>,
    Query(query): Query<ListAppVersionsQuery>,
) -> Result<Json<AppVersionListResponse>, AppError> {
    let store = VersionStore::new(state.database.clone());
    let platform_str = query.platform.trim();
    let platform = parse_required_version_platform(platform_str)?;

    let channel = query
        .channel
        .as_deref()
        .map(|c| c.trim())
        .filter(|c| !c.is_empty());
    let limit = query.limit.clamp(1, 100);
    let offset = query.offset.max(0);

    let items = store
        .list_versions(platform, channel, limit, offset)
        .await?;

    let total = store.count_versions(platform, channel).await?;

    Ok(Json(AppVersionListResponse {
        total,
        items: db_versions_to_api_list(&items),
    }))
}

pub async fn get_app_version(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<crate::models::AppVersionInfo>, AppError> {
    let version_id =
        Uuid::parse_str(&id).map_err(|_| AppError::ValidationError("无效的版本 ID".to_string()))?;

    let store = VersionStore::new(state.database.clone());
    let version = store
        .get_version(version_id)
        .await?
        .ok_or_else(|| version_not_found_error("version.not_found"))?;

    Ok(Json(db_app_version_to_api(&version)))
}

pub async fn deactivate_app_version(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<String>,
) -> Result<Json<crate::models::AppVersionInfo>, AppError> {
    let version_id =
        Uuid::parse_str(&id).map_err(|_| AppError::ValidationError("无效的版本 ID".to_string()))?;

    let operator = Some(Uuid::parse_str(&claims.sub).unwrap_or(Uuid::nil()));
    let store = VersionStore::new(state.database.clone());
    let version = store
        .deactivate_version(version_id, operator)
        .await?
        .ok_or_else(|| AppError::NotFound("版本不存在或已停用".to_string()))?;

    Ok(Json(db_app_version_to_api(&version)))
}

pub async fn delete_app_version(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let version_id =
        Uuid::parse_str(&id).map_err(|_| AppError::ValidationError("无效的版本 ID".to_string()))?;

    let store = VersionStore::new(state.database.clone());
    let deleted = store.delete_version(version_id).await?;

    if !deleted {
        return Err(version_not_found_error("version.not_found"));
    }

    Ok(Json(serde_json::json!({
        "success": true,
    })))
}

pub async fn latest_version(
    State(state): State<AppState>,
    Query(query): Query<LatestVersionQuery>,
) -> Result<Json<LatestVersionResponse>, AppError> {
    let platform = parse_required_version_platform(&query.platform)?;

    let channel = query.channel.trim();
    if channel.is_empty() {
        return Err(version_validation_error("version.channel_required"));
    }

    let store = VersionStore::new(state.database.clone());
    let latest = store.find_latest_active(platform, channel).await?;

    let current_version = query.current_version.clone();
    let has_update = match (&latest, &current_version) {
        (Some(latest_version), Some(current)) => latest_version.version != *current,
        (Some(_), None) => true,
        _ => false,
    };

    Ok(Json(LatestVersionResponse {
        has_update,
        current_version,
        version: latest.map(|model| db_app_version_to_api(&model)),
    }))
}

#[derive(Debug, Deserialize)]
pub struct VersionDownloadParams {
    pub id: Uuid,
    pub expires_in_seconds: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct VersionDownloadResponse {
    pub success: bool,
    pub message: String,
    pub download_url: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct HotUpdateDownloadParams {
    pub id: Uuid,
    pub expires_in_seconds: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct HotUpdateDownloadResponse {
    pub success: bool,
    pub message: String,
    pub download_url: Option<String>,
}

pub async fn download_version(
    State(state): State<AppState>,
    Query(params): Query<VersionDownloadParams>,
) -> Result<Json<VersionDownloadResponse>, AppError> {
    let store = VersionStore::new(state.database.clone());
    let version = store
        .get_version(params.id)
        .await?
        .ok_or_else(|| version_not_found_error("version.not_found"))?;

    let download_url = resolve_download_url(
        &state,
        &version.download_key,
        version.download_url.as_ref(),
        params.expires_in_seconds,
    )
    .await?;

    Ok(Json(VersionDownloadResponse {
        success: true,
        message: "生成下载链接成功".to_string(),
        download_url: Some(download_url),
    }))
}

pub async fn download_hot_update(
    State(state): State<AppState>,
    Query(params): Query<HotUpdateDownloadParams>,
) -> Result<Json<HotUpdateDownloadResponse>, AppError> {
    let store = VersionStore::new(state.database.clone());
    let patch = store
        .get_hot_update(params.id)
        .await?
        .ok_or_else(|| version_not_found_error("version.patch_not_found"))?;

    let signed_url = resolve_download_url(
        &state,
        &patch.download_key,
        patch.download_url.as_ref(),
        params.expires_in_seconds,
    )
    .await?;

    Ok(Json(HotUpdateDownloadResponse {
        success: true,
        message: "生成补丁下载链接成功".to_string(),
        download_url: Some(signed_url),
    }))
}

pub async fn create_hot_update(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<CreateHotUpdateRequest>,
) -> Result<Json<crate::models::HotUpdateInfo>, AppError> {
    ensure_rollout_percentage(req.rollout_percentage)?;
    if req.channel.trim().is_empty() {
        return Err(AppError::ValidationError("channel 不能为空".to_string()));
    }

    let platform = Platform::from_str(req.platform.trim()).ok_or_else(|| {
        AppError::ValidationError(format!(
            "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
            req.platform
        ))
    })?;
    let app_version_id = Uuid::parse_str(req.app_version_id.trim())
        .map_err(|_| AppError::ValidationError("无效的 app_version_id".to_string()))?;

    let store = VersionStore::new(state.database.clone());
    let base_version = store
        .get_version(app_version_id)
        .await?
        .ok_or_else(|| AppError::ValidationError("绑定的整包版本不存在".to_string()))?;
    if base_version.platform != platform {
        return Err(AppError::ValidationError(
            "热更新平台必须与整包版本一致".to_string(),
        ));
    }

    let operator = Some(Uuid::parse_str(&claims.sub).unwrap_or(Uuid::nil()));
    let mut insert = api_create_hot_update_to_db(&req, operator)?;
    insert.platform = platform;
    insert.app_version_id = base_version.id;
    let created = store.create_hot_update(&insert).await?;

    // 标记热更新补丁文件已上传完成（如果之前通过直传签名创建了记录）
    if !req.download_key.trim().is_empty() {
        let provider = load_default_storage_provider(&state).await?;
        let storage_service = storage::create_storage_service(&provider)?;
        match storage_service.head_object(req.download_key.trim()).await {
            Ok(head) => {
                if let Some(expected_size) = req.file_size {
                    if let Some(actual_size) = head.content_length {
                        if actual_size != expected_size as u64 {
                            return Err(AppError::ValidationError(format!(
                                "补丁大小校验失败：期望 {} 字节，实际 {} 字节",
                                expected_size, actual_size
                            )));
                        }
                    }
                }
            }
            Err(AppError::NotFound(_)) => {
                return Err(AppError::ValidationError(
                    "对象存储中未找到补丁，请先完成上传".to_string(),
                ));
            }
            Err(AppError::ValidationError(_)) => {
                if !storage_service.file_exists(req.download_key.trim()).await? {
                    return Err(AppError::ValidationError(
                        "对象存储中未找到补丁，请先完成上传".to_string(),
                    ));
                }
            }
            Err(e) => return Err(e),
        }
        let upload_store = FileUploadStore::new(state.database.clone());
        let _ = upload_store
            .mark_completed_by_key(&provider.id, req.download_key.trim())
            .await
            .map_err(AppError::from)?;

        // 写入内容审核任务（异步队列；违规会删除对象并记录原因）
        let record = upload_store
            .get_by_key(&provider.id, req.download_key.trim())
            .await
            .map_err(AppError::from)?;
        let audit_store = FileUploadAuditStore::new(state.database.clone());
        let content_type = record.as_ref().and_then(|r| r.content_type.as_deref());
        let file_size = record.as_ref().and_then(|r| r.file_size).or(req.file_size);
        let _ = audit_store
            .upsert_task(
                &provider.id,
                req.download_key.trim(),
                "hot_update",
                "document",
                content_type,
                file_size,
            )
            .await
            .map_err(AppError::from)?;
    }

    Ok(Json(db_hot_update_to_api(&created)))
}

pub async fn update_hot_update(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<String>,
    Json(req): Json<UpdateHotUpdateRequest>,
) -> Result<Json<crate::models::HotUpdateInfo>, AppError> {
    let hot_update_id =
        Uuid::parse_str(&id).map_err(|_| AppError::ValidationError("无效的补丁 ID".to_string()))?;
    if let Some(pct) = req.rollout_percentage {
        ensure_rollout_percentage(pct)?;
    }
    if let Some(channel) = &req.channel {
        if channel.trim().is_empty() {
            return Err(AppError::ValidationError("channel 不能为空".to_string()));
        }
    }
    if let Some(download_key) = &req.download_key {
        if download_key.trim().is_empty() {
            return Err(AppError::ValidationError(
                "download_key 不能为空".to_string(),
            ));
        }
    }

    let operator = Some(Uuid::parse_str(&claims.sub).unwrap_or(Uuid::nil()));
    let update = api_update_hot_update_to_db(&req, operator);
    let store = VersionStore::new(state.database.clone());
    let updated = store
        .update_hot_update(hot_update_id, &update)
        .await?
        .ok_or_else(|| AppError::NotFound("补丁不存在".to_string()))?;

    // 若更新了 download_key，则同步标记 file_upload_records 完成并写入审核任务
    if let Some(download_key) = req.download_key.as_deref() {
        let download_key = download_key.trim();
        if !download_key.is_empty() {
            let provider = load_default_storage_provider(&state).await?;
            let storage_service = storage::create_storage_service(&provider)?;
            match storage_service.head_object(download_key).await {
                Ok(head) => {
                    if let Some(expected_size) = req.file_size {
                        if let Some(actual_size) = head.content_length {
                            if actual_size != expected_size as u64 {
                                return Err(AppError::ValidationError(format!(
                                    "补丁大小校验失败：期望 {} 字节，实际 {} 字节",
                                    expected_size, actual_size
                                )));
                            }
                        }
                    }
                }
                Err(AppError::NotFound(_)) => {
                    return Err(AppError::ValidationError(
                        "对象存储中未找到补丁，请先完成上传".to_string(),
                    ));
                }
                Err(AppError::ValidationError(_)) => {
                    if !storage_service.file_exists(download_key).await? {
                        return Err(AppError::ValidationError(
                            "对象存储中未找到补丁，请先完成上传".to_string(),
                        ));
                    }
                }
                Err(e) => return Err(e),
            }

            let upload_store = FileUploadStore::new(state.database.clone());
            let _ = upload_store
                .mark_completed_by_key(&provider.id, download_key)
                .await
                .map_err(AppError::from)?;

            let record = upload_store
                .get_by_key(&provider.id, download_key)
                .await
                .map_err(AppError::from)?;
            let audit_store = FileUploadAuditStore::new(state.database.clone());
            let content_type = record.as_ref().and_then(|r| r.content_type.as_deref());
            let file_size = record.as_ref().and_then(|r| r.file_size).or(req.file_size);
            let _ = audit_store
                .upsert_task(
                    &provider.id,
                    download_key,
                    "hot_update",
                    "document",
                    content_type,
                    file_size,
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    Ok(Json(db_hot_update_to_api(&updated)))
}

pub async fn list_hot_updates(
    State(state): State<AppState>,
    Query(query): Query<ListHotUpdatesQuery>,
) -> Result<Json<HotUpdateListResponse>, AppError> {
    let platform = query
        .platform
        .as_deref()
        .map(|value| {
            Platform::from_str(value.trim()).ok_or_else(|| {
                AppError::ValidationError(format!(
                    "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
                    value
                ))
            })
        })
        .transpose()?;
    let channel_trimmed = query
        .channel
        .as_deref()
        .map(|c| c.trim())
        .filter(|c| !c.is_empty());

    let limit = query.limit.clamp(1, 100);
    let offset = query.offset.max(0);

    let store = VersionStore::new(state.database.clone());
    let items = store
        .list_hot_updates(platform, channel_trimmed, limit, offset)
        .await?;
    let total = store.count_hot_updates(platform, channel_trimmed).await?;

    Ok(Json(HotUpdateListResponse {
        total,
        items: db_hot_updates_to_api_list(&items),
    }))
}

pub async fn get_hot_update(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<crate::models::HotUpdateInfo>, AppError> {
    let hot_update_id =
        Uuid::parse_str(&id).map_err(|_| AppError::ValidationError("无效的补丁 ID".to_string()))?;
    let store = VersionStore::new(state.database.clone());
    let patch = store
        .get_hot_update(hot_update_id)
        .await?
        .ok_or_else(|| AppError::NotFound("补丁不存在".to_string()))?;
    Ok(Json(db_hot_update_to_api(&patch)))
}

pub async fn delete_hot_update(
    State(state): State<AppState>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let hot_update_id =
        Uuid::parse_str(&id).map_err(|_| AppError::ValidationError("无效的补丁 ID".to_string()))?;
    let store = VersionStore::new(state.database.clone());
    let deleted = store.delete_hot_update(hot_update_id).await?;
    if !deleted {
        return Err(AppError::NotFound("补丁不存在".to_string()));
    }
    Ok(Json(serde_json::json!({ "success": true })))
}

pub async fn activate_hot_update(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<String>,
) -> Result<Json<crate::models::HotUpdateInfo>, AppError> {
    toggle_hot_update(state, claims, id, true).await
}

pub async fn deactivate_hot_update(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(id): Path<String>,
) -> Result<Json<crate::models::HotUpdateInfo>, AppError> {
    toggle_hot_update(state, claims, id, false).await
}

async fn toggle_hot_update(
    state: AppState,
    claims: Claims,
    id: String,
    active: bool,
) -> Result<Json<crate::models::HotUpdateInfo>, AppError> {
    let hot_update_id =
        Uuid::parse_str(&id).map_err(|_| AppError::ValidationError("无效的补丁 ID".to_string()))?;
    let operator = Some(Uuid::parse_str(&claims.sub).unwrap_or(Uuid::nil()));
    let update = HotUpdateUpdate {
        is_active: Some(active),
        operator,
        ..Default::default()
    };
    let store = VersionStore::new(state.database.clone());
    let updated = store
        .update_hot_update(hot_update_id, &update)
        .await?
        .ok_or_else(|| AppError::NotFound("补丁不存在".to_string()))?;
    Ok(Json(db_hot_update_to_api(&updated)))
}

pub async fn latest_hot_update(
    State(state): State<AppState>,
    Query(query): Query<HotUpdateQuery>,
) -> Result<Json<HotUpdateResponse>, AppError> {
    let platform = parse_required_version_platform(&query.platform)?;
    let channel = query.channel.trim();
    if channel.is_empty() {
        return Err(version_validation_error("version.channel_required"));
    }
    if query.current_version.trim().is_empty() {
        return Err(version_validation_error("version.current_version_required"));
    }

    let store = VersionStore::new(state.database.clone());
    let patches = store
        .find_active_hot_updates(platform, channel, query.current_version.trim())
        .await?;

    let current_patch = query.current_patch_version.as_deref();
    let client_id = query.client_id.as_deref();
    let selected = patches.into_iter().find(|patch| {
        if let Some(current) = current_patch {
            if patch.patch_version == current {
                return false;
            }
        }
        is_rollout_hit(&patch, client_id)
    });

    Ok(Json(HotUpdateResponse {
        has_update: selected.is_some(),
        current_patch_version: query.current_patch_version.clone(),
        patch: selected.as_ref().map(db_hot_update_to_api),
    }))
}

pub async fn report_hot_update_event(
    State(state): State<AppState>,
    Json(req): Json<HotUpdateEventReport>,
) -> Result<Json<serde_json::Value>, AppError> {
    let platform = parse_required_version_platform(&req.platform)?;

    let base_version = req.base_version.trim();
    if base_version.is_empty() {
        return Err(version_validation_error("version.base_version_required"));
    }
    let patch_version = req.patch_version.trim();
    if patch_version.is_empty() {
        return Err(version_validation_error("version.patch_version_required"));
    }
    let event_type = req.event_type.trim();
    if event_type.is_empty() {
        return Err(version_validation_error("version.event_type_required"));
    }
    const ALLOWED_EVENTS: &[&str] = &[
        "download_success",
        "download_failed",
        "apply_success",
        "apply_failed",
        "rollback",
    ];
    if !ALLOWED_EVENTS.contains(&event_type) {
        return Err(version_validation_error_with_params(
            "version.event_type_unsupported",
            BTreeMap::from([("event_type".to_string(), event_type.to_string())]),
        ));
    }

    let store = VersionStore::new(state.database.clone());
    let insert = HotUpdateEventInsert {
        platform,
        channel: req
            .channel
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
        base_version: base_version.to_string(),
        patch_version: patch_version.to_string(),
        event_type: event_type.to_string(),
        client_id: req
            .client_id
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
        message: req
            .message
            .as_deref()
            .map(|m| m.trim().to_string())
            .filter(|m| !m.is_empty()),
        // 新增的详细字段
        client_type: req
            .client_type
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
        os_version: req
            .os_version
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
        os_arch: req
            .os_arch
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
        app_arch: req
            .app_arch
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
        build_number: req.build_number,
        trigger_source: req
            .trigger_source
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
        network_type: req
            .network_type
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
        device_info: req
            .device_info
            .as_deref()
            .map(|c| c.trim().to_string())
            .filter(|c| !c.is_empty()),
    };
    store.insert_hot_update_event(&insert).await?;

    Ok(Json(json!({ "success": true })))
}

pub async fn list_hot_update_events(
    State(state): State<AppState>,
    Query(query): Query<HotUpdateEventListQuery>,
) -> Result<Json<HotUpdateEventListResponse>, AppError> {
    let platform = if let Some(value) = query.platform.as_deref() {
        Some(parse_required_version_platform(value)?)
    } else {
        None
    };

    let start_time = parse_optional_timestamp(query.start_time.as_deref())?;
    let end_time = parse_optional_timestamp(query.end_time.as_deref())?;
    let limit = query.limit.clamp(1, 100);
    let offset = query.offset.max(0);

    let params = crate::database::version_store::HotUpdateEventQueryParams {
        platform,
        channel: query
            .channel
            .as_deref()
            .map(str::trim)
            .filter(|c| !c.is_empty()),
        event_type: query
            .event_type
            .as_deref()
            .map(str::trim)
            .filter(|c| !c.is_empty()),
        start_time,
        end_time,
        limit,
        offset,
    };

    let store = VersionStore::new(state.database.clone());
    let events = store.list_hot_update_events(&params).await?;
    let total = store.count_hot_update_events(&params).await?;

    Ok(Json(HotUpdateEventListResponse {
        total,
        items: db_hot_update_events_to_api_list(&events),
    }))
}

fn parse_optional_timestamp(value: Option<&str>) -> Result<Option<DateTime<Utc>>, AppError> {
    if let Some(text) = value {
        if text.trim().is_empty() {
            return Ok(None);
        }
        let parsed = DateTime::parse_from_rfc3339(text.trim())
            .map_err(|_| version_validation_error("version.timestamp_rfc3339_invalid"))?;
        Ok(Some(parsed.with_timezone(&Utc)))
    } else {
        Ok(None)
    }
}

fn validate_version_payload(req: &CreateAppVersionRequest) -> Result<(), AppError> {
    if req.platform.trim().is_empty() {
        return Err(version_validation_error("version.platform_required"));
    }
    if req.version.trim().is_empty() {
        return Err(version_validation_error("version.version_required"));
    }
    let has_download_key = !req.download_key.trim().is_empty();
    let has_download_url = req
        .download_url
        .as_ref()
        .is_some_and(|v| !v.trim().is_empty());
    let has_app_store_url = req
        .app_store_url
        .as_ref()
        .is_some_and(|v| !v.trim().is_empty());

    if !has_download_key && !has_download_url && !has_app_store_url {
        return Err(version_validation_error("version.download_source_required"));
    }
    Ok(())
}

pub async fn download_latest_version(
    State(state): State<AppState>,
    Query(params): Query<LatestVersionDownloadParams>,
) -> Result<Json<LatestVersionDownloadResponse>, AppError> {
    let platform = parse_required_version_platform(&params.platform)?;

    let channel = params.channel.trim();
    if channel.is_empty() {
        return Err(version_validation_error("version.channel_required"));
    }

    let store = VersionStore::new(state.database.clone());
    let latest = store
        .find_latest_active(platform, channel)
        .await?
        .ok_or_else(|| version_not_found_error("version.no_available_release"))?;

    let download_url = resolve_download_url(
        &state,
        &latest.download_key,
        latest.download_url.as_ref(),
        params.expires_in_seconds,
    )
    .await?;

    Ok(Json(LatestVersionDownloadResponse {
        success: true,
        message: "生成下载链接成功".to_string(),
        version: Some(db_app_version_to_api(&latest)),
        download_url: Some(download_url),
    }))
}

async fn resolve_download_url(
    state: &AppState,
    download_key: &str,
    explicit_download_url: Option<&String>,
    expires_in_seconds: Option<u32>,
) -> Result<String, AppError> {
    if let Some(url) = explicit_download_url.and_then(|url| (!url.trim().is_empty()).then_some(url))
    {
        return Ok(url.clone());
    }

    if download_key.trim().is_empty() {
        return Err(version_validation_error("version.download_info_missing"));
    }

    let provider = load_default_storage_provider(state).await?;
    let storage_service = storage::create_storage_service(&provider)?;
    let download_url = storage_service
        .generate_download_url(download_key, expires_in_seconds)
        .await?;
    Ok(download_url)
}

async fn load_default_storage_provider(
    state: &AppState,
) -> Result<crate::database::models::StorageProvider, AppError> {
    let store = StorageProviderStore::new(state.database.clone());
    let provider = store
        .get_default_provider()
        .await?
        .ok_or_else(|| version_not_found_error("version.default_storage_provider_not_found"))?;

    if !provider.is_active {
        return Err(version_validation_error(
            "version.default_storage_provider_inactive",
        ));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Err(version_validation_error_with_params(
            "version.default_storage_provider_unsupported",
            BTreeMap::from([(
                "provider_type".to_string(),
                format!("{:?}", provider.provider_type),
            )]),
        ));
    }

    Ok(provider)
}

fn build_release_object_key(platform: &str, channel: &str, filename: Option<&str>) -> String {
    let ext = filename
        .and_then(|name| name.rsplit_once('.'))
        .map(|(_, ext)| ext)
        .unwrap_or("pkg");
    let timestamp = Utc::now().format("%Y%m%d%H%M%S");
    let random = Uuid::new_v4().simple().to_string();
    format!(
        "releases/{}/{}/{}-{}.{}",
        platform,
        channel,
        timestamp,
        &random[..8],
        ext
    )
}

fn ensure_rollout_percentage(value: i32) -> Result<(), AppError> {
    if !(0..=100).contains(&value) {
        return Err(AppError::ValidationError(
            "rollout_percentage 必须在 0-100 之间".to_string(),
        ));
    }
    Ok(())
}

fn is_rollout_hit(patch: &crate::database::models::HotUpdate, client_id: Option<&str>) -> bool {
    let pct = patch.rollout_percentage.clamp(0, 100);
    if pct >= 100 {
        return true;
    }
    if pct <= 0 {
        return false;
    }
    if let Some(id) = client_id {
        let mut hasher = DefaultHasher::new();
        hasher.write(id.as_bytes());
        hasher.write(patch.id.as_bytes());
        let bucket = (hasher.finish() % 100) as i32;
        bucket < pct
    } else {
        false
    }
}
