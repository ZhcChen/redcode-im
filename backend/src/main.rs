use std::{env, sync::Arc};
use std::net::IpAddr;

use tokio::net::TcpListener;
use tokio::sync::mpsc;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing::{error, info};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

use redcode_im_backend::{
    database, redis, routes, services, websocket, middleware,
    logging::{self, DatabaseLayer, LoggingConfig, LogWriter, PostgresLogStore, LogStore, LogEntry},
    AppState,
};

#[tokio::main]
async fn main() {
    // 先生成 node_id
    let node_id = generate_node_id();

    // 读取日志配置
    let log_config = LoggingConfig::from_env();

    // 创建日志 channel
    let (log_tx, log_rx) = mpsc::channel::<LogEntry>(10000);

    // 初始化 tracing（包含数据库 layer）
    init_tracing(log_tx.clone(), node_id.clone(), &log_config);

    // 初始化数据库连接（使用 eprintln! 确保启动阶段日志即使控制台关闭也能输出）
    eprintln!("[STARTUP] 正在初始化数据库连接...");
    let database = database::Database::new().await.expect("数据库连接失败");

    // 运行数据库迁移
    eprintln!("[STARTUP] 正在运行数据库迁移...");
    database.migrate().await.expect("数据库迁移失败");

    eprintln!("[STARTUP] 数据库初始化完成!");

    // 初始化日志存储并启动写入任务
    let log_store: Arc<dyn LogStore> = Arc::new(PostgresLogStore::new(database.pool().clone()));
    if log_config.enabled {
        eprintln!("[STARTUP] 正在初始化日志存储系统...");
        let writer = LogWriter::new(log_rx, log_store.clone(), log_config.writer_config.clone());
        tokio::spawn(async move {
            writer.run().await;
        });

        // 启动日志清理任务
        let cleanup_store = log_store.clone();
        let retention_days = log_config.writer_config.retention_days;
        tokio::spawn(async move {
            logging::writer::start_log_cleanup_task(cleanup_store, retention_days).await;
        });
        eprintln!("[STARTUP] 日志存储系统初始化完成!");
    }

    // 初始化 Redis 连接
    eprintln!("[STARTUP] 正在初始化 Redis 连接...");
    let redis_manager = redis::RedisManager::new().await.expect("Redis 连接失败");

    // 测试 Redis 连接
    redis_manager
        .test_connections()
        .await
        .expect("Redis 连接测试失败");
    eprintln!("[STARTUP] Redis 连接初始化完成!");

    // 初始化地理位置服务
    eprintln!("[STARTUP] 正在初始化地理位置服务...");
    services::geolocation::init_geolocation_service(database.pool().clone());
    eprintln!("[STARTUP] 地理位置服务初始化完成!");

    // 初始化 WebSocket 连接管理器
    let connection_manager = std::sync::Arc::new(websocket::ConnectionManager::new());

    // 启动后台任务
    start_background_tasks(
        database.clone(),
        redis_manager.clone(),
        node_id.clone(),
        connection_manager.clone(),
    )
    .await;

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let state = AppState {
        database: database.clone(),
        redis: redis_manager,
        node_id: node_id.clone(),
        log_store,
        connection_manager,
    };

    let app = routes::create_routes()
        .layer(axum::middleware::from_fn_with_state(
            state.clone(),
            middleware::metrics_middleware,
        ))
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(state)
        .into_make_service_with_connect_info::<std::net::SocketAddr>();

    let port = env::var("PORT").unwrap_or_else(|_| "8010".to_string());
    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await.expect("bind");

    let local_ip = get_local_ip().unwrap_or_else(|| "Unknown".to_string());
    eprintln!("[STARTUP] 服务已启动:");
    eprintln!("[STARTUP]   > Local:   http://localhost:{}", port);
    eprintln!("[STARTUP]   > Network (Default): http://{}:{}", local_ip, port);

    // 尝试打印 en1 的 IP
    if let Some(en1_ip) = get_interface_ip("en1") {
        eprintln!("[STARTUP]   > Network (en1):     http://{}:{}", en1_ip, port);
    }

    axum::serve(listener, app).await.expect("server");
}

