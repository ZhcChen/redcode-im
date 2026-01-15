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
use sqlx::postgres::PgPoolOptions;
use std::env;
use std::sync::Arc;

static REDIS_READY: OnceCell<()> = OnceCell::new();
static TRACING_READY: OnceCell<()> = OnceCell::new();

fn ensure_env_defaults() {
    // 集成测试依赖真实 DB/Redis；这里给出“本地 docker-compose”默认值，避免忘记设置导致 NOAUTH。
    if env::var("REDIS_SESSION_URL").is_err() {
        env::set_var("REDIS_SESSION_URL", "redis://:123456@localhost:6381/0");
    }
    if env::var("REDIS_CACHE_URL").is_err() {
        env::set_var("REDIS_CACHE_URL", "redis://:123456@localhost:6383/0");
    }

    // 让测试默认开启必要日志（便于排错；可通过 RUST_LOG 覆盖）。
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
        .expect("DATABASE_URL_TEST 或 DATABASE_URL 必须设置（建议先在 backend/ 配置 .env，并启动 postgres/redis）");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .min_connections(1)
        .connect(&database_url)
        .await
        .expect("连接测试数据库失败");

    let database = database::Database { pool };
    database.migrate().await.expect("数据库迁移失败");

    // 初始化 Redis（仅做一次连通性检查，避免每个测试都 ping）
    let redis_manager = redis::RedisManager::new().await.expect("Redis 连接失败");
    if REDIS_READY.set(()).is_ok() {
        redis_manager
            .test_connections()
            .await
            .expect("Redis 连接测试失败（请确认 docker-compose redis-session/redis-cache 已启动，且 URL 包含密码）");
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
    // 注意：不要在多个 #[tokio::test] 之间缓存 PgPool/Redis 连接等异步资源，
    // 因为每个测试默认会创建独立 runtime，缓存资源会出现 runtime 不一致导致的超时/死锁。
    build_state().await
}

pub fn test_router(state: AppState) -> Router {
    // axum 0.8：Router<AppState> 本身不实现 Service，需要在 with_state 时将“剩余 State 类型”收敛为 ()。
    redcode_im_backend::create_routes().with_state::<()>(state)
}

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
