use rusqlite::{params, Connection, OptionalExtension, Result as SqlResult};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tauri::Manager;

// 消息搜索结果
#[derive(Debug, Serialize, Deserialize)]
pub struct MessageSearchResult {
    pub id: String,
    pub room_id: String,
    pub room_name: String,
    pub sender_id: String,
    pub sender_name: String,
    pub content: String,
    pub message_type: String,
    pub timestamp: i64,
    pub matched_text: Option<String>, // 匹配的文本片段
    pub relevance_score: f64,        // 相关性评分
}

// 搜索参数
#[derive(Debug, Deserialize)]
pub struct SearchParams {
    pub query: String,
    pub room_id: Option<String>,
    pub sender_id: Option<String>,
    pub message_type: Option<String>,
    pub date_from: Option<i64>,
    pub date_to: Option<i64>,
    pub limit: Option<i32>,
    pub offset: Option<i32>,
}

// 搜索统计
#[derive(Debug, Serialize)]
pub struct SearchStats {
    pub total_results: i32,
    pub search_time_ms: u64,
    pub query: String,
}

// 索引消息信息
#[derive(Debug, Serialize, Deserialize)]
pub struct IndexMessage {
    pub id: String,
    pub room_id: String,
    pub room_name: String,
    pub sender_id: String,
    pub sender_name: String,
    pub content: String,
    pub message_type: String,
    pub timestamp: i64,
}

const MESSAGE_SEARCH_SQL: &str = "
CREATE VIRTUAL TABLE IF NOT EXISTS message_search USING fts5(
    id UNINDEXED,
    room_id UNINDEXED,
    room_name,
    sender_id UNINDEXED,
    sender_name,
    content,
    message_type UNINDEXED,
    timestamp UNINDEXED
);

-- 创建触发器，当消息表更新时自动更新搜索索引
CREATE TRIGGER IF NOT EXISTS message_search_insert AFTER INSERT ON messages
BEGIN
    INSERT INTO message_search(id, room_id, room_name, sender_id, sender_name, content, message_type, timestamp)
    VALUES (NEW.id, NEW.room_id, NEW.room_name, NEW.sender_id, NEW.sender_name, NEW.content, NEW.message_type, NEW.timestamp);
END;

CREATE TRIGGER IF NOT EXISTS message_search_delete AFTER DELETE ON messages
BEGIN
    DELETE FROM message_search WHERE id = OLD.id;
END;

CREATE TRIGGER IF NOT EXISTS message_search_update AFTER UPDATE ON messages
BEGIN
    DELETE FROM message_search WHERE id = OLD.id;
    INSERT INTO message_search(id, room_id, room_name, sender_id, sender_name, content, message_type, timestamp)
    VALUES (NEW.id, NEW.room_id, NEW.room_name, NEW.sender_id, NEW.sender_name, NEW.content, NEW.message_type, NEW.timestamp);
END;
";

fn resolve_search_db_path(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    let mut dir = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("failed to resolve app data dir: {e}"))?;
    std::fs::create_dir_all(&dir)
        .map_err(|e| format!("failed to create app data dir {:?}: {e}", dir))?;
    dir.push("message_search.db");
    Ok(dir)
}

fn open_search_connection(db_path: &PathBuf) -> Result<Connection, String> {
    let conn = Connection::open(db_path).map_err(|e| format!("failed to open search db: {e}"))?;

    // 优化SQLite设置
    conn.execute("PRAGMA journal_mode = WAL", [])
        .map_err(|e| format!("failed to set WAL mode: {e}"))?;
    conn.execute("PRAGMA synchronous = NORMAL", [])
        .map_err(|e| format!("failed to set synchronous mode: {e}"))?;
    conn.execute("PRAGMA cache_size = -10000", []) // 10MB cache
        .map_err(|e| format!("failed to set cache size: {e}"))?;

    // 初始化FTS5表
    conn.execute_batch(MESSAGE_SEARCH_SQL)
        .map_err(|e| format!("failed to initialize search tables: {e}"))?;

    Ok(conn)
}

// 索引单个消息
#[tauri::command]
pub async fn index_message(
    app: tauri::AppHandle,
    message: IndexMessage,
) -> Result<(), String> {
    let db_path = resolve_search_db_path(&app)?;
    tauri::async_runtime::spawn_blocking(move || {
        let conn = open_search_connection(&db_path)?;

        conn.execute(
            "INSERT OR REPLACE INTO message_search
             (id, room_id, room_name, sender_id, sender_name, content, message_type, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                message.id,
                message.room_id,
                message.room_name,
                message.sender_id,
                message.sender_name,
                message.content,
                message.message_type,
                message.timestamp
            ],
        ).map_err(|e| format!("failed to index message: {e}"))?;

        Ok::<(), String>(())
    })
    .await
    .map_err(|e| format!("task join error: {e}"))??;

    Ok(())
}

