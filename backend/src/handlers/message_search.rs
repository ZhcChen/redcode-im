use axum::{
    extract::{Extension, Query, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use sqlx::{Postgres, QueryBuilder};
use uuid::Uuid;

use crate::database::models::MessageType as DbMessageType;
use crate::error::AppError;
use crate::i18n::message::MessageParams;
use crate::models::convert::db_message_type_to_api;
use crate::models::{Claims, MessageType as ApiMessageType};
use crate::AppState;

// 搜索参数
#[derive(Debug, Deserialize)]
pub struct MessageSearchParams {
    pub query: String,
    pub room_id: Option<Uuid>,
    pub sender_id: Option<Uuid>,
    pub message_type: Option<String>,
    pub date_from: Option<i64>,
    pub date_to: Option<i64>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

// 搜索结果
#[derive(Debug, Serialize)]
pub struct MessageSearchResult {
    pub id: Uuid,
    pub room_id: Uuid,
    pub room_name: String,
    pub sender_id: Uuid,
    pub sender_name: String,
    pub content: String,
    pub message_type: ApiMessageType,
    pub timestamp: String,
    pub matched_text: Option<String>, // 匹配的文本片段
    pub relevance_score: f64,         // 相关性评分
}

// 搜索统计
#[derive(Debug, Serialize)]
pub struct MessageSearchStats {
    pub total_results: i64,
    pub search_time_ms: u64,
    pub query: String,
}

// 搜索响应
#[derive(Debug, Serialize)]
pub struct MessageSearchResponse {
    pub results: Vec<MessageSearchResult>,
    pub stats: MessageSearchStats,
    pub has_more: bool,
}

fn message_validation_error(message_key: &'static str) -> AppError {
    AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn message_validation_error_with_params(message_key: &'static str, params: MessageParams) -> AppError {
    AppError::ValidationError(String::new()).with_message_key_and_params(message_key, Some(params))
}

fn message_invalid_token_error(message_key: &'static str) -> AppError {
    AppError::InvalidToken(String::new()).with_message_key(message_key)
}

fn message_internal_error(message_key: &'static str, cause: impl ToString) -> AppError {
    AppError::InternalError(cause.to_string()).with_message_key(message_key)
}

fn validate_search_query(query: &str) -> Result<(), AppError> {
    if query.trim().is_empty() {
        return Err(message_validation_error("message.search_query_required"));
    }

    if query.len() > 200 {
        return Err(message_validation_error_with_params(
            "message.search_query_too_long",
            MessageParams::from([("max".to_string(), "200".to_string())]),
        ));
    }

    Ok(())
}

fn parse_message_type_filter(raw: &str) -> Result<DbMessageType, AppError> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "text" => Ok(DbMessageType::Text),
        "image" => Ok(DbMessageType::Image),
        "file" => Ok(DbMessageType::File),
        "system" => Ok(DbMessageType::System),
        "video" => Ok(DbMessageType::Video),
        "audio" => Ok(DbMessageType::Audio),
        "mixed" => Ok(DbMessageType::Mixed),
        _ => Err(message_validation_error_with_params(
            "message.search_message_type_invalid",
            MessageParams::from([("message_type".to_string(), raw.to_string())]),
        )),
    }
}

pub async fn search_messages(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Query(params): Query<MessageSearchParams>,
) -> Result<Json<MessageSearchResponse>, AppError> {
    let start_time = std::time::Instant::now();

    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| message_invalid_token_error("auth.token_subject_invalid"))?;

    // 验证搜索查询
    validate_search_query(&params.query)?;

    // 设置分页
    let limit = params.limit.unwrap_or(50).min(100); // 最大100条
    let offset = params.offset.unwrap_or(0).max(0);
    let query_pattern = format!("%{}%", params.query.trim());

    // 必须按“用户在房间内的成员关系”过滤，避免越权读取
    let mut builder = QueryBuilder::<Postgres>::new(
        "SELECT m.id, m.room_id, r.name AS room_name, m.sender_id, u.username AS sender_username, u.nickname AS sender_nickname, m.content, m.message_type, m.created_at, ",
    );
    builder.push("CASE WHEN m.content ILIKE ");
    builder.push_bind(&query_pattern);
    builder.push(" THEN 1.0 WHEN u.username ILIKE ");
    builder.push_bind(&query_pattern);
    builder.push(" OR u.nickname ILIKE ");
    builder.push_bind(&query_pattern);
    builder.push(" THEN 0.8 ELSE 0.5 END::float8 AS relevance_score ");
    builder.push(
        "FROM messages m \
         JOIN room_members rm ON rm.room_id = m.room_id AND rm.user_id = ",
    );
    builder.push_bind(user_id);
    builder.push(
        " AND rm.deleted_at IS NULL \
         JOIN users u ON m.sender_id = u.id \
         JOIN rooms r ON m.room_id = r.id \
         WHERE m.deleted_at IS NULL AND r.deleted_at IS NULL AND (m.content ILIKE ",
    );
    builder.push_bind(&query_pattern);
    builder.push(" OR u.username ILIKE ");
    builder.push_bind(&query_pattern);
    builder.push(" OR u.nickname ILIKE ");
    builder.push_bind(&query_pattern);
    builder.push(")");

    if let Some(room_id) = params.room_id {
        builder.push(" AND m.room_id = ");
        builder.push_bind(room_id);
    }

    if let Some(sender_id) = params.sender_id {
        builder.push(" AND m.sender_id = ");
        builder.push_bind(sender_id);
    }

    if let Some(message_type) = params.message_type.as_deref() {
        let db_message_type = parse_message_type_filter(message_type)?;
        builder.push(" AND m.message_type = ");
        builder.push_bind(db_message_type);
    }

    if let Some(date_from) = params.date_from {
        let from_date = chrono::DateTime::from_timestamp(date_from, 0)
            .ok_or_else(|| message_validation_error("message.search_date_from_invalid"))?;
        builder.push(" AND m.created_at >= ");
        builder.push_bind(from_date);
    }

    if let Some(date_to) = params.date_to {
        let to_date = chrono::DateTime::from_timestamp(date_to, 0)
            .ok_or_else(|| message_validation_error("message.search_date_to_invalid"))?;
        builder.push(" AND m.created_at <= ");
        builder.push_bind(to_date);
    }

    builder.push(" ORDER BY relevance_score DESC, m.created_at DESC LIMIT ");
    builder.push_bind(limit);
    builder.push(" OFFSET ");
    builder.push_bind(offset);

    let pool = &state.database.pool;

    let search_results: Vec<MessageSearchRow> = builder
        .build_query_as()
        .fetch_all(pool)
        .await
        .map_err(|error| message_internal_error("message.search_failed", error))?;

    // 获取总数（与搜索条件保持一致）
    let mut count_builder = QueryBuilder::<Postgres>::new(
        "SELECT COUNT(*) FROM messages m JOIN room_members rm ON rm.room_id = m.room_id AND rm.user_id = ",
    );
    count_builder.push_bind(user_id);
    count_builder.push(
        " AND rm.deleted_at IS NULL \
         JOIN users u ON m.sender_id = u.id \
         JOIN rooms r ON m.room_id = r.id \
         WHERE m.deleted_at IS NULL AND r.deleted_at IS NULL AND (m.content ILIKE ",
    );
    count_builder.push_bind(&query_pattern);
    count_builder.push(" OR u.username ILIKE ");
    count_builder.push_bind(&query_pattern);
    count_builder.push(" OR u.nickname ILIKE ");
    count_builder.push_bind(&query_pattern);
    count_builder.push(")");

    if let Some(room_id) = params.room_id {
        count_builder.push(" AND m.room_id = ");
        count_builder.push_bind(room_id);
    }

    if let Some(sender_id) = params.sender_id {
        count_builder.push(" AND m.sender_id = ");
        count_builder.push_bind(sender_id);
    }

    if let Some(message_type) = params.message_type.as_deref() {
        let db_message_type = parse_message_type_filter(message_type)?;
        count_builder.push(" AND m.message_type = ");
        count_builder.push_bind(db_message_type);
    }

    if let Some(date_from) = params.date_from {
        let from_date = chrono::DateTime::from_timestamp(date_from, 0)
            .ok_or_else(|| message_validation_error("message.search_date_from_invalid"))?;
        count_builder.push(" AND m.created_at >= ");
        count_builder.push_bind(from_date);
    }

    if let Some(date_to) = params.date_to {
        let to_date = chrono::DateTime::from_timestamp(date_to, 0)
            .ok_or_else(|| message_validation_error("message.search_date_to_invalid"))?;
        count_builder.push(" AND m.created_at <= ");
        count_builder.push_bind(to_date);
    }

    let total_count: i64 = count_builder
        .build_query_scalar()
        .fetch_one(pool)
        .await
        .map_err(|error| message_internal_error("message.search_count_failed", error))?;

    // 转换结果
    let results: Vec<MessageSearchResult> = search_results
        .into_iter()
        .map(|row| {
            let sender_name = row
                .sender_nickname
                .filter(|n| !n.trim().is_empty())
                .unwrap_or_else(|| row.sender_username.clone());

            MessageSearchResult {
                id: row.id,
                room_id: row.room_id,
                room_name: row.room_name,
                sender_id: row.sender_id,
                sender_name,
                content: row.content,
                message_type: db_message_type_to_api(&row.message_type),
                timestamp: row.created_at.to_rfc3339(),
                matched_text: None, // 后端不提供高亮，由前端处理
                relevance_score: row.relevance_score,
            }
        })
        .collect();

    let search_time_ms = start_time.elapsed().as_millis() as u64;
    let has_more = (offset + results.len() as i64) < total_count;

    let response = MessageSearchResponse {
        results,
        stats: MessageSearchStats {
            total_results: total_count,
            search_time_ms,
            query: params.query,
        },
        has_more,
    };

    Ok(Json(response))
}

// 搜索结果行模型
#[derive(Debug, sqlx::FromRow)]
struct MessageSearchRow {
    id: Uuid,
    room_id: Uuid,
    room_name: String,
    sender_id: Uuid,
    sender_username: String,
    sender_nickname: Option<String>,
    content: String,
    message_type: DbMessageType,
    created_at: chrono::DateTime<chrono::Utc>,
    relevance_score: f64,
}

// 获取搜索建议
pub async fn get_search_suggestions(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Query(params): Query<SearchSuggestionsParams>,
) -> Result<Json<Vec<String>>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| message_invalid_token_error("auth.token_subject_invalid"))?;

    if params.prefix.trim().is_empty() || params.prefix.trim().len() < 2 {
        return Ok(Json(Vec::new()));
    }

    let limit = params.limit.unwrap_or(10).min(20);

    let sql = r#"
        SELECT suggestion
        FROM (
            SELECT LEFT(m.content, 50) AS suggestion, MAX(m.created_at) AS last_at
            FROM messages m
            JOIN room_members rm ON rm.room_id = m.room_id
                AND rm.user_id = $1
                AND rm.deleted_at IS NULL
            JOIN rooms r ON r.id = m.room_id
            WHERE m.content ILIKE $2
            AND m.deleted_at IS NULL
            AND r.deleted_at IS NULL
            GROUP BY suggestion
        ) t
        ORDER BY last_at DESC
        LIMIT $3
    "#;

    let suggestions = sqlx::query_scalar::<_, String>(sql)
        .bind(user_id)
        .bind(format!("{}%", params.prefix.trim()))
        .bind(limit)
        .fetch_all(&state.database.pool)
        .await
        .map_err(|error| message_internal_error("message.search_suggestions_failed", error))?;

    Ok(Json(suggestions))
}

