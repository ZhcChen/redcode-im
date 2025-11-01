use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use tracing::{error, info};
use uuid::Uuid;

use crate::database::{
    message_store::MessageStore,
    models::{MessageType, MessageWithSender},
};
use crate::error::AppError;
use crate::models::{convert::db_message_to_api_message_info, MessageInfo};
use crate::redis::models::{
    CacheKeys, CrossNodeMessage, ForwardMessagePayload, MessagePriority, MessageUpdatePayload,
    PinUpdatePayload, PubSubPayload, QuotedMessagePayload,
};
use crate::AppState;
use ::redis::AsyncCommands;

#[derive(Deserialize)]
pub struct SendMessagePayload {
    pub content: String,
    #[serde(default)]
    pub message_type: Option<MessageType>,
    #[serde(default)]
    pub quoted_message_id: Option<Uuid>,
}

#[derive(Deserialize)]
pub struct ForwardMessageRequest {
    pub original_message_id: Uuid,
}

#[derive(Deserialize)]
pub struct ListParams {
    pub limit: Option<i64>,
    pub before_id: Option<Uuid>,
    pub since_id: Option<Uuid>,
}

#[derive(Serialize)]
pub struct SendMessageResponse {
    pub message: MessageInfo,
}

#[derive(Serialize)]
pub struct PinMessageResponse {
    pub room_id: String,
    pub is_pinned: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<MessageInfo>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pinned_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pinned_by: Option<String>,
}

pub async fn send_message(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(claims): Extension<crate::models::Claims>,
    Json(payload): Json<SendMessagePayload>,
) -> Result<Json<SendMessageResponse>, AppError> {
    let sender_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = MessageStore::new(state.database.pool());

    // 确认成员资格
    let in_room = store.user_in_room(room_id, sender_id).await?;
    if !in_room {
        return Err(AppError::Forbidden(format!(
            "User {} is not a member of room {}",
            sender_id, room_id
        )));
    }

    // 简单速率限制：用户在房间内每10秒最多发送30条
    {
        let mut conn = state
            .redis
            .get_session_client()
            .get_async_connection()
            .await
            .map_err(|e| AppError::CacheError(format!("Redis connection failed: {}", e)))?;

        let key = format!("rl:send:{}:{}", sender_id, room_id);
        let count: i64 = redis::cmd("INCR")
            .arg(&key)
            .query_async(&mut conn)
            .await
            .map_err(|e| AppError::CacheError(format!("Redis INCR failed: {}", e)))?;

        if count == 1 {
            let _: () = redis::cmd("EXPIRE")
                .arg(&key)
                .arg(10)
                .query_async(&mut conn)
                .await
                .map_err(|e| AppError::CacheError(format!("Redis EXPIRE failed: {}", e)))?;
        }

        if count > 30 {
            return Err(AppError::RateLimitExceeded(
                "Message rate limit exceeded: max 30 messages per 10 seconds".to_string(),
            ));
        }
    }

    let SendMessagePayload {
        content,
        message_type,
        quoted_message_id,
    } = payload;

    let content = content.trim();
    if content.is_empty() {
        return Err(AppError::ValidationError("消息内容不能为空".to_string()));
    }

    let quoted_message_id = if let Some(quoted_id) = quoted_message_id {
        let quoted = store
            .get_message(quoted_id)
            .await?
            .ok_or_else(|| AppError::ValidationError("引用的消息不存在".to_string()))?;

        if quoted.room_id != room_id {
            return Err(AppError::ValidationError(
                "引用消息不属于当前房间".to_string(),
            ));
        }

        if quoted.deleted_at.is_some() {
            return Err(AppError::ValidationError("引用的消息已被删除".to_string()));
        }

        Some(quoted_id)
    } else {
        None
    };

    let message_type = message_type.unwrap_or(MessageType::Text);
    let created = store
        .create_message(
            room_id,
            sender_id,
            content.to_string(),
            message_type.clone(),
            quoted_message_id,
        )
        .await?;

    let enriched = store
        .get_message_with_sender(created.id)
        .await?
        .ok_or_else(|| AppError::InternalError("新消息加载失败".to_string()))?;

    // 实时广播到房间内所有WebSocket连接（通过Redis Pub/Sub）
    if let Err(e) = broadcast_message_to_room(&state, &enriched).await {
        error!("广播消息失败: {}", e);
    }

    let api_message = db_message_to_api_message_info(&enriched, None);
    Ok(Json(SendMessageResponse {
        message: api_message,
    }))
}

