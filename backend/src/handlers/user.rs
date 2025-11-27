use crate::auth::{hash_password, verify_password};
use crate::database::friend_store::FriendStore;
use crate::database::models::{
    StorageProvider, StorageProviderType, UpdateUserRequest as DbUpdateUserRequest,
};
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::models::convert::{api_update_user_to_db, db_user_to_api_user_info, string_to_uuid};
use crate::models::{ChangePasswordRequest, Claims, UpdateUserRequest, UserInfo};
use crate::redis::cache::CacheManager;
use crate::redis::models::CacheKeys;
use crate::storage;
use crate::storage::DirectUploadSignature;
use crate::websocket::ServerPush;
use crate::AppState;
use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::json;
use tracing::{debug, info, warn};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct AvatarDirectUploadRequest {
    pub content_type: Option<String>,
    pub file_size: Option<usize>,
}

#[derive(Debug, Serialize)]
pub struct AvatarDirectUploadResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub key: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub signature: Option<DirectUploadSignature>,
}

#[derive(Debug, Deserialize)]
pub struct AvatarUploadCommitRequest {
    pub key: String,
    pub expires_in_seconds: Option<u32>,
    #[serde(default = "AvatarUploadCommitRequest::default_delete_previous")]
    pub delete_previous: bool,
}

impl AvatarUploadCommitRequest {
    fn default_delete_previous() -> bool {
        true
    }
}

#[derive(Debug, Deserialize)]
pub struct AvatarDownloadUrlRequest {
    pub expires_in_seconds: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct AvatarDownloadUrlResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub download_url: Option<String>,
}

/// 更新当前用户资料

pub async fn update_me(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateUserRequest>,
) -> Result<Json<UserInfo>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = UserStore::new(state.database.clone());

    // 转换为数据库层请求
    let db_req = api_update_user_to_db(&payload);

    let updated = store.update_user(&user_id, db_req).await?;

    match updated {
        Some(u) => {
            let user_info = db_user_to_api_user_info(&u);
            Ok(Json(user_info))
        }
        None => Err(AppError::NotFound(format!("用户 {} 不存在", user_id))),
    }
}

pub async fn generate_avatar_direct_upload(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<AvatarDirectUploadRequest>,
) -> Result<Json<AvatarDirectUploadResponse>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    // 验证文件类型
    if let Some(content_type) = &req.content_type {
        if !crate::constants::AVATAR_ALLOWED_TYPES.contains(&content_type.as_str()) {
            return Ok(Json(AvatarDirectUploadResponse {
                success: false,
                message: format!("不支持的文件类型: {}", content_type),
                key: None,
                signature: None,
            }));
        }
    }

    // 验证文件大小
    if let Some(file_size) = req.file_size {
        if file_size > crate::constants::AVATAR_MAX_SIZE_BYTES {
            return Ok(Json(AvatarDirectUploadResponse {
                success: false,
                message: format!(
                    "文件大小超出限制，最大允许{}MB",
                    crate::constants::AVATAR_MAX_SIZE_BYTES / 1024 / 1024
                ),
                key: None,
                signature: None,
            }));
        }
    }

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    let key = build_avatar_object_key(&user_id, req.content_type.as_deref());
    let signature = storage_service
        .generate_direct_upload_signature(&key, req.content_type.as_deref())
        .await?;

    debug!("前端获取直传参数 key: {}", key);

    Ok(Json(AvatarDirectUploadResponse {
        success: true,
        message: "生成头像直传签名成功".to_string(),
        key: Some(key),
        signature: Some(signature),
    }))
}

