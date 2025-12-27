use crate::database::models::{MemberRole, MessagePart, MessagePartType, MessageType, UserStatus};
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
    pub client_ip: std::net::IpAddr,
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
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub parts: Vec<MessagePartEnvelope>,
}

/// 节点心跳信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeHeartbeat {
    pub node_id: String,
    pub address: String,
    pub status: NodeStatus,
    pub connected_users: usize,
    pub active_rooms: usize,
    pub cpu_usage: f64,
    pub memory_usage: f64,
    pub disk_usage: f64,
    pub cpu_count: u32,
    pub total_memory: u64,
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
#[allow(dead_code)]
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
#[allow(dead_code)]
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
#[allow(dead_code)]
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
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub parts: Vec<MessagePartEnvelope>,
}

/// 消息分片载荷
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessagePartEnvelope {
    pub position: i16,
    pub part_type: MessagePartType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub attachment: Option<MessageAttachmentEnvelope>,
}

/// 消息附件载荷
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageAttachmentEnvelope {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub key: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mime: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub size: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub width: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub height: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_ms: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub thumbnail_key: Option<String>,
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

/// 消息更新类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MessageUpdateType {
    Deleted,
    Edited,
}

impl std::fmt::Display for MessageUpdateType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            MessageUpdateType::Deleted => write!(f, "deleted"),
            MessageUpdateType::Edited => write!(f, "edited"),
        }
    }
}

impl std::str::FromStr for MessageUpdateType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "deleted" => Ok(MessageUpdateType::Deleted),
            "edited" => Ok(MessageUpdateType::Edited),
            _ => Err(format!("unknown update type: {}", s)),
        }
    }
}

/// 消息更新事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageUpdatePayload {
    pub room_id: Uuid,
    pub message_id: Uuid,
    /// 更新类型：deleted / edited
    #[serde(default = "default_update_type")]
    pub update_type: MessageUpdateType,
    /// 向后兼容：is_deleted 仍然保留
    pub is_deleted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub deleted_at: Option<DateTime<Utc>>,
    /// 编辑时间（仅 update_type=edited 时有值）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub edited_at: Option<DateTime<Utc>>,
    /// 编辑后的新内容（仅 update_type=edited 时有值）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
}

fn default_update_type() -> MessageUpdateType {
    MessageUpdateType::Deleted
}

/// 反应操作类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ReactionAction {
    Add,
    Remove,
}

impl std::fmt::Display for ReactionAction {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ReactionAction::Add => write!(f, "add"),
            ReactionAction::Remove => write!(f, "remove"),
        }
    }
}

impl std::str::FromStr for ReactionAction {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "add" => Ok(ReactionAction::Add),
            "remove" => Ok(ReactionAction::Remove),
            _ => Err(format!("unknown reaction action: {}", s)),
        }
    }
}

/// 消息反应更新事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReactionUpdatePayload {
    pub room_id: Uuid,
    pub message_id: Uuid,
    pub reaction_key: String,
    pub user_id: Uuid,
    pub action: ReactionAction,
}

/// 房间聊天记录被清空事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomHistoryClearedPayload {
    pub room_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cleared_by: Option<Uuid>,
    pub cleared_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomUpdatePayload {
    pub room_id: Uuid,
    pub room_name: String,
    pub room_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_object_key: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
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

/// 群设置更新事件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupSettingsUpdatePayload {
    pub room_id: Uuid,
    pub global_mute_enabled: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub global_mute_reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub global_mute_until: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub global_mute_set_by: Option<Uuid>,
}

/// 群成员变更类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum GroupMemberChangeType {
    RoleChanged,
    Muted,
    Unmuted,
    Kicked,
    Joined,
    Left,
}

impl std::fmt::Display for GroupMemberChangeType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            GroupMemberChangeType::RoleChanged => write!(f, "role_changed"),
            GroupMemberChangeType::Muted => write!(f, "muted"),
            GroupMemberChangeType::Unmuted => write!(f, "unmuted"),
            GroupMemberChangeType::Kicked => write!(f, "kicked"),
            GroupMemberChangeType::Joined => write!(f, "joined"),
            GroupMemberChangeType::Left => write!(f, "left"),
        }
    }
}

