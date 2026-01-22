//! API 集成测试共享工具
//!
//! 提供 Axum in-process 测试的基础设施。

use axum::body::Body;
use axum::http::{header, Method, Request, StatusCode};
use axum::Router;
use http_body_util::BodyExt;
use once_cell::sync::OnceCell;
use redcode_im_backend::database;
use redcode_im_backend::logging::{LogStore, PostgresLogStore};
use redcode_im_backend::redis;
use redcode_im_backend::services;
use redcode_im_backend::websocket;
use redcode_im_backend::AppState;
use serde_json::Value;
use tower::ServiceExt;
use sqlx::postgres::PgPoolOptions;
use std::env;
use std::sync::Arc;
use uuid::Uuid;

static REDIS_READY: OnceCell<()> = OnceCell::new();
static TRACING_READY: OnceCell<()> = OnceCell::new();

fn ensure_env_defaults() {
    if env::var("REDIS_SESSION_URL").is_err() {
        env::set_var("REDIS_SESSION_URL", "redis://:123456@localhost:6381/0");
    }
    if env::var("REDIS_CACHE_URL").is_err() {
        env::set_var("REDIS_CACHE_URL", "redis://:123456@localhost:6383/0");
    }
    if env::var("RUST_LOG").is_err() {
        env::set_var("RUST_LOG", "info");
    }
    // 允许管理员初始化接口（测试用）
    if env::var("ALLOW_INSECURE_ADMIN_BOOTSTRAP").is_err() {
        env::set_var("ALLOW_INSECURE_ADMIN_BOOTSTRAP", "true");
    }
}

async fn build_state() -> AppState {
    dotenvy::dotenv().ok();
    ensure_env_defaults();

    if TRACING_READY.set(()).is_ok() {
        let _ = tracing_subscriber::fmt()
            .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
            .with_test_writer()
            .try_init();
    }

    let database_url = env::var("DATABASE_URL_TEST")
        .or_else(|_| env::var("DATABASE_URL"))
        .expect("DATABASE_URL_TEST 或 DATABASE_URL 必须设置");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .min_connections(1)
        .connect(&database_url)
        .await
        .expect("连接测试数据库失败");

    let database = database::Database { pool };
    database.migrate().await.expect("数据库迁移失败");

    let redis_manager = redis::RedisManager::new().await.expect("Redis 连接失败");
    if REDIS_READY.set(()).is_ok() {
        redis_manager
            .test_connections()
            .await
            .expect("Redis 连接测试失败");
    }

    services::geolocation::init_geolocation_service(database.pool().clone());

    let log_store: Arc<dyn LogStore> = Arc::new(PostgresLogStore::new(database.pool().clone()));
    let connection_manager = Arc::new(websocket::ConnectionManager::new());

    AppState {
        database,
        redis: redis_manager,
        node_id: "test-node".to_string(),
        log_store,
        connection_manager,
    }
}

pub async fn test_state() -> AppState {
    build_state().await
}

pub fn test_router(state: AppState) -> Router {
    redcode_im_backend::create_routes().with_state::<()>(state)
}

// ============================================================================
// 请求构造辅助函数
// ============================================================================

pub fn json_request(method: Method, uri: &str, token: Option<&str>, body: Value) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    builder = builder.header(header::CONTENT_TYPE, "application/json");
    if let Some(token) = token {
        builder = builder.header(header::AUTHORIZATION, format!("Bearer {}", token));
    }
    builder
        .body(Body::from(
            serde_json::to_vec(&body).expect("序列化 JSON 请求体失败"),
        ))
        .expect("构造请求失败")
}

pub fn empty_request(method: Method, uri: &str, token: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(token) = token {
        builder = builder.header(header::AUTHORIZATION, format!("Bearer {}", token));
    }
    builder.body(Body::empty()).expect("构造请求失败")
}

// ============================================================================
// 响应读取辅助函数
// ============================================================================

pub async fn read_bytes(response: axum::response::Response) -> (StatusCode, Vec<u8>) {
    let status = response.status();
    let bytes = response
        .into_body()
        .collect()
        .await
        .expect("读取响应 body 失败")
        .to_bytes();
    (status, bytes.to_vec())
}

pub async fn read_text(response: axum::response::Response) -> (StatusCode, String) {
    let (status, bytes) = read_bytes(response).await;
    let text = String::from_utf8(bytes).expect("响应不是 UTF-8 文本");
    (status, text)
}

