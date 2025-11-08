use redis::{AsyncCommands, Client, RedisResult};
use tokio::sync::mpsc;
use uuid::Uuid;
use serde_json;
use tracing::{error, info, warn};
use std::collections::HashSet;
use std::str;
use std::sync::Arc;

use prost::Message as _;

use crate::proto::ws;
use crate::redis::models::{CacheKeys, PubSubPayload};

/// Redis Pub/Sub 管理器
pub struct PubSubManager {
    client: Client,
    node_id: String,
    subscribed_rooms: Arc<tokio::sync::RwLock<HashSet<Uuid>>>,
    message_sender: mpsc::UnboundedSender<PubSubPayload>,
}

impl PubSubManager {
    /// 创建新的 Pub/Sub 管理器
    pub fn new(client: Client, node_id: String) -> (Self, mpsc::UnboundedReceiver<PubSubPayload>) {
        let (message_sender, message_receiver) = mpsc::unbounded_channel();

        let manager = Self {
            client,
            node_id,
            subscribed_rooms: Arc::new(tokio::sync::RwLock::new(HashSet::new())),
            message_sender,
        };

        (manager, message_receiver)
    }

    /// 订阅房间频道
    pub async fn subscribe_to_room(&self, room_id: &Uuid) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let channel = CacheKeys::pubsub_channel(room_id);

        conn.subscribe(&channel).await?;

        // 记录订阅的房间
        let mut rooms = self.subscribed_rooms.write().await;
        rooms.insert(*room_id);