pub async fn forward_message(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(claims): Extension<crate::models::Claims>,
    Json(payload): Json<ForwardMessageRequest>,
) -> Result<Json<SendMessageResponse>, AppError> {
    let sender_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = MessageStore::new(state.database.pool());

    if !store.user_in_room(room_id, sender_id).await? {
        return Err(AppError::Forbidden(
            "用户不在目标房间，无法转发消息".to_string(),
        ));
    }

    let original = store
        .get_message_with_sender(payload.original_message_id)
        .await?
        .ok_or_else(|| AppError::ValidationError("原消息不存在或已被删除".to_string()))?;

    if original.deleted_at.is_some() {
        return Err(AppError::ValidationError(
            "原消息已删除，无法转发".to_string(),
        ));
    }

    if !store.user_in_room(original.room_id, sender_id).await? {
        return Err(AppError::Forbidden("用户无权转发该消息".to_string()));
    }

    if original.message_type != MessageType::Text {
        return Err(AppError::ValidationError(
            "当前仅支持转发文本消息".to_string(),
        ));
    }

    let created = store
        .create_forward_message(room_id, sender_id, &original)
        .await?;

    let enriched = store
        .get_message_with_sender(created.id)
        .await?
        .ok_or_else(|| AppError::InternalError("转发消息加载失败".to_string()))?;

    if let Err(e) = broadcast_message_to_room(&state, &enriched).await {
        error!("广播转发消息失败: {}", e);
    }

    let api_message = db_message_to_api_message_info(&enriched, None);
    Ok(Json(SendMessageResponse {
        message: api_message,
    }))
}

pub async fn list_messages(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Query(params): Query<ListParams>,
    Extension(claims): Extension<crate::models::Claims>,
) -> Result<Json<Vec<MessageInfo>>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = MessageStore::new(state.database.pool());

    let in_room = store.user_in_room(room_id, user_id).await?;
    if !in_room {
        return Err(AppError::Forbidden(format!(
            "User {} is not a member of room {}",
            user_id, room_id
        )));
    }

    let limit = params.limit.unwrap_or(50).clamp(1, 200);

    if params.before_id.is_some() && params.since_id.is_some() {
        return Err(AppError::ValidationError(
            "before_id and since_id are mutually exclusive".to_string(),
        ));
    }

    let items = store
        .get_room_messages_paged(room_id, limit, params.before_id, params.since_id)
        .await?;

    let room_pin = store.get_room_pin(room_id).await?;

    let messages = items
        .into_iter()
        .map(|msg| {
            let pin_ref = room_pin.as_ref().and_then(|pin| {
                if pin.message_id == msg.id {
                    Some(pin)
                } else {
                    None
                }
            });
            db_message_to_api_message_info(&msg, pin_ref)
        })
        .collect();

    Ok(Json(messages))
}

pub async fn pin_message(
    State(state): State<AppState>,
    Path((room_id, message_id)): Path<(Uuid, Uuid)>,
    Extension(claims): Extension<crate::models::Claims>,
) -> Result<Json<PinMessageResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = MessageStore::new(state.database.pool());

    if !store.user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(
            "用户不在该房间，无法置顶消息".to_string(),
        ));
    }

    let message = store
        .get_message_with_sender(message_id)
        .await?
        .ok_or_else(|| AppError::ValidationError("消息不存在".to_string()))?;

    if message.room_id != room_id {
        return Err(AppError::ValidationError("消息不属于当前房间".to_string()));
    }
    if message.deleted_at.is_some() {
        return Err(AppError::ValidationError(
            "消息已删除，无法置顶".to_string(),
        ));
    }

    let pin = store.upsert_room_pin(room_id, message_id, user_id).await?;

    if let Err(e) = broadcast_pin_update(
        &state,
        PinUpdatePayload {
            room_id,
            message_id: Some(message_id),
            pinned_by: Some(pin.pinned_by),
            pinned_at: Some(pin.pinned_at),
            is_pinned: true,
        },
    )
    .await
    {
        error!("广播置顶消息失败: {}", e);
    }

    let api_message = db_message_to_api_message_info(&message, Some(&pin));

    Ok(Json(PinMessageResponse {
        room_id: room_id.to_string(),
        is_pinned: true,
        message: Some(api_message),
        pinned_at: Some(pin.pinned_at.to_rfc3339()),
        pinned_by: Some(pin.pinned_by.to_string()),
    }))
}

