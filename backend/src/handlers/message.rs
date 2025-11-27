use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{HashMap, HashSet};
use tracing::{debug, error, info};
use uuid::Uuid;

use crate::database::{
    group_management_store::GroupManagementStore,
    message_read_store::MessageReadStore,
    message_store::{MessageStore, NewMessagePart},
    models::{
        MessagePart, MessagePartType, MessageType, MessageWithSender, RoomType, StorageProvider,
        StorageProviderType,
    },
    room_store::RoomStore,
    storage_provider_store::StorageProviderStore,
};
use crate::error::AppError;
use crate::models::{
    convert::db_message_to_api_message_info, MessageDeliveryStatus, MessageInfo,
    MessagePartPayload, MessagePartType as ApiMessagePartType,
};
use crate::redis::cache::CacheManager;
use crate::redis::models::{
    CacheKeys, CrossNodeMessage, ForwardMessagePayload, MessagePartEnvelope, MessagePriority,
    MessageUpdatePayload, PinUpdatePayload, PubSubPayload, QuotedMessagePayload,
};
use crate::storage;
use crate::storage::DirectUploadSignature;
use crate::AppState;
use ::redis::AsyncCommands;
use chrono::{Duration, Utc};

#[derive(Deserialize)]
pub struct SendMessagePayload {
    pub content: Option<String>,
    #[serde(default)]
    pub parts: Vec<crate::models::MessagePartPayload>,
    #[serde(default)]
    pub quoted_message_id: Option<Uuid>,
}

struct PreparedMessagePart {
    position: i16,
    part_type: MessagePartType,
    text_content: Option<String>,
    attachment_key: Option<String>,
    attachment_name: Option<String>,
    attachment_mime: Option<String>,
    attachment_size: Option<i64>,
    width: Option<i32>,
    height: Option<i32>,
    duration_ms: Option<i32>,
    thumbnail_key: Option<String>,
    extra: Option<Value>,
}

async fn ensure_group_message_permissions(
    state: &AppState,
    room_id: Uuid,
    sender_id: Uuid,
) -> Result<(), AppError> {
    let room_store = RoomStore::new(state.database.pool());
    let room = room_store
        .get_room(room_id)
        .await
        .map_err(|_| AppError::NotFound("Room not found".to_string()))?;

    if room.room_type != RoomType::Group {
        return Ok(());
    }

    let group_store = GroupManagementStore::new(state.database.pool());

    if let Some(mute) = group_store.find_active_mute(room_id, sender_id).await? {
        let mut message = String::from("您已被禁言");
        if mute.mute_duration_hours > 0 {
            let expire_at = mute.muted_at + Duration::hours(mute.mute_duration_hours as i64);
            if expire_at > Utc::now() {
                message.push_str(&format!("，预计 {} 解除", expire_at.to_rfc3339()));
            }
        }
        if let Some(reason) = mute.reason {
            message.push_str(&format!("：{}", reason));
        }
        return Err(AppError::Forbidden(message));
    }

    if let Some(settings) = group_store.get_group_settings(room_id).await? {
        if settings.global_mute_enabled {
            let can_manage = group_store.can_manage_group(room_id, sender_id).await?;
            if !can_manage {
                let mut message = String::from("当前群聊已开启全体禁言");
                if let Some(reason) = settings.global_mute_reason.as_ref() {
                    message.push_str(&format!("：{}", reason));
                }
                if let Some(until) = settings.global_mute_until {
                    if until > Utc::now() {
                        message.push_str(&format!("，预计 {} 解除", until.to_rfc3339()));
                    }
                }
                return Err(AppError::Forbidden(message));
            }
        }
    }

    Ok(())
}

