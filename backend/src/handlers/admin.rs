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
use crate::storage;
use crate::AppState;
use chrono::Utc;
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
    
    // 如果是腾讯云 COS 且没有指定 bucket_name，尝试创建一个默认的 bucket
    let mut bucket_name = req.bucket_name.clone();
    if provider_type == StorageProviderType::TencentCos && bucket_name.is_none() {
        // 生成一个默认的 bucket 名称
        let uuid_str = Uuid::new_v4().to_string().replace("-", "");
        let default_bucket_name = format!("redcode-im-{}", &uuid_str[..8]);
        
        // 创建临时的存储服务实例来创建 bucket
        let temp_provider = StorageProvider {
            id: Uuid::new_v4(),
            provider_type: StorageProviderType::TencentCos,
            name: req.name.clone(),
            secret_id: req.secret_id.clone(),
            secret_key: req.secret_key.clone(),
            region: req.region.clone(),
            endpoint: req.endpoint.clone(),
            bucket_name: None,
            is_active: false,
            is_default: false,
            description: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            updated_by: None,
        };
        
        match storage::create_storage_service_without_bucket(&temp_provider) {
            Ok(storage_service) => {
                match storage_service.create_bucket(&default_bucket_name).await {
                    Ok(_) => {
                        bucket_name = Some(default_bucket_name);
                        tracing::info!("自动创建 bucket: {}", bucket_name.as_ref().unwrap());
                    }
                    Err(e) => {
                        tracing::warn!("自动创建 bucket 失败: {}，将使用用户指定的 bucket_name", e);
                        // 继续执行，让用户稍后手动指定 bucket_name
                    }
                }
            }
            Err(e) => {
                tracing::warn!("创建存储服务实例失败: {}，将使用用户指定的 bucket_name", e);
            }
        }
    }
    
    let provider = store
        .create_provider(
            provider_type,
            req.name.trim(),
            req.secret_id.trim(),
            req.secret_key.trim(),
            req.region.trim(),
            req.endpoint.trim(),
            bucket_name.as_deref(),
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

// ========== COS 测试 API ==========

#[derive(Debug, Deserialize)]
pub struct TestCosUploadRequest {
    pub provider_id: Option<String>,
    pub key: String,
    pub content: String,
    pub content_type: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TestCosUploadResponse {
    pub success: bool,
    pub url: Option<String>,
    pub message: String,
}

/// 测试 COS 文件上传
pub async fn test_cos_upload(
    State(state): State<AppState>,
    Json(req): Json<TestCosUploadRequest>,
) -> Result<Json<TestCosUploadResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    // 检查提供商是否启用
    if !provider.is_active {
        return Ok(Json(TestCosUploadResponse {
            success: false,
            url: None,
            message: "提供商未启用".to_string(),
        }));
    }

    // 检查是否为腾讯云 COS
    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosUploadResponse {
            success: false,
            url: None,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    // 创建存储服务
    let storage_service = storage::create_storage_service(&provider)?;

    // 上传文件
    let content_bytes = bytes::Bytes::from(req.content);
    match storage_service
        .upload_file(&req.key, content_bytes, req.content_type.as_deref())
        .await
    {
        Ok(url) => Ok(Json(TestCosUploadResponse {
            success: true,
            url: Some(url),
            message: "上传成功".to_string(),
        })),
        Err(e) => Ok(Json(TestCosUploadResponse {
            success: false,
            url: None,
            message: format!("上传失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestCosDeleteRequest {
    pub provider_id: Option<String>,
    pub key: String,
}

#[derive(Debug, Serialize)]
pub struct TestCosDeleteResponse {
    pub success: bool,
    pub message: String,
}

/// 测试 COS 文件删除
pub async fn test_cos_delete(
    State(state): State<AppState>,
    Json(req): Json<TestCosDeleteRequest>,
) -> Result<Json<TestCosDeleteResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestCosDeleteResponse {
            success: false,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosDeleteResponse {
            success: false,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service.delete_file(&req.key).await {
        Ok(_) => Ok(Json(TestCosDeleteResponse {
            success: true,
            message: "删除成功".to_string(),
        })),
        Err(e) => Ok(Json(TestCosDeleteResponse {
            success: false,
            message: format!("删除失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestCosExistsRequest {
    pub provider_id: Option<String>,
    pub key: String,
}

#[derive(Debug, Serialize)]
pub struct TestCosExistsResponse {
    pub success: bool,
    pub exists: bool,
    pub message: String,
}

/// 测试 COS 文件是否存在
pub async fn test_cos_exists(
    State(state): State<AppState>,
    Json(req): Json<TestCosExistsRequest>,
) -> Result<Json<TestCosExistsResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestCosExistsResponse {
            success: false,
            exists: false,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosExistsResponse {
            success: false,
            exists: false,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service.file_exists(&req.key).await {
        Ok(exists) => Ok(Json(TestCosExistsResponse {
            success: true,
            exists,
            message: if exists {
                "文件存在".to_string()
            } else {
                "文件不存在".to_string()
            },
        })),
        Err(e) => Ok(Json(TestCosExistsResponse {
            success: false,
            exists: false,
            message: format!("检查失败: {}", e),
        })),
    }
}

// ========== Bucket 管理 API ==========

#[derive(Debug, Deserialize)]
pub struct TestCosListBucketsRequest {
    pub provider_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TestCosListBucketsResponse {
    pub success: bool,
    pub buckets: Vec<storage::BucketInfo>,
    pub message: String,
}

/// 测试 COS 获取 bucket 列表
pub async fn test_cos_list_buckets(
    State(state): State<AppState>,
    Json(req): Json<TestCosListBucketsRequest>,
) -> Result<Json<TestCosListBucketsResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestCosListBucketsResponse {
            success: false,
            buckets: Vec::new(),
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosListBucketsResponse {
            success: false,
            buckets: Vec::new(),
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service_without_bucket(&provider)?;

    match storage_service.list_buckets().await {
        Ok(buckets) => Ok(Json(TestCosListBucketsResponse {
            success: true,
            buckets: buckets.clone(),
            message: format!("成功获取 {} 个 bucket", buckets.len()),
        })),
        Err(e) => Ok(Json(TestCosListBucketsResponse {
            success: false,
            buckets: Vec::new(),
            message: format!("获取 bucket 列表失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestCosCreateBucketRequest {
    pub provider_id: Option<String>,
    pub bucket_name: String,
}

#[derive(Debug, Serialize)]
pub struct TestCosCreateBucketResponse {
    pub success: bool,
    pub message: String,
}

/// 测试 COS 创建 bucket
pub async fn test_cos_create_bucket(
    State(state): State<AppState>,
    Json(req): Json<TestCosCreateBucketRequest>,
) -> Result<Json<TestCosCreateBucketResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestCosCreateBucketResponse {
            success: false,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosCreateBucketResponse {
            success: false,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    if req.bucket_name.trim().is_empty() {
        return Ok(Json(TestCosCreateBucketResponse {
            success: false,
            message: "bucket 名称不能为空".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service_without_bucket(&provider)?;

    match storage_service.create_bucket(&req.bucket_name.trim()).await {
        Ok(_) => Ok(Json(TestCosCreateBucketResponse {
            success: true,
            message: format!("成功创建 bucket: {}", req.bucket_name),
        })),
        Err(e) => Ok(Json(TestCosCreateBucketResponse {
            success: false,
            message: format!("创建 bucket 失败: {}", e),
        })),
    }
}
