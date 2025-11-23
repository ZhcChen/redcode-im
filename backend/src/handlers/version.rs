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
use std::collections::hash_map::DefaultHasher;
use std::hash::Hasher;
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct VersionUploadSignatureRequest {
    pub platform: String,
    #[serde(default = "default_channel")]
    pub channel: String,
    pub filename: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct VersionUploadSignatureResponse {
    pub success: bool,
    pub message: String,
    pub key: Option<String>,
    pub signature: Option<DirectUploadSignature>,
}

#[derive(Debug, Serialize)]
pub struct AppVersionListResponse {
    pub total: i64,
    pub items: Vec<crate::models::AppVersionInfo>,
}

fn default_channel() -> String {
    "stable".to_string()
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
    let key =
        build_release_object_key(&req.platform, req.channel.as_str(), req.filename.as_deref());

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;
    let signature = storage_service
        .generate_direct_upload_signature(&key, None)
        .await?;

    Ok(Json(VersionUploadSignatureResponse {
        success: true,
        message: "生成安装包直传签名成功".to_string(),
        key: Some(key),
        signature: Some(signature),
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

    Ok(Json(db_app_version_to_api(&updated)))
}

pub async fn list_app_versions(
    State(state): State<AppState>,
    Query(query): Query<ListAppVersionsQuery>,
) -> Result<Json<AppVersionListResponse>, AppError> {
    let store = VersionStore::new(state.database.clone());
    let platform_str = query.platform.trim();
    if platform_str.is_empty() {
        return Err(AppError::ValidationError("platform 必填".to_string()));
    }

    let platform = Platform::from_str(platform_str).ok_or_else(|| {
        AppError::ValidationError(format!(
            "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
            platform_str
        ))
    })?;

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
        .ok_or_else(|| AppError::NotFound("版本不存在".to_string()))?;

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
        return Err(AppError::NotFound("版本不存在".to_string()));
    }

    Ok(Json(serde_json::json!({
        "success": true,
    })))
}

pub async fn latest_version(
    State(state): State<AppState>,
    Query(query): Query<LatestVersionQuery>,
) -> Result<Json<LatestVersionResponse>, AppError> {
    let platform_str = query.platform.trim();
    if platform_str.is_empty() {
        return Err(AppError::ValidationError("platform 必填".to_string()));
    }

    let platform = Platform::from_str(platform_str).ok_or_else(|| {
        AppError::ValidationError(format!(
            "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
            platform_str
        ))
    })?;

    let channel = query.channel.trim();
    if channel.is_empty() {
        return Err(AppError::ValidationError("channel 必填".to_string()));
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
        .ok_or_else(|| AppError::NotFound("版本不存在".to_string()))?;

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
        .ok_or_else(|| AppError::NotFound("补丁不存在".to_string()))?;

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
    let platform = Platform::from_str(query.platform.trim()).ok_or_else(|| {
        AppError::ValidationError(format!(
            "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
            query.platform
        ))
    })?;
    let channel = query.channel.trim();
    if channel.is_empty() {
        return Err(AppError::ValidationError("channel 不能为空".to_string()));
    }
    if query.current_version.trim().is_empty() {
        return Err(AppError::ValidationError(
            "current_version 不能为空".to_string(),
        ));
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
    let platform = Platform::from_str(req.platform.trim()).ok_or_else(|| {
        AppError::ValidationError(format!(
            "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
            req.platform
        ))
    })?;

    let base_version = req.base_version.trim();
    if base_version.is_empty() {
        return Err(AppError::ValidationError(
            "base_version 不能为空".to_string(),
        ));
    }
    let patch_version = req.patch_version.trim();
    if patch_version.is_empty() {
        return Err(AppError::ValidationError(
            "patch_version 不能为空".to_string(),
        ));
    }
    let event_type = req.event_type.trim();
    if event_type.is_empty() {
        return Err(AppError::ValidationError("event_type 不能为空".to_string()));
    }
    const ALLOWED_EVENTS: &[&str] = &[
        "download_success",
        "download_failed",
        "apply_success",
        "apply_failed",
        "rollback",
    ];
    if !ALLOWED_EVENTS.contains(&event_type) {
        return Err(AppError::ValidationError(format!(
            "不支持的事件类型: {}",
            event_type
        )));
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
        Some(Platform::from_str(value).ok_or_else(|| {
            AppError::ValidationError(format!(
                "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
                value
            ))
        })?)
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
            .map_err(|_| AppError::ValidationError("时间格式必须为 RFC3339".to_string()))?;
        Ok(Some(parsed.with_timezone(&Utc)))
    } else {
        Ok(None)
    }
}

fn validate_version_payload(req: &CreateAppVersionRequest) -> Result<(), AppError> {
    if req.platform.trim().is_empty() {
        return Err(AppError::ValidationError("platform 不能为空".to_string()));
    }
    if req.version.trim().is_empty() {
        return Err(AppError::ValidationError("version 不能为空".to_string()));
    }
    if req.download_key.trim().is_empty() {
        return Err(AppError::ValidationError(
            "download_key 不能为空".to_string(),
        ));
    }
    Ok(())
}

pub async fn download_latest_version(
    State(state): State<AppState>,
    Query(params): Query<LatestVersionDownloadParams>,
) -> Result<Json<LatestVersionDownloadResponse>, AppError> {
    let platform = Platform::from_str(params.platform.trim()).ok_or_else(|| {
        AppError::ValidationError(format!(
            "不支持的平台: {}。支持的平台: windows, macos, ios, android, linux",
            params.platform
        ))
    })?;

    let channel = params.channel.trim();
    if channel.is_empty() {
        return Err(AppError::ValidationError("channel 不能为空".to_string()));
    }

    let store = VersionStore::new(state.database.clone());
    let latest = store
        .find_latest_active(platform, channel)
        .await?
        .ok_or_else(|| AppError::NotFound("暂无可用版本".to_string()))?;

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
    if let Some(url) = explicit_download_url {
        return Ok(url.clone());
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
        .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?;

    if !provider.is_active {
        return Err(AppError::ValidationError(
            "默认文件上传提供商未启用".to_string(),
        ));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Err(AppError::ValidationError(format!(
            "不支持的提供商类型: {:?}",
            provider.provider_type
        )));
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