impl std::str::FromStr for GroupMemberChangeType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "role_changed" => Ok(GroupMemberChangeType::RoleChanged),
            "muted" => Ok(GroupMemberChangeType::Muted),
            "unmuted" => Ok(GroupMemberChangeType::Unmuted),
            "kicked" => Ok(GroupMemberChangeType::Kicked),
            "joined" => Ok(GroupMemberChangeType::Joined),
            "left" => Ok(GroupMemberChangeType::Left),
            _ => Err(format!("unknown change type: {}", s)),
        }
    }
}

/// 群成员变更事件载荷
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupMemberChangedPayload {
    pub room_id: Uuid,
    pub member_id: Uuid,
    pub change_type: GroupMemberChangeType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub new_role: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub operator_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub until: Option<DateTime<Utc>>,
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
    RoomUpdate {
        #[serde(flatten)]
        data: RoomUpdatePayload,
    },
    GroupSettingsUpdate {
        #[serde(flatten)]
        data: GroupSettingsUpdatePayload,
    },
    GroupMemberChanged {
        #[serde(flatten)]
        data: GroupMemberChangedPayload,
    },
    RoomHistoryCleared {
        #[serde(flatten)]
        data: RoomHistoryClearedPayload,
    },
    ReactionUpdate {
        #[serde(flatten)]
        data: ReactionUpdatePayload,
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
            PubSubPayload::RoomUpdate { data } => {
                Payload::RoomUpdate(ws::PubSubRoomUpdate::from(data))
            }
            PubSubPayload::GroupSettingsUpdate { data } => {
                Payload::GroupSettingsUpdate(ws::PubSubGroupSettingsUpdate::from(data))
            }
            PubSubPayload::GroupMemberChanged { data } => {
                Payload::GroupMemberChanged(ws::PubSubGroupMemberChanged::from(data))
            }
            PubSubPayload::RoomHistoryCleared { data } => {
                Payload::RoomHistoryCleared(ws::PubSubRoomHistoryCleared::from(data))
            }
            PubSubPayload::ReactionUpdate { data } => {
                Payload::ReactionUpdate(ws::PubSubReactionUpdate::from(data))
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
            Payload::RoomUpdate(update) => {
                let data = RoomUpdatePayload::try_from(update)?;
                Ok(PubSubPayload::RoomUpdate { data })
            }
            Payload::GroupSettingsUpdate(update) => {
                let data = GroupSettingsUpdatePayload::try_from(update)?;
                Ok(PubSubPayload::GroupSettingsUpdate { data })
            }
            Payload::GroupMemberChanged(update) => {
                let data = GroupMemberChangedPayload::try_from(update)?;
                Ok(PubSubPayload::GroupMemberChanged { data })
            }
            Payload::RoomHistoryCleared(update) => {
                let data = RoomHistoryClearedPayload::try_from(update)?;
                Ok(PubSubPayload::RoomHistoryCleared { data })
            }
            Payload::ReactionUpdate(update) => {
                let data = ReactionUpdatePayload::try_from(update)?;
                Ok(PubSubPayload::ReactionUpdate { data })
            }
        }
    }
}

impl From<&RoomHistoryClearedPayload> for ws::PubSubRoomHistoryCleared {
    fn from(value: &RoomHistoryClearedPayload) -> Self {
        ws::PubSubRoomHistoryCleared {
            room_id: value.room_id.to_string(),
            cleared_by: value
                .cleared_by
                .map(|id| id.to_string())
                .unwrap_or_default(),
            cleared_at: value.cleared_at.to_rfc3339(),
        }
    }
}

impl TryFrom<ws::PubSubRoomHistoryCleared> for RoomHistoryClearedPayload {
    type Error = String;