fn normalize_message_parts(
    content: Option<String>,
    parts_payload: Vec<MessagePartPayload>,
) -> Result<(Vec<PreparedMessagePart>, MessageType, String), AppError> {
    let mut normalized_payloads: Vec<MessagePartPayload> = Vec::new();

    if let Some(text) = content {
        let trimmed = text.trim();
        if !trimmed.is_empty() {
            normalized_payloads.push(MessagePartPayload::Text {
                text: trimmed.to_string(),
            });
        }
    }

    for payload in parts_payload {
        match &payload {
            MessagePartPayload::Text { text } if text.trim().is_empty() => continue,
            _ => normalized_payloads.push(payload),
        }
    }

    if normalized_payloads.is_empty() {
        return Err(AppError::ValidationError("消息内容不能为空".to_string()));
    }

    let mut prepared_parts: Vec<PreparedMessagePart> = Vec::new();
    let mut position: i16 = 0;
    let mut audio_count = 0;
    let mut has_text = false;
    let mut attachment_types = Vec::new();

    for payload in normalized_payloads {
        match payload {
            MessagePartPayload::Text { text } => {
                let trimmed = text.trim();
                if trimmed.is_empty() {
                    continue;
                }
                has_text = true;
                prepared_parts.push(PreparedMessagePart {
                    position,
                    part_type: MessagePartType::Text,
                    text_content: Some(trimmed.to_string()),
                    attachment_key: None,
                    attachment_name: None,
                    attachment_mime: None,
                    attachment_size: None,
                    width: None,
                    height: None,
                    duration_ms: None,
                    thumbnail_key: None,
                    extra: None,
                });
            }
            MessagePartPayload::Image {
                key,
                name,
                mime,
                size,
                width,
                height,
                thumbnail_key,
            } => {
                let trimmed_key = key.trim();
                if trimmed_key.is_empty() {
                    return Err(AppError::ValidationError(
                        "图片附件的 key 不能为空".to_string(),
                    ));
                }
                attachment_types.push(MessagePartType::Image);
                prepared_parts.push(PreparedMessagePart {
                    position,
                    part_type: MessagePartType::Image,
                    text_content: None,
                    attachment_key: Some(trimmed_key.to_string()),
                    attachment_name: name,
                    attachment_mime: mime,
                    attachment_size: size,
                    width,
                    height,
                    duration_ms: None,
                    thumbnail_key,
                    extra: None,
                });
            }
            MessagePartPayload::Video {
                key,
                name,
                mime,
                size,
                width,
                height,
                duration_ms,
                thumbnail_key,
            } => {
                let trimmed_key = key.trim();
                if trimmed_key.is_empty() {
                    return Err(AppError::ValidationError(
                        "视频附件的 key 不能为空".to_string(),
                    ));
                }
                attachment_types.push(MessagePartType::Video);
                prepared_parts.push(PreparedMessagePart {
                    position,
                    part_type: MessagePartType::Video,
                    text_content: None,
                    attachment_key: Some(trimmed_key.to_string()),
                    attachment_name: name,
                    attachment_mime: mime,
                    attachment_size: size,
                    width,
                    height,
                    duration_ms,
                    thumbnail_key,
                    extra: None,
                });
            }
            MessagePartPayload::Audio {
                key,
                name,
                mime,
                size,
                duration_ms,
            } => {
                let trimmed_key = key.trim();
                if trimmed_key.is_empty() {
                    return Err(AppError::ValidationError(
                        "语音附件的 key 不能为空".to_string(),
                    ));
                }
                audio_count += 1;
                attachment_types.push(MessagePartType::Audio);
                prepared_parts.push(PreparedMessagePart {
                    position,
                    part_type: MessagePartType::Audio,
                    text_content: None,
                    attachment_key: Some(trimmed_key.to_string()),
                    attachment_name: name,
                    attachment_mime: mime,
                    attachment_size: size,
                    width: None,
                    height: None,
                    duration_ms,
                    thumbnail_key: None,
                    extra: None,
                });
            }
            MessagePartPayload::File {
                key,
                name,
                mime,
                size,
            } => {
                let trimmed_key = key.trim();
                if trimmed_key.is_empty() {
                    return Err(AppError::ValidationError(
                        "文件附件的 key 不能为空".to_string(),
                    ));
                }
                attachment_types.push(MessagePartType::File);
                prepared_parts.push(PreparedMessagePart {
                    position,
                    part_type: MessagePartType::File,
                    text_content: None,
                    attachment_key: Some(trimmed_key.to_string()),
                    attachment_name: name,
                    attachment_mime: mime,
                    attachment_size: size,
                    width: None,
                    height: None,
                    duration_ms: None,
                    thumbnail_key: None,
                    extra: None,
                });
            }
        }
        position += 1;
    }

    if prepared_parts.is_empty() {
        return Err(AppError::ValidationError("消息内容不能为空".to_string()));
    }

    if audio_count > 0 && prepared_parts.len() > 1 {
        return Err(AppError::ValidationError(
            "语音消息暂不支持混合其他内容".to_string(),
        ));
    }

    let message_type = infer_message_type(has_text, &attachment_types, audio_count);
    let summary = summarize_message_parts(&prepared_parts);

    Ok((prepared_parts, message_type, summary))
}

