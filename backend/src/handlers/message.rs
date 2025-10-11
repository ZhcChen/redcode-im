use axum::{
    extract::{Path, State, Query, Extension},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::Utc;

use crate::{AppState};
use crate::database::{message_store::MessageStore, models::{Message, MessageType}};
use crate::redis::{models::{CrossNodeMessage, MessagePriority, CacheKeys}, streams::StreamManager};
use ::redis::AsyncCommands;

#[derive(Deserialize)]
pub struct SendMessagePayload {
    pub content: String,
    #[serde(default)]
    pub message_type: Option<MessageType>,
}

#[derive(Deserialize)]
pub struct ListParams { pub limit: Option<i64> }

#[derive(Serialize)]
pub struct SendMessageResponse { pub message: Message }

pub async fn send_message(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(claims): Extension<crate::models::Claims>,
    Json(payload): Json<SendMessagePayload>,
) -> Result<Json<SendMessageResponse>, (StatusCode, String)> {
    let sender_id = Uuid::parse_str(&claims.sub).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid user id".to_string()))?;

    let store = MessageStore::new(state.database.pool());

    // 确认成员资格
    let in_room = store.user_in_room(room_id, sender_id).await.map_err(internal_error)?;
    if !in_room { return Err((StatusCode::FORBIDDEN, "Not a room member".to_string())); }

    let msg_type = payload.message_type.unwrap_or(MessageType::Text);
    let created = store.create_message(room_id, sender_id, payload.content.clone(), msg_type.clone()).await.map_err(internal_error)?;

    // 发布到 Redis Pub/Sub
    if let Ok(mut conn) = state.redis.get_pubsub_client().get_async_connection().await {
        let channel = CacheKeys::pubsub_channel(&room_id);
        let payload = serde_json::to_string(&CrossNodeMessage {
            id: created.id,
            room_id,
            sender_id,
            content: created.content.clone(),
            message_type: msg_type.clone(),
            priority: MessagePriority::Normal,
            timestamp: Utc::now(),
            source_node: state.node_id.clone(),
            target_nodes: vec![],
        }).unwrap();
        let _: Result<i32, _> = conn.publish(&channel, payload).await;
    }

    // 高优先级消息才入 Stream（此处保留接口，默认 Normal 不入流）
    let _ = StreamManager::new(state.redis.get_streams_client().clone(), state.node_id.clone())
        .send_message(&CrossNodeMessage {
            id: created.id,
            room_id,
            sender_id,
            content: created.content.clone(),
            message_type: msg_type,
            priority: MessagePriority::Normal,
            timestamp: Utc::now(),
            source_node: state.node_id.clone(),
            target_nodes: vec![],
        }).await;

    Ok(Json(SendMessageResponse { message: created }))
}

pub async fn list_messages(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Query(params): Query<ListParams>,
    Extension(claims): Extension<crate::models::Claims>,
) -> Result<Json<Vec<Message>>, (StatusCode, String)> {
    let user_id = Uuid::parse_str(&claims.sub).map_err(|_| (StatusCode::BAD_REQUEST, "Invalid user id".to_string()))?;
    let store = MessageStore::new(state.database.pool());

    let in_room = store.user_in_room(room_id, user_id).await.map_err(internal_error)?;
    if !in_room { return Err((StatusCode::FORBIDDEN, "Not a room member".to_string())); }

    let limit = params.limit.unwrap_or(50).clamp(1, 200);
    let items = store.get_room_messages(room_id, limit).await.map_err(internal_error)?;
    Ok(Json(items))
}

fn internal_error<E: std::fmt::Display>(e: E) -> (StatusCode, String) {
    (StatusCode::INTERNAL_SERVER_ERROR, e.to_string())
}
