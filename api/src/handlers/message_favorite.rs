use axum::{
    extract::{Path, Query, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::message_favorite_store::MessageFavoriteStore;
use crate::database::message_store::MessageStore;
use crate::database::room_store::RoomStore;
use crate::error::AppError;
use crate::models::{Claims, convert::string_to_uuid};

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FavoriteMessageInfo {
    pub message_id: String,
    pub room_id: String,
    pub sender_id: String,
    pub content: String,
    pub message_type: String,
    pub message_created_at: String,
    pub favorited_at: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ListFavoritesResponse {
    pub items: Vec<FavoriteMessageInfo>,
    pub total: i64,
}

#[derive(Debug, Deserialize)]
pub struct ListFavoritesQuery {
    #[serde(default = "default_limit")]
    pub limit: i64,
    #[serde(default)]
    pub offset: i64,
}

fn default_limit() -> i64 {
    50
}

async fn validate_message_in_room(
    state: &crate::AppState,
    room_id: Uuid,
    message_id: Uuid,
    user_id: Uuid,
) -> Result<(), AppError> {
    let room_store = RoomStore::new(state.database.pool());
    let in_room = room_store
        .is_user_in_room(room_id, user_id)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;
    if !in_room {
        return Err(AppError::Forbidden(
            "不是房间成员，无法操作消息收藏".to_string(),
        ));
    }

    let message_store = MessageStore::new(state.database.pool());
    let message = message_store
        .get_message(message_id)
        .await
        .map_err(|e| AppError::DatabaseError(e))?
        .ok_or_else(|| AppError::NotFound("消息不存在".to_string()))?;
    if message.room_id != room_id {
        return Err(AppError::ValidationError("消息不属于该房间".to_string()));
    }

    Ok(())
}

/// POST /rooms/{room_id}/messages/{message_id}/favorite
pub async fn favorite_message(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, message_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    validate_message_in_room(&state, room_id, message_id, user_id).await?;

    let store = MessageFavoriteStore::new(state.database.clone());
    store.favorite(user_id, room_id, message_id).await?;

    Ok(Json(serde_json::json!({ "success": true })))
}

/// DELETE /rooms/{room_id}/messages/{message_id}/favorite
pub async fn unfavorite_message(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, message_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    validate_message_in_room(&state, room_id, message_id, user_id).await?;

    let store = MessageFavoriteStore::new(state.database.clone());
    let deleted = store.unfavorite(user_id, message_id).await?;
    if !deleted {
        return Err(AppError::NotFound("未收藏该消息".to_string()));
    }

    Ok(Json(serde_json::json!({ "success": true })))
}

/// GET /messages/favorites
pub async fn list_favorites(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Query(query): Query<ListFavoritesQuery>,
) -> Result<Json<ListFavoritesResponse>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = MessageFavoriteStore::new(state.database.clone());
    let (rows, total) = store
        .list_favorites(user_id, query.limit.clamp(1, 100), query.offset.max(0))
        .await?;

    let items = rows
        .into_iter()
        .map(|row| FavoriteMessageInfo {
            message_id: row.message_id.to_string(),
            room_id: row.room_id.to_string(),
            sender_id: row.sender_id.to_string(),
            content: row.content,
            message_type: row.message_type.to_string(),
            message_created_at: row.message_created_at.to_rfc3339(),
            favorited_at: row.favorited_at.to_rfc3339(),
        })
        .collect();

    Ok(Json(ListFavoritesResponse { items, total }))
}