pub async fn commit_avatar_upload(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<AvatarUploadCommitRequest>,
) -> Result<Json<AvatarDownloadUrlResponse>, AppError> {
    let key = req.key.trim();
    if key.is_empty() {
        return Ok(Json(AvatarDownloadUrlResponse {
            success: false,
            message: "文件路径（key）不能为空".to_string(),
            download_url: None,
        }));
    }

    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    if !is_valid_avatar_key(&user_id, key) {
        return Ok(Json(AvatarDownloadUrlResponse {
            success: false,
            message: "文件路径不合法".to_string(),
            download_url: None,
        }));
    }

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    let user_store = UserStore::new(state.database.clone());
    let existing_user = user_store
        .find_by_id(&user_id)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("用户 {} 不存在", user_id)))?;
    let previous_key = existing_user.avatar_object_key.clone();

    let file_url = storage_service.get_file_url(key);
    let update_req = DbUpdateUserRequest {
        nickname: None,
        avatar_url: Some(file_url.clone()),
        avatar_object_key: Some(key.to_string()),
        status: None,
    };

    let updated = user_store.update_user(&user_id, update_req).await?;
    if updated.is_none() {
        return Err(AppError::InternalError("更新用户头像失败".to_string()));
    }

    if req.delete_previous {
        if let Some(prev_key) = previous_key {
            if prev_key != key {
                if let Err(e) = storage_service.delete_file(&prev_key).await {
                    warn!(
                        "failed to delete previous avatar for user {}: {}",
                        user_id, e
                    );
                }
            }
        }
    }

    let download_url = storage_service
        .generate_download_url(key, req.expires_in_seconds)
        .await?;

    // 通知所有好友：用户资料已更新
    let friend_store = FriendStore::new(state.database.clone());
    if let Ok(friendships) = friend_store.list_friendships(user_id).await {
        let updated_user = user_store.find_by_id(&user_id).await?.ok_or_else(|| {
            AppError::InternalError("用户信息加载失败".to_string())
        })?;

        let payload = ServerPush::FriendProfileUpdated {
            user_id: user_id.to_string(),
            username: Some(updated_user.username.clone()),
            nickname: updated_user.nickname.clone(),
            avatar_url: updated_user.avatar_url.clone(),
            avatar_object_key: Some(key.to_string()),
        };

        for friendship in &friendships {
            let friend_id = friendship.friend_user_id.to_string();
            state
                .connection_manager
                .send_to_user(&friend_id, payload.clone())
                .await;
        }

        info!(
            "用户 {} 头像更新，已通知 {} 个好友",
            user_id,
            friendships.len()
        );
    }

    Ok(Json(AvatarDownloadUrlResponse {
        success: true,
        message: "头像更新成功".to_string(),
        download_url: Some(download_url),
    }))
}

pub async fn get_avatar_download_url(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Query(params): Query<AvatarDownloadUrlRequest>,
) -> Result<Json<AvatarDownloadUrlResponse>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let user_store = UserStore::new(state.database.clone());
    let user = user_store
        .find_by_id(&user_id)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("用户 {} 不存在", user_id)))?;

    let key = match user.avatar_object_key {
        Some(ref key) => key.clone(),
        None => {
            return Ok(Json(AvatarDownloadUrlResponse {
                success: false,
                message: "尚未设置头像".to_string(),
                download_url: None,
            }));
        }
    };

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    // 生成缓存键
    let cache_key = CacheKeys::download_url_cache(
        &key,
        &provider.id.to_string(),
        params.expires_in_seconds.unwrap_or(3600),
    );

    // 创建缓存管理器
    let cache_manager = CacheManager::new(state.redis.get_cache_client().clone());

    // 尝试从缓存获取URL
    let download_url =
        if let Ok(Some(cached_url)) = cache_manager.get_cached_download_url(&cache_key).await {
            cached_url
        } else {
            // 缓存未命中，生成新的URL
            let url = storage_service
                .generate_download_url(&key, params.expires_in_seconds)
                .await?;

            // 缓存URL，过期时间为URL有效期的90%
            let url_expires_in = params.expires_in_seconds.unwrap_or(3600);
            let cache_ttl = (url_expires_in as f64 * 0.9) as u64;

            if let Err(e) = cache_manager
                .cache_download_url(&cache_key, &url, cache_ttl)
                .await
            {
                warn!("缓存头像下载URL失败: {:?}", e);
            }

            url
        };

    Ok(Json(AvatarDownloadUrlResponse {
        success: true,
        message: "生成下载链接成功".to_string(),
        download_url: Some(download_url),
    }))
}

/// 获取指定用户的头像下载地址（用于显示好友/聊天列表中的头像）
pub async fn get_user_avatar_download_url(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
    Path(target_user_id): Path<String>,
    Query(params): Query<AvatarDownloadUrlRequest>,
) -> Result<Json<AvatarDownloadUrlResponse>, AppError> {
    let user_id = string_to_uuid(&target_user_id)
        .map_err(|e| AppError::ValidationError(format!("Invalid user ID: {}", e)))?;

    let user_store = UserStore::new(state.database.clone());
    let user = user_store
        .find_by_id(&user_id)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("用户 {} 不存在", user_id)))?;

    let key = match user.avatar_object_key {
        Some(ref key) => key.clone(),
        None => {
            return Ok(Json(AvatarDownloadUrlResponse {
                success: false,
                message: "该用户尚未设置头像".to_string(),
                download_url: None,
            }));
        }
    };

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;
    let download_url = storage_service
        .generate_download_url(&key, params.expires_in_seconds)
        .await?;

    Ok(Json(AvatarDownloadUrlResponse {
        success: true,
        message: "生成下载链接成功".to_string(),
        download_url: Some(download_url),
    }))
}

