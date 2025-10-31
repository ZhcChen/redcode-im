use axum::{
    extract::{Extension, Path, Query, State},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::models::{
    CaptchaSettingRecord, StorageProvider, StorageProviderType, UserStatus,
};
use crate::database::settings_store::SettingsStore;
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::AppState;
use tracing::error;

#[derive(Debug, Serialize)]
pub struct SystemStats {
    pub total_users: i64,
    pub online_users: i64,
    pub total_rooms: i64,
    pub active_rooms: i64,
    pub total_messages: i64,
    pub today_messages: i64,
    pub system_load: f64,
    pub memory_usage: f64,
    pub storage_usage: f64,
}

#[derive(Debug, Serialize)]
pub struct SystemMonitor {
    pub cpu: f64,
    pub memory: f64,
    pub disk: f64,
    pub network_in: f64,
    pub network_out: f64,
    pub connections: i64,
}

#[derive(Debug, Deserialize)]
pub struct PaginationParams {
    #[serde(default = "default_page")]
    pub page: usize,
    #[serde(default = "default_page_size", alias = "pageSize")]
    pub page_size: usize,
}

fn default_page() -> usize {
    1
}

fn default_page_size() -> usize {
    20
}

#[derive(Debug, Deserialize)]
pub struct UserListParams {
    #[serde(default = "default_page")]
    pub page: usize,
    #[serde(default = "default_page_size", alias = "pageSize")]
    pub page_size: usize,
    pub status: Option<String>,
    pub username: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct AdminUser {
    pub id: String,
    pub username: String,
    pub email: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub status: String,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct UserListResponse {
    pub users: Vec<AdminUser>,
    pub total: usize,
    pub page: usize,
    pub page_size: usize,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserStatusRequest {
    pub status: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CaptchaSetting {
    pub enabled: bool,
    pub captcha_code: String,
    pub description: String,
    pub updated_at: String,
}

impl From<CaptchaSettingRecord> for CaptchaSetting {
    fn from(record: CaptchaSettingRecord) -> Self {
        Self {
            enabled: record.enabled,
            captcha_code: record.captcha_code,
            description: record.description,
            updated_at: record.updated_at.to_rfc3339(),
        }
    }
}

pub async fn get_dashboard_stats(
    State(_state): State<AppState>,
) -> Result<Json<SystemStats>, StatusCode> {
    // TODO: 实现真实的统计数据计算
    let stats = SystemStats {
        total_users: 1250,
        online_users: 324,
        total_rooms: 156,
        active_rooms: 42,
        total_messages: 54280,
        today_messages: 1280,
        system_load: 0.45,
        memory_usage: 0.62,
        storage_usage: 0.28,
    };

    Ok(Json(stats))
}

pub async fn get_system_monitor(
    State(_state): State<AppState>,
) -> Result<Json<SystemMonitor>, StatusCode> {
    // TODO: 实现真实的系统监控数据
    let monitor = SystemMonitor {
        cpu: 0.35,
        memory: 0.62,
        disk: 0.28,
        network_in: 512000.0,
        network_out: 256000.0,
        connections: 68,
    };

    Ok(Json(monitor))
}

pub async fn get_user_list(
    State(state): State<AppState>,
    Query(params): Query<UserListParams>,
) -> Result<Json<UserListResponse>, StatusCode> {
    let store = UserStore::new(state.database.clone());

    let page = params.page.max(1);
    let page_size = params.page_size.max(1).min(100);

    let status_param = params
        .status
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let status = match status_param {
        Some("active") => Some(UserStatus::Active),
        Some("inactive") => Some(UserStatus::Inactive),
        Some("banned") => Some(UserStatus::Banned),
        None => None,
        Some(_) => return Err(StatusCode::BAD_REQUEST),
    };

    let username = params
        .username
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let (users, total) = store
        .list_users(page, page_size, status, username)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let admins = users
        .into_iter()
        .map(|user| AdminUser {
            id: user.id.to_string(),
            username: user.username,
            email: user.email,
            nickname: user.nickname,
            avatar_url: user.avatar_url,
            status: user.status.to_string(),
            created_at: user.created_at.to_rfc3339(),
            updated_at: user.updated_at.to_rfc3339(),
            deleted_at: user.deleted_at.map(|dt| dt.to_rfc3339()),
        })
        .collect();

    Ok(Json(UserListResponse {
        users: admins,
        total: total as usize,
        page,
        page_size,
    }))
}

pub async fn update_user_status(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
    Json(req): Json<UpdateUserStatusRequest>,
) -> Result<(), StatusCode> {
    let user_id = Uuid::parse_str(&user_id).map_err(|_| StatusCode::BAD_REQUEST)?;

    let status = match req.status.as_str() {
        "active" => UserStatus::Active,
        "inactive" => UserStatus::Inactive,
        "banned" => UserStatus::Banned,
        _ => return Err(StatusCode::BAD_REQUEST),
    };

    let store = UserStore::new(state.database.clone());

    let updated = store
        .update_user_status(&user_id, status)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if !updated {
        return Err(StatusCode::NOT_FOUND);
    }

    Ok(())
}

pub async fn get_captcha_setting(
    State(state): State<AppState>,
) -> Result<Json<CaptchaSetting>, StatusCode> {
    let store = SettingsStore::new(state.database.clone());
    let setting = store
        .get_captcha_setting()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(setting.into()))
}

#[derive(Debug, Deserialize)]
pub struct UpdateCaptchaSettingRequest {
    pub enabled: Option<bool>,
    pub captcha_code: Option<String>,
    pub description: Option<String>,
}

pub async fn update_captcha_setting(
    State(state): State<AppState>,
    Json(req): Json<UpdateCaptchaSettingRequest>,
) -> Result<Json<CaptchaSetting>, StatusCode> {
    let store = SettingsStore::new(state.database.clone());

    let enabled = req.enabled.unwrap_or(false);
    let captcha_code = req.captcha_code.unwrap_or_default().trim().to_string();
    let description = req.description.unwrap_or_default();

    let setting = store
        .upsert_captcha_setting(enabled, &captcha_code, &description, None)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(setting.into()))
}

pub async fn is_universal_captcha_code(state: &AppState, input: &str) -> bool {
    if input.trim().is_empty() {
        return false;
    }

    let store = SettingsStore::new(state.database.clone());
    match store.is_universal_captcha_code(input).await {
        Ok(result) => result,
        Err(err) => {
            error!(?err, "读取通用验证码配置失败");
            false
        }
    }
}

// ========== 文件上传提供商管理 API ==========

#[derive(Debug, Serialize)]
pub struct StorageProviderResponse {
    pub id: String,
    pub provider_type: String,
    pub name: String,
    pub secret_id: String,
    pub secret_key: String,
    pub region: String,
    pub endpoint: String,
    pub bucket_name: Option<String>,
    pub is_active: bool,
    pub is_default: bool,
    pub description: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub updated_by: Option<String>,
}

impl From<StorageProvider> for StorageProviderResponse {
    fn from(provider: StorageProvider) -> Self {
        Self {
            id: provider.id.to_string(),
            provider_type: provider.provider_type.to_string(),
            name: provider.name,
            secret_id: provider.secret_id,
            secret_key: provider.secret_key,
            region: provider.region,
            endpoint: provider.endpoint,
            bucket_name: provider.bucket_name,
            is_active: provider.is_active,
            is_default: provider.is_default,
            description: provider.description,
            created_at: provider.created_at.to_rfc3339(),
            updated_at: provider.updated_at.to_rfc3339(),
            updated_by: provider.updated_by.map(|u| u.to_string()),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct StorageProviderListResponse {
    pub providers: Vec<StorageProviderResponse>,
}

/// 获取所有文件上传提供商配置
pub async fn list_storage_providers(
    State(state): State<AppState>,
) -> Result<Json<StorageProviderListResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());
    let providers = store.list_providers().await?;

    let responses: Vec<StorageProviderResponse> = providers.into_iter().map(Into::into).collect();

    Ok(Json(StorageProviderListResponse {
        providers: responses,
    }))
}

#[derive(Debug, Deserialize)]
pub struct CreateStorageProviderRequest {
    pub provider_type: String,
    pub name: String,
    pub secret_id: String,
    pub secret_key: String,
    pub region: String,
    pub endpoint: String,
    pub bucket_name: Option<String>,
    pub is_active: Option<bool>,
    pub is_default: Option<bool>,
    pub description: Option<String>,
}

/// 创建文件上传提供商配置
pub async fn create_storage_provider(
    State(state): State<AppState>,
    Extension(claims): Extension<crate::models::Claims>,
    Json(req): Json<CreateStorageProviderRequest>,
) -> Result<Json<StorageProviderResponse>, AppError> {
    // 验证必填字段
    if req.name.trim().is_empty() {
        return Err(AppError::ValidationError("提供商名称不能为空".to_string()));
    }
    if req.secret_id.trim().is_empty() {
        return Err(AppError::ValidationError("密钥ID不能为空".to_string()));
    }
    if req.secret_key.trim().is_empty() {
        return Err(AppError::ValidationError("密钥Key不能为空".to_string()));
    }
    if req.region.trim().is_empty() {
        return Err(AppError::ValidationError("地域不能为空".to_string()));
    }
    if req.endpoint.trim().is_empty() {
        return Err(AppError::ValidationError("端点域名不能为空".to_string()));
    }

    // 解析提供商类型
    let provider_type = match req.provider_type.as_str() {
        "tencent_cos" => StorageProviderType::TencentCos,
        "aliyun_oss" => StorageProviderType::AliyunOss,
        "aws_s3" => StorageProviderType::AwsS3,
        "minio" => StorageProviderType::Minio,
        "unknown" => StorageProviderType::Unknown,
        _ => {
            return Err(AppError::ValidationError(format!(
                "不支持的提供商类型: {}",
                req.provider_type
            )));
        }
    };

    let updated_by = Uuid::parse_str(&claims.sub).ok();

    let store = StorageProviderStore::new(state.database.clone());
    let provider = store
        .create_provider(
            provider_type,
            req.name.trim(),
            req.secret_id.trim(),
            req.secret_key.trim(),
            req.region.trim(),
            req.endpoint.trim(),
            req.bucket_name.as_deref(),
            req.is_active.unwrap_or(false),
            req.is_default.unwrap_or(false),
            req.description.as_deref(),
            updated_by,
        )
        .await?;

    Ok(Json(provider.into()))
}

#[derive(Debug, Deserialize)]
pub struct UpdateStorageProviderRequest {
    pub provider_type: Option<String>,
    pub name: Option<String>,
    pub secret_id: Option<String>,
    pub secret_key: Option<String>,
    pub region: Option<String>,
    pub endpoint: Option<String>,
    pub bucket_name: Option<Option<String>>,
    pub is_active: Option<bool>,
    pub is_default: Option<bool>,
    pub description: Option<Option<String>>,
}

/// 更新文件上传提供商配置
pub async fn update_storage_provider(
    State(state): State<AppState>,
    Path(provider_id): Path<String>,
    Extension(claims): Extension<crate::models::Claims>,
    Json(req): Json<UpdateStorageProviderRequest>,
) -> Result<Json<StorageProviderResponse>, AppError> {
    let provider_id = Uuid::parse_str(&provider_id)
        .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;

    let updated_by = Uuid::parse_str(&claims.sub).ok();

    // 解析提供商类型（如果提供）
    let provider_type = if let Some(ref pt) = req.provider_type {
        match pt.as_str() {
            "tencent_cos" => Some(StorageProviderType::TencentCos),
            "aliyun_oss" => Some(StorageProviderType::AliyunOss),
            "aws_s3" => Some(StorageProviderType::AwsS3),
            "minio" => Some(StorageProviderType::Minio),
            "unknown" => Some(StorageProviderType::Unknown),
            _ => {
                return Err(AppError::ValidationError(format!(
                    "不支持的提供商类型: {}",
                    pt
                )));
            }
        }
    } else {
        None
    };

    let store = StorageProviderStore::new(state.database.clone());
    let provider = store
        .update_provider(
            &provider_id,
            provider_type,
            req.name.as_deref(),
            req.secret_id.as_deref(),
            req.secret_key.as_deref(),
            req.region.as_deref(),
            req.endpoint.as_deref(),
            req.bucket_name.as_ref().map(|x| x.as_deref()),
            req.is_active,
            req.is_default,
            req.description.as_ref().map(|x| x.as_deref()),
            updated_by,
        )
        .await?;

    match provider {
        Some(p) => Ok(Json(p.into())),
        None => Err(AppError::NotFound("提供商配置不存在".to_string())),
    }
}

/// 删除文件上传提供商配置
pub async fn delete_storage_provider(
    State(state): State<AppState>,
    Path(provider_id): Path<String>,
) -> Result<StatusCode, AppError> {
    let provider_id = Uuid::parse_str(&provider_id)
        .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;

    let store = StorageProviderStore::new(state.database.clone());
    let deleted = store.delete_provider(&provider_id).await?;

    if deleted {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err(AppError::NotFound("提供商配置不存在".to_string()))
    }
}

/// 获取默认文件上传提供商配置
pub async fn get_default_storage_provider(
    State(state): State<AppState>,
) -> Result<Json<StorageProviderResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());
    let provider = store.get_default_provider().await?;

    match provider {
        Some(p) => Ok(Json(p.into())),
        None => Err(AppError::NotFound(
            "未找到默认文件上传提供商配置".to_string(),
        )),
    }
}
