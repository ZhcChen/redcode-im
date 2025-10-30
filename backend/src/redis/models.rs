use crate::database::models::{MemberRole, MessageType, UserStatus};
use crate::proto::ws;
use chrono::{DateTime, Utc};
use prost::Message as _;
use serde::{Deserialize, Serialize};
use std::convert::TryFrom;
use uuid::Uuid;

/// Redis 消息优先级
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum MessagePriority {
    Critical, // 系统消息、私信 - 必须持久化
    High,     // 重要群消息 - 双重保证
    Normal,   // 普通群聊 - 实时分发
    Low,      // 状态更新 - 实时分发
}

impl Default for MessagePriority {
    fn default() -> Self {
        MessagePriority::Normal
    }
}

impl From<MessagePriority> for ws::PubSubPriority {
    fn from(value: MessagePriority) -> Self {
        match value {
            MessagePriority::Critical => ws::PubSubPriority::PubsubPriorityCritical,
            MessagePriority::High => ws::PubSubPriority::PubsubPriorityHigh,
            MessagePriority::Normal => ws::PubSubPriority::PubsubPriorityNormal,
            MessagePriority::Low => ws::PubSubPriority::PubsubPriorityLow,
        }
    }
}

impl From<ws::PubSubPriority> for MessagePriority {
    fn from(value: ws::PubSubPriority) -> Self {
        match value {
            ws::PubSubPriority::PubsubPriorityCritical => MessagePriority::Critical,
            ws::PubSubPriority::PubsubPriorityHigh => MessagePriority::High,
            ws::PubSubPriority::PubsubPriorityLow => MessagePriority::Low,
            ws::PubSubPriority::PubsubPriorityNormal => MessagePriority::Normal,
            ws::PubSubPriority::PubsubPriorityUnknown => MessagePriority::Normal,
        }
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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sender_username: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sender_nickname: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sender_avatar_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub quoted_message: Option<QuotedMessagePayload>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub forward_message: Option<ForwardMessagePayload>,
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

/// 已读回执事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReadReceiptEvent {
    pub room_id: Uuid,
    pub reader_id: Uuid,
    pub message_id: Uuid,
    pub read_at: DateTime<Utc>,
    pub source_node: String,
}

/// 被引用的消息载荷
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuotedMessagePayload {
    pub id: Uuid,
    pub room_id: Uuid,
    pub sender_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sender_username: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sender_nickname: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sender_avatar_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
    pub message_type: MessageType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_at: Option<DateTime<Utc>>,
    pub is_deleted: bool,
}

/// 被转发的消息载荷
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ForwardMessagePayload {
    pub message_id: Uuid,
    pub room_id: Uuid,
    pub sender_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sender_username: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sender_nickname: Option<String>,
}

/// 消息更新事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageUpdatePayload {
    pub room_id: Uuid,
    pub message_id: Uuid,
    pub is_deleted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub deleted_at: Option<DateTime<Utc>>,
}

/// 置顶消息事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PinUpdatePayload {
    pub room_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pinned_by: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pinned_at: Option<DateTime<Utc>>,
    pub is_pinned: bool,
}

/// Pub/Sub 统一事件载荷
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "event_type", rename_all = "snake_case")]
pub enum PubSubPayload {
    Message {
        #[serde(flatten)]
        data: CrossNodeMessage,
    },
    ReadReceipt {
        #[serde(flatten)]
        data: ReadReceiptEvent,
    },
    MessageUpdate {
        #[serde(flatten)]
        data: MessageUpdatePayload,
    },
    PinUpdate {
        #[serde(flatten)]
        data: PinUpdatePayload,
    },
}

/// 缓存键生成器
pub struct CacheKeys;

impl PubSubPayload {
    pub fn to_proto_event(&self) -> ws::PubSubEvent {
        use ws::pub_sub_event::Payload;

        let payload = match self {
            PubSubPayload::Message { data } => Payload::Message(ws::PubSubMessage::from(data)),
            PubSubPayload::ReadReceipt { data } => {
                Payload::ReadReceipt(ws::PubSubReadReceipt::from(data))
            }
            PubSubPayload::MessageUpdate { data } => {
                Payload::MessageUpdate(ws::PubSubMessageUpdate::from(data))
            }
            PubSubPayload::PinUpdate { data } => {
                Payload::PinUpdate(ws::PubSubPinUpdate::from(data))
            }
        };

        ws::PubSubEvent {
            payload: Some(payload),
        }
    }

    pub fn encode_protobuf(&self) -> Vec<u8> {
        self.to_proto_event().encode_to_vec()
    }
}

impl TryFrom<ws::PubSubEvent> for PubSubPayload {
    type Error = String;