    fn try_from(value: ws::PubSubRoomHistoryCleared) -> Result<Self, Self::Error> {
        let room_id = parse_uuid(&value.room_id, "room_id")?;
        let cleared_by = if value.cleared_by.is_empty() {
            None
        } else {
            Some(parse_uuid(&value.cleared_by, "cleared_by")?)
        };
        let cleared_at = parse_datetime(&value.cleared_at, "cleared_at")?;

        Ok(RoomHistoryClearedPayload {
            room_id,
            cleared_by,
            cleared_at,
        })
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
            parts: value.parts.iter().map(ws::MessagePart::from).collect(),
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
            parts: value
                .parts
                .into_iter()
                .map(MessagePartEnvelope::try_from)
                .collect::<Result<_, _>>()?,
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
            update_type: value.update_type.to_string(),
            edited_at: value
                .edited_at
                .map(|dt| dt.to_rfc3339())
                .unwrap_or_default(),
            content: value.content.clone().unwrap_or_default(),
        }
    }
}

impl TryFrom<ws::PubSubMessageUpdate> for MessageUpdatePayload {
    type Error = String;

    fn try_from(value: ws::PubSubMessageUpdate) -> Result<Self, Self::Error> {
        let update_type = if value.update_type.is_empty() {
            // 兼容旧版本：如果 update_type 为空，根据 is_deleted 推断
            if value.is_deleted {
                MessageUpdateType::Deleted
            } else {
                MessageUpdateType::Edited
            }
        } else {
            value.update_type.parse().unwrap_or(MessageUpdateType::Deleted)
        };

        Ok(MessageUpdatePayload {
            room_id: parse_uuid(&value.room_id, "room_id")?,
            message_id: parse_uuid(&value.message_id, "message_id")?,
            update_type,
            is_deleted: value.is_deleted,
            deleted_at: option_from_string(value.deleted_at)
                .map(|val| parse_datetime(&val, "deleted_at"))
                .transpose()?,
            edited_at: option_from_string(value.edited_at)
                .map(|val| parse_datetime(&val, "edited_at"))
                .transpose()?,
            content: option_from_string(value.content),
        })
    }
}

impl From<&RoomUpdatePayload> for ws::PubSubRoomUpdate {
    fn from(value: &RoomUpdatePayload) -> Self {
        ws::PubSubRoomUpdate {
            room_id: value.room_id.to_string(),
            room_name: value.room_name.clone(),
            room_type: value.room_type.clone(),
            avatar_url: value.avatar_url.clone().unwrap_or_default(),
            avatar_object_key: value.avatar_object_key.clone().unwrap_or_default(),
            description: value.description.clone().unwrap_or_default(),
        }
    }
}

impl TryFrom<ws::PubSubRoomUpdate> for RoomUpdatePayload {
    type Error = String;

    fn try_from(value: ws::PubSubRoomUpdate) -> Result<Self, Self::Error> {
        let room_id = Uuid::parse_str(&value.room_id).map_err(|e| e.to_string())?;

        Ok(RoomUpdatePayload {
            room_id,
            room_name: value.room_name,
            room_type: value.room_type,
            avatar_url: if value.avatar_url.is_empty() {
                None
            } else {
                Some(value.avatar_url)
            },
            avatar_object_key: if value.avatar_object_key.is_empty() {
                None
            } else {
                Some(value.avatar_object_key)
            },
            description: if value.description.is_empty() {
                None
            } else {
                Some(value.description)
            },
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
            parts: value.parts.iter().map(ws::MessagePart::from).collect(),
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
            parts: value
                .parts
                .into_iter()
                .map(MessagePartEnvelope::try_from)
                .collect::<Result<_, _>>()?,
        })
    }
}

impl From<&MessagePartEnvelope> for ws::MessagePart {
    fn from(value: &MessagePartEnvelope) -> Self {
        ws::MessagePart {
            position: i32::from(value.position),
            part_type: message_part_type_to_str(value.part_type).to_string(),
            text: value.text.clone().unwrap_or_default(),
            attachment: value.attachment.as_ref().map(ws::MessageAttachment::from),
        }
    }
}

impl TryFrom<ws::MessagePart> for MessagePartEnvelope {
    type Error = String;

    fn try_from(value: ws::MessagePart) -> Result<Self, Self::Error> {
        Ok(MessagePartEnvelope {
            position: value.position as i16,
            part_type: parse_message_part_type(&value.part_type)?,
            text: option_from_string(value.text),
            attachment: value
                .attachment
                .map(MessageAttachmentEnvelope::try_from)
                .transpose()?,
        })
    }
}

