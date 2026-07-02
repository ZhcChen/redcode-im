use crate::auth::{hash_password, verify_password};
use crate::database::file_upload_audit_store::FileUploadAuditStore;
use crate::database::friend_store::FriendStore;
use crate::database::models::{
    RoomType, StorageProvider, UpdateUserRequest as DbUpdateUserRequest,
};
use crate::database::room_store::RoomStore;
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
use std::collections::HashSet;
use tracing::{info, warn};
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct AvatarDirectUploadRequest {
    pub content_type: Option<String>,
    pub file_size: Option<usize>,
    /// 文件哈希值（由前端计算并上报，十六进制字符串）
    pub hash_value: Option<String>,
    /// 哈希算法：1=md5, 2=sha256；缺省视为 1
    pub hash_alg: Option<i16>,
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

    // 检查是否有需要推送的字段变更（昵称）
    let should_notify = payload.nickname.is_some();

    let updated = store.update_user(&user_id, db_req).await?;

    match updated {
        Some(u) => {
            // 如果有可见字段变更，通知好友和关联群成员
            if should_notify {
                let push_payload = ServerPush::FriendProfileUpdated {
                    user_id: user_id.to_string(),
                    username: Some(u.username.clone()),
                    nickname: u.nickname.clone(),
                    avatar_url: u.avatar_url.clone(),
                    avatar_object_key: u.avatar_object_key.clone(),
                };

                // 收集需要通知的用户 ID（去重）
                let mut notified_users: HashSet<Uuid> = HashSet::new();

                // 1. 通知好友
                let friend_store = FriendStore::new(state.database.clone());
                if let Ok(friendships) = friend_store.list_friendships(user_id).await {
                    for friendship in &friendships {
                        notified_users.insert(friendship.friend_user_id);
                    }
                }

                // 2. 通知关联群的所有成员（仅群聊，不包括私聊）
                let room_store = RoomStore::new(state.database.pool());
                if let Ok(rooms) = room_store.list_user_rooms(user_id).await {
                    for room in rooms {
                        if room.room_type == RoomType::Group {
                            if let Ok(member_ids) = room_store.list_member_ids(room.id).await {
                                for member_id in member_ids {
                                    if member_id != user_id {
                                        notified_users.insert(member_id);
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. 批量推送
                let notified_count = notified_users.len();
                for target_user_id in notified_users {
                    state
                        .connection_manager
                        .send_to_user(&target_user_id.to_string(), push_payload.clone())
                        .await;
                }

                info!(
                    "用户 {} 资料更新，已通知 {} 个关联用户（好友+群成员）",
                    user_id, notified_count
                );
            }

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

    // 头像直传目前主要针对单用户头像，考虑到 object_key 校验依赖用户前缀，
    // 这里仅在当前用户自己的 avatars/ 前缀下尝试复用。
    if let (Some(ref hash_value), Some(file_size)) = (&req.hash_value, req.file_size) {
        if file_size > 0 {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store =
                crate::database::file_upload_store::FileUploadStore::new(state.database.clone());
            let prefix = format!("avatars/{}/", user_id);
            if let Some(existing) = upload_store
                .find_completed_by_hash(
                    &provider.id,
                    hash_alg,
                    hash_value,
                    file_size as i64,
                    Some(&prefix),
                )
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
                        "复用已上传的用户头像: key={}, hash_alg={}, hash_value={}",
                        existing.object_key, hash_alg, hash_value
                    );

                    return Ok(Json(AvatarDirectUploadResponse {
                        success: true,
                        message: "复用已上传的头像，未生成新的直传签名".to_string(),
                        key: Some(existing.object_key),
                        signature: None,
                    }));
                }
            }
        }
    }

    let key = build_avatar_object_key(&user_id, req.content_type.as_deref());

    // 记录一条“上传中”的文件记录（仅在提供了 hash 时）
    if let (Some(ref hash_value), Some(file_size)) = (&req.hash_value, req.file_size) {
        if file_size > 0 {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store =
                crate::database::file_upload_store::FileUploadStore::new(state.database.clone());
            let _ = upload_store
                .create_pending_record(
                    &provider.id,
                    &key,
                    hash_alg,
                    hash_value,
                    Some(file_size as i64),
                    req.content_type.as_deref(),
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    let signature = storage_service
        .generate_direct_upload_signature(&key, req.content_type.as_deref())
        .await?;

    info!("前端获取直传参数 key: {}", key);

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
    let upload_store =
        crate::database::file_upload_store::FileUploadStore::new(state.database.clone());

    // 上传完成校验：确认对象存在，并在可用时校验 file_size/hash
    let record = upload_store
        .get_by_key(&provider.id, key)
        .await
        .map_err(AppError::from)?;
    match storage_service.head_object(key).await {
        Ok(head) => {
            if let Some(expected_size) = record.as_ref().and_then(|r| r.file_size) {
                if let Some(actual_size) = head.content_length {
                    if actual_size != expected_size as u64 {
                        return Err(AppError::ValidationError(format!(
                            "头像大小校验失败：期望 {} 字节，实际 {} 字节",
                            expected_size, actual_size
                        )));
                    }
                }
            }

            if let Some(r) = record.as_ref() {
                if r.hash_alg == 1 {
                    if let Some(etag) = head.etag.as_deref() {
                        if !etag.contains('-')
                            && etag.len() == 32
                            && r.hash_value.trim().len() == 32
                            && etag.chars().all(|c| c.is_ascii_hexdigit())
                            && r.hash_value.chars().all(|c| c.is_ascii_hexdigit())
                            && etag.to_ascii_lowercase() != r.hash_value.trim().to_ascii_lowercase()
                        {
                            return Err(AppError::ValidationError(
                                "头像哈希校验失败，请重新上传".to_string(),
                            ));
                        }
                    }
                }
            }
        }
        Err(AppError::NotFound(_)) => {
            return Err(AppError::ValidationError(
                "对象存储中尚未找到该头像，请稍后重试".to_string(),
            ));
        }
        Err(AppError::ValidationError(_)) => {
            if !storage_service.file_exists(key).await? {
                return Err(AppError::ValidationError(
                    "对象存储中尚未找到该头像，请稍后重试".to_string(),
                ));
            }
        }
        Err(e) => return Err(e),
    }

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
                } else {
                    let _ = upload_store
                        .mark_deleted_by_key(&provider.id, &prev_key, Some("头像已被替换并删除"))
                        .await;
                }
            }
        }
    }

    let download_url = storage_service
        .generate_download_url(key, req.expires_in_seconds)
        .await?;

    // 通知所有好友和关联群成员：用户资料已更新
    let updated_user = user_store
        .find_by_id(&user_id)
        .await?
        .ok_or_else(|| AppError::InternalError("用户信息加载失败".to_string()))?;

    let payload = ServerPush::FriendProfileUpdated {
        user_id: user_id.to_string(),
        username: Some(updated_user.username.clone()),
        nickname: updated_user.nickname.clone(),
        avatar_url: updated_user.avatar_url.clone(),
        avatar_object_key: Some(key.to_string()),
    };

    // 收集需要通知的用户 ID（去重）
    let mut notified_users: HashSet<Uuid> = HashSet::new();

    // 1. 通知好友
    let friend_store = FriendStore::new(state.database.clone());
    if let Ok(friendships) = friend_store.list_friendships(user_id).await {
        for friendship in &friendships {
            notified_users.insert(friendship.friend_user_id);
        }
    }

    // 2. 通知关联群的所有成员（仅群聊，不包括私聊）
    let room_store = RoomStore::new(state.database.pool());
    if let Ok(rooms) = room_store.list_user_rooms(user_id).await {
        for room in rooms {
            // 只处理群聊类型的房间
            if room.room_type == RoomType::Group {
                if let Ok(member_ids) = room_store.list_member_ids(room.id).await {
                    for member_id in member_ids {
                        if member_id != user_id {
                            notified_users.insert(member_id);
                        }
                    }
                }
            }
        }
    }

    // 3. 批量推送
    let notified_count = notified_users.len();
    for target_user_id in notified_users {
        state
            .connection_manager
            .send_to_user(&target_user_id.to_string(), payload.clone())
            .await;
    }

    info!(
        "用户 {} 头像更新，已通知 {} 个关联用户（好友+群成员）",
        user_id, notified_count
    );

    // 标记文件上传完成（如果之前通过直传签名创建了记录）
    let _ = upload_store
        .mark_completed_by_key(&provider.id, key)
        .await
        .map_err(AppError::from)?;

    // 写入内容审核任务（异步队列；违规会删除对象并记录原因）
    let audit_store = FileUploadAuditStore::new(state.database.clone());
    let content_type = record.as_ref().and_then(|r| r.content_type.as_deref());
    let file_size = record.as_ref().and_then(|r| r.file_size);
    let _ = audit_store
        .upsert_task(
            &provider.id,
            key,
            "avatar",
            "image",
            content_type,
            file_size,
        )
        .await
        .map_err(AppError::from)?;

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
        state.redis.get_session_connection(),
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

// ============================================================================
// 验证辅助函数（可测试的纯逻辑）
// ============================================================================

/// 验证密码长度（至少 6 个字符）
pub fn validate_password_length(password: &str) -> bool {
    password.len() >= 6
}

/// 验证搜索关键字（不能为空）
pub fn validate_search_keyword(keyword: &str) -> bool {
    !keyword.trim().is_empty()
}

/// 规范化搜索限制（限制在 1-50 之间）
pub fn normalize_search_limit(limit: Option<i64>) -> i64 {
    limit.unwrap_or(20).clamp(1, 50)
}

#[cfg(test)]
mod tests {
    use super::*;

    // ========================================================================
    // 头像文件扩展名推断测试
    // ========================================================================

    #[test]
    fn test_infer_avatar_extension_png() {
        assert_eq!(infer_avatar_extension(Some("image/png")), ".png");
        assert_eq!(infer_avatar_extension(Some("IMAGE/PNG")), ".png");
    }

    #[test]
    fn test_infer_avatar_extension_jpeg() {
        assert_eq!(infer_avatar_extension(Some("image/jpeg")), ".jpg");
        assert_eq!(infer_avatar_extension(Some("image/jpg")), ".jpg");
    }

    #[test]
    fn test_infer_avatar_extension_webp() {
        assert_eq!(infer_avatar_extension(Some("image/webp")), ".webp");
    }

    #[test]
    fn test_infer_avatar_extension_gif() {
        assert_eq!(infer_avatar_extension(Some("image/gif")), ".gif");
    }

    #[test]
    fn test_infer_avatar_extension_heic() {
        assert_eq!(infer_avatar_extension(Some("image/heic")), ".heic");
        assert_eq!(infer_avatar_extension(Some("image/heif")), ".heif");
    }

    #[test]
    fn test_infer_avatar_extension_svg() {
        assert_eq!(infer_avatar_extension(Some("image/svg+xml")), ".svg");
    }

    #[test]
    fn test_infer_avatar_extension_unknown() {
        assert_eq!(
            infer_avatar_extension(Some("application/octet-stream")),
            ".bin"
        );
        assert_eq!(infer_avatar_extension(Some("video/mp4")), ".bin");
        assert_eq!(infer_avatar_extension(None), ".bin");
    }

    // ========================================================================
    // 头像对象键验证测试
    // ========================================================================

    #[test]
    fn test_is_valid_avatar_key_valid() {
        let user_id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        let key = format!("avatars/{}/20250113_abc123.png", user_id);
        assert!(is_valid_avatar_key(&user_id, &key));
    }

    #[test]
    fn test_is_valid_avatar_key_with_whitespace() {
        let user_id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        let key = format!("  avatars/{}/20250113_abc123.png  ", user_id);
        assert!(is_valid_avatar_key(&user_id, &key));
    }

    #[test]
    fn test_is_valid_avatar_key_wrong_user() {
        let user_id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        let other_user_id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440001").unwrap();
        let key = format!("avatars/{}/20250113_abc123.png", other_user_id);
        assert!(!is_valid_avatar_key(&user_id, &key));
    }

    #[test]
    fn test_is_valid_avatar_key_path_traversal() {
        let user_id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        let key = format!("avatars/{}/../../../etc/passwd", user_id);
        assert!(!is_valid_avatar_key(&user_id, &key));
    }

    #[test]
    fn test_is_valid_avatar_key_empty() {
        let user_id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        assert!(!is_valid_avatar_key(&user_id, ""));
        assert!(!is_valid_avatar_key(&user_id, "   "));
    }

    #[test]
    fn test_is_valid_avatar_key_wrong_prefix() {
        let user_id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        assert!(!is_valid_avatar_key(&user_id, "uploads/avatar.png"));
        assert!(!is_valid_avatar_key(&user_id, "room_avatars/abc.png"));
    }

    // ========================================================================
    // 密码验证测试
    // ========================================================================

    #[test]
    fn test_validate_password_length_valid() {
        assert!(validate_password_length("123456"));
        assert!(validate_password_length("password123"));
        assert!(validate_password_length("很长的密码1234567890"));
    }

    #[test]
    fn test_validate_password_length_invalid() {
        assert!(!validate_password_length(""));
        assert!(!validate_password_length("12345"));
        assert!(!validate_password_length("abc"));
    }

    // ========================================================================
    // 搜索关键字验证测试
    // ========================================================================

    #[test]
    fn test_validate_search_keyword_valid() {
        assert!(validate_search_keyword("test"));
        assert!(validate_search_keyword("用户名"));
        assert!(validate_search_keyword("  keyword  ")); // 有内容
    }

    #[test]
    fn test_validate_search_keyword_invalid() {
        assert!(!validate_search_keyword(""));
        assert!(!validate_search_keyword("   "));
        assert!(!validate_search_keyword("\t\n"));
    }

    // ========================================================================
    // 搜索限制规范化测试
    // ========================================================================

    #[test]
    fn test_normalize_search_limit_default() {
        assert_eq!(normalize_search_limit(None), 20);
    }

    #[test]
    fn test_normalize_search_limit_within_range() {
        assert_eq!(normalize_search_limit(Some(10)), 10);
        assert_eq!(normalize_search_limit(Some(1)), 1);
        assert_eq!(normalize_search_limit(Some(50)), 50);
    }

    #[test]
    fn test_normalize_search_limit_below_min() {
        assert_eq!(normalize_search_limit(Some(0)), 1);
        assert_eq!(normalize_search_limit(Some(-5)), 1);
    }

    #[test]
    fn test_normalize_search_limit_above_max() {
        assert_eq!(normalize_search_limit(Some(100)), 50);
        assert_eq!(normalize_search_limit(Some(1000)), 50);
    }

    // ========================================================================
    // 头像对象键构建测试
    // ========================================================================

    #[test]
    fn test_build_avatar_object_key_format() {
        let user_id = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        let key = build_avatar_object_key(&user_id, Some("image/png"));

        // 验证前缀
        assert!(key.starts_with(&format!("avatars/{}/", user_id)));
        // 验证扩展名
        assert!(key.ends_with(".png"));
        // 验证格式：avatars/uuid/timestamp_random.ext
        let parts: Vec<&str> = key.split('/').collect();
        assert_eq!(parts.len(), 3);
        assert_eq!(parts[0], "avatars");
    }

    #[test]
    fn test_build_avatar_object_key_different_types() {
        let user_id = Uuid::new_v4();

        assert!(build_avatar_object_key(&user_id, Some("image/jpeg")).ends_with(".jpg"));
        assert!(build_avatar_object_key(&user_id, Some("image/webp")).ends_with(".webp"));
        assert!(build_avatar_object_key(&user_id, Some("image/gif")).ends_with(".gif"));
        assert!(build_avatar_object_key(&user_id, None).ends_with(".bin"));
    }
}
