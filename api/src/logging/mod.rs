//! 可扩展日志存储系统
//!
//! 将应用日志存储到 PostgreSQL，支持 7 天自动清理，
//! 并保持架构可扩展（便于后续切换到 ELK 等系统）。
//!
//! ## 架构
//!
//! ```text
//! tracing-subscriber
//!   ├── Console Layer (可选，由 LOG_CONSOLE_ENABLED 控制)
//!   └── Database Layer (DEBUG/WARN/ERROR)
//!              │
//!              ▼
//!         mpsc::channel
//!              │
//!              ▼
//!         LogWriter (批量写入)
//!              │
//!              ▼
//!         dyn LogStore
//!         └── PostgresLogStore
//! ```

pub mod layer;
pub mod store;
pub mod writer;

use sqlx::PgPool;
use std::sync::Arc;
use tokio::sync::mpsc;

pub use layer::{DatabaseLayer, LogLevelConfig};
pub use store::{LogEntry, LogQueryParams, LogQueryResult, LogStats, LogStore, PostgresLogStore};
pub use writer::{LogWriter, LogWriterConfig};

/// 日志系统配置
#[derive(Debug, Clone)]
pub struct LoggingConfig {
    /// 是否启用数据库日志
    pub enabled: bool,
    /// 是否启用控制台日志输出（生产环境可关闭以提升性能）
    pub console_enabled: bool,
    /// 日志级别配置
    pub level_config: LogLevelConfig,
    /// 写入器配置
    pub writer_config: LogWriterConfig,
    /// channel 容量
    pub channel_capacity: usize,
}

impl Default for LoggingConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            console_enabled: true,
            level_config: LogLevelConfig::default(),
            writer_config: LogWriterConfig::default(),
            channel_capacity: 10000,
        }
    }
}

impl LoggingConfig {
    /// 从环境变量读取配置
    pub fn from_env() -> Self {
        let enabled = std::env::var("LOG_DB_ENABLED")
            .map(|v| v.to_lowercase() != "false" && v != "0")
            .unwrap_or(true);

        // 控制台日志默认开启，生产环境可通过 LOG_CONSOLE_ENABLED=false 关闭
        let console_enabled = std::env::var("LOG_CONSOLE_ENABLED")
            .map(|v| v.to_lowercase() != "false" && v != "0")
            .unwrap_or(true);

        Self {
            enabled,
            console_enabled,
            level_config: LogLevelConfig::from_env(),
            writer_config: LogWriterConfig::from_env(),
            channel_capacity: 10000,
        }
    }
}

/// 日志系统初始化结果
pub struct LoggingSystem {
    /// 数据库 Layer（用于注册到 tracing-subscriber）
    pub layer: Option<DatabaseLayer>,
    /// 日志存储实例（用于查询和清理）
    pub store: Arc<dyn LogStore>,
    /// 写入器配置（用于启动清理任务）
    pub writer_config: LogWriterConfig,
}

/// 初始化日志系统
///
/// 返回 DatabaseLayer 和相关任务，需要在调用方注册到 tracing-subscriber
pub fn init_logging_system(pool: PgPool, node_id: String, config: LoggingConfig) -> LoggingSystem {
    let store: Arc<dyn LogStore> = Arc::new(PostgresLogStore::new(pool));

    if !config.enabled {
        return LoggingSystem {
            layer: None,
            store,
            writer_config: config.writer_config,
        };
    }

    let (tx, rx) = mpsc::channel(config.channel_capacity);

    // 创建 Layer
    let layer = DatabaseLayer::new(tx, node_id, config.level_config);

    // 启动写入任务
    let writer = LogWriter::new(rx, store.clone(), config.writer_config.clone());
    tokio::spawn(async move {
        writer.run().await;
    });

    LoggingSystem {
        layer: Some(layer),
        store,
        writer_config: config.writer_config,
    }
}

/// 启动日志清理后台任务
pub fn start_cleanup_task(store: Arc<dyn LogStore>, retention_days: i64) {
    tokio::spawn(async move {
        writer::start_log_cleanup_task(store, retention_days).await;
    });
}
