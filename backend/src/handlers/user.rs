use crate::auth::{hash_password, verify_password};
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::models::convert::{api_update_user_to_db, db_user_to_api_user_info, string_to_uuid};
use crate::models::{
    ChangePasswordRequest, Claims, UpdateUserRequest, UploadAvatarResponse, UserInfo,
};
use crate::AppState;
use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
};
use serde::Deserialize;
use serde_json::json;
use tracing::warn;

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
        None => Err(AppError::NotFound(format!("User {} not found", user_id))),
    }
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
        .ok_or_else(|| AppError::NotFound(format!("User {} not found", user_id)))?;

    // 验证旧密码
    let is_valid = verify_password(&payload.old_password, &user.password_hash)
        .map_err(|e| AppError::InternalError(format!("Password verification failed: {}", e)))?;

    if !is_valid {
        return Err(AppError::ValidationError(
            "Old password is incorrect".to_string(),
        ));
    }

    // 生成新密码哈希
    let new_password_hash = hash_password(&payload.new_password)
        .map_err(|e| AppError::InternalError(format!("Password hashing failed: {}", e)))?;

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
        return Err(AppError::NotFound(format!("User {} not found", user_id)));
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
        .ok_or_else(|| AppError::NotFound(format!("User {} not found", user_id)))?;

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

/// 上传头像（占位接口）
pub async fn upload_avatar(
    State(_state): State<AppState>,
    Extension(claims): Extension<Claims>,
    // TODO: 接收 multipart/form-data 文件上传
) -> Result<Json<UploadAvatarResponse>, AppError> {
    // 占位实现：返回示例 URL
    // 实际应该：
    // 1. 接收上传的文件
    // 2. 验证文件类型和大小
    // 3. 上传到对象存储（S3/MinIO/OSS）
    // 4. 返回文件访问 URL

    let mock_avatar_url = format!(
        "https://api.dicebear.com/7.x/avataaars/svg?seed={}",
        claims.sub
    );

    Ok(Json(UploadAvatarResponse {
        avatar_url: mock_avatar_url,
    }))
}
