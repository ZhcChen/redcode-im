use std::{
    collections::{HashMap, HashSet},
    convert::TryFrom,
};

use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
};
use serde::Deserialize;
use tracing::warn;
use uuid::Uuid;

use crate::database::friend_store::{FriendRequestDirection, FriendStore};
use crate::database::message_store::MessageStore;
use crate::database::models::{FriendRequestStatus as DbFriendRequestStatus, MessageType};
use crate::database::room_store::RoomStore;
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::handlers::message::broadcast_message_to_room;
use crate::i18n::message::MessageParams;
use crate::models::convert::{
    db_friend_request_to_api, db_friendship_to_api, db_room_type_to_api, string_to_uuid,
};
use crate::models::{
    Claims, CreateFriendRequest, FriendInfo, FriendRequestAction, FriendRequestInfo,
    RespondFriendRequest,
};
use crate::websocket::ServerPush;
use crate::AppState;

#[derive(Debug, Deserialize)]
pub struct FriendRequestQuery {
    pub direction: Option<String>,
    pub status: Option<String>,
}

fn friend_validation_error(message_key: &'static str) -> AppError {
    AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn friend_validation_error_with_params(
    message_key: &'static str,
    params: MessageParams,
) -> AppError {
    AppError::ValidationError(String::new()).with_message_key_and_params(message_key, Some(params))
}

fn friend_invalid_token_error(message_key: &'static str) -> AppError {
    AppError::InvalidToken(String::new()).with_message_key(message_key)
}

fn friend_not_found_error(message_key: &'static str) -> AppError {
    AppError::NotFound(String::new()).with_message_key(message_key)
}

fn friend_internal_error(message_key: &'static str) -> AppError {
    AppError::InternalError(String::new()).with_message_key(message_key)
}

/// 创建好友请求
pub async fn create_friend_request(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<CreateFriendRequest>,
) -> Result<Json<FriendRequestInfo>, AppError> {
    let requester_id = string_to_uuid(&claims.sub)
        .map_err(|_| friend_invalid_token_error("auth.token_subject_invalid"))?;
    let target_user_id = string_to_uuid(&payload.target_user_id)
        .map_err(|_| friend_validation_error("friend.target_user_id_invalid"))?;

    if requester_id == target_user_id {
        return Err(friend_validation_error("friend.cannot_add_self"));
    }

    let user_store = UserStore::new(state.database.clone());
    let target_user = user_store
        .find_by_id(&target_user_id)
        .await?
        .ok_or_else(|| friend_not_found_error("friend.target_user_not_found"))?;

    let current_user = user_store
        .find_by_id(&requester_id)
        .await?
        .ok_or_else(|| friend_not_found_error("friend.current_user_not_found"))?;

    let friend_store = FriendStore::new(state.database.clone());
    let request = friend_store
        .create_request(requester_id, target_user_id, payload.message.clone())
        .await?;

    let info = db_friend_request_to_api(&request, &current_user, &target_user, &requester_id);

    notify_pending_count(&state, &friend_store, request.addressee_id).await?;
    notify_pending_count(&state, &friend_store, requester_id).await?;

    let request_id = request.id;
    let requester_name = current_user
        .nickname
        .clone()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| current_user.username.clone());
    let request_message = request.message.clone();
    crate::services::push::enqueue_friend_request(
        &state,
        request_id,
        requester_id,
        requester_name,
        target_user_id,
        request_message,
    )
    .await;

    Ok(Json(info))
}