// 搜索建议参数
#[derive(Debug, Deserialize)]
pub struct SearchSuggestionsParams {
    pub prefix: String,
    pub limit: Option<i64>,
}

// 获取热门搜索关键词
pub async fn get_trending_keywords(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<Vec<TrendingKeyword>>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| message_invalid_token_error("auth.token_subject_invalid"))?;

    let sql = r#"
        SELECT
            word,
            COUNT(*) as frequency
        FROM (
            SELECT regexp_split_to_table(content, '\s+') as word
            FROM messages m
            JOIN room_members rm ON rm.room_id = m.room_id
                AND rm.user_id = $1
                AND rm.deleted_at IS NULL
            JOIN rooms r ON r.id = m.room_id
            WHERE m.created_at > NOW() - INTERVAL '7 days'
            AND m.deleted_at IS NULL
            AND r.deleted_at IS NULL
        ) as words
        WHERE length(word) >= 2
        AND word !~ '^[^\w]+$'  -- 过滤掉纯符号
        GROUP BY word
        ORDER BY frequency DESC
        LIMIT 10
    "#;

    let keywords = sqlx::query_as::<_, TrendingKeywordRow>(sql)
        .bind(user_id)
        .fetch_all(&state.database.pool)
        .await
        .map_err(|error| message_internal_error("message.search_trending_failed", error))?;

    let results: Vec<TrendingKeyword> = keywords
        .into_iter()
        .map(|row| TrendingKeyword {
            keyword: row.word,
            frequency: row.frequency,
        })
        .collect();

    Ok(Json(results))
}