fn summarize_message_parts(parts: &[PreparedMessagePart]) -> String {
    let mut summary_segments: Vec<String> = Vec::new();
    for part in parts {
        match part.part_type {
            MessagePartType::Text => {
                if let Some(text) = &part.text_content {
                    summary_segments.push(text.clone());
                }
            }
            MessagePartType::Image => summary_segments.push("[图片]".to_string()),
            MessagePartType::Video => summary_segments.push("[视频]".to_string()),
            MessagePartType::Audio => summary_segments.push("[语音]".to_string()),
            MessagePartType::File => summary_segments.push("[文件]".to_string()),
        }
    }
    let summary = summary_segments.join(" ");
    if summary.trim().is_empty() {
        "[消息]".to_string()
    } else {
        summary
    }
}

fn infer_message_type(
    has_text: bool,
    attachment_types: &[MessagePartType],
    audio_count: i32,
) -> MessageType {
    if audio_count > 0 {
        return MessageType::Audio;
    }

    if attachment_types.is_empty() {
        return MessageType::Text;
    }

    let mut unique_types = attachment_types
        .iter()
        .copied()
        .filter(|ty| !matches!(ty, MessagePartType::Text))
        .collect::<Vec<_>>();
    unique_types.sort_unstable();
    unique_types.dedup();

    if unique_types.len() == 1 && !has_text {
        match unique_types[0] {
            MessagePartType::Image => MessageType::Image,
            MessagePartType::Video => MessageType::Video,
            MessagePartType::File => MessageType::File,
            MessagePartType::Audio => MessageType::Audio,
            MessagePartType::Text => MessageType::Text,
        }
    } else if unique_types.len() == 1
        && has_text
        && matches!(unique_types[0], MessagePartType::Image)
    {
        MessageType::Mixed
    } else if unique_types.len() == 1
        && has_text
        && matches!(unique_types[0], MessagePartType::Video)
    {
        MessageType::Mixed
    } else {
        MessageType::Mixed
    }
}

async fn load_default_storage_provider(state: &AppState) -> Result<StorageProvider, AppError> {
    let store = StorageProviderStore::new(state.database.clone());
    let provider = store
        .get_default_provider()
        .await?
        .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?;

    if !provider.is_active {
        return Err(AppError::ValidationError(
            "默认文件上传提供商未启用".to_string(),
        ));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Err(AppError::ValidationError(format!(
            "不支持的存储提供商类型: {:?}",
            provider.provider_type
        )));
    }

    Ok(provider)
}

fn build_message_attachment_key(
    room_id: &Uuid,
    part_type: &ApiMessagePartType,
    filename: Option<&str>,
    content_type: Option<&str>,
) -> String {
    let date = Utc::now().format("%Y%m%d");
    let random = Uuid::new_v4().simple().to_string();
    let extension = infer_attachment_extension(filename, content_type, part_type);
    let category = match part_type {
        ApiMessagePartType::Text => "text",
        ApiMessagePartType::Image => "images",
        ApiMessagePartType::Video => "videos",
        ApiMessagePartType::Audio => "audios",
        ApiMessagePartType::File => "files",
    };

    format!(
        "messages/{}/{}_{}/{}{}",
        room_id,
        category,
        date,
        &random[..8],
        extension
    )
}

