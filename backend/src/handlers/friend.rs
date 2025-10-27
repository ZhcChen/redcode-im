use std::collections::{HashMap, HashSet};

use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
};
use serde::Deserialize;
use serde_json::json;
use tracing::warn;
use uuid::Uuid;

use crate::database::friend_store::{FriendRequestDirection, FriendStore};
use crate::database::message_store::MessageStore;
use crate::database::models::{FriendRequestStatus as DbFriendRequestStatus, MessageType};
use crate::database::room_store::RoomStore;
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::handlers::message::broadcast_message_to_room;
use crate::models::convert::{
    db_friend_request_to_api, db_friendship_to_api, db_room_type_to_api, string_to_uuid,
};
use crate::models::{
    Claims, CreateFriendRequest, FriendInfo, FriendRequestAction, FriendRequestInfo,
    RespondFriendRequest,
};
use crate::AppState;

#[derive(Debug, Deserialize)]
pub struct FriendRequestQuery {
    pub direction: Option<String>,
    pub status: Option<String>,
}

/// 创建好友请求
pub async fn create_friend_request(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<CreateFriendRequest>,
) -> Result<Json<FriendRequestInfo>, AppError> {
    let requester_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;
    let target_user_id = string_to_uuid(&payload.target_user_id)
        .map_err(|e| AppError::ValidationError(format!("无效的用户ID: {}", e)))?;

    if requester_id == target_user_id {
        return Err(AppError::ValidationError("不能添加自己为好友".to_string()));
    }

    let user_store = UserStore::new(state.database.clone());
    let target_user = user_store
        .find_by_id(&target_user_id)
        .await?
        .ok_or_else(|| AppError::NotFound("目标用户不存在或已被停用".to_string()))?;

    let current_user = user_store
        .find_by_id(&requester_id)
        .await?
        .ok_or_else(|| AppError::NotFound("当前用户不存在".to_string()))?;

    let friend_store = FriendStore::new(state.database.clone());
    let request = friend_store
        .create_request(requester_id, target_user_id, payload.message.clone())
        .await?;

    let info = db_friend_request_to_api(&request, &current_user, &target_user, &requester_id);

    notify_pending_count(&state, &friend_store, request.addressee_id).await?;
    notify_pending_count(&state, &friend_store, requester_id).await?;

    Ok(Json(info))
}

/// 列出好友请求
pub async fn list_friend_requests(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Query(params): Query<FriendRequestQuery>,
) -> Result<Json<Vec<FriendRequestInfo>>, AppError> {
    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let direction = match params.direction.as_deref() {
        None | Some("") => None,
        Some("incoming") => Some(FriendRequestDirection::Incoming),
        Some("outgoing") => Some(FriendRequestDirection::Outgoing),
        Some(other) => {
            return Err(AppError::ValidationError(format!(
                "不支持的 direction 参数: {}",
                other
            )));
        }
    };

    let status = match params.status.as_deref() {
        None | Some("") => None,
        Some("pending") => Some(DbFriendRequestStatus::Pending),
        Some("accepted") => Some(DbFriendRequestStatus::Accepted),
        Some("declined") => Some(DbFriendRequestStatus::Declined),
        Some(other) => {
            return Err(AppError::ValidationError(format!(
                "不支持的 status 参数: {}",
                other
            )));
        }
    };

    let friend_store = FriendStore::new(state.database.clone());
    let requests = friend_store
        .list_requests(current_user_id, direction, status)
        .await?;

    if requests.is_empty() {
        return Ok(Json(Vec::new()));
    }

    let mut user_ids: HashSet<Uuid> = HashSet::new();
    for req in &requests {
        user_ids.insert(req.requester_id);
        user_ids.insert(req.addressee_id);
    }

    let user_store = UserStore::new(state.database.clone());
    let user_map: HashMap<Uuid, crate::database::models::User> = user_store
        .find_by_ids(&user_ids.into_iter().collect::<Vec<_>>())
        .await?
        .into_iter()
        .map(|user| (user.id, user))
        .collect();

    let infos = requests
        .into_iter()
        .filter_map(|request| {
            let requester = user_map.get(&request.requester_id)?;
            let addressee = user_map.get(&request.addressee_id)?;
            Some(db_friend_request_to_api(
                &request,
                requester,
                addressee,
                &current_user_id,
            ))
        })
        .collect();

    Ok(Json(infos))
}