pub async fn unpin_message(
    State(state): State<AppState>,
    Path((room_id, message_id)): Path<(Uuid, Uuid)>,
    Extension(claims): Extension<crate::models::Claims>,
) -> Result<Json<PinMessageResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = MessageStore::new(state.database.pool());

    if !store.user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(
            "用户不在该房间，无法取消置顶".to_string(),
        ));
    }

    let current_pin = store.get_room_pin(room_id).await?;
    if let Some(pin) = current_pin.as_ref() {
        if pin.message_id != message_id {
            return Err(AppError::ValidationError(
                "当前置顶的不是该消息".to_string(),
            ));
        }
    } else {
        return Ok(Json(PinMessageResponse {
            room_id: room_id.to_string(),
            is_pinned: false,
            message: None,
            pinned_at: None,
            pinned_by: None,
        }));
    }

    store.remove_room_pin(room_id, Some(message_id)).await?;

    if let Err(e) = broadcast_pin_update(
        &state,
        PinUpdatePayload {
            room_id,
            message_id: Some(message_id),
            pinned_by: None,
            pinned_at: None,
            is_pinned: false,
        },
    )
    .await
    {
        error!("广播取消置顶失败: {}", e);
    }

    let message_info = store
        .get_message_with_sender(message_id)
        .await?
        .map(|msg| db_message_to_api_message_info(&msg, None));

    Ok(Json(PinMessageResponse {
        room_id: room_id.to_string(),
        is_pinned: false,
        message: message_info,
        pinned_at: None,
        pinned_by: None,
    }))
}

pub async fn delete_message(
    State(state): State<AppState>,
    Path((room_id, message_id)): Path<(Uuid, Uuid)>,
    Extension(claims): Extension<crate::models::Claims>,
) -> Result<Json<MessageInfo>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = MessageStore::new(state.database.pool());

    if !store.user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(
            "用户不在该房间，无法删除消息".to_string(),
        ));
    }

    let existing = store
        .get_message_with_sender(message_id)
        .await?
        .ok_or_else(|| AppError::ValidationError("消息不存在".to_string()))?;

    if existing.room_id != room_id {
        return Err(AppError::ValidationError("消息不属于当前房间".to_string()));
    }

    if existing.sender_id != user_id {
        return Err(AppError::Forbidden("仅支持删除自己发送的消息".to_string()));
    }

    let marked = store.mark_message_deleted(message_id).await?;
    if marked.is_none() {
        return Err(AppError::ValidationError("消息已删除".to_string()));
    }

    let current_pin = store.get_room_pin(room_id).await?;
    if let Some(pin) = current_pin.as_ref() {
        if pin.message_id == message_id {
            store.remove_room_pin(room_id, Some(message_id)).await?;
            if let Err(e) = broadcast_pin_update(
                &state,
                PinUpdatePayload {
                    room_id,
                    message_id: Some(message_id),
                    pinned_by: None,
                    pinned_at: None,
                    is_pinned: false,
                },
            )
            .await
            {
                error!("广播取消置顶失败: {}", e);
            }
        }
    }

    let updated = store
        .get_message_with_sender(message_id)
        .await?
        .ok_or_else(|| AppError::InternalError("消息删除后加载失败".to_string()))?;

    if let Err(e) = broadcast_message_update(
        &state,
        MessageUpdatePayload {
            room_id,
            message_id,
            is_deleted: true,
            deleted_at: updated.deleted_at,
        },
    )
    .await
    {
        error!("广播消息更新失败: {}", e);
    }

    let api_message = db_message_to_api_message_info(&updated, None);
    Ok(Json(api_message))
}