fn infer_attachment_extension(
    filename: Option<&str>,
    content_type: Option<&str>,
    part_type: &ApiMessagePartType,
) -> String {
    if let Some(name) = filename {
        if let Some((_, ext)) = name.rsplit_once('.') {
            if !ext.is_empty() {
                return format!(".{}", ext.to_ascii_lowercase());
            }
        }
    }

    if let Some(mime) = content_type {
        let lowered = mime.trim().to_ascii_lowercase();
        if let Some((_, ext)) = lowered.rsplit_once('/') {
            if !ext.is_empty() {
                return format!(".{}", ext);
            }
        }
    }

    match part_type {
        ApiMessagePartType::Image => ".png".to_string(),
        ApiMessagePartType::Video => ".mp4".to_string(),
        ApiMessagePartType::Audio => ".m4a".to_string(),
        ApiMessagePartType::File => ".bin".to_string(),
        ApiMessagePartType::Text => ".txt".to_string(),
    }
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

    ensure_group_message_permissions(&state, room_id, sender_id).await?;

    // 简单速率限制：用户在房间内每10秒最多发送30条
    {
        let mut conn = state
            .redis
            .get_session_client()
            .get_multiplexed_async_connection()
            .await
            .map_err(|_| AppError::CacheError("Redis 连接失败".to_string()))?;

        let key = format!("rl:send:{}:{}", sender_id, room_id);
        let count: i64 = redis::cmd("INCR")
            .arg(&key)
            .query_async(&mut conn)
            .await
            .map_err(|_| AppError::CacheError("Redis 自增失败".to_string()))?;

        if count == 1 {
            let _: () = redis::cmd("EXPIRE")
                .arg(&key)
                .arg(10)
                .query_async(&mut conn)
                .await
                .map_err(|_| AppError::CacheError("Redis 设置过期时间失败".to_string()))?;
        }

        if count > 30 {
            return Err(AppError::RateLimitExceeded(
                "消息发送过于频繁：每10秒最多发送30条消息".to_string(),
            ));
        }
    }

    let SendMessagePayload {
        content,
        parts,
        quoted_message_id,
    } = payload;

    let (prepared_parts, resolved_message_type, content_summary) =
        normalize_message_parts(content, parts)?;

    let db_parts: Vec<NewMessagePart> = prepared_parts
        .iter()
        .map(|part| NewMessagePart {
            position: part.position,
            part_type: part.part_type,
            text_content: part.text_content.clone(),
            attachment_key: part.attachment_key.clone(),
            attachment_name: part.attachment_name.clone(),
            attachment_mime: part.attachment_mime.clone(),
            attachment_size: part.attachment_size,
            width: part.width,
            height: part.height,
            duration_ms: part.duration_ms,
            thumbnail_key: part.thumbnail_key.clone(),
            extra: part.extra.clone(),
        })
        .collect();

    let expected_prefix = format!("messages/{}/", room_id);
    for part in &db_parts {
        if part.part_type == MessagePartType::Text {
            continue;
        }
        if let Some(key) = &part.attachment_key {
            if !key.starts_with(&expected_prefix) {
                return Err(AppError::ValidationError(
                    "附件 key 与房间不匹配，请重新获取上传签名".to_string(),
                ));
            }
        }
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

    let created = store
        .create_message_with_parts(
            room_id,
            sender_id,
            content_summary.clone(),
            resolved_message_type.clone(),
            quoted_message_id,
            &db_parts,
        )
        .await?;

    let enriched = store
        .get_message_with_sender(created.id)
        .await?
        .ok_or_else(|| AppError::InternalError("新消息加载失败".to_string()))?;

    let mut part_query_ids = vec![created.id];
    if let Some(qid) = enriched.quoted_message_id {
        part_query_ids.push(qid);
    }
    let part_map = store.get_message_parts_map(&part_query_ids).await?;

    // 实时广播到房间内所有WebSocket连接（通过Redis Pub/Sub）
    if let Err(e) = broadcast_message_to_room(&state, &enriched, &part_map).await {
        error!("广播消息失败: {}", e);
    }

    let api_message = db_message_to_api_message_info(
        &enriched,
        &part_map,
        None,
        Some(crate::models::MessageDeliveryStatus::Sent),
    );
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

    ensure_group_message_permissions(&state, room_id, sender_id).await?;

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

    let mut part_ids = vec![enriched.id];
    if let Some(qid) = enriched.quoted_message_id {
        part_ids.push(qid);
    }
    let parts_map = store.get_message_parts_map(&part_ids).await?;

    if let Err(e) = broadcast_message_to_room(&state, &enriched, &parts_map).await {
        error!("广播转发消息失败: {}", e);
    }

    let api_message = db_message_to_api_message_info(
        &enriched,
        &parts_map,
        None,
        Some(crate::models::MessageDeliveryStatus::Sent),
    );
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
    let read_store = MessageReadStore::new(state.database.pool());

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

    let mut part_query_ids: Vec<Uuid> = Vec::new();
    for msg in &items {
        part_query_ids.push(msg.id);
        if let Some(qid) = msg.quoted_message_id {
            part_query_ids.push(qid);
        }
    }
    let parts_map = store.get_message_parts_map(&part_query_ids).await?;

    let self_message_ids: Vec<Uuid> = items
        .iter()
        .filter(|msg| msg.sender_id == user_id)
        .map(|msg| msg.id)
        .collect();

    let read_message_ids: HashSet<Uuid> = if self_message_ids.is_empty() {
        HashSet::new()
    } else {
        read_store
            .message_ids_read_by_others(&self_message_ids, user_id)
            .await?
    };

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

            let delivery_status = if msg.sender_id == user_id {
                if read_message_ids.contains(&msg.id) {
                    Some(MessageDeliveryStatus::Read)
                } else {
                    Some(MessageDeliveryStatus::Sent)
                }
            } else {
                None
            };

            db_message_to_api_message_info(&msg, &parts_map, pin_ref, delivery_status)
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

    let part_map = store.get_message_parts_map(&[message.id]).await?;

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

    let api_message = db_message_to_api_message_info(
        &message,
        &part_map,
        Some(&pin),
        if message.sender_id == user_id {
            Some(MessageDeliveryStatus::Sent)
        } else {
            None
        },
    );

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

    let message_info = if let Some(msg) = store.get_message_with_sender(message_id).await? {
        let parts_map = store.get_message_parts_map(&[msg.id]).await?;
        Some(db_message_to_api_message_info(
            &msg,
            &parts_map,
            None,
            if msg.sender_id == user_id {
                Some(MessageDeliveryStatus::Sent)
            } else {
                None
            },
        ))
    } else {
        None
    };

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

    let parts_map = store.get_message_parts_map(&[updated.id]).await?;
    let api_message = db_message_to_api_message_info(
        &updated,
        &parts_map,
        None,
        if updated.sender_id == user_id {
            Some(MessageDeliveryStatus::Sent)
        } else {
            None
        },
    );
    Ok(Json(api_message))
}

#[derive(Debug, Deserialize)]
pub struct MessageAttachmentSignatureRequest {
    pub part_type: ApiMessagePartType,
    pub filename: Option<String>,
    pub content_type: Option<String>,
    pub file_size: Option<usize>,
}

#[derive(Debug, Serialize)]
pub struct MessageAttachmentSignatureResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub key: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub signature: Option<DirectUploadSignature>,
}

