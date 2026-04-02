use axum::{
    extract::{Path, Query, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::database::message_store::MessageStore;
use crate::error::AppError;
use crate::i18n::localizer::default_localizer;
use crate::middleware::current_request_locale;
use crate::AppState;
use chrono::{DateTime, Utc};

#[derive(Debug, Deserialize)]
pub struct ChatHistoryParams {
    #[serde(default = "default_page")]
    pub page: usize,
    #[serde(default = "default_page_size", alias = "pageSize")]
    pub page_size: usize,
    pub room_id: Option<String>,
    pub user_id: Option<String>,
    pub start_date: Option<String>,
    pub end_date: Option<String>,
    pub keyword: Option<String>,
}

fn default_page() -> usize {
    1
}

fn default_page_size() -> usize {
    50
}

fn chat_history_localized_message(message_key: &'static str) -> String {
    let localizer = default_localizer();
    let locale =
        current_request_locale().unwrap_or_else(|| localizer.fallback_locale().to_string());
    localizer.localize(&locale, message_key, None)
}

#[derive(Debug, Serialize)]
pub struct ChatHistoryResponse {
    pub messages: Vec<ChatMessage>,
    pub total: usize,
    pub page: usize,
    pub page_size: usize,
}

#[derive(Debug, Serialize)]
pub struct ChatMessage {
    pub id: String,
    pub room_id: String,
    pub room_name: Option<String>,
    pub sender_id: String,
    pub sender_name: String,
    pub sender_avatar: Option<String>,
    pub message_type: String,
    pub content: String,
    pub parts: Vec<MessagePart>,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct MessagePart {
    pub id: String,
    pub message_id: String,
    pub part_type: String,
    pub text_content: Option<String>,
    pub attachment_key: Option<String>,
    pub attachment_name: Option<String>,
    pub attachment_mime: Option<String>,
    pub attachment_size: Option<i64>,
    pub thumbnail_key: Option<String>,
    pub duration_ms: Option<i32>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub created_at: String,
}

impl From<crate::database::models::MessagePart> for MessagePart {
    fn from(part: crate::database::models::MessagePart) -> Self {
        Self {
            id: part.id.to_string(),
            message_id: part.message_id.to_string(),
            part_type: part.part_type.to_string(),
            text_content: part.text_content,
            attachment_key: part.attachment_key,
            attachment_name: part.attachment_name,
            attachment_mime: part.attachment_mime,
            attachment_size: part.attachment_size,
            thumbnail_key: part.thumbnail_key,
            duration_ms: part.duration_ms,
            width: part.width,
            height: part.height,
            created_at: part.created_at.to_rfc3339(),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct UserRoomResponse {
    pub rooms: Vec<UserRoom>,
    pub total: usize,
}

#[derive(Debug, Serialize)]
pub struct UserRoom {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub avatar_url: Option<String>,
    pub is_private: bool,
    pub is_group: bool,
    pub member_count: i64,
    pub last_message: Option<ChatMessage>,
    pub created_at: String,
    pub updated_at: String,
}

/// 获取用户聊天记录
pub async fn get_chat_history(
    State(state): State<AppState>,
    Query(params): Query<ChatHistoryParams>,
) -> Result<Json<ChatHistoryResponse>, AppError> {
    let pool = &state.database.pool;
    let message_store = MessageStore::new(&state.database.pool);

    let page = params.page.max(1);
    let page_size = params.page_size.max(1).min(100);

    // 构建查询条件
    let mut query_conditions = Vec::new();
    let mut uuid_params: Vec<Uuid> = Vec::new();
    let mut string_params: Vec<String> = Vec::new();
    let mut param_index = 1;

    // 基础条件：未删除的消息
    query_conditions.push("m.deleted_at IS NULL".to_string());

    // 房间ID条件
    if let Some(room_id) = &params.room_id {
        if let Ok(uuid) = Uuid::parse_str(room_id) {
            query_conditions.push(format!("m.room_id = ${}", param_index));
            uuid_params.push(uuid);
            param_index += 1;
        }
    }

    // 用户ID条件
    if let Some(user_id) = &params.user_id {
        if let Ok(uuid) = Uuid::parse_str(user_id) {
            query_conditions.push(format!("m.sender_id = ${}", param_index));
            uuid_params.push(uuid);
            param_index += 1;
        }
    }

    // 日期范围条件
    if let Some(start_date) = &params.start_date {
        if let Ok(dt) = DateTime::parse_from_rfc3339(start_date) {
            query_conditions.push(format!("m.created_at >= ${}", param_index));
            string_params.push(dt.with_timezone(&Utc).to_rfc3339());
            param_index += 1;
        }
    }

    if let Some(end_date) = &params.end_date {
        if let Ok(dt) = DateTime::parse_from_rfc3339(end_date) {
            query_conditions.push(format!("m.created_at <= ${}", param_index));
            string_params.push(dt.with_timezone(&Utc).to_rfc3339());
            param_index += 1;
        }
    }

    // 关键词搜索条件
    if let Some(keyword) = &params.keyword {
        if !keyword.trim().is_empty() {
            query_conditions.push(format!("(m.content ILIKE ${} OR EXISTS (SELECT 1 FROM message_parts mp WHERE mp.message_id = m.id AND mp.text_content ILIKE ${}))", param_index, param_index + 1));
            string_params.push(format!("%{}%", keyword.trim()));
            string_params.push(format!("%{}%", keyword.trim()));
            param_index += 2;
        }
    }

    let where_clause = if query_conditions.is_empty() {
        String::new()
    } else {
        format!("WHERE {}", query_conditions.join(" AND "))
    };

    // 获取总数
    let count_query = format!("SELECT COUNT(*) FROM messages m {}", where_clause);

    let mut count_query_builder = sqlx::query_scalar(&count_query);

    // 先绑定UUID参数
    for param in &uuid_params {
        count_query_builder = count_query_builder.bind(param);
    }

    // 再绑定字符串参数
    for param in &string_params {
        count_query_builder = count_query_builder.bind(param);
    }

    let total: i64 = count_query_builder.fetch_one(pool).await.map_err(|e| {
        tracing::error!("获取聊天记录总数失败: {}", e);
        AppError::DatabaseError(e)
    })?;

    // 获取分页数据
    let offset = (page - 1) * page_size;
    let data_query = format!(
        r#"
        SELECT 
            m.id, m.room_id, m.sender_id, m.message_type, m.content,
            m.created_at, m.updated_at, m.deleted_at,
            u.username as sender_name, u.avatar_url as sender_avatar,
            r.name as room_name
        FROM messages m
        LEFT JOIN users u ON m.sender_id = u.id
        LEFT JOIN rooms r ON m.room_id = r.id
        {}
        ORDER BY m.created_at DESC
        LIMIT ${} OFFSET ${}
        "#,
        where_clause,
        param_index,
        param_index + 1
    );

    let mut data_query_builder = sqlx::query(&data_query);

    // 先绑定UUID参数
    for param in &uuid_params {
        data_query_builder = data_query_builder.bind(param);
    }

    // 再绑定字符串参数
    for param in &string_params {
        data_query_builder = data_query_builder.bind(param);
    }

    data_query_builder = data_query_builder.bind(page_size as i64);
    data_query_builder = data_query_builder.bind(offset as i64);

    let rows = data_query_builder.fetch_all(pool).await.map_err(|e| {
        tracing::error!("获取聊天记录失败: {}", e);
        AppError::DatabaseError(e)
    })?;

    let mut messages = Vec::new();

    for row in rows {
        let message_id: Uuid = row.get("id");
        let room_id: Uuid = row.get("room_id");
        let sender_id: Uuid = row.get("sender_id");

        // 获取消息部件
        let parts_map = message_store
            .get_message_parts_map(&[message_id])
            .await
            .map_err(|e| {
                tracing::error!("获取消息部件失败: {}", e);
                AppError::DatabaseError(e)
            })?;

        let message_parts: Vec<MessagePart> = parts_map
            .get(&message_id)
            .unwrap_or(&Vec::new())
            .iter()
            .map(|part| MessagePart::from(part.clone()))
            .collect();

        let chat_message = ChatMessage {
            id: message_id.to_string(),
            room_id: room_id.to_string(),
            room_name: row.get("room_name"),
            sender_id: sender_id.to_string(),
            sender_name: row
                .get::<Option<String>, _>("sender_name")
                .unwrap_or_else(|| chat_history_localized_message("chat_history.unknown_user")),
            sender_avatar: row.get("sender_avatar"),
            message_type: match row.get::<i16, _>("message_type") {
                0 => "text".to_string(),
                1 => "image".to_string(),
                2 => "file".to_string(),
                3 => "system".to_string(),
                _ => "unknown".to_string(),
            },
            content: row.get("content"),
            parts: message_parts,
            created_at: row
                .get::<chrono::DateTime<Utc>, _>("created_at")
                .to_rfc3339(),
            updated_at: row
                .get::<chrono::DateTime<Utc>, _>("updated_at")
                .to_rfc3339(),
            deleted_at: row
                .get::<Option<chrono::DateTime<Utc>>, _>("deleted_at")
                .map(|dt| dt.to_rfc3339()),
        };

        messages.push(chat_message);
    }

    Ok(Json(ChatHistoryResponse {
        messages,
        total: total as usize,
        page,
        page_size,
    }))
}

/// 获取用户参与的房间列表
pub async fn get_user_rooms(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
) -> Result<Json<UserRoomResponse>, AppError> {
    let user_id = Uuid::parse_str(&user_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("user.user_id_invalid")
    })?;

    let pool = &state.database.pool;

    // 获取用户参与的房间
    let query = r#"
    SELECT 
        r.id, r.name, r.description, r.avatar_url, r.room_type,
        r.created_at, r.updated_at,
        (SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = r.id AND rm.deleted_at IS NULL) as member_count
    FROM rooms r
    INNER JOIN room_members rm ON r.id = rm.room_id
    WHERE rm.user_id = $1 AND r.deleted_at IS NULL AND rm.deleted_at IS NULL
    ORDER BY r.updated_at DESC
    "#;

    let rows = sqlx::query(query)
        .bind(user_id)
        .fetch_all(pool)
        .await
        .map_err(|e| {
            tracing::error!("获取用户房间列表失败: {}", e);
            AppError::DatabaseError(e)
        })?;

    let mut rooms = Vec::new();

    for row in rows {
        let room_id: Uuid = row.get("id");

        // 获取房间最后一条消息
        let last_message_query = r#"
        SELECT 
            m.id, m.sender_id, m.message_type, m.content,
            m.created_at, m.updated_at,
            u.username as sender_name, u.avatar_url as sender_avatar,
            r.name as room_name
        FROM messages m
        LEFT JOIN users u ON m.sender_id = u.id
        LEFT JOIN rooms r ON m.room_id = r.id
        WHERE m.room_id = $1 AND m.deleted_at IS NULL
        ORDER BY m.created_at DESC
        LIMIT 1
        "#;

        let last_message_row = sqlx::query(last_message_query)
            .bind(room_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| {
                tracing::error!("获取房间最后消息失败: {}", e);
                AppError::DatabaseError(e)
            })?;

        let last_message = if let Some(row) = last_message_row {
            Some(ChatMessage {
                id: row.get::<Uuid, _>("id").to_string(),
                room_id: room_id.to_string(),
                room_name: row.get::<Option<String>, _>("room_name"),
                sender_id: row.get::<Uuid, _>("sender_id").to_string(),
                sender_name: row
                    .get::<Option<String>, _>("sender_name")
                    .unwrap_or_else(|| chat_history_localized_message("chat_history.unknown_user")),
                sender_avatar: row.get("sender_avatar"),
                message_type: match row.get::<i16, _>("message_type") {
                    0 => "text".to_string(),
                    1 => "image".to_string(),
                    2 => "file".to_string(),
                    3 => "system".to_string(),
                    _ => "unknown".to_string(),
                },
                content: row.get("content"),
                parts: Vec::new(),
                created_at: row
                    .get::<chrono::DateTime<Utc>, _>("created_at")
                    .to_rfc3339(),
                updated_at: row
                    .get::<chrono::DateTime<Utc>, _>("updated_at")
                    .to_rfc3339(),
                deleted_at: None,
            })
        } else {
            None
        };

        let room = UserRoom {
            id: room_id.to_string(),
            name: row
                .get::<Option<String>, _>("name")
                .unwrap_or_else(|| chat_history_localized_message("chat_history.unnamed_room")),
            description: row.get("description"),
            avatar_url: row.get("avatar_url"),
            is_private: row.get::<i16, _>("room_type") == 0, // 0=private
            is_group: row.get::<i16, _>("room_type") == 1,   // 1=group
            member_count: row.get("member_count"),
            last_message,
            created_at: row
                .get::<chrono::DateTime<Utc>, _>("created_at")
                .to_rfc3339(),
            updated_at: row
                .get::<chrono::DateTime<Utc>, _>("updated_at")
                .to_rfc3339(),
        };

        rooms.push(room);
    }

    let total = rooms.len();
    Ok(Json(UserRoomResponse { rooms, total }))
}

/// 获取特定房间的聊天记录
pub async fn get_room_chat_history(
    State(state): State<AppState>,
    Path(room_id): Path<String>,
    Query(params): Query<ChatHistoryParams>,
) -> Result<Json<ChatHistoryResponse>, AppError> {
    let room_id = Uuid::parse_str(&room_id).map_err(|_| {
        AppError::ValidationError(String::new()).with_message_key("room.room_id_invalid")
    })?;

    // 设置房间ID并复用获取聊天记录的逻辑
    let mut room_params = params;
    room_params.room_id = Some(room_id.to_string());

    get_chat_history(State(state), Query(room_params)).await
}

#[cfg(test)]
mod tests {
    #[test]
    fn chat_history_fallbacks_should_use_catalog_keys() {
        let source = include_str!("chat_history.rs");

        assert!(
            source.contains("chat_history.unknown_user"),
            "chat history handler should use chat_history.unknown_user catalog key"
        );
        assert!(
            source.contains("chat_history.unnamed_room"),
            "chat history handler should use chat_history.unnamed_room catalog key"
        );
    }

    #[test]
    fn chat_history_should_not_embed_legacy_fallback_literals() {
        let source = include_str!("chat_history.rs");

        for legacy in [
            "\u{672a}\u{77e5}\u{7528}\u{6237}",
            "\u{672a}\u{547d}\u{540d}\u{623f}\u{95f4}",
        ] {
            assert!(
                !source.contains(legacy),
                "chat history handler should not embed legacy fallback literal: {legacy}"
            );
        }
    }
}
