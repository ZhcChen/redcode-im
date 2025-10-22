use crate::redis::models::{CacheKeys, CrossNodeMessage, MessagePriority};
use redis::{AsyncCommands, Client, RedisResult};
use tracing::info;

/// Redis Streams 管理器
pub struct StreamManager {
    client: Client,
    node_id: String,
    consumer_group: String,
}

impl StreamManager {
    /// 创建新的 Stream 管理器
    pub fn new(client: Client, node_id: String) -> Self {
        let consumer_group = format!("node_{}", node_id);

        Self {
            client,
            node_id,
            consumer_group,
        }
    }

    /// 发送消息到 Stream
    pub async fn send_message(&self, message: &CrossNodeMessage) -> RedisResult<String> {
        let mut conn = self.client.get_async_connection().await?;
        let stream_key = CacheKeys::stream_key(&message.room_id);

        // 根据消息优先级决定发送策略
        match message.priority {
            MessagePriority::Critical | MessagePriority::High => {
                // 重要消息发送到 Stream
                let message_json = serde_json::to_string(message).map_err(|e| {
                    redis::RedisError::from((
                        redis::ErrorKind::TypeError,
                        "JSON序列化失败",
                        e.to_string(),
                    ))
                })?;

                let message_id: String = conn
                    .xadd(
                        &stream_key,
                        "*",
                        &[
                            ("data", &message_json),
                            ("priority", &format!("{:?}", message.priority)),
                            ("source_node", &message.source_node),
                            ("timestamp", &message.timestamp.timestamp().to_string()),
                        ],
                    )
                    .await?;

                info!(
                    "消息发送到 Stream {}: {} (优先级: {:?})",
                    stream_key, message_id, message.priority
                );
                Ok(message_id)
            }
            MessagePriority::Normal | MessagePriority::Low => {
                // 普通消息不走 Stream，直接返回
                info!("普通消息跳过 Stream 存储: {:?}", message.priority);
                Ok("normal_message".to_string())
            }
        }
    }
}