#[derive(Debug, Deserialize)]
pub struct MessageAttachmentDownloadQuery {
    pub key: String,
    pub expires_in_seconds: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct MessageAttachmentDownloadResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub download_url: Option<String>,
}

pub async fn generate_message_attachment_signature(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(claims): Extension<crate::models::Claims>,
    Json(req): Json<MessageAttachmentSignatureRequest>,
) -> Result<Json<MessageAttachmentSignatureResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = MessageStore::new(state.database.pool());
    if !store.user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(
            "用户不在该房间，无法上传附件".to_string(),
        ));
    }

    if matches!(req.part_type, ApiMessagePartType::Text) {
        return Err(AppError::ValidationError(
            "纯文本内容无需生成上传签名".to_string(),
        ));
    }

    // 验证文件类型
    if let Some(content_type) = &req.content_type {
        if !crate::constants::is_content_type_allowed(content_type) {
            return Err(AppError::ValidationError(format!(
                "不支持的文件类型: {}",
                content_type
            )));
        }
    }

    // 验证文件大小
    if let Some(file_size) = req.file_size {
        let max_size = if let Some(content_type) = &req.content_type {
            crate::constants::get_max_size_by_content_type(content_type)
        } else {
            crate::constants::FILE_MAX_SIZE_BYTES
        };

        if file_size > max_size {
            return Err(AppError::ValidationError(format!(
                "文件大小超出限制，最大允许{}MB",
                max_size / 1024 / 1024
            )));
        }
    }

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    let key = build_message_attachment_key(
        &room_id,
        &req.part_type,
        req.filename.as_deref(),
        req.content_type.as_deref(),
    );

    let signature = storage_service
        .generate_direct_upload_signature(&key, req.content_type.as_deref())
        .await?;

    debug!("前端获取直传参数 key: {}", key);

    Ok(Json(MessageAttachmentSignatureResponse {
        success: true,
        message: "生成消息附件直传签名成功".to_string(),
        key: Some(key),
        signature: Some(signature),
    }))
}