fn init_tracing(
    log_sender: mpsc::Sender<LogEntry>,
    node_id: String,
    log_config: &LoggingConfig,
) {
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into());

    // 控制台日志 layer（可选，由 LOG_CONSOLE_ENABLED 控制）
    let console_layer = if log_config.console_enabled {
        Some(tracing_subscriber::fmt::layer())
    } else {
        None
    };

    // 数据库日志 layer（可选，只存储 DEBUG/WARN/ERROR）
    let db_layer = if log_config.enabled {
        Some(DatabaseLayer::new(
            log_sender,
            node_id,
            log_config.level_config.clone(),
        ))
    } else {
        None
    };

    // 组合 layers（使用 Option 的 layer 支持）
    tracing_subscriber::registry()
        .with(env_filter)
        .with(console_layer)
        .with(db_layer)
        .init();
}

/// 启动后台任务
async fn start_background_tasks(
    database: database::Database,
    redis_manager: redis::RedisManager,
    node_id: String,
    connection_manager: std::sync::Arc<websocket::ConnectionManager>,
) {
    // 启动节点心跳任务
    let redis_heartbeat = redis_manager.clone();
    let node_id_clone = node_id.clone();
    let conn_mgr_heartbeat = connection_manager.clone();
    tokio::spawn(async move {
        loop {
            if let Err(e) =
                register_node_heartbeat(&redis_heartbeat, &node_id_clone, &conn_mgr_heartbeat).await
            {
                error!("节点心跳注册失败: {:?}", e);
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
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

    // 启动直传文件清理任务（回收 COS 空间，修正脏数据）
    let cleanup_db = database.clone();
    let cleanup_cfg = services::file_upload_cleanup::FileUploadCleanupConfig::from_env();
    let cleanup_interval_seconds = env::var("FILE_UPLOAD_CLEANUP_INTERVAL_SECONDS")
        .ok()
        .and_then(|v| v.trim().parse::<u64>().ok())
        .filter(|v| *v > 0)
        .unwrap_or(3600);
    tokio::spawn(async move {
        loop {
            if let Err(e) = services::file_upload_cleanup::run_file_upload_cleanup(
                cleanup_db.clone(),
                &cleanup_cfg,
            )
            .await
            {
                error!("文件上传清理任务失败: {:?}", e);
            }
            tokio::time::sleep(tokio::time::Duration::from_secs(cleanup_interval_seconds)).await;
        }
    });

    info!("后台任务启动完成: 节点ID = {}", node_id);
}

/// 生成节点ID
fn generate_node_id() -> String {
    format!("node_{}", uuid::Uuid::new_v4())
}

/// 注册节点心跳
async fn register_node_heartbeat(
    redis_manager: &redis::RedisManager,
    node_id: &str,
    connection_manager: &websocket::ConnectionManager,
) -> Result<(), Box<dyn std::error::Error>> {
    let session_manager = redis::session::SessionManager::new(
        redis_manager.get_session_client().clone(),
        node_id.to_string(),
    );

    // 获取当前节点统计信息
    let connected_users = connection_manager.get_online_user_count().await;
    let active_rooms = connection_manager.get_active_room_count().await;

    // 获取系统指标
    let cpu_usage = redcode_im_backend::utils::system::get_system_load().await.unwrap_or(0.0);
    let memory_usage = redcode_im_backend::utils::system::get_memory_usage().await.unwrap_or(0.0);
    let disk_usage = redcode_im_backend::utils::system::get_disk_usage().await.unwrap_or(0.0);
    let cpu_count = redcode_im_backend::utils::system::get_cpu_count().await.unwrap_or(1);
    let total_memory = redcode_im_backend::utils::system::get_total_memory().await.unwrap_or(0);

    session_manager
        .register_node_heartbeat(
            format!(
                "localhost:{}",
                env::var("PORT").unwrap_or_else(|_| "8010".to_string())
            ),
            connected_users,
            active_rooms,
            cpu_usage,
            memory_usage,
            disk_usage,
            cpu_count,
            total_memory,
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

/// 获取本机内网 IP 地址 (默认)
fn get_local_ip() -> Option<String> {
    let socket = std::net::UdpSocket::bind("0.0.0.0:0").ok()?;
    socket.connect("8.8.8.8:80").ok()?;
    socket.local_addr().ok().map(|addr| match addr.ip() {
        IpAddr::V4(ipv4) => ipv4.to_string(),
        IpAddr::V6(ipv6) => ipv6.to_string(),
    })
}

/// 获取指定网卡的 IPv4 地址
fn get_interface_ip(interface_name: &str) -> Option<String> {
    use local_ip_address::list_afinet_netifas;

    let network_interfaces = list_afinet_netifas().ok()?;

    for (name, ip) in network_interfaces {
        if name == interface_name {
            if let IpAddr::V4(ipv4) = ip {
                return Some(ipv4.to_string());
            }
        }
    }
    None
}