    fn try_from(value: ws::PubSubEvent) -> Result<Self, Self::Error> {
        use ws::pub_sub_event::Payload;

        match value
            .payload
            .ok_or_else(|| "missing pubsub payload".to_string())?
        {
            Payload::Message(msg) => {
                let data = CrossNodeMessage::try_from(msg)?;
                Ok(PubSubPayload::Message { data })
            }
            Payload::ReadReceipt(receipt) => {
                let data = ReadReceiptEvent::try_from(receipt)?;
                Ok(PubSubPayload::ReadReceipt { data })
            }
            Payload::MessageUpdate(update) => {
                let data = MessageUpdatePayload::try_from(update)?;
                Ok(PubSubPayload::MessageUpdate { data })
            }
            Payload::PinUpdate(update) => {
                let data = PinUpdatePayload::try_from(update)?;
                Ok(PubSubPayload::PinUpdate { data })
            }
        }
    }
}

impl From<&CrossNodeMessage> for ws::PubSubMessage {
    fn from(value: &CrossNodeMessage) -> Self {
        ws::PubSubMessage {
            id: value.id.to_string(),
            room_id: value.room_id.to_string(),
            sender_id: value.sender_id.to_string(),
            content: value.content.clone(),
            message_type: value.message_type.to_string(),
            priority: ws::PubSubPriority::from(value.priority.clone()) as i32,
            timestamp: value.timestamp.to_rfc3339(),
            source_node: value.source_node.clone(),
            target_nodes: value.target_nodes.clone(),
            sender_username: value.sender_username.clone().unwrap_or_default(),
            sender_nickname: value.sender_nickname.clone().unwrap_or_default(),
            sender_avatar_url: value.sender_avatar_url.clone().unwrap_or_default(),
            quoted_message: value.quoted_message.as_ref().map(ws::QuotedMessage::from),
            forward_message: value.forward_message.as_ref().map(ws::ForwardMessage::from),
        }
    }
}

impl TryFrom<ws::PubSubMessage> for CrossNodeMessage {
    type Error = String;

    fn try_from(value: ws::PubSubMessage) -> Result<Self, Self::Error> {
        let id = parse_uuid(&value.id, "id")?;
        let room_id = parse_uuid(&value.room_id, "room_id")?;
        let sender_id = parse_uuid(&value.sender_id, "sender_id")?;
        let message_type = parse_message_type(&value.message_type)?;
        let priority_proto = ws::PubSubPriority::try_from(value.priority)
            .unwrap_or(ws::PubSubPriority::PubsubPriorityUnknown);
        let priority = MessagePriority::from(priority_proto);
        let timestamp = parse_datetime(&value.timestamp, "timestamp")?;

        Ok(CrossNodeMessage {
            id,
            room_id,
            sender_id,
            content: value.content,
            message_type,
            priority,
            timestamp,
            source_node: value.source_node,
            target_nodes: value.target_nodes,
            sender_username: option_from_string(value.sender_username),
            sender_nickname: option_from_string(value.sender_nickname),
            sender_avatar_url: option_from_string(value.sender_avatar_url),
            quoted_message: value
                .quoted_message
                .map(QuotedMessagePayload::try_from)
                .transpose()?,
            forward_message: value
                .forward_message
                .map(ForwardMessagePayload::try_from)
                .transpose()?,
        })
    }
}

impl From<&ReadReceiptEvent> for ws::PubSubReadReceipt {
    fn from(value: &ReadReceiptEvent) -> Self {
        ws::PubSubReadReceipt {
            room_id: value.room_id.to_string(),
            reader_id: value.reader_id.to_string(),
            message_id: value.message_id.to_string(),
            read_at: value.read_at.to_rfc3339(),
            source_node: value.source_node.clone(),
        }
    }
}

impl TryFrom<ws::PubSubReadReceipt> for ReadReceiptEvent {
    type Error = String;

    fn try_from(value: ws::PubSubReadReceipt) -> Result<Self, Self::Error> {
        Ok(ReadReceiptEvent {
            room_id: parse_uuid(&value.room_id, "room_id")?,
            reader_id: parse_uuid(&value.reader_id, "reader_id")?,
            message_id: parse_uuid(&value.message_id, "message_id")?,
            read_at: parse_datetime(&value.read_at, "read_at")?,
            source_node: value.source_node,
        })
    }
}

impl From<&MessageUpdatePayload> for ws::PubSubMessageUpdate {
    fn from(value: &MessageUpdatePayload) -> Self {
        ws::PubSubMessageUpdate {
            room_id: value.room_id.to_string(),
            message_id: value.message_id.to_string(),
            is_deleted: value.is_deleted,
            deleted_at: value
                .deleted_at
                .map(|dt| dt.to_rfc3339())
                .unwrap_or_default(),
        }
    }
}

impl TryFrom<ws::PubSubMessageUpdate> for MessageUpdatePayload {
    type Error = String;

    fn try_from(value: ws::PubSubMessageUpdate) -> Result<Self, Self::Error> {
        Ok(MessageUpdatePayload {
            room_id: parse_uuid(&value.room_id, "room_id")?,
            message_id: parse_uuid(&value.message_id, "message_id")?,
            is_deleted: value.is_deleted,
            deleted_at: option_from_string(value.deleted_at)
                .map(|val| parse_datetime(&val, "deleted_at"))
                .transpose()?,
        })
    }
}