/// 列出好友请求
pub async fn list_friend_requests(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Query(params): Query<FriendRequestQuery>,
) -> Result<Json<Vec<FriendRequestInfo>>, AppError> {
    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|_| friend_invalid_token_error("auth.token_subject_invalid"))?;

    let direction = parse_direction(params.direction.as_deref())?;
    let status = parse_status(params.status.as_deref())?;

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
        .map_err(|_| friend_validation_error("friend.request_id_invalid"))?;
    let responder_id = string_to_uuid(&claims.sub)
        .map_err(|_| friend_invalid_token_error("auth.token_subject_invalid"))?;

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
        .ok_or_else(|| friend_internal_error("friend.requester_profile_missing"))?;
    let addressee = user_map
        .remove(&request.addressee_id)
        .ok_or_else(|| friend_internal_error("friend.addressee_profile_missing"))?;

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
                let mut part_ids = vec![enriched.id];
                if let Some(qid) = enriched.quoted_message_id {
                    part_ids.push(qid);
                }
                let parts_map = message_store.get_message_parts_map(&part_ids).await?;

                if let Err(err) = broadcast_message_to_room(&state, &enriched, &parts_map).await {
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
    let pending_i32 = i32::try_from(pending).unwrap_or(i32::MAX);
    let payload = ServerPush::FriendRequestUpdate {
        pending_count: pending_i32,
    };
    state
        .connection_manager
        .send_to_user(&user_id.to_string(), payload)
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
    pub friend_avatar_object_key: Option<String>,
}

/// 确保与好友的私聊房间存在
pub async fn ensure_private_chat(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(friend_user_id_str): Path<String>,
) -> Result<Json<EnsureChatResponse>, AppError> {
    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|_| friend_invalid_token_error("auth.token_subject_invalid"))?;
    let friend_user_id = string_to_uuid(&friend_user_id_str)
        .map_err(|_| friend_validation_error("friend.friend_user_id_invalid"))?;

    if current_user_id == friend_user_id {
        return Err(friend_validation_error("friend.cannot_chat_with_self"));
    }

    let user_store = UserStore::new(state.database.clone());
    let _current_user = user_store
        .find_by_id(&current_user_id)
        .await?
        .ok_or_else(|| friend_not_found_error("friend.current_user_not_found"))?;
    let friend_user = user_store
        .find_by_id(&friend_user_id)
        .await?
        .ok_or_else(|| friend_not_found_error("friend.friend_user_not_found"))?;

    // 使用好友的显示名称作为房间名称（昵称优先，否则使用用户名）
    let friend_display = friend_user
        .nickname
        .clone()
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| friend_user.username.clone());

    let room_name = friend_display.clone();

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
        friend_avatar_object_key: friend_user.avatar_object_key.clone(),
    };

    Ok(Json(response))
}

/// 好友列表
pub async fn list_friends(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<FriendInfo>>, AppError> {
    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|_| friend_invalid_token_error("auth.token_subject_invalid"))?;

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
            Some(db_friendship_to_api(&record, friend_user))
        })
        .collect();

    Ok(Json(infos))
}

#[derive(serde::Deserialize)]
pub struct UpdateRemarkRequest {
    pub remark: Option<String>,
}

#[derive(serde::Serialize)]
pub struct UpdateRemarkResponse {
    pub remark: Option<String>,
}

#[derive(serde::Serialize)]
pub struct DeleteFriendResponse {
    pub success: bool,
    pub message: String,
}

/// 更新好友备注
pub async fn update_friend_remark(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(friend_user_id_str): Path<String>,
    Json(payload): Json<UpdateRemarkRequest>,
) -> Result<Json<UpdateRemarkResponse>, AppError> {
    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|_| friend_invalid_token_error("auth.token_subject_invalid"))?;
    let friend_user_id = string_to_uuid(&friend_user_id_str)
        .map_err(|_| friend_validation_error("friend.friend_user_id_invalid"))?;

    if current_user_id == friend_user_id {
        return Err(friend_validation_error("friend.cannot_set_self_remark"));
    }

    let friend_store = FriendStore::new(state.database.clone());
    let remark = friend_store
        .upsert_friend_remark(current_user_id, friend_user_id, payload.remark)
        .await?;

    Ok(Json(UpdateRemarkResponse { remark }))
}