/// 响应好友请求
pub async fn respond_friend_request(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(request_id_str): Path<String>,
    Json(payload): Json<RespondFriendRequest>,
) -> Result<Json<FriendRequestInfo>, AppError> {
    let request_id = string_to_uuid(&request_id_str)
        .map_err(|e| AppError::ValidationError(format!("无效的请求ID: {}", e)))?;
    let responder_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let new_status = match payload.action {
        FriendRequestAction::Accept => DbFriendRequestStatus::Accepted,
        FriendRequestAction::Decline => DbFriendRequestStatus::Declined,
    };

    let friend_store = FriendStore::new(state.database.clone());
    let request = friend_store
        .respond_request(request_id, responder_id, new_status.clone())
        .await?;

    let user_store = UserStore::new(state.database.clone());
    let users = user_store
        .find_by_ids(&[request.requester_id, request.addressee_id])
        .await?;

    let mut user_map: HashMap<Uuid, crate::database::models::User> =
        users.into_iter().map(|user| (user.id, user)).collect();

    let requester = user_map
        .remove(&request.requester_id)
        .ok_or_else(|| AppError::InternalError("请求人信息缺失".to_string()))?;
    let addressee = user_map
        .remove(&request.addressee_id)
        .ok_or_else(|| AppError::InternalError("接收人信息缺失".to_string()))?;

    if new_status == DbFriendRequestStatus::Accepted {
        let room_store = RoomStore::new(state.database.pool());
        let requester_display = requester
            .nickname
            .clone()
            .filter(|name| !name.is_empty())
            .unwrap_or_else(|| requester.username.clone());
        let addressee_display = addressee
            .nickname
            .clone()
            .filter(|name| !name.is_empty())
            .unwrap_or_else(|| addressee.username.clone());
        let room_name = format!("{} & {}", requester_display, addressee_display);

        let room = room_store
            .ensure_private_room(request.requester_id, request.addressee_id, room_name)
            .await?;

        let trimmed = request
            .message
            .as_ref()
            .map(|msg| msg.trim())
            .unwrap_or_default();

        let (sender_id, content, message_type) = if trimmed.is_empty() {
            (
                request.requester_id,
                format!("你与 {} 已成为好友，开始聊天吧！", addressee_display),
                MessageType::System,
            )
        } else {
            (request.requester_id, trimmed.to_string(), MessageType::Text)
        };

        let message_store = MessageStore::new(state.database.pool());
        let created_message = message_store
            .create_message(room.id, sender_id, content, message_type.clone(), None)
            .await?;

        match message_store
            .get_message_with_sender(created_message.id)
            .await?
        {
            Some(enriched) => {
                if let Err(err) = broadcast_message_to_room(&state, &enriched).await {
                    warn!(
                        "Failed to broadcast welcome message for room {}: {}",
                        room.id, err
                    );
                }
            }
            None => warn!(
                "Created welcome message {} for room {} but failed to load enriched data",
                created_message.id, room.id
            ),
        }
    }

    let info = db_friend_request_to_api(&request, &requester, &addressee, &responder_id);

    notify_pending_count(&state, &friend_store, request.addressee_id).await?;
    notify_pending_count(&state, &friend_store, request.requester_id).await?;

    Ok(Json(info))
}

async fn notify_pending_count(
    state: &AppState,
    friend_store: &FriendStore,
    user_id: Uuid,
) -> Result<(), AppError> {
    let pending = friend_store.count_pending_incoming(user_id).await?;
    state
        .connection_manager
        .send_to_user(
            &user_id.to_string(),
            json!({
                "type": "friend_request_update",
                "pending_count": pending
            }),
        )
        .await;
    Ok(())
}

#[derive(serde::Serialize)]
pub struct EnsureChatResponse {
    pub room_id: String,
    pub room_name: String,
    pub room_type: crate::models::RoomType,
    pub friend_id: String,
    pub friend_name: String,
    pub friend_avatar: Option<String>,
}

/// 确保与好友的私聊房间存在
pub async fn ensure_private_chat(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(friend_user_id_str): Path<String>,
) -> Result<Json<EnsureChatResponse>, AppError> {
    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;
    let friend_user_id = string_to_uuid(&friend_user_id_str)
        .map_err(|e| AppError::ValidationError(format!("无效的好友ID: {}", e)))?;

    if current_user_id == friend_user_id {
        return Err(AppError::ValidationError("不能与自己创建聊天".to_string()));
    }

    let user_store = UserStore::new(state.database.clone());
    let current_user = user_store
        .find_by_id(&current_user_id)
        .await?
        .ok_or_else(|| AppError::NotFound("当前用户不存在".to_string()))?;
    let friend_user = user_store
        .find_by_id(&friend_user_id)
        .await?
        .ok_or_else(|| AppError::NotFound("好友不存在或已被停用".to_string()))?;

    let current_display = current_user
        .nickname
        .clone()
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| current_user.username.clone());
    let friend_display = friend_user
        .nickname
        .clone()
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| friend_user.username.clone());

    let room_name = format!("{} · {}", current_display, friend_display);

    let room_store = RoomStore::new(state.database.pool());
    let room = room_store
        .ensure_private_room(current_user_id, friend_user_id, room_name.clone())
        .await?;

    let response = EnsureChatResponse {
        room_id: room.id.to_string(),
        room_name: room.name.clone(),
        room_type: db_room_type_to_api(&room.room_type),
        friend_id: friend_user.id.to_string(),
        friend_name: friend_display,
        friend_avatar: friend_user.avatar_url.clone(),
    };

    Ok(Json(response))
}

/// 好友列表
pub async fn list_friends(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<FriendInfo>>, AppError> {
    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let friend_store = FriendStore::new(state.database.clone());
    let friendships = friend_store.list_friendships(current_user_id).await?;

    if friendships.is_empty() {
        return Ok(Json(Vec::new()));
    }

    let friend_ids: Vec<Uuid> = friendships
        .iter()
        .map(|record| record.friend_user_id)
        .collect();

    let user_store = UserStore::new(state.database.clone());
    let user_map: HashMap<Uuid, crate::database::models::User> = user_store
        .find_by_ids(&friend_ids)
        .await?
        .into_iter()
        .map(|user| (user.id, user))
        .collect();

    let infos = friendships
        .into_iter()
        .filter_map(|record| {
            let friend_user = user_map.get(&record.friend_user_id)?;
            Some(db_friendship_to_api(&record.friendship, friend_user))
        })
        .collect();

    Ok(Json(infos))
}