impl From<&PinUpdatePayload> for ws::PubSubPinUpdate {
    fn from(value: &PinUpdatePayload) -> Self {
        ws::PubSubPinUpdate {
            room_id: value.room_id.to_string(),
            message_id: value
                .message_id
                .map(|id| id.to_string())
                .unwrap_or_default(),
            is_pinned: value.is_pinned,
            pinned_at: value
                .pinned_at
                .map(|ts| ts.to_rfc3339())
                .unwrap_or_default(),
            pinned_by: value.pinned_by.map(|id| id.to_string()).unwrap_or_default(),
        }
    }
}

impl TryFrom<ws::PubSubPinUpdate> for PinUpdatePayload {
    type Error = String;

    fn try_from(value: ws::PubSubPinUpdate) -> Result<Self, Self::Error> {
        Ok(PinUpdatePayload {
            room_id: parse_uuid(&value.room_id, "room_id")?,
            message_id: option_from_string(value.message_id)
                .map(|s| parse_uuid(&s, "message_id"))
                .transpose()?,
            pinned_by: option_from_string(value.pinned_by)
                .map(|s| parse_uuid(&s, "pinned_by"))
                .transpose()?,
            pinned_at: option_from_string(value.pinned_at)
                .map(|s| parse_datetime(&s, "pinned_at"))
                .transpose()?,
            is_pinned: value.is_pinned,
        })
    }
}

impl From<&QuotedMessagePayload> for ws::QuotedMessage {
    fn from(value: &QuotedMessagePayload) -> Self {
        ws::QuotedMessage {
            id: value.id.to_string(),
            room_id: value.room_id.to_string(),
            sender_id: value.sender_id.to_string(),
            sender_username: value.sender_username.clone().unwrap_or_default(),
            sender_nickname: value.sender_nickname.clone().unwrap_or_default(),
            sender_avatar_url: value.sender_avatar_url.clone().unwrap_or_default(),
            content: value.content.clone().unwrap_or_default(),
            message_type: value.message_type.to_string(),
            created_at: value
                .created_at
                .map(|dt| dt.to_rfc3339())
                .unwrap_or_default(),
            is_deleted: value.is_deleted,
        }
    }
}

impl TryFrom<ws::QuotedMessage> for QuotedMessagePayload {
    type Error = String;

    fn try_from(value: ws::QuotedMessage) -> Result<Self, Self::Error> {
        Ok(QuotedMessagePayload {
            id: parse_uuid(&value.id, "quoted.id")?,
            room_id: parse_uuid(&value.room_id, "quoted.room_id")?,
            sender_id: parse_uuid(&value.sender_id, "quoted.sender_id")?,
            sender_username: option_from_string(value.sender_username),
            sender_nickname: option_from_string(value.sender_nickname),
            sender_avatar_url: option_from_string(value.sender_avatar_url),
            content: option_from_string(value.content),
            message_type: parse_message_type(&value.message_type)?,
            created_at: option_from_string(value.created_at)
                .map(|s| parse_datetime(&s, "quoted.created_at"))
                .transpose()?,
            is_deleted: value.is_deleted,
        })
    }
}

impl From<&ForwardMessagePayload> for ws::ForwardMessage {
    fn from(value: &ForwardMessagePayload) -> Self {
        ws::ForwardMessage {
            message_id: value.message_id.to_string(),
            room_id: value.room_id.to_string(),
            sender_id: value.sender_id.to_string(),
            sender_username: value.sender_username.clone().unwrap_or_default(),
            sender_nickname: value.sender_nickname.clone().unwrap_or_default(),
        }
    }
}

impl TryFrom<ws::ForwardMessage> for ForwardMessagePayload {
    type Error = String;

    fn try_from(value: ws::ForwardMessage) -> Result<Self, Self::Error> {
        Ok(ForwardMessagePayload {
            message_id: parse_uuid(&value.message_id, "forward.message_id")?,
            room_id: parse_uuid(&value.room_id, "forward.room_id")?,
            sender_id: parse_uuid(&value.sender_id, "forward.sender_id")?,
            sender_username: option_from_string(value.sender_username),
            sender_nickname: option_from_string(value.sender_nickname),
        })
    }
}

fn option_from_string(value: String) -> Option<String> {
    if value.trim().is_empty() {
        None
    } else {
        Some(value)
    }
}

fn parse_uuid(value: &str, field: &str) -> Result<Uuid, String> {
    Uuid::parse_str(value).map_err(|e| format!("invalid uuid for {}: {}", field, e))
}

fn parse_datetime(value: &str, field: &str) -> Result<DateTime<Utc>, String> {
    chrono::DateTime::parse_from_rfc3339(value)
        .map(|dt| dt.with_timezone(&Utc))
        .map_err(|e| format!("invalid datetime for {}: {}", field, e))
}

fn parse_message_type(value: &str) -> Result<MessageType, String> {
    match value {
        "text" => Ok(MessageType::Text),
        "image" => Ok(MessageType::Image),
        "file" => Ok(MessageType::File),
        "system" => Ok(MessageType::System),
        other => Err(format!("unknown message_type: {}", other)),
    }
}

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