impl From<&MessageAttachmentEnvelope> for ws::MessageAttachment {
    fn from(value: &MessageAttachmentEnvelope) -> Self {
        ws::MessageAttachment {
            key: value.key.clone().unwrap_or_default(),
            name: value.name.clone().unwrap_or_default(),
            mime: value.mime.clone().unwrap_or_default(),
            size: value.size.unwrap_or(0),
            width: value.width.unwrap_or(0),
            height: value.height.unwrap_or(0),
            duration_ms: value.duration_ms.unwrap_or(0),
            thumbnail_key: value.thumbnail_key.clone().unwrap_or_default(),
        }
    }
}

impl TryFrom<ws::MessageAttachment> for MessageAttachmentEnvelope {
    type Error = String;

    fn try_from(value: ws::MessageAttachment) -> Result<Self, Self::Error> {
        Ok(MessageAttachmentEnvelope {
            key: option_from_string(value.key),
            name: option_from_string(value.name),
            mime: option_from_string(value.mime),
            size: option_from_zero_i64(value.size),
            width: option_from_zero_i32(value.width),
            height: option_from_zero_i32(value.height),
            duration_ms: option_from_zero_i32(value.duration_ms),
            thumbnail_key: option_from_string(value.thumbnail_key),
        })
    }
}

