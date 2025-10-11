mod routes;
mod handlers;
mod websocket;
mod models;
mod auth;
mod storage;
mod database;
mod redis;

use std::{env, net::SocketAddr};

use tokio::net::TcpListener;
use axum::Router;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
    services::ServeDir,
};
use tracing::{info, error};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() {
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    // 初始化数据库连接
    info!("正在初始化数据库连接...");
    let database = database::Database::new().await.expect("数据库连接失败");

    // 运行数据库迁移
    info!("正在运行数据库迁移...");
    database.migrate().await.expect("数据库迁移失败");

    info!("数据库初始化完成!");

    // 初始化 Redis 连接
    info!("正在初始化 Redis 连接...");
    let redis_manager = redis::RedisManager::new().await.expect("Redis 连接失败");

    // 测试 Redis 连接
    redis_manager.test_connections().await.expect("Redis 连接测试失败");
    info!("Redis 连接初始化完成!");

    // 启动后台任务
    let node_id = start_background_tasks(redis_manager.clone()).await;

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app = routes::create_routes()
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(AppState {
            database,
            redis: redis_manager,
            node_id,
        });

    let port: u16 = env::var("PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(8010);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));

    info!("服务器启动在 {}", addr);
    info!("PostgreSQL + Redis 多节点架构已就绪!");

    // 启动 API 文档静态服务 (端口 8011 默认)
    let api_doc_port: u16 = env::var("API_DOC_PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(8011);
    let api_doc_dir = env::var("API_DOC_DIR").unwrap_or_else(|_| "api_doc".to_string());

    let docs_router = Router::new()
        .nest_service("/", ServeDir::new(api_doc_dir).append_index_html_on_directories(true));

    tokio::spawn(async move {
        let docs_addr = SocketAddr::from(([0, 0, 0, 0], api_doc_port));
        match TcpListener::bind(docs_addr).await {
            Ok(listener_docs) => {
                info!("API 文档服务启动在 http://{}", docs_addr);
                info!("API Doc Banner: 服务已启动");
                if let Err(e) = axum::serve(listener_docs, docs_router).await {
                    tracing::error!("API 文档服务异常: {:?}", e);
                }
            }
            Err(e) => {
                tracing::error!("API 文档服务端口绑定失败: {:?}", e);
            }
        }
    });

    let listener = TcpListener::bind(addr).await.expect("bind");
    info!("服务已启动");
    axum::serve(listener, app).await.expect("server");
}

/// 应用状态
#[derive(Clone)]
pub struct AppState {
    pub database: database::Database,
    pub redis: redis::RedisManager,
    pub node_id: String,
}

/// 启动后台任务
async fn start_background_tasks(redis_manager: redis::RedisManager) -> String {
    let node_id = generate_node_id();

    // 启动节点心跳任务
    let redis_heartbeat = redis_manager.clone();
    let node_id_clone = node_id.clone();
    tokio::spawn(async move {
        loop {
            if let Err(e) = register_node_heartbeat(&redis_heartbeat, &node_id_clone).await {
                error!("节点心跳注册失败: {:?}", e);
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
        }
    });

    // 启动会话清理任务
    let redis_cleanup = redis_manager.clone();
    let node_id_cleanup = node_id.clone();
    tokio::spawn(async move {
        loop {
            if let Err(e) = cleanup_expired_sessions(&redis_cleanup, &node_id_cleanup).await {
                error!("会话清理失败: {:?}", e);
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(300)).await; // 5分钟
        }
    });

    info!("后台任务启动完成: 节点ID = {}", node_id);
    node_id
}

/// 生成节点ID
fn generate_node_id() -> String {
    format!("node_{}", uuid::Uuid::new_v4())
}

/// 注册节点心跳
async fn register_node_heartbeat(
    redis_manager: &redis::RedisManager,
    node_id: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let session_manager = redis::session::SessionManager::new(
        redis_manager.get_session_client().clone(),
        node_id.to_string(),
    );

    // 获取当前节点统计信息（这里简化处理）
    let connected_users = 0;
    let active_rooms = 0;

    session_manager
        .register_node_heartbeat(
            format!("localhost:{}", env::var("PORT").unwrap_or_else(|_| "8010".to_string())),
            connected_users,
            active_rooms,
        )
        .await?;

    Ok(())
}

/// 清理过期会话
async fn cleanup_expired_sessions(
    redis_manager: &redis::RedisManager,
    node_id: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let session_manager = redis::session::SessionManager::new(
        redis_manager.get_session_client().clone(),
        node_id.to_string(),
    );

    let cleaned_count = session_manager.cleanup_expired_sessions().await?;
    if cleaned_count > 0 {
        info!("清理了 {} 个过期会话", cleaned_count);
    }

    Ok(())
}