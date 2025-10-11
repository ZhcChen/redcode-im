use redis::{Client, Commands, RedisResult, AsyncCommands, Connection};
use redis::streams::{StreamReadOptions, StreamRangeOptions};
use uuid::Uuid;
use serde_json;
use tracing::{info, error, warn};
use std::sync::Arc;
use tokio::sync::mpsc;

use crate::redis::models::{CrossNodeMessage, MessagePriority, MessageDeliveryResult, CacheKeys};

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
                let message_json = serde_json::to_string(message)
                    .map_err(|e| redis::RedisError::from((redis::ErrorKind::TypeError, "JSON序列化失败", e.to_string())))?;

                let message_id: String = conn.xadd(&stream_key, "*", &[
                    ("data", &message_json),
                    ("priority", &format!("{:?}", message.priority)),
                    ("source_node", &message.source_node),
                    ("timestamp", &message.timestamp.timestamp().to_string()),
                ]).await?;

                info!("消息发送到 Stream {}: {} (优先级: {:?})", stream_key, message_id, message.priority);
                Ok(message_id)
            }
            MessagePriority::Normal | MessagePriority::Low => {
                // 普通消息不走 Stream，直接返回
                info!("普通消息跳过 Stream 存储: {:?}", message.priority);
                Ok("normal_message".to_string())
            }
        }
    }

    /// 创建消费者组
    pub async fn create_consumer_group(&self, stream_key: &str) -> RedisResult<()> {
        let mut conn = self.client.get_async_connection().await?;

        // 尝试创建消费者组，如果已存在会忽略错误
        match conn.xgroup_create_mkstream(stream_key, &self.consumer_group, "$").await {
            Ok(_) => {
                info!("创建消费者组成功: {} -> {}", stream_key, self.consumer_group);
            }
            Err(e) => {
                // 如果消费者组已存在，忽略错误
                if e.to_string().contains("BUSYGROUP") {
                    info!("消费者组已存在: {} -> {}", stream_key, self.consumer_group);
                } else {
                    error!("创建消费者组失败: {:?}", e);
                    return Err(e);
                }
            }
        }

        Ok(())
    }

    /// 从 Stream 读取消息
    pub async fn read_messages(&self, stream_key: &str, count: Option<usize>) -> RedisResult<Vec<redis::streams::StreamKey>> {
        let mut conn = self.client.get_async_connection().await?;

        let options = StreamReadOptions::default()
            .group(&self.consumer_group, &format!("consumer_{}", self.node_id))
            .count(count.unwrap_or(10));

        let result: Vec<redis::streams::StreamKey> = conn
            .xread_options(&[stream_key], &[">"], &options)
            .await?;

        Ok(result)
    }

    /// 确认消息处理完成
    pub async fn acknowledge_message(&self, stream_key: &str, message_id: &str) -> RedisResult<i32> {
        let mut conn = self.client.get_async_connection().await?;

        let count: i32 = conn.xack(stream_key, &self.consumer_group, &[message_id]).await?;

        if count > 0 {
            info!("消息确认成功: {}@{}", stream_key, message_id);
        }

        Ok(count)
    }

    /// 启动 Stream 消费者
    pub async fn start_consumer(
        &self,
        message_sender: mpsc::UnboundedSender<CrossNodeMessage>,
        room_id: Uuid,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let stream_key = CacheKeys::stream_key(&room_id);
        let consumer_group = self.consumer_group.clone();
        let node_id = self.node_id.clone();

        // 确保消费者组存在
        self.create_consumer_group(&stream_key).await?;

        // 启动消费任务
        tokio::spawn(async move {
            let client = Client::open(redis_url_from_env().unwrap_or_else(|_| "redis://localhost:6382".to_string())).unwrap();

            loop {
                match Self::consume_messages(
                    &client,
                    &stream_key,
                    &consumer_group,
                    &node_id,
                    room_id,
                    message_sender.clone(),
                ).await {
                    Ok(_) => {
                        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
                    }
                    Err(e) => {
                        error!("Stream 消费者错误 [{}]: {:?}", node_id, e);
                        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                    }
                }
            }
        });

        Ok(())
    }

    /// 消费消息的具体实现
    async fn consume_messages(
        client: &Client,
        stream_key: &str,
        consumer_group: &str,
        node_id: &str,
        room_id: Uuid,
        message_sender: mpsc::UnboundedSender<CrossNodeMessage>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let mut conn = client.get_async_connection().await?;

        let options = StreamReadOptions::default()
            .group(consumer_group, &format!("consumer_{}", node_id))
            .count(10)
            .block(1000);

        let results: Vec<redis::streams::StreamKey> = conn
            .xread_options(&[stream_key], &[">"], &options)
            .await?;

        for stream_key_data in results {
            for stream_id in stream_key_data.ids {
                let message_id = stream_id.id;
                let fields = stream_id.fields;
                // 解析消息数据
                if let Some(data) = fields.get("data") {
                    match serde_json::from_str::<CrossNodeMessage>(data) {
                        Ok(mut message) => {
                            // 过滤掉自己发送的消息
                            if message.source_node != node_id {
                                info!("从 Stream 收到消息 [{}]: {}@{}",
                                      node_id, stream_key, message_id);

                                // 发送到消息处理器
                                if let Err(e) = message_sender.send(message) {
                                    error!("发送 Stream 消息到处理器失败: {:?}", e);
                                }
                            }

                            // 确认消息处理
                            if let Err(e) = Self::ack_message(client, stream_key, consumer_group, &message_id).await {
                                error!("确认消息失败: {:?}", e);
                            }
                        }
                        Err(e) => {
                            error!("解析 Stream 消息失败 [{}]: {}@{} -> {:?}",
                                  node_id, stream_key, message_id, e);
                        }
                    }
                }
            }
        }

        Ok(())
    }

    /// 确认消息的静态方法
    async fn ack_message(
        client: &Client,
        stream_key: &str,
        consumer_group: &str,
        message_id: &str,
    ) -> RedisResult<i32> {
        let mut conn = client.get_async_connection().await?;
        conn.xack(stream_key, consumer_group, &[message_id]).await
    }

    /// 获取 Stream 消息历史
    pub async fn get_message_history(&self, stream_key: &str, limit: usize) -> RedisResult<Vec<CrossNodeMessage>> {
        let mut conn = self.client.get_async_connection().await?;

        let options = StreamRangeOptions::default()
            .count(limit)
            .reverse();

        let results: Vec<redis::streams::StreamKey> = conn
            .xrange_options(stream_key, "-", "+", &options)
            .await?;

        let mut messages = Vec::new();
        for stream_key_data in results {
            for stream_id in stream_key_data.ids {
                let message_id = stream_id.id;
                let fields = stream_id.fields;
                if let Some(data) = fields.get("data") {
                    if let Ok(message) = serde_json::from_str::<CrossNodeMessage>(data) {
                        messages.push(message);
                    }
                }
            }
        }

        Ok(messages)
    }

    /// 清理过期的 Stream 数据
    pub async fn cleanup_old_messages(&self, stream_key: &str, max_length: usize) -> RedisResult<i32> {
        let mut conn = self.client.get_async_connection().await?;

        let deleted_count: i32 = conn.xtrim(stream_key, redis::streams::StreamMaxlen::Approx(max_length)).await?;

        if deleted_count > 0 {
            info!("清理 Stream {} 过期消息: {} 条", stream_key, deleted_count);
        }

        Ok(deleted_count)
    }

    /// 获取 Stream 信息
    pub async fn get_stream_info(&self, stream_key: &str) -> RedisResult<redis::streams::StreamInfo> {
        let mut conn = self.client.get_async_connection().await?;
        conn.xinfo_stream(stream_key).await
    }
}

// 辅助函数：从环境变量获取 Redis URL
fn redis_url_from_env() -> Result<String, Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    Ok(std::env::var("REDIS_STREAM_URL")
        .unwrap_or_else(|_| "redis://localhost:6382".to_string()))
}