// 热门关键词模型
#[derive(Debug, sqlx::FromRow)]
struct TrendingKeywordRow {
    word: String,
    frequency: i64,
}

#[derive(Debug, Serialize)]
pub struct TrendingKeyword {
    pub keyword: String,
    pub frequency: i64,
}

#[cfg(test)]
mod tests {
    use super::{message_internal_error, parse_message_type_filter, validate_search_query};

    #[test]
    fn test_parse_message_type_filter_invalid_value_returns_localized_override() {
        let error = parse_message_type_filter("unsupported").expect_err("should fail");

        assert_eq!(
            error.response_message_key(),
            "message.search_message_type_invalid"
        );
        assert_eq!(error.localized_message(), "无效的消息类型：unsupported");
        let params = error.message_params().expect("message params should exist");
        assert_eq!(
            params.get("message_type").map(String::as_str),
            Some("unsupported")
        );
    }

    #[test]
    fn test_validate_search_query_empty_returns_required_key() {
        let error = validate_search_query("   ").expect_err("should fail");
        assert_eq!(error.response_message_key(), "message.search_query_required");
        assert_eq!(error.localized_message(), "搜索内容不能为空");
    }

    #[test]
    fn test_validate_search_query_too_long_returns_key_and_max_param() {
        let query = "x".repeat(201);
        let error = validate_search_query(&query).expect_err("should fail");

        assert_eq!(error.response_message_key(), "message.search_query_too_long");
        let params = error.message_params().expect("message params should exist");
        assert_eq!(params.get("max").map(String::as_str), Some("200"));
    }

    #[test]
    fn test_message_internal_error_preserves_cause_message_for_observability() {
        let error = message_internal_error("message.search_failed", "db timeout");
        assert_eq!(error.response_message_key(), "message.search_failed");
        assert_eq!(error.to_string(), "db timeout");
    }
}
