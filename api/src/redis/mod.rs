use redis::{aio::MultiplexedConnection, Client};
use tracing::info;

pub mod cache;
pub mod config;
pub mod models;
pub mod session;

pub use config::{RedisConfig, RedisTopology};

/// Redis 连接管理器
///
/// 逻辑入口架构：
/// - Session：持久化状态，存储用户会话、节点心跳和跨节点在线态
/// - Cache：纯缓存数据，存储刷新令牌、短信验证码和下载 URL 缓存
/// - Pub/Sub：单独 client/connection，负责跨节点广播
///
/// 部署上可映射到 1~3 套 Redis 实例：
/// - `REDIS_SESSION_URL` 必填逻辑入口，未设置时回退 `redis://localhost:6381`
/// - `REDIS_CACHE_URL` 可选，未设置时回退 `REDIS_SESSION_URL`
/// - `REDIS_PUBSUB_URL` 可选，未设置时回退 `REDIS_SESSION_URL`
#[derive(Clone)]
pub struct RedisManager {
    config: RedisConfig,
    pub pubsub_client: Client,
    pub cache_client: Client,
    pub session_client: Client,
    pub pubsub_connection: MultiplexedConnection,
    pub cache_connection: MultiplexedConnection,
    pub session_connection: MultiplexedConnection,
}

impl RedisManager {
    /// 创建 Redis 管理器
    pub async fn new() -> Result<Self, Box<dyn std::error::Error>> {
        dotenvy::dotenv().ok();
        Self::from_config(RedisConfig::from_env()).await
    }

    /// 基于解析后的 Redis 配置创建管理器。
    pub async fn from_config(config: RedisConfig) -> Result<Self, Box<dyn std::error::Error>> {
        let pubsub_client = Self::open_client("Pub/Sub", config.pubsub_url())?;
        let cache_client = Self::open_client("Cache", config.cache_url())?;
        let session_client = Self::open_client("Session", config.session_url())?;
        let pubsub_connection = pubsub_client.get_multiplexed_async_connection().await?;
        let cache_connection = cache_client.get_multiplexed_async_connection().await?;
        let session_connection = session_client.get_multiplexed_async_connection().await?;

        Ok(Self {
            config,
            pubsub_client,
            cache_client,
            session_client,
            pubsub_connection,
            cache_connection,
            session_connection,
        })
    }

    fn open_client(label: &str, url: &str) -> Result<Client, redis::RedisError> {
        let client = Client::open(url)?;
        info!("Redis {} 连接建立成功", label);
        Ok(client)
    }

    pub fn config(&self) -> &RedisConfig {
        &self.config
    }

    pub fn topology(&self) -> RedisTopology {
        self.config.topology()
    }

    /// 测试连接
    pub async fn test_connections(&self) -> Result<(), Box<dyn std::error::Error>> {
        Self::ping_client("Pub/Sub", &self.pubsub_client).await?;
        Self::ping_client("Cache", &self.cache_client).await?;
        Self::ping_client("Session", &self.session_client).await?;

        Ok(())
    }

    async fn ping_client(label: &str, client: &Client) -> Result<(), redis::RedisError> {
        let mut conn = client.get_multiplexed_async_connection().await?;
        let _: String = redis::cmd("PING").query_async(&mut conn).await?;
        info!("Redis {} 连接测试成功", label);
        Ok(())
    }

    /// 获取 Pub/Sub 客户端
    pub fn get_pubsub_client(&self) -> &Client {
        &self.pubsub_client
    }

    /// 获取 Cache 客户端
    pub fn get_cache_client(&self) -> &Client {
        &self.cache_client
    }

    /// 获取 Session 客户端
    pub fn get_session_client(&self) -> &Client {
        &self.session_client
    }

    pub fn get_pubsub_connection(&self) -> MultiplexedConnection {
        self.pubsub_connection.clone()
    }

    pub fn get_cache_connection(&self) -> MultiplexedConnection {
        self.cache_connection.clone()
    }

    pub fn get_session_connection(&self) -> MultiplexedConnection {
        self.session_connection.clone()
    }

    /// 获取会话管理器
    pub fn get_session_manager(&self, node_id: String) -> session::SessionManager {
        session::SessionManager::new(self.session_connection.clone(), node_id)
    }
}