/// 广播消息到房间内的所有连接
pub async fn broadcast_message_to_room(
    state: &AppState,
    message: &MessageWithSender,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    // 发布到Redis Pub/Sub频道 - 所有节点都会收到
    let redis_message = CrossNodeMessage {
        id: message.id,
        room_id: message.room_id,
        sender_id: message.sender_id,
        content: message.content.clone(),
        message_type: message.message_type.clone(),
        priority: MessagePriority::Normal,
        timestamp: message.created_at,
        source_node: state.node_id.clone(),
        target_nodes: vec![], // 空表示广播给所有订阅该房间的连接
        sender_username: Some(message.sender_username.clone()),
        sender_nickname: message.sender_nickname.clone(),
        sender_avatar_url: message.sender_avatar_url.clone(),
        quoted_message: build_quoted_payload(message),
        forward_message: build_forward_payload(message),
    };

    let payload = PubSubPayload::Message {
        data: redis_message,
    };
    let encoded = payload.encode_protobuf();
    let channel = CacheKeys::pubsub_channel(&message.room_id);

    // 发布到Redis
    let mut conn = state
        .redis
        .get_pubsub_client()
        .get_async_connection()
        .await?;
    let subscriber_count: i64 = conn.publish(&channel, encoded).await?;

    info!(
        "消息 {} 已广播到房间 {} ({} 个订阅者)",
        message.id, message.room_id, subscriber_count
    );

    Ok(())
}

pub async fn broadcast_message_update(
    state: &AppState,
    payload: MessageUpdatePayload,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let channel = CacheKeys::pubsub_channel(&payload.room_id);
    let encoded = PubSubPayload::MessageUpdate { data: payload }.encode_protobuf();

    let mut conn = state
        .redis
        .get_pubsub_client()
        .get_async_connection()
        .await?;
    let subscriber_count: i64 = conn.publish(&channel, &encoded).await?;

    info!(
        "消息更新已广播到房间 {} ({} 个订阅者)",
        channel, subscriber_count
    );

    Ok(())
}

pub async fn broadcast_pin_update(
    state: &AppState,
    payload: PinUpdatePayload,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let channel = CacheKeys::pubsub_channel(&payload.room_id);
    let encoded = PubSubPayload::PinUpdate { data: payload }.encode_protobuf();

    let mut conn = state
        .redis
        .get_pubsub_client()
        .get_async_connection()
        .await?;
    let subscriber_count: i64 = conn.publish(&channel, &encoded).await?;

    info!(
        "置顶状态已广播到房间 {} ({} 个订阅者)",
        channel, subscriber_count
    );

    Ok(())
}

fn build_quoted_payload(message: &MessageWithSender) -> Option<QuotedMessagePayload> {
    let quoted_id = message.quoted_message_id?;
    let quoted_room_id = message.quoted_message_room_id.unwrap_or(message.room_id);
    let quoted_sender_id = message
        .quoted_message_sender_id
        .unwrap_or(message.sender_id);

    let message_type = message.quoted_message_type.unwrap_or(MessageType::Text);
    let is_deleted = message.quoted_message_deleted_at.is_some();
    let content = if is_deleted {
        None
    } else {
        message.quoted_message_content.clone()
    };

    Some(QuotedMessagePayload {
        id: quoted_id,
        room_id: quoted_room_id,
        sender_id: quoted_sender_id,
        sender_username: message.quoted_message_sender_username.clone(),
        sender_nickname: message.quoted_message_sender_nickname.clone(),
        sender_avatar_url: message.quoted_message_sender_avatar_url.clone(),
        content,
        message_type,
        created_at: message.quoted_message_created_at.clone(),
        is_deleted,
    })
}

fn build_forward_payload(message: &MessageWithSender) -> Option<ForwardMessagePayload> {
    let forward_id = message.forward_from_message_id?;
    let room_id = message.forward_from_room_id.unwrap_or(message.room_id);
    let sender_id = message.forward_from_sender_id.unwrap_or(message.sender_id);

    Some(ForwardMessagePayload {
        message_id: forward_id,
        room_id,
        sender_id,
        sender_username: message.forward_from_sender_username.clone(),
        sender_nickname: message.forward_from_sender_nickname.clone(),
    })
}
