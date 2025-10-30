use std::collections::HashSet;

use axum::{
    extract::{Extension, Path, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::{
    models::{MemberRole, Room, RoomType},
    room_store::RoomStore,
};
use crate::error::AppError;
use crate::models::convert::{db_chat_summary_to_api, string_to_uuid};
use crate::models::{ChatSummary, Claims};
use crate::websocket::{RoomCreatedPayload, ServerPush};
use crate::AppState;

#[derive(Deserialize)]
pub struct CreateRoomPayload {
    pub name: String,
    pub description: Option<String>,
    pub room_type: Option<RoomType>,
    #[serde(default)]
    pub member_ids: Vec<String>,
}

#[derive(Serialize)]
pub struct CreateRoomResponse {
    pub room: Room,
}

pub async fn create_room(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<CreateRoomPayload>,
) -> Result<Json<CreateRoomResponse>, AppError> {
    let CreateRoomPayload {
        name,
        description,
        room_type,
        member_ids,
    } = payload;

    if name.trim().is_empty() {
        return Err(AppError::ValidationError(
            "Room name cannot be empty".to_string(),
        ));
    }

    let requested_type = room_type.unwrap_or(RoomType::Group);
    if matches!(requested_type, RoomType::Private | RoomType::Favorite) {
        return Err(AppError::ValidationError(
            "Cannot create room of this type via this endpoint".to_string(),
        ));
    }

    let owner = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let mut unique_members = HashSet::new();
    let mut member_uuid_list = Vec::new();
    for raw_id in member_ids {
        let trimmed = raw_id.trim();
        if trimmed.is_empty() {
            continue;
        }
        let member_uuid = Uuid::parse_str(trimmed)
            .map_err(|_| AppError::ValidationError(format!("Invalid member ID: {}", trimmed)))?;
        if member_uuid == owner {
            continue;
        }
        if unique_members.insert(member_uuid) {
            member_uuid_list.push(member_uuid);
        }
    }

    if requested_type == RoomType::Group && member_uuid_list.is_empty() {
        return Err(AppError::ValidationError(
            "Group room must contain at least one additional member".to_string(),
        ));
    }

    let store = RoomStore::new(state.database.pool());
    let room = store
        .create_room_with_members(
            owner,
            name,
            description,
            Some(requested_type),
            &member_uuid_list,
        )
        .await?;

    // 通知所有相关成员刷新会话列表
    let mut notify_targets: HashSet<Uuid> = member_uuid_list.into_iter().collect();
    notify_targets.insert(owner);
    let room_id = room.id;
    let room_name = room.name.clone();
    let room_description = room.description.clone();
    let room_avatar = room.avatar_url.clone();
    let room_created_at = room.created_at;
    let room_owner = room.owner_id;
    for user_id in notify_targets {
        let payload = ServerPush::RoomCreated {
            data: RoomCreatedPayload {
                room_id,
                room_name: room_name.clone(),
                room_type: requested_type.to_string(),
                initiator_id: owner,
                owner_id: room_owner,
                description: room_description.clone(),
                avatar_url: room_avatar.clone(),
                created_at: Some(room_created_at),
            },
        };
        state
            .connection_manager
            .send_to_user(&user_id.to_string(), payload)
            .await;
    }

    Ok(Json(CreateRoomResponse { room }))
}

#[derive(Serialize)]
pub struct JoinRoomResponse {
    pub ok: bool,
}

pub async fn join_room(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<JoinRoomResponse>, AppError> {
    let user = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    let _ = store
        .add_member(room_id, user, Some(MemberRole::Member))
        .await?;

    Ok(Json(JoinRoomResponse { ok: true }))
}

#[derive(Serialize)]
pub struct LeaveRoomResponse {
    pub ok: bool,
}

pub async fn leave_room(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<LeaveRoomResponse>, AppError> {
    let user = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    let ok = store.remove_member(room_id, user).await?;

    if !ok {
        return Err(AppError::NotFound(format!(
            "User {} is not a member of room {}",
            user, room_id
        )));
    }

    Ok(Json(LeaveRoomResponse { ok }))
}

#[derive(Serialize)]
pub struct RoomMemberDto {
    pub user_id: Uuid,
    pub role: MemberRole,
}

pub async fn list_members(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<Vec<RoomMemberDto>>, AppError> {
    let store = RoomStore::new(state.database.pool());
    let rows = store.list_members(room_id).await?;

    let items = rows
        .into_iter()
        .map(|rm| RoomMemberDto {
            user_id: rm.user_id,
            role: rm.role,
        })
        .collect();

    Ok(Json(items))
}

#[derive(Serialize)]
pub struct MyRoomDto {
    pub id: Uuid,
    pub name: String,
    pub room_type: RoomType,
}

pub async fn list_my_rooms(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<MyRoomDto>>, AppError> {
    let user = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = RoomStore::new(state.database.pool());
    let rooms = store.list_user_rooms(user).await?;

    let result = rooms
        .into_iter()
        .map(|r| MyRoomDto {
            id: r.id,
            name: r.name,
            room_type: r.room_type,
        })
        .collect();

    Ok(Json(result))
}

/// 获取当前用户的会话列表概要
pub async fn list_chat_summaries(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<ChatSummary>>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = RoomStore::new(state.database.pool());
    store.ensure_favorite_room(user_id).await?;
    let rows = store.list_chat_summaries(user_id).await?;

    let summaries = rows
        .into_iter()
        .map(|row| db_chat_summary_to_api(&row))
        .collect();

    Ok(Json(summaries))
}