// 批量索引消息
#[tauri::command]
pub async fn index_messages(
    app: tauri::AppHandle,
    messages: Vec<IndexMessage>,
) -> Result<(), String> {
    if messages.is_empty() {
        return Ok(());
    }

    let db_path = resolve_search_db_path(&app)?;
    tauri::async_runtime::spawn_blocking(move || {
        let conn = open_search_connection(&db_path)?;
        let tx = conn.transaction().map_err(|e| format!("failed to begin transaction: {e}"))?;

        for message in messages {
            tx.execute(
                "INSERT OR REPLACE INTO message_search
                 (id, room_id, room_name, sender_id, sender_name, content, message_type, timestamp)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                params![
                    message.id,
                    message.room_id,
                    message.room_name,
                    message.sender_id,
                    message.sender_name,
                    message.content,
                    message.message_type,
                    message.timestamp
                ],
            ).map_err(|e| format!("failed to index message: {e}"))?;
        }

        tx.commit().map_err(|e| format!("failed to commit transaction: {e}"))?;
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| format!("task join error: {e}"))??;

    Ok(())
}

// 删除索引
#[tauri::command]
pub async fn remove_message_index(
    app: tauri::AppHandle,
    message_id: String,
) -> Result<(), String> {
    let db_path = resolve_search_db_path(&app)?;
    tauri::async_runtime::spawn_blocking(move || {
        let conn = open_search_connection(&db_path)?;
        conn.execute("DELETE FROM message_search WHERE id = ?1", params![message_id])
            .map_err(|e| format!("failed to remove message index: {e}"))?;
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| format!("task join error: {e}"))??;

    Ok(())
}

// 清空所有索引
#[tauri::command]
pub async fn clear_all_indices(app: tauri::AppHandle) -> Result<(), String> {
    let db_path = resolve_search_db_path(&app)?;
    tauri::async_runtime::spawn_blocking(move || {
        let conn = open_search_connection(&db_path)?;
        conn.execute("DELETE FROM message_search", [])
            .map_err(|e| format!("failed to clear indices: {e}"))?;
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| format!("task join error: {e}"))??;

    Ok(())
}

// 构建搜索查询
fn build_search_query(params: &SearchParams) -> (String, Vec<String>) {
    let mut query_parts = Vec::new();
    let mut bind_params = Vec::new();

    // 主搜索查询
    if !params.query.trim().is_empty() {
        // 支持FTS5搜索语法
        let processed_query = process_search_query(&params.query);
        query_parts.push(format!("message_search MATCH ?"));
        bind_params.push(processed_query);
    }

    // 房间过滤
    if let Some(room_id) = &params.room_id {
        query_parts.push("room_id = ?".to_string());
        bind_params.push(room_id.clone());
    }

    // 发送者过滤
    if let Some(sender_id) = &params.sender_id {
        query_parts.push("sender_id = ?".to_string());
        bind_params.push(sender_id.clone());
    }

    // 消息类型过滤
    if let Some(message_type) = &params.message_type {
        query_parts.push("message_type = ?".to_string());
        bind_params.push(message_type.clone());
    }

    // 日期范围过滤
    if let Some(date_from) = params.date_from {
        query_parts.push("timestamp >= ?".to_string());
        bind_params.push(date_from.to_string());
    }

    if let Some(date_to) = params.date_to {
        query_parts.push("timestamp <= ?".to_string());
        bind_params.push(date_to.to_string());
    }

    let where_clause = if query_parts.is_empty() {
        "1".to_string()
    } else {
        query_parts.join(" AND ")
    };

    let limit = params.limit.unwrap_or(50);
    let offset = params.offset.unwrap_or(0);

    let sql = format!(
        "SELECT
            id, room_id, room_name, sender_id, sender_name,
            snippet(message_search, 5, '<mark>', '</mark>', '...', 20) as matched_text,
            content, message_type, timestamp,
            bm25(message_search) as relevance_score
         FROM message_search
         WHERE {}
         ORDER BY relevance_score, timestamp DESC
         LIMIT {} OFFSET {}",
        where_clause, limit, offset
    );

    (sql, bind_params)
}

// 处理搜索查询，支持高级语法
fn process_search_query(query: &str) -> String {
    let query = query.trim();

    // 如果查询包含高级语法，直接返回
    if query.contains('"') || query.contains("AND") || query.contains("OR") || query.contains("NOT") {
        return query.to_string();
    }

    // 简单查询，支持分词
    let words: Vec<&str> = query.split_whitespace().collect();
    if words.len() == 1 {
        // 单个词，直接搜索
        format!("\"{}\"*", query)
    } else {
        // 多个词，使用AND连接
        let quoted_words: Vec<String> = words.iter().map(|word| format!("\"{}\"*", word)).collect();
        quoted_words.join(" AND ")
    }
}

// 执行搜索
#[tauri::command]
pub async fn search_messages(
    app: tauri::AppHandle,
    params: SearchParams,
) -> Result<(Vec<MessageSearchResult>, SearchStats), String> {
    let start_time = std::time::Instant::now();
    let db_path = resolve_search_db_path(&app)?;

    let (sql, bind_params) = build_search_query(&params);

    let results = tauri::async_runtime::spawn_blocking(move || {
        let conn = open_search_connection(&db_path)?;
        let mut stmt = conn.prepare(&sql)
            .map_err(|e| format!("failed to prepare search statement: {e}"))?;

        let param_refs: Vec<&dyn rusqlite::ToSql> = bind_params.iter().map(|p| p as &dyn rusqlite::ToSql).collect();

        let rows = stmt.query_map(&*param_refs, |row| {
            Ok(MessageSearchResult {
                id: row.get(0)?,
                room_id: row.get(1)?,
                room_name: row.get(2)?,
                sender_id: row.get(3)?,
                sender_name: row.get(4)?,
                matched_text: row.get(5)?,
                content: row.get(6)?,
                message_type: row.get(7)?,
                timestamp: row.get(8)?,
                relevance_score: row.get::<_, f64>(9)?,
            })
        })
        .map_err(|e| format!("failed to execute search query: {e}"))?;

        let mut results = Vec::new();
        for row in rows {
            results.push(row.map_err(|e| format!("failed to parse search result: {e}"))?);
        }

        Ok::<Vec<MessageSearchResult>, String>(results)
    })
    .await
    .map_err(|e| format!("task join error: {e}"))??;

    let search_time_ms = start_time.elapsed().as_millis() as u64;
    let stats = SearchStats {
        total_results: results.len() as i32,
        search_time_ms,
        query: params.query.clone(),
    };

    Ok((results, stats))
}

// 获取搜索建议
#[tauri::command]
pub async fn get_search_suggestions(
    app: tauri::AppHandle,
    prefix: String,
    limit: Option<i32>,
) -> Result<Vec<String>, String> {
    if prefix.trim().is_empty() {
        return Ok(vec![]);
    }

    let db_path = resolve_search_db_path(&app)?;
    let limit = limit.unwrap_or(10);

    let suggestions = tauri::async_runtime::spawn_blocking(move || {
        let conn = open_search_connection(&db_path)?;

        // 使用FTS5的prefix查询获取建议
        let sql = "
            SELECT DISTINCT substr(content, 1, 50) as suggestion
            FROM message_search
            WHERE content MATCH ? || '*'
            LIMIT ?
        ";

        let mut stmt = conn.prepare(sql)
            .map_err(|e| format!("failed to prepare suggestion query: {e}"))?;

        let rows = stmt.query_map(params![prefix, limit], |row| {
            let suggestion: String = row.get(0)?;
            Ok(suggestion)
        })
        .map_err(|e| format!("failed to execute suggestion query: {e}"))?;

        let mut suggestions = Vec::new();
        for row in rows {
            suggestions.push(row.map_err(|e| format!("failed to parse suggestion: {e}"))?);
        }

        Ok::<Vec<String>, String>(suggestions)
    })
    .await
    .map_err(|e| format!("task join error: {e}"))??;

    Ok(suggestions)
}

// 获取搜索统计信息
#[tauri::command]
pub async fn get_search_stats(app: tauri::AppHandle) -> Result<serde_json::Value, String> {
    let db_path = resolve_search_db_path(&app)?;

    let stats = tauri::async_runtime::spawn_blocking(move || {
        let conn = open_search_connection(&db_path)?;

        // 获取索引的消息总数
        let total_messages: i64 = conn.query_row(
            "SELECT COUNT(*) FROM message_search",
            [],
            |row| row.get(0)
        ).optional()?.unwrap_or(0);

        // 获取房间数量
        let total_rooms: i64 = conn.query_row(
            "SELECT COUNT(DISTINCT room_id) FROM message_search",
            [],
            |row| row.get(0)
        ).optional()?.unwrap_or(0);

        // 获取发送者数量
        let total_senders: i64 = conn.query_row(
            "SELECT COUNT(DISTINCT sender_id) FROM message_search",
            [],
            |row| row.get(0)
        ).optional()?.unwrap_or(0);

        // 获取数据库大小
        let db_size = std::fs::metadata(&db_path)
            .map(|m| m.len() as i64)
            .unwrap_or(0);

        Ok::<serde_json::Value, String>(serde_json::json!({
            "total_messages": total_messages,
            "total_rooms": total_rooms,
            "total_senders": total_senders,
            "db_size_bytes": db_size,
            "db_size_mb": format!("{:.2}", db_size as f64 / 1024.0 / 1024.0)
        }))
    })
    .await
    .map_err(|e| format!("task join error: {e}"))??;

    Ok(stats)
}

// 优化搜索数据库
#[tauri::command]
pub async fn optimize_search_db(app: tauri::AppHandle) -> Result<(), String> {
    let db_path = resolve_search_db_path(&app)?;

    tauri::async_runtime::spawn_blocking(move || {
        let conn = open_search_connection(&db_path)?;

        // 优化FTS5表
        conn.execute("INSERT INTO message_search(message_search) VALUES('optimize')", [])
            .map_err(|e| format!("failed to optimize search db: {e}"))?;

        // 分析表以更新统计信息
        conn.execute("ANALYZE", [])
            .map_err(|e| format!("failed to analyze search db: {e}"))?;

        // 清理WAL文件
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE)", [])
            .map_err(|e| format!("failed to checkpoint wal: {e}"))?;

        Ok::<(), String>(())
    })
    .await
    .map_err(|e| format!("task join error: {e}"))??;

    Ok(())
}