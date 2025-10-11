use redis::{Client, Connection, ConnectionManager};
use std::env;
use tracing::{info, error};

pub mod pubsub;
pub mod streams;
pub mod cache;
pub mod session;
pub mod models;

/// Redis 连接管理器
///
/// 多实例架构:
/// - Session专用Redis (6381): 持久化模式，存储用户会话和节点心跳
/// - Streams专用Redis (6382): 消息分发模式，实时消息推送和分发
/// - Cache专用Redis (6383): 纯缓存模式，存储房间信息、用户资料等元数据
#[derive(Clone)]
pub struct RedisManager {
    pub pubsub_client: Client,
    pub streams_client: Client,
    pub cache_client: Client,
    pub session_client: Client,
}

impl RedisManager {
    /// 创建 Redis 管理器
    pub async fn new() -> Result<Self, Box<dyn std::error::Error>> {
        dotenvy::dotenv().ok();

        // Pub/Sub 专用连接 (使用Session Redis)
        let pubsub_url = env::var("REDIS_SESSION_URL")
            .unwrap_or_else(|_| "redis://localhost:6381".to_string());
        let pubsub_client = Client::open(pubsub_url)?;
        info!("Redis Pub/Sub 连接建立成功");

        // Streams 专用连接
        let streams_url = env::var("REDIS_STREAM_URL")
            .unwrap_or_else(|_| "redis://localhost:6382".to_string());
        let streams_client = Client::open(streams_url)?;
        info!("Redis Streams 连接建立成功");

        // Cache 专用连接
        let cache_url = env::var("REDIS_CACHE_URL")
            .unwrap_or_else(|_| "redis://localhost:6383".to_string());
        let cache_client = Client::open(cache_url)?;
        info!("Redis Cache 连接建立成功");

        // Session 专用连接
        let session_url = env::var("REDIS_SESSION_URL")
            .unwrap_or_else(|_| "redis://localhost:6381".to_string());
        let session_client = Client::open(session_url)?;
        info!("Redis Session 连接建立成功");

        Ok(RedisManager {
            pubsub_client,
            streams_client,
            cache_client,
            session_client,
        })
    }

    /// 测试连接
    pub async fn test_connections(&self) -> Result<(), Box<dyn std::error::Error>> {
        // 测试各个专用连接
        let mut pubsub_conn = self.pubsub_client.get_connection()?;
        let _: String = redis::cmd("PING").query(&mut pubsub_conn)?;
        info!("Redis Pub/Sub 连接测试成功");

        let mut streams_conn = self.streams_client.get_connection()?;
        let _: String = redis::cmd("PING").query(&mut streams_conn)?;
        info!("Redis Streams 连接测试成功");

        let mut cache_conn = self.cache_client.get_connection()?;
        let _: String = redis::cmd("PING").query(&mut cache_conn)?;
        info!("Redis Cache 连接测试成功");

        let mut session_conn = self.session_client.get_connection()?;
        let _: String = redis::cmd("PING").query(&mut session_conn)?;
        info!("Redis Session 连接测试成功");

        Ok(())
    }

    /// 获取 Pub/Sub 客户端
    pub fn get_pubsub_client(&self) -> &Client {
        &self.pubsub_client
    }

    /// 获取 Streams 客户端
    pub fn get_streams_client(&self) -> &Client {
        &self.streams_client
    }

    /// 获取 Cache 客户端
    pub fn get_cache_client(&self) -> &Client {
        &self.cache_client
    }

    /// 获取 Session 客户端
    pub fn get_session_client(&self) -> &Client {
        &self.session_client
    }
}