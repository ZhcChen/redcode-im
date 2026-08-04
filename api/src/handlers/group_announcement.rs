use axum::{
    extract::{Path, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::group_announcement_store::GroupAnnouncementStore;
use crate::database::group_management_store::GroupManagementStore;
use crate::database::room_store::RoomStore;
use crate::database::models::{RoomType};
use crate::error::AppError;
use crate::models::{Claims, convert::string_to_uuid};
use crate::websocket::ServerPush;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupAnnouncementResponse {
    pub room_id: String,
    pub content: String,
    pub created_by: String,
    pub updated_by: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Deserialize)]
pub struct UpdateAnnouncementRequest {
    pub content: String,
}

async fn resolve_room(
    state: &crate::AppState,
    room_id: Uuid,
    user_id: Uuid,
    require_manage: bool,
) -> Result<(), AppError> {
    let room_store = RoomStore::new(state.database.pool());
    let room = room_store
        .get_room(room_id)
        .await
        .map_err(|_| AppError::NotFound("房间不存在".to_string()))?;

    if room.room_type != RoomType::Group {
        return Err(AppError::ValidationError("只有群聊支持公告".to_string()));
    }

    let in_room = room_store
        .is_user_in_room(room_id, user_id)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;
    if !in_room {
        return Err(AppError::Forbidden("不是群成员，无法操作公告".to_string()));
    }

    if require_manage {
        let group_store = GroupManagementStore::new(state.database.pool());
        let can_manage = group_store
            .can_manage_group(room_id, user_id)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;
        if !can_manage {
            return Err(AppError::Forbidden(
                "只有群主或管理员可以管理公告".to_string(),
            ));
        }
    }

    Ok(())
}

fn to_response(record: &crate::database::group_announcement_store::GroupAnnouncementRecord) -> GroupAnnouncementResponse {
    GroupAnnouncementResponse {
        room_id: record.room_id.to_string(),
        content: record.content.clone(),
        created_by: record.created_by.to_string(),
        updated_by: record.updated_by.to_string(),
        created_at: record.created_at.to_rfc3339(),
        updated_at: record.updated_at.to_rfc3339(),
    }
}

/// GET /rooms/{room_id}/announcement
pub async fn get_announcement(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<GroupAnnouncementResponse>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    resolve_room(&state, room_id, user_id, false).await?;

    let store = GroupAnnouncementStore::new(state.database.clone());
    let record = store
        .get(room_id)
        .await?
        .ok_or_else(|| AppError::NotFound("群公告不存在".to_string()))?;

    Ok(Json(to_response(&record)))
}

/// PUT /rooms/{room_id}/announcement
pub async fn update_announcement(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(payload): Json<UpdateAnnouncementRequest>,
) -> Result<Json<GroupAnnouncementResponse>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;
    let content = payload.content.trim().to_string();
    if content.is_empty() {
        return Err(AppError::ValidationError("公告内容不能为空".to_string()));
    }

    resolve_room(&state, room_id, user_id, true).await?;

    let store = GroupAnnouncementStore::new(state.database.clone());
    let record = store.upsert(room_id, content, user_id).await?;

    state
        .connection_manager
        .send_to_room(
            room_id,
            ServerPush::GroupAnnouncementUpdated {
                room_id,
                content: Some(record.content.clone()),
                updated_by: user_id,
                updated_at: record.updated_at.to_rfc3339(),
            },
        )
        .await;

    Ok(Json(to_response(&record)))
}

/// DELETE /rooms/{room_id}/announcement
pub async fn delete_announcement(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    resolve_room(&state, room_id, user_id, true).await?;

    let store = GroupAnnouncementStore::new(state.database.clone());
    let deleted = store.delete(room_id).await?;
    if !deleted {
        return Err(AppError::NotFound("群公告不存在".to_string()));
    }

    state
        .connection_manager
        .send_to_room(
            room_id,
            ServerPush::GroupAnnouncementUpdated {
                room_id,
                content: None,
                updated_by: user_id,
                updated_at: chrono::Utc::now().to_rfc3339(),
            },
        )
        .await;

    Ok(Json(serde_json::json!({ "success": true })))
}
