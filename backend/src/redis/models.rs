use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;
use crate::database::models::{UserStatus, RoomType, MessageType, MemberRole};

/// Redis 消息优先级
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MessagePriority {
    Critical,    // 系统消息、私信 - 必须持久化
    High,        // 重要群消息 - 双重保证
    Normal,      // 普通群聊 - 实时分发
    Low,         // 状态更新 - 实时分发
}

impl Default for MessagePriority {
    fn default() -> Self {
        MessagePriority::Normal
    }
}

/// Redis 会话信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionInfo {
    pub user_id: Uuid,
    pub node_id: String,
    pub socket_id: String,
    pub rooms: Vec<Uuid>,
    pub last_heartbeat: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

/// 跨节点消息结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CrossNodeMessage {
    pub id: Uuid,
    pub room_id: Uuid,
    pub sender_id: Uuid,
    pub content: String,
    pub message_type: MessageType,
    pub priority: MessagePriority,
    pub timestamp: DateTime<Utc>,
    pub source_node: String,
    pub target_nodes: Vec<String>,
}

/// 节点心跳信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeHeartbeat {
    pub node_id: String,
    pub address: String,
    pub status: NodeStatus,
    pub connected_users: usize,
    pub active_rooms: usize,
    pub last_heartbeat: DateTime<Utc>,
    pub started_at: DateTime<Utc>,
}

/// 节点状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum NodeStatus {
    Active,
    Inactive,
    Maintenance,
}

impl Default for NodeStatus {
    fn default() -> Self {
        NodeStatus::Active
    }
}

/// 房间成员信息 (Redis 缓存)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomMemberCache {
    pub user_id: Uuid,
    pub username: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub role: MemberRole,
    pub joined_at: DateTime<Utc>,
    pub last_seen: DateTime<Utc>,
}

/// 用户在线状态 (Redis 缓存)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserOnlineStatus {
    pub user_id: Uuid,
    pub username: String,
    pub status: UserStatus,
    pub last_activity: DateTime<Utc>,
    pub current_node: Option<String>,
    pub is_online: bool,
}

/// 消息发送结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageDeliveryResult {
    pub message_id: Uuid,
    pub target_nodes: Vec<String>,
    pub successful_nodes: Vec<String>,
    pub failed_nodes: Vec<String>,
    pub delivery_time: DateTime<Utc>,
}

/// 缓存键生成器
pub struct CacheKeys;

impl CacheKeys {
    /// 用户会话键
    pub fn user_session(user_id: &Uuid) -> String {
        format!("session:user:{}", user_id)
    }

    /// 节点会话列表键
    pub fn node_sessions(node_id: &str) -> String {
        format!("sessions:node:{}", node_id)
    }

    /// 房间成员缓存键
    pub fn room_members(room_id: &Uuid) -> String {
        format!("room:members:{}", room_id)
    }

    /// 用户在线状态键
    pub fn user_online_status(user_id: &Uuid) -> String {
        format!("user:online:{}", user_id)
    }

    /// 节点心跳键
    pub fn node_heartbeat(node_id: &str) -> String {
        format!("node:heartbeat:{}", node_id)
    }

    /// 活跃节点列表键
    pub fn active_nodes() -> String {
        "nodes:active".to_string()
    }

    /// Pub/Sub 频道名
    pub fn pubsub_channel(room_id: &Uuid) -> String {
        format!("room:{}", room_id)
    }

    /// Stream 键名
    pub fn stream_key(room_id: &Uuid) -> String {
        format!("stream:room:{}", room_id)
    }

    /// 用户缓存键
    pub fn user_cache(user_id: &Uuid) -> String {
        format!("cache:user:{}", user_id)
    }

    /// 房间信息缓存键
    pub fn room_cache(room_id: &Uuid) -> String {
        format!("cache:room:{}", room_id)
    }
}