/// 删除好友
pub async fn delete_friend(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(friend_user_id_str): Path<String>,
) -> Result<Json<DeleteFriendResponse>, AppError> {
    let current_user_id = string_to_uuid(&claims.sub)
        .map_err(|_| friend_invalid_token_error("auth.token_subject_invalid"))?;
    let friend_user_id = string_to_uuid(&friend_user_id_str)
        .map_err(|_| friend_validation_error("friend.friend_user_id_invalid"))?;

    if current_user_id == friend_user_id {
        return Err(friend_validation_error("friend.cannot_delete_self"));
    }

    let friend_store = FriendStore::new(state.database.clone());
    let deleted = friend_store
        .delete_friendship(current_user_id, friend_user_id)
        .await?;

    if !deleted {
        return Err(friend_not_found_error("friend.friendship_not_found"));
    }

    // 向双方推送好友删除事件
    let current_id_str = current_user_id.to_string();
    let friend_id_str = friend_user_id.to_string();

    let event_for_current = ServerPush::FriendshipDeleted {
        user_id: friend_id_str.clone(),
    };
    let event_for_friend = ServerPush::FriendshipDeleted {
        user_id: current_id_str.clone(),
    };

    state
        .connection_manager
        .send_to_user(&current_id_str, event_for_current)
        .await;

    state
        .connection_manager
        .send_to_user(&friend_id_str, event_for_friend)
        .await;

    Ok(Json(DeleteFriendResponse {
        success: true,
        message: "删除好友成功".to_string(),
    }))
}

// ============================================================================
// 验证辅助函数（可测试的纯逻辑）
// ============================================================================

/// 解析好友请求方向参数
pub fn parse_direction(
    direction: Option<&str>,
) -> Result<Option<FriendRequestDirection>, AppError> {
    match direction {
        None | Some("") => Ok(None),
        Some("incoming") => Ok(Some(FriendRequestDirection::Incoming)),
        Some("outgoing") => Ok(Some(FriendRequestDirection::Outgoing)),
        Some(other) => Err(friend_validation_error_with_params(
            "friend.direction_invalid",
            MessageParams::from([("direction".to_string(), other.to_string())]),
        )),
    }
}

/// 解析好友请求状态参数
pub fn parse_status(status: Option<&str>) -> Result<Option<DbFriendRequestStatus>, AppError> {
    match status {
        None | Some("") => Ok(None),
        Some("pending") => Ok(Some(DbFriendRequestStatus::Pending)),
        Some("accepted") => Ok(Some(DbFriendRequestStatus::Accepted)),
        Some("declined") => Ok(Some(DbFriendRequestStatus::Declined)),
        Some(other) => Err(friend_validation_error_with_params(
            "friend.status_invalid",
            MessageParams::from([("status".to_string(), other.to_string())]),
        )),
    }
}