impl From<&MessagePart> for MessagePartEnvelope {
    fn from(part: &MessagePart) -> Self {
        let attachment = if matches!(part.part_type, MessagePartType::Text) {
            None
        } else {
            Some(MessageAttachmentEnvelope {
                key: part.attachment_key.clone(),
                name: part.attachment_name.clone(),
                mime: part.attachment_mime.clone(),
                size: part.attachment_size,
                width: part.width,
                height: part.height,
                duration_ms: part.duration_ms,
                thumbnail_key: part.thumbnail_key.clone(),
            })
        };

        MessagePartEnvelope {
            position: part.position,
            part_type: part.part_type,
            text: part.text_content.clone(),
            attachment,
        }
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

fn option_from_zero_i32(value: i32) -> Option<i32> {
    if value == 0 {
        None
    } else {
        Some(value)
    }
}

fn option_from_zero_i64(value: i64) -> Option<i64> {
    if value == 0 {
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
        "video" => Ok(MessageType::Video),
        "audio" => Ok(MessageType::Audio),
        "mixed" => Ok(MessageType::Mixed),
        other => Err(format!("unknown message_type: {}", other)),
    }
}

fn message_part_type_to_str(value: MessagePartType) -> &'static str {
    match value {
        MessagePartType::Text => "text",
        MessagePartType::Image => "image",
        MessagePartType::Video => "video",
        MessagePartType::Audio => "audio",
        MessagePartType::File => "file",
    }
}

fn parse_message_part_type(value: &str) -> Result<MessagePartType, String> {
    match value {
        "text" => Ok(MessagePartType::Text),
        "image" => Ok(MessagePartType::Image),
        "video" => Ok(MessagePartType::Video),
        "audio" => Ok(MessagePartType::Audio),
        "file" => Ok(MessagePartType::File),
        other => Err(format!("unknown part_type: {}", other)),
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
    #[allow(dead_code)]
    pub fn room_members(room_id: &Uuid) -> String {
        format!("room:members:{}", room_id)
    }

    /// 用户在线状态键
    #[allow(dead_code)]
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

    /// 用户缓存键
    #[allow(dead_code)]
    pub fn user_cache(user_id: &Uuid) -> String {
        format!("cache:user:{}", user_id)
    }

    /// 房间信息缓存键
    #[allow(dead_code)]
    pub fn room_cache(room_id: &Uuid) -> String {
        format!("cache:room:{}", room_id)
    }

    pub fn download_url_cache(key: &str, provider_id: &str, expires_in: u32) -> String {
        format!("cache:download_url:{}:{}:{}", key, provider_id, expires_in)
    }

    /// API 指标：命中次数 (Hash)
    pub fn api_metrics_hits() -> String {
        "api:metrics:hits".to_string()
    }

    /// API 指标：总耗时 (Hash)
    pub fn api_metrics_duration() -> String {
        "api:metrics:duration".to_string()
    }

    /// API 指标：慢日志 (ZSet)
    pub fn api_metrics_slow_log() -> String {
        "api:metrics:slow_log".to_string()
    }
}

impl From<&GroupSettingsUpdatePayload> for ws::PubSubGroupSettingsUpdate {
    fn from(value: &GroupSettingsUpdatePayload) -> Self {
        ws::PubSubGroupSettingsUpdate {
            room_id: value.room_id.to_string(),
            global_mute_enabled: value.global_mute_enabled,
            global_mute_reason: value.global_mute_reason.clone(),
            global_mute_until: value.global_mute_until.map(|ts| ts.to_rfc3339()),
            global_mute_set_by: value.global_mute_set_by.map(|id| id.to_string()),
        }
    }
}

impl TryFrom<ws::PubSubGroupSettingsUpdate> for GroupSettingsUpdatePayload {
    type Error = String;

    fn try_from(value: ws::PubSubGroupSettingsUpdate) -> Result<Self, Self::Error> {
        let room_id = Uuid::parse_str(&value.room_id).map_err(|e| e.to_string())?;

        let global_mute_until = value
            .global_mute_until
            .and_then(|s| DateTime::parse_from_rfc3339(&s).ok())
            .map(|dt| dt.with_timezone(&Utc));

        let global_mute_set_by = value
            .global_mute_set_by
            .and_then(|s| Uuid::parse_str(&s).ok());

        Ok(GroupSettingsUpdatePayload {
            room_id,
            global_mute_enabled: value.global_mute_enabled,
            global_mute_reason: value.global_mute_reason,
            global_mute_until,
            global_mute_set_by,
        })
    }
}

impl From<&GroupMemberChangedPayload> for ws::PubSubGroupMemberChanged {
    fn from(value: &GroupMemberChangedPayload) -> Self {
        ws::PubSubGroupMemberChanged {
            room_id: value.room_id.to_string(),
            member_id: value.member_id.to_string(),
            change_type: value.change_type.to_string(),
            new_role: value.new_role.clone(),
            operator_id: value.operator_id.map(|id| id.to_string()),
            reason: value.reason.clone(),
            until: value.until.map(|ts| ts.to_rfc3339()),
        }
    }
}

impl TryFrom<ws::PubSubGroupMemberChanged> for GroupMemberChangedPayload {
    type Error = String;

    fn try_from(value: ws::PubSubGroupMemberChanged) -> Result<Self, Self::Error> {
        let room_id = Uuid::parse_str(&value.room_id).map_err(|e| e.to_string())?;
        let member_id = Uuid::parse_str(&value.member_id).map_err(|e| e.to_string())?;
        let change_type: GroupMemberChangeType =
            value.change_type.parse().map_err(|e: String| e)?;

        let operator_id = value.operator_id.and_then(|s| Uuid::parse_str(&s).ok());

        let until = value
            .until
            .and_then(|s| DateTime::parse_from_rfc3339(&s).ok())
            .map(|dt| dt.with_timezone(&Utc));

        Ok(GroupMemberChangedPayload {
            room_id,
            member_id,
            change_type,
            new_role: value.new_role,
            operator_id,
            reason: value.reason,
            until,
        })
    }
}

impl From<&ReactionUpdatePayload> for ws::PubSubReactionUpdate {
    fn from(value: &ReactionUpdatePayload) -> Self {
        ws::PubSubReactionUpdate {
            room_id: value.room_id.to_string(),
            message_id: value.message_id.to_string(),
            reaction_key: value.reaction_key.clone(),
            user_id: value.user_id.to_string(),
            action: value.action.to_string(),
        }
    }
}

impl TryFrom<ws::PubSubReactionUpdate> for ReactionUpdatePayload {
    type Error = String;

    fn try_from(value: ws::PubSubReactionUpdate) -> Result<Self, Self::Error> {
        let room_id = parse_uuid(&value.room_id, "room_id")?;
        let message_id = parse_uuid(&value.message_id, "message_id")?;
        let user_id = parse_uuid(&value.user_id, "user_id")?;
        let action = value.action.parse().unwrap_or(ReactionAction::Add);

        Ok(ReactionUpdatePayload {
            room_id,
            message_id,
            reaction_key: value.reaction_key,
            user_id,
            action,
        })
    }
}
