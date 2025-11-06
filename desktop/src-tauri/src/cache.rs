use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;
use serde_json::Value;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::Manager;

const TABLE_INIT_SQL: &str = "CREATE TABLE IF NOT EXISTS kv_cache (\
    cache_key TEXT PRIMARY KEY,\
    updated_at INTEGER NOT NULL,\
    payload TEXT NOT NULL\
)";

fn resolve_db_path(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    let mut dir = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("failed to resolve app data dir: {e}"))?;
    std::fs::create_dir_all(&dir)
        .map_err(|e| format!("failed to create app data dir {:?}: {e}", dir))?;
    dir.push("cache.db");
    Ok(dir)
}

fn open_connection(db_path: &PathBuf) -> Result<Connection, String> {
    let conn = Connection::open(db_path).map_err(|e| format!("failed to open cache db: {e}"))?;
    conn.execute("PRAGMA journal_mode = WAL", [])
        .map_err(|e| format!("failed to set WAL mode: {e}"))?;
    conn.execute(TABLE_INIT_SQL, [])
        .map_err(|e| format!("failed to initialize cache table: {e}"))?;
    Ok(conn)
}

fn now_ts() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CacheEnvelope {
    pub data: Value,
    pub updated_at: i64,
}

fn save_value(db_path: PathBuf, key: String, payload: Value) -> Result<(), String> {
    let payload_text =
        serde_json::to_string(&payload).map_err(|e| format!("failed to serialize payload: {e}"))?;
    let conn = open_connection(&db_path)?;
    let ts = now_ts();
    conn.execute(
        "INSERT INTO kv_cache (cache_key, updated_at, payload) VALUES (?1, ?2, ?3)\
        ON CONFLICT(cache_key) DO UPDATE SET updated_at = excluded.updated_at, payload = excluded.payload",
        params![key, ts, payload_text],
    )
    .map_err(|e| format!("failed to persist cache value: {e}"))?;
    Ok(())
}

fn load_value(db_path: PathBuf, key: String) -> Result<Option<CacheEnvelope>, String> {
    let conn = open_connection(&db_path)?;
    let mut stmt = conn
        .prepare("SELECT payload, updated_at FROM kv_cache WHERE cache_key = ?1")
        .map_err(|e| format!("failed to prepare select statement: {e}"))?;

    let row_opt = stmt
        .query_row(params![key], |row| {
            let payload_text: String = row.get(0)?;
            let updated_at: i64 = row.get(1)?;
            let data: Value = serde_json::from_str(&payload_text).map_err(|e| {
                rusqlite::Error::FromSqlConversionFailure(
                    0,
                    rusqlite::types::Type::Text,
                    Box::new(e),
                )
            })?;
            Ok(CacheEnvelope { data, updated_at })
        })
        .optional()
        .map_err(|e| format!("failed to query cache: {e}"))?;

    Ok(row_opt)
}

fn clear_value(db_path: PathBuf, key: String) -> Result<(), String> {
    let conn = open_connection(&db_path)?;
    conn.execute("DELETE FROM kv_cache WHERE cache_key = ?1", params![key])
        .map_err(|e| format!("failed to delete cache key: {e}"))?;
    Ok(())
}

#[tauri::command]
pub async fn cache_save_value(
    app: tauri::AppHandle,
    key: String,
    payload: Value,
) -> Result<(), String> {
    let db_path = resolve_db_path(&app)?;
    tauri::async_runtime::spawn_blocking(move || save_value(db_path, key, payload))
        .await
        .map_err(|e| format!("task join error: {e}"))??;
    Ok(())
}

#[tauri::command]
pub async fn cache_load_value(
    app: tauri::AppHandle,
    key: String,
) -> Result<Option<CacheEnvelope>, String> {
    let db_path = resolve_db_path(&app)?;
    let result = tauri::async_runtime::spawn_blocking(move || load_value(db_path, key))
        .await
        .map_err(|e| format!("task join error: {e}"))??;
    Ok(result)
}

#[tauri::command]
pub async fn cache_clear_value(app: tauri::AppHandle, key: String) -> Result<(), String> {
    let db_path = resolve_db_path(&app)?;
    tauri::async_runtime::spawn_blocking(move || clear_value(db_path, key))
        .await
        .map_err(|e| format!("task join error: {e}"))??;
    Ok(())
}
