//! WebSocket 集成测试
//!
//! 使用真实端口方式测试 WebSocket 功能，包括 auth、join、ping/pong 和消息推送。
//!
//! 运行方式：
//! ```bash
//! cargo test --test ws_tests
//! ```

use axum::http::StatusCode;
use futures_util::{SinkExt, StreamExt};
use once_cell::sync::OnceCell;
use redcode_im_backend::database;
use redcode_im_backend::logging::{LogStore, PostgresLogStore};
use redcode_im_backend::redis;
use redcode_im_backend::services;
use redcode_im_backend::websocket;
use redcode_im_backend::AppState;
use serde_json::{json, Value};
use sqlx::postgres::PgPoolOptions;
use std::env;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::net::TcpListener;
use tokio_tungstenite::tungstenite::Utf8Bytes;
use tokio_tungstenite::{connect_async, tungstenite::Message};
use uuid::Uuid;

static TRACING_READY: OnceCell<()> = OnceCell::new();

fn ensure_env_defaults() {
    if env::var("REDIS_SESSION_URL").is_err() {
        env::set_var("REDIS_SESSION_URL", "redis://:123456@redis-session:6381/0");
    }
    if env::var("REDIS_CACHE_URL").is_err() {
        env::set_var("REDIS_CACHE_URL", "redis://:123456@redis-cache:6383/0");
    }
    if env::var("RUST_LOG").is_err() {
        env::set_var("RUST_LOG", "info");
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

fn unique_phone_username() -> String {
    let n = (Uuid::new_v4().as_u128() % 100_000_000) as u64;
    format!("138{:08}", n)
}

async fn start_test_server(state: AppState) -> SocketAddr {
    let app = redcode_im_backend::create_routes().with_state::<()>(state);
    let listener = TcpListener::bind("127.0.0.1:0").await.expect("绑定端口失败");
    let addr = listener.local_addr().expect("获取本地地址失败");

    tokio::spawn(async move {
        axum::serve(
            listener,
            app.into_make_service_with_connect_info::<SocketAddr>(),
        )
        .await
        .expect("服务器启动失败");
    });

    // 等待服务器启动
    tokio::time::sleep(Duration::from_millis(100)).await;
    addr
}

async fn register_user(addr: SocketAddr, username: &str, password: &str) -> String {
    let client = reqwest::Client::new();
    let resp = client
        .post(format!("http://{}/auth/register", addr))
        .json(&json!({
            "username": username,
            "email": "ignored@example.com",
            "password": password,
            "nickname": "WS测试用户"
        }))
        .send()
        .await
        .expect("注册请求失败");

    assert_eq!(resp.status(), StatusCode::OK, "注册失败");
    let body: Value = resp.json().await.expect("解析注册响应失败");
    body["id"].as_str().expect("响应缺少 id").to_string()
}

async fn login_user(addr: SocketAddr, username: &str, password: &str) -> String {
    let client = reqwest::Client::new();
    let resp = client
        .post(format!("http://{}/auth/login", addr))
        .json(&json!({
            "username": username,
            "password": password
        }))
        .send()
        .await
        .expect("登录请求失败");

    assert_eq!(resp.status(), StatusCode::OK, "登录失败");
    let body: Value = resp.json().await.expect("解析登录响应失败");
    body["token"].as_str().expect("响应缺少 token").to_string()
}

async fn create_group_room(addr: SocketAddr, token: &str, name: &str, member_ids: Vec<&str>) -> String {
    let client = reqwest::Client::new();
    let resp = client
        .post(format!("http://{}/rooms", addr))
        .header("Authorization", format!("Bearer {}", token))
        .json(&json!({
            "name": name,
            "description": "ws-test",
            "room_type": "group",
            "member_ids": member_ids
        }))
        .send()
        .await
        .expect("创建房间请求失败");

    assert_eq!(resp.status(), StatusCode::OK, "创建房间失败");
    let body: Value = resp.json().await.expect("解析创建房间响应失败");
    body["room"]["id"]
        .as_str()
        .expect("响应缺少 room.id")
        .to_string()
}

async fn send_message(addr: SocketAddr, token: &str, room_id: &str, content: &str) {
    let client = reqwest::Client::new();
    let resp = client
        .post(format!("http://{}/rooms/{}/messages", addr, room_id))
        .header("Authorization", format!("Bearer {}", token))
        .json(&json!({
            "content": content
        }))
        .send()
        .await
        .expect("发送消息请求失败");

    assert_eq!(resp.status(), StatusCode::OK, "发送消息失败");
}

async fn read_ws_event(
    read: &mut futures_util::stream::SplitStream<
        tokio_tungstenite::WebSocketStream<
            tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
        >,
    >,
    timeout: Duration,
) -> Option<Value> {
    match tokio::time::timeout(timeout, read.next()).await {
        Ok(Some(Ok(Message::Text(text)))) => serde_json::from_str(&text).ok(),
        _ => None,
    }
}

async fn wait_for_event_type(
    read: &mut futures_util::stream::SplitStream<
        tokio_tungstenite::WebSocketStream<
            tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
        >,
    >,
    event_type: &str,
    timeout: Duration,
) -> Option<Value> {
    let deadline = tokio::time::Instant::now() + timeout;
    loop {
        let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
        if remaining.is_zero() {
            return None;
        }
        if let Some(event) = read_ws_event(read, remaining).await {
            if event.get("type").and_then(|v| v.as_str()) == Some(event_type) {
                return Some(event);
            }
        } else {
            return None;
        }
    }
}

#[tokio::test]
async fn ws_auth_and_ping_pong() {
    let state = build_state().await;
    let addr = start_test_server(state).await;

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let _ = register_user(addr, &user1, pass).await;
    let token = login_user(addr, &user1, pass).await;

    // 连接 WebSocket
    let ws_url = format!("ws://{}/ws?format=json", addr);
    let (ws_stream, _) = connect_async(&ws_url).await.expect("WebSocket 连接失败");
    let (mut write, mut read) = ws_stream.split();

    // 发送 auth
    let auth_msg = json!({"type": "auth", "token": token});
    write
        .send(Message::Text(Utf8Bytes::from(auth_msg.to_string())))
        .await
        .expect("发送 auth 失败");

    // 等待 authed
    let authed = wait_for_event_type(&mut read, "authed", Duration::from_secs(5)).await;
    assert!(authed.is_some(), "未收到 authed 事件");
    assert!(
        authed.as_ref().unwrap().get("user_id").is_some(),
        "authed 响应缺少 user_id"
    );

    // 发送 ping
    let ping_msg = json!({"type": "ping"});
    write
        .send(Message::Text(Utf8Bytes::from(ping_msg.to_string())))
        .await
        .expect("发送 ping 失败");

    // 等待 pong
    let pong = wait_for_event_type(&mut read, "pong", Duration::from_secs(5)).await;
    assert!(pong.is_some(), "未收到 pong 事件");
}

#[tokio::test]
async fn ws_join_room_and_receive_message() {
    let state = build_state().await;
    let addr = start_test_server(state).await;

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(addr, &user2, pass).await;
    let _ = register_user(addr, &user1, pass).await;

    let token1 = login_user(addr, &user1, pass).await;
    let token2 = login_user(addr, &user2, pass).await;

    // user1 创建群聊，邀请 user2
    let room_id = create_group_room(addr, &token1, "ws-test-room", vec![&user2_id]).await;

    // user2 连接 WebSocket
    let ws_url = format!("ws://{}/ws?format=json", addr);
    let (ws_stream, _) = connect_async(&ws_url).await.expect("WebSocket 连接失败");
    let (mut write, mut read) = ws_stream.split();

    // user2 发送 auth
    let auth_msg = json!({"type": "auth", "token": token2});
    write
        .send(Message::Text(Utf8Bytes::from(auth_msg.to_string())))
        .await
        .expect("发送 auth 失败");

    let authed = wait_for_event_type(&mut read, "authed", Duration::from_secs(5)).await;
    assert!(authed.is_some(), "未收到 authed 事件");

    // user2 加入房间
    let join_msg = json!({"type": "join", "room_id": room_id});
    write
        .send(Message::Text(Utf8Bytes::from(join_msg.to_string())))
        .await
        .expect("发送 join 失败");

    let joined = wait_for_event_type(&mut read, "joined", Duration::from_secs(5)).await;
    assert!(joined.is_some(), "未收到 joined 事件");
    assert_eq!(
        joined.as_ref().unwrap().get("room_id").and_then(|v| v.as_str()),
        Some(room_id.as_str()),
        "joined 响应 room_id 不匹配"
    );

    // user1 发送消息
    let needle = format!("ws_push_{}", Uuid::new_v4());
    send_message(addr, &token1, &room_id, &needle).await;

    // user2 接收消息推送
    let msg = wait_for_event_type(&mut read, "message", Duration::from_secs(8)).await;
    assert!(msg.is_some(), "未收到 message 推送");
    assert_eq!(
        msg.as_ref().unwrap().get("room_id").and_then(|v| v.as_str()),
        Some(room_id.as_str()),
        "message 推送 room_id 不匹配"
    );
    assert_eq!(
        msg.as_ref().unwrap().get("content").and_then(|v| v.as_str()),
        Some(needle.as_str()),
        "message 推送 content 不匹配"
    );
}

#[tokio::test]
async fn ws_join_without_auth_returns_error() {
    let state = build_state().await;
    let addr = start_test_server(state).await;

    // 连接 WebSocket（不认证）
    let ws_url = format!("ws://{}/ws?format=json", addr);
    let (ws_stream, _) = connect_async(&ws_url).await.expect("WebSocket 连接失败");
    let (mut write, mut read) = ws_stream.split();

    // 直接发送 join（未认证）
    let join_msg = json!({"type": "join", "room_id": Uuid::new_v4().to_string()});
    write
        .send(Message::Text(Utf8Bytes::from(join_msg.to_string())))
        .await
        .expect("发送 join 失败");

    // 应该收到 error
    let error = wait_for_event_type(&mut read, "error", Duration::from_secs(5)).await;
    assert!(error.is_some(), "未收到 error 事件");
}

#[tokio::test]
async fn ws_invalid_auth_returns_error() {
    let state = build_state().await;
    let addr = start_test_server(state).await;

    // 连接 WebSocket
    let ws_url = format!("ws://{}/ws?format=json", addr);
    let (ws_stream, _) = connect_async(&ws_url).await.expect("WebSocket 连接失败");
    let (mut write, mut read) = ws_stream.split();

    // 发送无效 token
    let auth_msg = json!({"type": "auth", "token": "invalid_token_here"});
    write
        .send(Message::Text(Utf8Bytes::from(auth_msg.to_string())))
        .await
        .expect("发送 auth 失败");

    // 应该收到 error
    let error = wait_for_event_type(&mut read, "error", Duration::from_secs(5)).await;
    assert!(error.is_some(), "未收到 error 事件");
}

#[tokio::test]
async fn ws_join_nonmember_room_returns_error() {
    let state = build_state().await;
    let addr = start_test_server(state).await;

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();
    let user3 = unique_phone_username();

    let user2_id = register_user(addr, &user2, pass).await;
    let _ = register_user(addr, &user1, pass).await;
    let _ = register_user(addr, &user3, pass).await;

    let token1 = login_user(addr, &user1, pass).await;
    let token3 = login_user(addr, &user3, pass).await;

    // user1 创建群聊，只邀请 user2（不包含 user3）
    let room_id = create_group_room(addr, &token1, "ws-test-room-2", vec![&user2_id]).await;

    // user3 连接 WebSocket
    let ws_url = format!("ws://{}/ws?format=json", addr);
    let (ws_stream, _) = connect_async(&ws_url).await.expect("WebSocket 连接失败");
    let (mut write, mut read) = ws_stream.split();

    // user3 认证
    let auth_msg = json!({"type": "auth", "token": token3});
    write
        .send(Message::Text(Utf8Bytes::from(auth_msg.to_string())))
        .await
        .expect("发送 auth 失败");

    let authed = wait_for_event_type(&mut read, "authed", Duration::from_secs(5)).await;
    assert!(authed.is_some(), "未收到 authed 事件");

    // user3 尝试加入不是成员的房间
    let join_msg = json!({"type": "join", "room_id": room_id});
    write
        .send(Message::Text(Utf8Bytes::from(join_msg.to_string())))
        .await
        .expect("发送 join 失败");

    // 应该收到 error
    let error = wait_for_event_type(&mut read, "error", Duration::from_secs(5)).await;
    assert!(error.is_some(), "未收到 error 事件");
}
