use crate::database::models::StorageProviderType;
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::version_store::{version_exists, VersionStore};
use crate::error::AppError;
use crate::models::convert::{
    api_create_version_to_db, api_update_version_to_db, db_app_version_to_api,
    db_versions_to_api_list,
};
use crate::models::{
    Claims, CreateAppVersionRequest, LatestVersionQuery, LatestVersionResponse,
    ListAppVersionsQuery, UpdateAppVersionRequest,
};
use crate::storage;
use crate::storage::DirectUploadSignature;
use crate::AppState;
use axum::{
    extract::{Extension, Path, Query, State},
    Json,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
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

    let platform_trimmed = req.platform.trim();
    let channel_trimmed = req.channel.trim();
    let version_trimmed = req.version.trim();

    if version_exists(
        &state.database,
        platform_trimmed,
        channel_trimmed,
        version_trimmed,
    )
    .await?
    {
        return Err(AppError::ValidationError(
            "该平台该渠道的版本已存在".to_string(),
        ));
    }

    let operator = Some(Uuid::parse_str(&claims.sub).unwrap_or(Uuid::nil()));
    let store = VersionStore::new(state.database.clone());

    let insert = api_create_version_to_db(&req, operator);
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
    let platform = query.platform.trim();
    if platform.is_empty() {
        return Err(AppError::ValidationError("platform 必填".to_string()));
    }

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
    let platform = query.platform.trim();
    if platform.is_empty() {
        return Err(AppError::ValidationError("platform 必填".to_string()));
    }

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

pub async fn download_version(
    State(state): State<AppState>,
    Query(params): Query<VersionDownloadParams>,
) -> Result<Json<VersionDownloadResponse>, AppError> {
    let store = VersionStore::new(state.database.clone());
    let version = store
        .get_version(params.id)
        .await?
        .ok_or_else(|| AppError::NotFound("版本不存在".to_string()))?;

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    let download_url = storage_service
        .generate_download_url(&version.download_key, params.expires_in_seconds)
        .await?;

    Ok(Json(VersionDownloadResponse {
        success: true,
        message: "生成下载链接成功".to_string(),
        download_url: Some(download_url),
    }))
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