/// 修改密码
pub async fn change_password(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<ChangePasswordRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    // 验证新密码长度
    if payload.new_password.len() < 6 {
        return Err(AppError::ValidationError(
            "New password must be at least 6 characters".to_string(),
        ));
    }

    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = UserStore::new(state.database.clone());

    // 获取用户信息
    let user = store
        .find_by_id(&user_id)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("用户 {} 不存在", user_id)))?;

    // 验证旧密码
    let is_valid = verify_password(&payload.old_password, &user.password_hash)
        .map_err(|_| AppError::InternalError("密码验证失败".to_string()))?;

    if !is_valid {
        return Err(AppError::ValidationError("旧密码错误".to_string()));
    }

    // 生成新密码哈希
    let new_password_hash = hash_password(&payload.new_password)
        .map_err(|_| AppError::InternalError("密码加密失败".to_string()))?;

    // 更新密码
    store.update_password(&user_id, &new_password_hash).await?;

    Ok(Json(serde_json::json!({
        "success": true,
        "message": "Password changed successfully"
    })))
}

pub async fn deactivate_me(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = UserStore::new(state.database.clone());
    let deleted = store.delete_user(&user_id).await?;

    if !deleted {
        return Err(AppError::NotFound(format!("用户 {} 不存在", user_id)));
    }

    let session_manager = crate::redis::session::SessionManager::new(
        state.redis.get_session_client().clone(),
        state.node_id.clone(),
    );

    if let Err(err) = session_manager.delete_user_session(&user_id).await {
        warn!("Failed to cleanup sessions for user {}: {}", user_id, err);
    }

    Ok(Json(json!({
        "success": true,
        "message": "Account deactivated"
    })))
}

/// 获取用户信息（通过用户ID）
pub async fn get_user_by_id(
    State(state): State<AppState>,
    Path(user_id_str): Path<String>,
) -> Result<Json<UserInfo>, AppError> {
    let user_id = string_to_uuid(&user_id_str)
        .map_err(|e| AppError::ValidationError(format!("Invalid user ID: {}", e)))?;

    let store = UserStore::new(state.database.clone());

    let user = store
        .find_by_id(&user_id)
        .await?
        .ok_or_else(|| AppError::NotFound(format!("用户 {} 不存在", user_id)))?;

    Ok(Json(db_user_to_api_user_info(&user)))
}

#[derive(Debug, Deserialize)]
pub struct UserSearchQuery {
    pub keyword: String,
    pub limit: Option<i64>,
}

/// 搜索用户
pub async fn search_users(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Query(params): Query<UserSearchQuery>,
) -> Result<Json<Vec<UserInfo>>, AppError> {
    let keyword = params.keyword.trim();
    if keyword.is_empty() {
        return Err(AppError::ValidationError("搜索关键字不能为空".to_string()));
    }

    let limit = params.limit.unwrap_or(20).clamp(1, 50);

    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = UserStore::new(state.database.clone());

    let users = store.search_users(keyword, limit, &current_user_id).await?;

    let infos = users.iter().map(|u| db_user_to_api_user_info(u)).collect();

    Ok(Json(infos))
}

pub async fn load_default_storage_provider(state: &AppState) -> Result<StorageProvider, AppError> {
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

fn build_avatar_object_key(user_id: &Uuid, content_type: Option<&str>) -> String {
    let extension = infer_avatar_extension(content_type);
    let timestamp = Utc::now().format("%Y%m%d%H%M%S");
    let random = Uuid::new_v4().simple().to_string();
    let short = &random[..8];
    format!("avatars/{}/{}_{}{}", user_id, timestamp, short, extension)
}

fn infer_avatar_extension(content_type: Option<&str>) -> &'static str {
    let lowered = content_type
        .map(|ct| ct.trim().to_ascii_lowercase())
        .unwrap_or_default();
    match lowered.as_str() {
        "image/png" => ".png",
        "image/jpeg" | "image/jpg" => ".jpg",
        "image/webp" => ".webp",
        "image/gif" => ".gif",
        "image/heic" => ".heic",
        "image/heif" => ".heif",
        "image/svg+xml" => ".svg",
        _ => ".bin",
    }
}

fn is_valid_avatar_key(user_id: &Uuid, key: &str) -> bool {
    let normalized = key.trim();
    if normalized.is_empty() || normalized.contains("..") {
        return false;
    }
    let expected_prefix = format!("avatars/{}/", user_id);
    normalized.starts_with(&expected_prefix)
}