        info!("节点 {} 订阅房间频道: {}", self.node_id, channel);
        Ok(())
    }

    /// 取消订阅房间频道
    pub async fn unsubscribe_from_room(&self, room_id: &Uuid) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let channel = CacheKeys::pubsub_channel(room_id);

        conn.unsubscribe(&channel).await?;

        // 移除订阅记录
        let mut rooms = self.subscribed_rooms.write().await;
        rooms.remove(room_id);

        info!("节点 {} 取消订阅房间频道: {}", self.node_id, channel);
        Ok(())
    }

    /// 发布消息到房间频道
    pub async fn publish_to_room(&self, room_id: &Uuid, payload: &PubSubPayload) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let channel = CacheKeys::pubsub_channel(room_id);

        let encoded = payload.encode_protobuf();

        let subscriber_count: i32 = conn.publish(&channel, encoded).await?;

        info!("消息发布到房间 {}: {} 个订阅者收到", room_id, subscriber_count);
        Ok(())
    }

    /// 启动 Pub/Sub 监听器
    pub async fn start_listener(&self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let client = self.client.clone();
        let node_id = self.node_id.clone();
        let message_sender = self.message_sender.clone();

        // 启动监听任务
        tokio::spawn(async move {
            loop {
                match Self::create_and_listen(client.clone(), node_id.clone(), message_sender.clone()).await {
                    Ok(_) => {
                        warn!("Pub/Sub 监听器意外结束，重新启动...");
                        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
                    }
                    Err(e) => {
                        error!("Pub/Sub 监听器错误: {:?}，等待 10 秒后重试...", e);
                        tokio::time::sleep(tokio::time::Duration::from_secs(10)).await;
                    }
                }
            }
        });

        Ok(())
    }

    /// 创建连接并监听消息
    async fn create_and_listen(
        client: Client,
        node_id: String,
        message_sender: mpsc::UnboundedSender<PubSubPayload>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let mut conn = client.get_multiplexed_async_connection().await?;
        let mut pubsub = conn.into_pubsub();

        // 订阅系统控制频道
        pubsub.subscribe("system:control").await?;

        info!("Pub/Sub 监听器启动，节点: {}", node_id);

        // 监听消息
        let mut stream = pubsub.on_message();
        while let Some(msg) = stream.next().await {
            let channel = msg.get_channel_name();
            let payload_bytes: Vec<u8> = msg.get_payload()?;

            if channel == "system:control" {
                if let Ok(text) = str::from_utf8(&payload_bytes) {
                    Self::handle_system_control(text, &node_id).await;
                } else {
                    warn!("系统控制消息不是有效的 UTF-8 文本");
                }
            } else if channel.starts_with("room:") {
                Self::handle_room_message(&payload_bytes, &node_id, &message_sender).await;
            }
        }

        Ok(())
    }

    /// 处理系统控制消息
    async fn handle_system_control(payload: &str, node_id: &str) {
        info!("收到系统控制消息 [{}]: {}", node_id, payload);

        // 解析控制命令
        if let Ok(control) = serde_json::from_str::<serde_json::Value>(payload) {
            if let Some(command) = control.get("command").and_then(|c| c.as_str()) {
                match command {
                    "ping" => {
                        info!("收到 ping 命令");
                        // 可以在这里发送 pong 响应
                    }
                    "restart" => {
                        warn!("收到重启命令 [{}]", node_id);
                        // 可以在这里实现优雅重启逻辑
                    }
                    _ => {
                        warn!("未知控制命令: {}", command);
                    }
                }
            }
        }
    }

    /// 处理房间消息
    async fn handle_room_message(
        payload: &[u8],
        node_id: &str,
        message_sender: &mpsc::UnboundedSender<PubSubPayload>,
    ) {
        let parsed = ws::PubSubEvent::decode(payload)
            .ok()
            .and_then(|event| PubSubPayload::try_from(event).ok())
            .or_else(|| {
                match str::from_utf8(payload) {
                    Ok(text) => match serde_json::from_str::<PubSubPayload>(text) {
                        Ok(event) => Some(event),
                        Err(err) => {
                            error!("解析房间消息失败 [{}]: {:?}", node_id, err);
                            None
                        }
                    },
                    Err(err) => {
                        error!("房间消息不是有效的 UTF-8 [{}]: {:?}", node_id, err);
                        None
                    }
                }
            });

        let Some(event) = parsed else {
            return;
        };

        let should_forward = match &event {
            PubSubPayload::Message { data } => data.source_node != node_id,
            PubSubPayload::ReadReceipt { data } => data.source_node != node_id,
            PubSubPayload::MessageUpdate { .. } => true,
            PubSubPayload::PinUpdate { .. } => true,
        };

        if !should_forward {
            return;
        }

        match &event {
            PubSubPayload::Message { data } => {
                info!(
                    "收到跨节点消息 [{}]: 房间={}, 发送者={}",
                    node_id, data.room_id, data.sender_id
                );
            }
            PubSubPayload::ReadReceipt { data } => {
                info!(
                    "收到跨节点已读回执 [{}]: 房间={}, 读者={}, 消息={}",
                    node_id, data.room_id, data.reader_id, data.message_id
                );
            }
            PubSubPayload::MessageUpdate { data } => {
                info!(
                    "收到跨节点消息更新 [{}]: 房间={}, 消息={}, 删除状态={}",
                    node_id, data.room_id, data.message_id, data.is_deleted
                );
            }
            PubSubPayload::PinUpdate { data } => {
                info!(
                    "收到跨节点置顶更新 [{}]: 房间={}, 消息={}, 是否置顶={}",
                    node_id,
                    data.room_id,
                    data
                        .message_id
                        .map(|id| id.to_string())
                        .unwrap_or_else(|| "<none>".to_string()),
                    data.is_pinned
                );
            }
        }

        if let Err(e) = message_sender.send(event) {
            error!("发送消息到处理器失败: {:?}", e);
        }
    }

    /// 广播系统消息
    pub async fn broadcast_system_message(&self, message: &str) -> RedisResult<()> {
        let mut conn = self.client.get_multiplexed_async_connection().await?;
        let subscriber_count: i32 = conn.publish("system:control", message).await?;

        info!("系统消息广播: {} 个节点收到", subscriber_count);
        Ok(())
    }

    /// 获取当前订阅的房间数量
    pub async fn subscribed_rooms_count(&self) -> usize {
        self.subscribed_rooms.read().await.len()
    }

    /// 获取当前订阅的房间列表
    pub async fn get_subscribed_rooms(&self) -> Vec<Uuid> {
        self.subscribed_rooms.read().await.iter().copied().collect()
    }
}