pub async fn read_json(response: axum::response::Response) -> (StatusCode, Value) {
    let (status, bytes) = read_bytes(response).await;
    let json: Value = serde_json::from_slice(&bytes).unwrap_or_else(|e| {
        panic!(
            "响应不是有效 JSON: {} body={}",
            e,
            String::from_utf8_lossy(&bytes)
        )
    });
    (status, json)
}

// ============================================================================
// 测试数据生成
// ============================================================================

pub fn unique_phone_username() -> String {
    let n = (Uuid::new_v4().as_u128() % 100_000_000) as u64;
    format!("138{:08}", n)
}

pub fn unique_email() -> String {
    format!("test_{}@example.com", Uuid::new_v4().simple())
}

// ============================================================================
// 用户注册登录辅助函数
// ============================================================================

pub async fn register_user(app: Router, username: &str, password: &str) -> String {
    let register_body = serde_json::json!({
        "username": username,
        "email": "ignored@example.com",
        "password": password,
        "nickname": "集成测试用户"
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/register", None, register_body))
        .await
        .expect("请求失败");
    let (status, user) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "register 响应异常: {user}");
    user.get("id")
        .and_then(Value::as_str)
        .expect("register 响应缺少 id")
        .to_string()
}

pub async fn login_user(app: Router, username: &str, password: &str) -> String {
    let login_body = serde_json::json!({
        "username": username,
        "password": password
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/login", None, login_body))
        .await
        .expect("请求失败");
    let (status, login) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "login 响应异常: {login}");
    login.get("token")
        .and_then(Value::as_str)
        .expect("login 响应缺少 token")
        .to_string()
}

pub async fn create_public_room(app: Router, token: &str, name: &str) -> String {
    let body = serde_json::json!({
        "name": name,
        "description": "rust-test",
        "room_type": "public",
        "member_ids": []
    });
    let response = app
        .oneshot(json_request(Method::POST, "/rooms", Some(token), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "create room 响应异常: {resp}");
    resp.get("room")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("create room 响应缺少 room.id")
        .to_string()
}

// ============================================================================
// 群组房间辅助函数
// ============================================================================

pub async fn create_group_room(app: Router, token: &str, name: &str, member_ids: &[&str]) -> String {
    let body = serde_json::json!({
        "name": name,
        "description": "rust-test-group",
        "room_type": "group",
        "member_ids": member_ids
    });
    let response = app
        .oneshot(json_request(Method::POST, "/rooms", Some(token), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "create group room 响应异常: {resp}");
    resp.get("room")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("create group room 响应缺少 room.id")
        .to_string()
}

// ============================================================================
// 管理员辅助函数
// ============================================================================

/// 初始化默认管理员账号
/// 返回 (username, password)
pub async fn init_default_admin(app: Router) -> (String, String) {
    let response = app
        .oneshot(empty_request(Method::POST, "/api/admin/init-default-admin", None))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    // 可能已存在，200 或 409 都算成功
    assert!(
        status == StatusCode::OK || status == StatusCode::CONFLICT,
        "init default admin 响应异常: {resp}"
    );

    // 默认管理员账号
    ("admin".to_string(), "admin123".to_string())
}

/// 管理员登录
pub async fn login_admin(app: Router, username: &str, password: &str) -> String {
    let login_body = serde_json::json!({
        "username": username,
        "password": password
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/admin/login", None, login_body))
        .await
        .expect("请求失败");

    let (status, login) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "admin login 响应异常: {login}");
    login.get("token")
        .and_then(Value::as_str)
        .expect("admin login 响应缺少 token")
        .to_string()
}

/// 获取管理员 token（初始化 + 登录）
pub async fn get_admin_token(app: Router) -> String {
    let (username, password) = init_default_admin(app.clone()).await;
    login_admin(app, &username, &password).await
}

// ============================================================================
// 消息辅助函数
// ============================================================================

/// 发送消息并返回消息 ID
pub async fn send_message(app: Router, token: &str, room_id: &str, content: &str) -> String {
    let body = serde_json::json!({
        "content": content
    });
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(token),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "send message 响应异常: {resp}");
    resp.get("message")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("send message 响应缺少 message.id")
        .to_string()
}

/// 创建私密群组并返回房间 ID
pub async fn create_private_group(app: Router, token: &str, name: &str, member_ids: &[&str]) -> String {
    let body = serde_json::json!({
        "name": name,
        "description": "rust-test-private",
        "room_type": "group",
        "member_ids": member_ids,
        "is_private": true
    });
    let response = app
        .oneshot(json_request(Method::POST, "/rooms", Some(token), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "create private group 响应异常: {resp}");
    resp.get("room")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("create private group 响应缺少 room.id")
        .to_string()
}
