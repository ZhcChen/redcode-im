use axum::{
    extract::{Query, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::models::MessageWithSender;
use crate::error::AppError;
use crate::models::Claims;
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
    pub message_type: String,
    pub timestamp: String,
    pub matched_text: Option<String>, // 匹配的文本片段
    pub relevance_score: f64,        // 相关性评分
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

pub async fn search_messages(
    State(state): State<AppState>,
    Query(params): Query<MessageSearchParams>,
) -> Result<Json<MessageSearchResponse>, AppError> {
    let start_time = std::time::Instant::now();

    // 验证搜索查询
    if params.query.trim().is_empty() {
        return Err(AppError::ValidationError("搜索内容不能为空".to_string()));
    }

    if params.query.len() > 200 {
        return Err(AppError::ValidationError("搜索内容过长，最多200个字符".to_string()));
    }

    // 构建SQL查询
    let mut query_conditions: Vec<String> = vec!["m.deleted_at IS NULL".to_string()];
    let mut bind_params: Vec<Box<dyn sqlx::Encode<'_, sqlx::Postgres> + Send>> = Vec::new();

    // 添加搜索条件（使用全文搜索）
    if !params.query.trim().is_empty() {
        query_conditions.push("(m.content ILIKE $1 OR u.username ILIKE $1 OR u.nickname ILIKE $1)".to_string());
        bind_params.push(Box::new(format!("%{}%", params.query.trim())));
    }

    // 添加房间过滤
    if let Some(room_id) = params.room_id {
        query_conditions.push("m.room_id = $".to_string() + &(bind_params.len() + 1).to_string());
        bind_params.push(Box::new(room_id));
    }

    // 添加发送者过滤
    if let Some(sender_id) = params.sender_id {
        query_conditions.push("m.sender_id = $".to_string() + &(bind_params.len() + 1).to_string());
        bind_params.push(Box::new(sender_id));
    }

    // 添加消息类型过滤
    if let Some(message_type) = &params.message_type {
        query_conditions.push("m.message_type = $".to_string() + &(bind_params.len() + 1).to_string());
        bind_params.push(Box::new(message_type.clone()));
    }

    // 添加日期范围过滤
    if let Some(date_from) = params.date_from {
        let from_date = chrono::DateTime::from_timestamp(date_from, 0)
            .ok_or_else(|| AppError::ValidationError("无效的开始时间".to_string()))?;
        query_conditions.push("m.created_at >= $".to_string() + &(bind_params.len() + 1).to_string());
        bind_params.push(Box::new(from_date));
    }

    if let Some(date_to) = params.date_to {
        let to_date = chrono::DateTime::from_timestamp(date_to, 0)
            .ok_or_else(|| AppError::ValidationError("无效的结束时间".to_string()))?;
        query_conditions.push("m.created_at <= $".to_string() + &(bind_params.len() + 1).to_string());
        bind_params.push(Box::new(to_date));
    }

    // 设置分页
    let limit = params.limit.unwrap_or(50).min(100); // 最大100条
    let offset = params.offset.unwrap_or(0);

    let where_clause = query_conditions.join(" AND ");

    // 执行搜索查询
    let search_sql = format!(
        r#"
        SELECT
            m.id,
            m.room_id,
            r.name as room_name,
            m.sender_id,
            u.username as sender_username,
            u.nickname as sender_nickname,
            m.content,
            m.message_type,
            m.created_at,
            -- 简单的相关性评分
            CASE
                WHEN m.content ILIKE $1 THEN 1.0
                WHEN u.username ILIKE $1 OR u.nickname ILIKE $1 THEN 0.8
                ELSE 0.5
            END as relevance_score
        FROM messages m
        JOIN users u ON m.sender_id = u.id
        JOIN rooms r ON m.room_id = r.id
        WHERE {}
        ORDER BY relevance_score DESC, m.created_at DESC
        LIMIT {} OFFSET {}
        "#,
        where_clause, limit, offset
    );

    // 获取总数查询
    let count_sql = format!(
        r#"
        SELECT COUNT(*) as total
        FROM messages m
        JOIN users u ON m.sender_id = u.id
        JOIN rooms r ON m.room_id = r.id
        WHERE {}
        "#,
        where_clause
    );

    let pool = &state.database.pool;

    // 执行搜索
    let mut search_query = sqlx::query_as::<_, MessageSearchRow>(&search_sql);

    // 绑定参数（这里需要根据实际的SQL库调整）
    // 注意：这是一个简化的实现，实际使用时需要正确处理参数绑定

    let search_results = search_query
        .fetch_all(pool)
        .await
        .map_err(|e| AppError::InternalError(format!("搜索失败: {}", e)))?;

    // 获取总数
    let total_count: i64 = sqlx::query_scalar(&count_sql)
        .fetch_one(pool)
        .await
        .map_err(|e| AppError::InternalError(format!("获取总数失败: {}", e)))?;

    // 转换结果
    let results: Vec<MessageSearchResult> = search_results
        .into_iter()
        .map(|row| {
            let sender_name = row.sender_nickname
                .filter(|n| !n.trim().is_empty())
                .unwrap_or_else(|| row.sender_username.clone());

            MessageSearchResult {
                id: row.id,
                room_id: row.room_id,
                room_name: row.room_name,
                sender_id: row.sender_id,
                sender_name,
                content: row.content,
                message_type: row.message_type,
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
    message_type: String,
    created_at: chrono::DateTime<chrono::Utc>,
    relevance_score: f64,
}

// 获取搜索建议
pub async fn get_search_suggestions(
    State(state): State<AppState>,
    Query(params): Query<SearchSuggestionsParams>,
) -> Result<Json<Vec<String>>, AppError> {
    if params.prefix.trim().is_empty() || params.prefix.trim().len() < 2 {
        return Ok(Json(Vec::new()));
    }

    let limit = params.limit.unwrap_or(10).min(20);

    let sql = r#"
        SELECT DISTINCT LEFT(m.content, 50) as suggestion
        FROM messages m
        WHERE m.content ILIKE $1
        AND m.deleted_at IS NULL
        ORDER BY m.created_at DESC
        LIMIT $2
    "#;

    let suggestions = sqlx::query_scalar::<_, String>(sql)
        .bind(format!("{}%", params.prefix.trim()))
        .bind(limit as i64)
        .fetch_all(&state.database.pool)
        .await
        .map_err(|e| AppError::InternalError(format!("获取建议失败: {}", e)))?;

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
) -> Result<Json<Vec<TrendingKeyword>>, AppError> {
    let sql = r#"
        SELECT
            word,
            COUNT(*) as frequency
        FROM (
            SELECT regexp_split_to_table(content, '\s+') as word
            FROM messages
            WHERE created_at > NOW() - INTERVAL '7 days'
            AND deleted_at IS NULL
            AND length(word) >= 2
        ) as words
        WHERE word !~ '^[^\w]+$'  -- 过滤掉纯符号
        GROUP BY word
        ORDER BY frequency DESC
        LIMIT 10
    "#;

    let keywords = sqlx::query_as::<_, TrendingKeywordRow>(sql)
        .fetch_all(&state.database.pool)
        .await
        .map_err(|e| AppError::InternalError(format!("获取热门关键词失败: {}", e)))?;

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