pub async fn generate_message_attachment_download_url(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
    Extension(claims): Extension<crate::models::Claims>,
    Query(query): Query<MessageAttachmentDownloadQuery>,
) -> Result<Json<MessageAttachmentDownloadResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = MessageStore::new(state.database.pool());
    if !store.user_in_room(room_id, user_id).await? {
        return Err(AppError::Forbidden(
            "用户不在该房间，无法获取附件".to_string(),
        ));
    }

    let key = query.key.trim();
    if key.is_empty() {
        return Err(AppError::ValidationError("附件 key 不能为空".to_string()));
    }

    let expected_prefix = format!("messages/{}/", room_id);
    if !key.starts_with(&expected_prefix) {
        return Err(AppError::ValidationError("附件 key 不合法".to_string()));
    }

    let expires = query.expires_in_seconds.unwrap_or(600).clamp(60, 86_400);

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    // 生成缓存键
    let cache_key = CacheKeys::download_url_cache(key, &provider.id.to_string(), expires);

    // 创建缓存管理器
    let cache_manager = CacheManager::new(state.redis.get_cache_client().clone());

    // 尝试从缓存获取URL
    let download_url =
        if let Ok(Some(cached_url)) = cache_manager.get_cached_download_url(&cache_key).await {
            cached_url
        } else {
            // 缓存未命中，生成新的URL
            let url = storage_service
                .generate_download_url(key, Some(expires))
                .await?;

            // 缓存URL，过期时间为URL有效期的90%
            let cache_ttl = (expires as f64 * 0.9) as u64;

            if let Err(e) = cache_manager
                .cache_download_url(&cache_key, &url, cache_ttl)
                .await
            {
                error!("缓存消息附件下载URL失败: {:?}", e);
            }

            url
        };

    Ok(Json(MessageAttachmentDownloadResponse {
        success: true,
        message: "生成附件下载链接成功".to_string(),
        download_url: Some(download_url),
    }))
}

/// 广播消息到房间内的所有连接
pub async fn broadcast_message_to_room(
    state: &AppState,
    message: &MessageWithSender,
    parts_lookup: &HashMap<Uuid, Vec<MessagePart>>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let message_parts: Vec<MessagePartEnvelope> = parts_lookup
        .get(&message.id)
        .map(|parts| parts.iter().map(MessagePartEnvelope::from).collect())
        .unwrap_or_default();

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
        quoted_message: build_quoted_payload(message, parts_lookup),
        forward_message: build_forward_payload(message),
        parts: message_parts,
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
        .get_multiplexed_async_connection()
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
        .get_multiplexed_async_connection()
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
        .get_multiplexed_async_connection()
        .await?;
    let subscriber_count: i64 = conn.publish(&channel, &encoded).await?;

    info!(
        "置顶状态已广播到房间 {} ({} 个订阅者)",
        channel, subscriber_count
    );

    Ok(())
}

fn build_quoted_payload(
    message: &MessageWithSender,
    parts_lookup: &HashMap<Uuid, Vec<MessagePart>>,
) -> Option<QuotedMessagePayload> {
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

    let parts = if is_deleted {
        Vec::new()
    } else {
        parts_lookup
            .get(&quoted_id)
            .map(|items| items.iter().map(MessagePartEnvelope::from).collect())
            .unwrap_or_default()
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
        parts,
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
