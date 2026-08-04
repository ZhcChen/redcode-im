use axum::{
    extract::{Path, Query, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::user_block_store::UserBlockStore;
use crate::error::AppError;
use crate::models::Claims;
use crate::models::convert::string_to_uuid;

/// 黑名单列表项响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BlockedUserInfo {
    pub user_id: String,
    pub username: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub signature: Option<String>,
    pub blocked_at: String,
}

/// 拉黑请求
#[derive(Debug, Deserialize)]
pub struct BlockUserRequest {
    pub user_id: String,
}

#[derive(Debug, Deserialize)]
pub struct ListBlockedQuery {
    #[serde(default = "default_limit")]
    pub limit: i64,
    #[serde(default)]
    pub offset: i64,
}

fn default_limit() -> i64 {
    50
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ListBlockedResponse {
    pub items: Vec<BlockedUserInfo>,
    pub total: i64,
}

/// GET /users/blocked
pub async fn list_blocked(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Query(query): Query<ListBlockedQuery>,
) -> Result<Json<ListBlockedResponse>, AppError> {
    let blocker_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = UserBlockStore::new(state.database.clone());
    let (rows, total) = store
        .list_blocked(blocker_id, query.limit.clamp(1, 100), query.offset.max(0))
        .await?;

    let items = rows
        .into_iter()
        .map(|row| BlockedUserInfo {
            user_id: row.blocked_id.to_string(),
            username: row.username,
            nickname: row.nickname,
            avatar_url: row.avatar_url,
            signature: row.signature,
            blocked_at: row.created_at.to_rfc3339(),
        })
        .collect();

    Ok(Json(ListBlockedResponse { items, total }))
}

/// POST /users/blocked
pub async fn block_user(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<BlockUserRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    let blocker_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;
    let blocked_id = string_to_uuid(&payload.user_id)
        .map_err(|e| AppError::ValidationError(format!("无效的用户ID: {}", e)))?;

    let store = UserBlockStore::new(state.database.clone());
    store.block_user(blocker_id, blocked_id).await?;

    Ok(Json(serde_json::json!({ "success": true })))
}

/// DELETE /users/blocked/{user_id}
pub async fn unblock_user(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Path(user_id): Path<String>,
) -> Result<Json<serde_json::Value>, AppError> {
    let blocker_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;
    let blocked_id = string_to_uuid(&user_id)
        .map_err(|e| AppError::ValidationError(format!("无效的用户ID: {}", e)))?;

    let store = UserBlockStore::new(state.database.clone());
    let deleted = store.unblock_user(blocker_id, blocked_id).await?;
    if !deleted {
        return Err(AppError::NotFound("未找到该拉黑关系".to_string()));
    }

    Ok(Json(serde_json::json!({ "success": true })))
}

/// 供消息/好友链路复用的拉黑检查。
pub async fn ensure_not_mutually_blocked(
    state: &crate::AppState,
    user_a: Uuid,
    user_b: Uuid,
) -> Result<(), AppError> {
    let store = UserBlockStore::new(state.database.clone());
    if store.is_mutually_blocked(user_a, user_b).await? {
        return Err(AppError::Forbidden(
            "操作被阻止：双方存在拉黑关系".to_string(),
        ));
    }
    Ok(())
}
