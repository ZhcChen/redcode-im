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
use crate::redis::{
    models::{CacheKeys, CrossNodeMessage, MessagePriority, PubSubPayload},
    streams::StreamManager,
};
use crate::AppState;
use ::redis::AsyncCommands;

#[derive(Deserialize)]
pub struct SendMessagePayload {
    pub content: String,
    #[serde(default)]
    pub message_type: Option<MessageType>,
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
    } = payload;

    let content = content.trim();
    if content.is_empty() {
        return Err(AppError::ValidationError("消息内容不能为空".to_string()));
    }

    let message_type = message_type.unwrap_or(MessageType::Text);
    let created = store
        .create_message(
            room_id,
            sender_id,
            content.to_string(),
            message_type.clone(),
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

    // 高优先级消息才入 Stream（此处保留接口，默认 Normal 不入流）
    // Stream用于消息持久化和离线消息等场景
    let _ = StreamManager::new(
        state.redis.get_streams_client().clone(),
        state.node_id.clone(),
    )
    .send_message(&CrossNodeMessage {
        id: enriched.id,
        room_id,
        sender_id,
        content: enriched.content.clone(),
        message_type: message_type.clone(),
        priority: MessagePriority::Normal,
        timestamp: enriched.created_at,
        source_node: state.node_id.clone(),
        target_nodes: vec![],
        sender_username: Some(enriched.sender_username.clone()),
        sender_nickname: enriched.sender_nickname.clone(),
        sender_avatar_url: enriched.sender_avatar_url.clone(),
    })
    .await;

    let api_message = db_message_to_api_message_info(&enriched);
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

    let messages = items
        .into_iter()
        .map(|msg| db_message_to_api_message_info(&msg))
        .collect();

    Ok(Json(messages))
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
    };

    let payload = serde_json::to_string(&PubSubPayload::Message {
        data: redis_message,
    })?;
    let channel = CacheKeys::pubsub_channel(&message.room_id);

    // 发布到Redis
    let mut conn = state
        .redis
        .get_pubsub_client()
        .get_async_connection()
        .await?;
    let subscriber_count: i64 = conn.publish(&channel, &payload).await?;

    info!(
        "消息 {} 已广播到房间 {} ({} 个订阅者)",
        message.id, message.room_id, subscriber_count
    );

    Ok(())
}