/// 检查是否为自身操作（不允许对自己进行好友操作）
pub fn validate_not_self_operation(current_user_id: &Uuid, target_user_id: &Uuid) -> bool {
    current_user_id != target_user_id
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::i18n::message::MessageParams;

    // ========================================================================
    // 方向参数解析测试
    // ========================================================================

    #[test]
    fn test_parse_direction_none() {
        let result = parse_direction(None);
        assert!(result.is_ok());
        assert!(result.unwrap().is_none());
    }

    #[test]
    fn test_parse_direction_empty() {
        let result = parse_direction(Some(""));
        assert!(result.is_ok());
        assert!(result.unwrap().is_none());
    }

    #[test]
    fn test_parse_direction_incoming() {
        let result = parse_direction(Some("incoming"));
        assert!(result.is_ok());
        assert!(matches!(
            result.unwrap(),
            Some(FriendRequestDirection::Incoming)
        ));
    }

    #[test]
    fn test_parse_direction_outgoing() {
        let result = parse_direction(Some("outgoing"));
        assert!(result.is_ok());
        assert!(matches!(
            result.unwrap(),
            Some(FriendRequestDirection::Outgoing)
        ));
    }

    #[test]
    fn test_parse_direction_invalid() {
        let result = parse_direction(Some("invalid"));
        assert!(result.is_err());
        let error = result.unwrap_err();
        assert_eq!(error.message_key(), "common.validation_error");
        assert_eq!(error.response_message_key(), "friend.direction_invalid");
        let params = error
            .message_params()
            .expect("direction invalid should include params");
        assert_eq!(
            params
                .get("direction")
                .expect("direction param should be present"),
            "invalid"
        );
    }

    #[test]
    fn test_friend_validation_error_uses_friend_domain_message_key() {
        let error = friend_validation_error("friend.cannot_add_self");
        assert_eq!(error.message_key(), "common.validation_error");
        assert_eq!(error.response_message_key(), "friend.cannot_add_self");
        assert_eq!(error.message_params(), None);
    }

    #[test]
    fn test_friend_invalid_token_error_can_reuse_auth_domain_message_key() {
        let error = friend_invalid_token_error("auth.token_subject_invalid");
        assert_eq!(error.message_key(), "auth.invalid_token");
        assert_eq!(error.response_message_key(), "auth.token_subject_invalid");
        assert_eq!(error.message_params(), None);
    }

    // ========================================================================
    // 状态参数解析测试
    // ========================================================================

    #[test]
    fn test_parse_status_none() {
        let result = parse_status(None);
        assert!(result.is_ok());
        assert!(result.unwrap().is_none());
    }

    #[test]
    fn test_parse_status_empty() {
        let result = parse_status(Some(""));
        assert!(result.is_ok());
        assert!(result.unwrap().is_none());
    }

    #[test]
    fn test_parse_status_pending() {
        let result = parse_status(Some("pending"));
        assert!(result.is_ok());
        assert!(matches!(
            result.unwrap(),
            Some(DbFriendRequestStatus::Pending)
        ));
    }

    #[test]
    fn test_parse_status_accepted() {
        let result = parse_status(Some("accepted"));
        assert!(result.is_ok());
        assert!(matches!(
            result.unwrap(),
            Some(DbFriendRequestStatus::Accepted)
        ));
    }

    #[test]
    fn test_parse_status_declined() {
        let result = parse_status(Some("declined"));
        assert!(result.is_ok());
        assert!(matches!(
            result.unwrap(),
            Some(DbFriendRequestStatus::Declined)
        ));
    }

    #[test]
    fn test_parse_status_invalid() {
        let result = parse_status(Some("unknown"));
        assert!(result.is_err());
        let error = result.unwrap_err();
        assert_eq!(error.message_key(), "common.validation_error");
        assert_eq!(error.response_message_key(), "friend.status_invalid");
        let params = error
            .message_params()
            .expect("status invalid should include params");
        assert_eq!(
            params
                .get("status")
                .expect("status param should be present"),
            "unknown"
        );
    }

    #[test]
    fn test_friend_validation_error_with_params_preserves_message_params() {
        let params = MessageParams::from([("status".to_string(), "archived".to_string())]);
        let error = friend_validation_error_with_params("friend.status_invalid", params.clone());
        assert_eq!(error.message_key(), "common.validation_error");
        assert_eq!(error.response_message_key(), "friend.status_invalid");
        assert_eq!(error.message_params(), Some(params));
    }

    // ========================================================================
    // 自身操作验证测试
    // ========================================================================

    #[test]
    fn test_validate_not_self_operation_different_users() {
        let user1 = Uuid::new_v4();
        let user2 = Uuid::new_v4();
        assert!(validate_not_self_operation(&user1, &user2));
    }

    #[test]
    fn test_validate_not_self_operation_same_user() {
        let user = Uuid::new_v4();
        assert!(!validate_not_self_operation(&user, &user));
    }

    #[test]
    fn test_validate_not_self_operation_with_specific_uuids() {
        let user1 = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440000").unwrap();
        let user2 = Uuid::parse_str("550e8400-e29b-41d4-a716-446655440001").unwrap();
        assert!(validate_not_self_operation(&user1, &user2));
        assert!(!validate_not_self_operation(&user1, &user1));
    }
}
