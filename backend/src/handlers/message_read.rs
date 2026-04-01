use axum::{
    extract::{Path, State},
    Extension, Json,
};
use serde_json::json;

use crate::{
    database::{message_read_store::MessageReadStore, message_store::MessageStore},
    error::AppError,
    models::{convert::*, Claims, MarkMessageReadRequest, MessageReadInfo, UnreadCount},
    redis::models::{CacheKeys, PubSubPayload, ReadReceiptEvent},
    AppState,
};
use ::redis::AsyncCommands;
use chrono::Utc;
use tracing::error;
use uuid::Uuid;

pub async fn mark_message_read(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<String>,
    Json(payload): Json<MarkMessageReadRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = string_to_uuid(&claims.sub)?;
    let room_id = string_to_uuid(&room_id)?;
    let message_id = string_to_uuid(&payload.message_id)?;

    let message_store = MessageStore::new(&state.database.pool);
    if !message_store.user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(String::new()).with_message_key("room.membership_required"));
    }

    let read_store = MessageReadStore::new(&state.database.pool);
    let _read = read_store
        .mark_message_read(message_id, user_id, room_id)
        .await?;

    if let Err(e) = publish_read_receipt(&state, room_id, user_id, message_id, Utc::now()).await {
        error!(
            "广播已读回执失败: room={}, message={}, user={}, err={}",
            room_id, message_id, user_id, e
        );
    }

    Ok(Json(json!({
        "success": true,
        "message": "ok"
    })))
}

pub async fn mark_messages_read_until(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<String>,
    Json(payload): Json<MarkMessageReadRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = string_to_uuid(&claims.sub)?;
    let room_id = string_to_uuid(&room_id)?;
    let message_id = string_to_uuid(&payload.message_id)?;

    let message_store = MessageStore::new(&state.database.pool);
    if !message_store.user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(String::new()).with_message_key("room.membership_required"));
    }

    let read_store = MessageReadStore::new(&state.database.pool);
    let count = read_store
        .mark_messages_read_until(room_id, user_id, message_id)
        .await?;

    if let Err(e) = publish_read_receipt(&state, room_id, user_id, message_id, Utc::now()).await {
        error!(
            "广播区间已读回执失败: room={}, message={}, user={}, err={}",
            room_id, message_id, user_id, e
        );
    }

    Ok(Json(json!({
        "success": true,
        "message": "ok",
        "count": count
    })))
}

pub async fn get_message_read_list(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, message_id)): Path<(String, String)>,
) -> Result<Json<Vec<MessageReadInfo>>, AppError> {
    let user_id = string_to_uuid(&claims.sub)?;
    let room_id = string_to_uuid(&room_id)?;
    let message_id = string_to_uuid(&message_id)?;

    let message_store = MessageStore::new(&state.database.pool);
    if !message_store.user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(String::new()).with_message_key("room.membership_required"));
    }

    let read_store = MessageReadStore::new(&state.database.pool);
    let read_users = read_store.get_message_read_users(message_id).await?;

    let read_list: Vec<MessageReadInfo> = read_users
        .into_iter()
        .map(|(user, read_at)| MessageReadInfo {
            user_id: user.id.to_string(),
            username: user.username,
            nickname: user.nickname,
            avatar_url: user.avatar_url,
            read_at: read_at.to_rfc3339(),
        })
        .collect();

    Ok(Json(read_list))
}

pub async fn get_unread_count(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<String>,
) -> Result<Json<UnreadCount>, AppError> {
    let user_id = string_to_uuid(&claims.sub)?;
    let room_id_uuid = string_to_uuid(&room_id)?;

    let message_store = MessageStore::new(&state.database.pool);
    if !message_store.user_in_room(room_id_uuid, user_id).await? {
        return Err(AppError::Forbidden(String::new()).with_message_key("room.membership_required"));
    }

    let read_store = MessageReadStore::new(&state.database.pool);
    let unread_count = read_store.get_unread_count(room_id_uuid, user_id).await?;

    let last_read_info: Option<(Option<uuid::Uuid>, Option<chrono::DateTime<chrono::Utc>>)> =
        sqlx::query_as(
            "SELECT last_read_message_id, last_read_at FROM room_members
         WHERE room_id = $1 AND user_id = $2 AND deleted_at IS NULL",
        )
        .bind(room_id_uuid)
        .bind(user_id)
        .fetch_optional(&state.database.pool)
        .await?;

    let (last_read_message_id, last_read_at) = last_read_info.unwrap_or((None, None));

    Ok(Json(UnreadCount {
        room_id,
        unread_count,
        last_read_message_id: last_read_message_id.map(|id| id.to_string()),
        last_read_at: last_read_at.map(|dt| dt.to_rfc3339()),
    }))
}

pub async fn get_all_unread_counts(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<UnreadCount>>, AppError> {
    let user_id = string_to_uuid(&claims.sub)?;

    let read_store = MessageReadStore::new(&state.database.pool);
    let unread_counts = read_store.get_all_unread_counts(user_id).await?;

    let result: Vec<UnreadCount> = unread_counts
        .into_iter()
        .map(|(room_id, count, last_msg_id, last_read_at)| UnreadCount {
            room_id: room_id.to_string(),
            unread_count: count,
            last_read_message_id: last_msg_id.map(|id| id.to_string()),
            last_read_at: last_read_at.map(|dt| dt.to_rfc3339()),
        })
        .collect();

    Ok(Json(result))
}

async fn publish_read_receipt(
    state: &AppState,
    room_id: Uuid,
    reader_id: Uuid,
    message_id: Uuid,
    read_at: chrono::DateTime<Utc>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let payload = PubSubPayload::ReadReceipt {
        data: ReadReceiptEvent {
            room_id,
            reader_id,
            message_id,
            read_at,
            source_node: state.node_id.clone(),
        },
    };

    let serialized = payload.encode_protobuf();
    let channel = CacheKeys::pubsub_channel(&room_id);

    let mut conn = state
        .redis
        .get_pubsub_client()
        .get_multiplexed_async_connection()
        .await?;
    let _: i64 = conn.publish(&channel, serialized).await?;

    Ok(())
}
