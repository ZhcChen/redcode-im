use chrono::{DateTime, Utc};
use prost::Message;
use serde_json::{json, Value};
use uuid::Uuid;

use crate::{
    proto::ws,
    redis::models::{
        CrossNodeMessage, ForwardMessagePayload, MessagePartEnvelope, MessageUpdatePayload,
        PinUpdatePayload, QuotedMessagePayload, ReadReceiptEvent,
    },
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectionFormat {
    Json,
    Protobuf,
}

impl ConnectionFormat {
    pub fn from_query(value: Option<&str>) -> Self {
        match value.map(|v| v.trim().to_ascii_lowercase()).as_deref() {
            Some("proto") | Some("protobuf") | Some("pb") | Some("binary") => {
                ConnectionFormat::Protobuf
            }
            _ => ConnectionFormat::Json,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            ConnectionFormat::Json => "json",
            ConnectionFormat::Protobuf => "protobuf",
        }
    }
}

#[derive(Debug, Clone)]
pub enum OutboundFrame {
    Text(String),
    Binary(Vec<u8>),
}

#[derive(Debug, Clone)]
pub struct RoomCreatedPayload {
    pub room_id: Uuid,
    pub room_name: String,
    pub room_type: String,
    pub initiator_id: Uuid,
    pub owner_id: Uuid,
    pub description: Option<String>,
    pub avatar_url: Option<String>,
    pub created_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone)]
pub enum ServerPush {
    Authed { user_id: String, conn_id: String },
    Joined { room_id: Uuid },
    Left { room_id: Uuid },
    Message { data: CrossNodeMessage },
    MessageRead { data: ReadReceiptEvent },
    MessageUpdate { data: MessageUpdatePayload },
    PinUpdate { data: PinUpdatePayload },
    Error { message: String },
    Pong,
    FriendRequestUpdate { pending_count: i32 },
    RoomCreated { data: RoomCreatedPayload },
    UserBanned { user_id: String, reason: String },
}

impl ServerPush {
    pub fn event_name(&self) -> &'static str {
        match self {
            ServerPush::Authed { .. } => "authed",
            ServerPush::Joined { .. } => "joined",
            ServerPush::Left { .. } => "left",
            ServerPush::Message { .. } => "message",
            ServerPush::MessageRead { .. } => "message_read",
            ServerPush::MessageUpdate { .. } => "message_update",
            ServerPush::PinUpdate { .. } => "pin_update",
            ServerPush::Error { .. } => "error",
            ServerPush::Pong => "pong",
            ServerPush::FriendRequestUpdate { .. } => "friend_request_update",
            ServerPush::RoomCreated { .. } => "room_created",
            ServerPush::UserBanned { .. } => "user_banned",
        }
    }

    pub fn to_json_value(&self) -> Value {
        match self {
            ServerPush::Authed { user_id, conn_id } => {
                json!({ "type": "authed", "user_id": user_id, "conn_id": conn_id })
            }
            ServerPush::Joined { room_id } => {
                json!({ "type": "joined", "room_id": room_id })
            }
            ServerPush::Left { room_id } => json!({ "type": "left", "room_id": room_id }),
            ServerPush::Message { data } => {
                let quoted = data.quoted_message.as_ref().map(quoted_to_json);
                let forward = data.forward_message.as_ref().map(forward_to_json);
                let parts: Vec<Value> = data.parts.iter().map(part_to_json).collect();
                json!({
                    "type": "message",
                    "id": data.id,
                    "message_id": data.id,
                    "room_id": data.room_id,
                    "sender_id": data.sender_id,
                    "sender_username": data.sender_username,
                    "sender_nickname": data.sender_nickname,
                    "sender_avatar_url": data.sender_avatar_url,
                    "content": data.content,
                    "message_type": data.message_type.to_string(),
                    "quoted_message": quoted,
                    "forward_message": forward,
                    "timestamp": data.timestamp.to_rfc3339(),
                    "parts": parts,
                })
            }
            ServerPush::MessageRead { data } => json!({
                "type": "message_read",
                "room_id": data.room_id,
                "message_id": data.message_id,
                "reader_id": data.reader_id,
                "read_at": data.read_at.to_rfc3339(),
            }),
            ServerPush::MessageUpdate { data } => json!({
                "type": "message_update",
                "room_id": data.room_id,
                "message_id": data.message_id,
                "is_deleted": data.is_deleted,
                "deleted_at": data.deleted_at.map(|ts| ts.to_rfc3339()),
            }),
            ServerPush::PinUpdate { data } => json!({
                "type": "pin_update",
                "room_id": data.room_id,
                "message_id": data.message_id,
                "is_pinned": data.is_pinned,
                "pinned_at": data.pinned_at.map(|ts| ts.to_rfc3339()),
                "pinned_by": data.pinned_by,
            }),
            ServerPush::Error { message } => json!({ "type": "error", "message": message }),
            ServerPush::Pong => json!({ "type": "pong" }),
            ServerPush::FriendRequestUpdate { pending_count } => {
                json!({ "type": "friend_request_update", "pending_count": pending_count })
            }
            ServerPush::RoomCreated { data } => json!({
                "type": "room_created",
                "room_id": data.room_id,
                "room_name": data.room_name,
                "room_type": data.room_type,
                "initiator_id": data.initiator_id,
                "owner_id": data.owner_id,
                "description": data.description,
                "avatar_url": data.avatar_url,
                "created_at": data.created_at.map(|ts| ts.to_rfc3339()),
            }),
            ServerPush::UserBanned { user_id, reason } => json!({
                "type": "user_banned",
                "user_id": user_id,
                "reason": reason,
            }),
        }
    }

    pub fn to_json_string(&self) -> String {
        self.to_json_value().to_string()
    }

    pub fn to_protobuf_event(&self) -> ws::ServerEvent {
        use ws::server_event::Payload;

        let payload = match self {
            ServerPush::Authed { user_id, conn_id } => Payload::Authed(ws::ServerAuthed {
                user_id: user_id.clone(),
                conn_id: conn_id.clone(),
            }),
            ServerPush::Joined { room_id } => Payload::Joined(ws::ServerJoined {
                room_id: room_id.to_string(),
            }),
            ServerPush::Left { room_id } => Payload::Left(ws::ServerLeft {
                room_id: room_id.to_string(),
            }),
            ServerPush::Message { data } => Payload::Message(ws::ServerMessage {
                id: data.id.to_string(),
                message_id: data.id.to_string(),
                room_id: data.room_id.to_string(),
                sender_id: data.sender_id.to_string(),
                sender_username: data.sender_username.clone().unwrap_or_default(),
                sender_nickname: data.sender_nickname.clone().unwrap_or_default(),
                sender_avatar_url: data.sender_avatar_url.clone().unwrap_or_default(),
                content: data.content.clone(),
                message_type: data.message_type.to_string(),
                timestamp: data.timestamp.to_rfc3339(),
                quoted_message: data.quoted_message.as_ref().map(quoted_to_proto),
                forward_message: data.forward_message.as_ref().map(forward_to_proto),
                parts: data.parts.iter().map(ws::MessagePart::from).collect(),
            }),
            ServerPush::MessageRead { data } => Payload::MessageRead(ws::ServerMessageRead {
                room_id: data.room_id.to_string(),
                message_id: data.message_id.to_string(),
                reader_id: data.reader_id.to_string(),
                read_at: data.read_at.to_rfc3339(),
            }),
            ServerPush::MessageUpdate { data } => Payload::MessageUpdate(ws::ServerMessageUpdate {
                room_id: data.room_id.to_string(),
                message_id: data.message_id.to_string(),
                is_deleted: data.is_deleted,
                deleted_at: data
                    .deleted_at
                    .map(|ts| ts.to_rfc3339())
                    .unwrap_or_default(),
            }),
            ServerPush::PinUpdate { data } => Payload::PinUpdate(ws::ServerPinUpdate {
                room_id: data.room_id.to_string(),
                message_id: data.message_id.map(|id| id.to_string()).unwrap_or_default(),
                is_pinned: data.is_pinned,
                pinned_at: data.pinned_at.map(|ts| ts.to_rfc3339()).unwrap_or_default(),
                pinned_by: data.pinned_by.map(|id| id.to_string()).unwrap_or_default(),
            }),
            ServerPush::Error { message } => Payload::Error(ws::ServerError {
                message: message.clone(),
            }),
            ServerPush::Pong => Payload::Pong(ws::ServerPong {}),
            ServerPush::FriendRequestUpdate { pending_count } => {
                Payload::FriendRequestUpdate(ws::ServerFriendRequestUpdate {
                    pending_count: *pending_count,
                })
            }
            ServerPush::RoomCreated { data } => Payload::RoomCreated(ws::ServerRoomCreated {
                room_id: data.room_id.to_string(),
                room_name: data.room_name.clone(),
                room_type: data.room_type.clone(),
                initiator_id: data.initiator_id.to_string(),
                owner_id: data.owner_id.to_string(),
                description: data.description.clone().unwrap_or_default(),
                avatar_url: data.avatar_url.clone().unwrap_or_default(),
                created_at: data
                    .created_at
                    .map(|ts| ts.to_rfc3339())
                    .unwrap_or_default(),
            }),
            ServerPush::UserBanned { user_id, reason } => Payload::UserBanned(ws::ServerBanned {
                user_id: user_id.clone(),
                reason: reason.clone(),
            }),
        };

        ws::ServerEvent {
            payload: Some(payload),
        }
    }

    pub fn to_protobuf_bytes(&self) -> Vec<u8> {
        self.to_protobuf_event().encode_to_vec()
    }

    pub fn encode(&self, format: ConnectionFormat) -> OutboundFrame {
        match format {
            ConnectionFormat::Json => OutboundFrame::Text(self.to_json_string()),
            ConnectionFormat::Protobuf => OutboundFrame::Binary(self.to_protobuf_bytes()),
        }
    }
}

pub fn quoted_to_json(payload: &QuotedMessagePayload) -> Value {
    json!({
        "id": payload.id,
        "room_id": payload.room_id,
        "sender_id": payload.sender_id,
        "sender_username": payload.sender_username,
        "sender_nickname": payload.sender_nickname,
        "sender_avatar_url": payload.sender_avatar_url,
        "content": payload.content,
        "message_type": payload.message_type.to_string(),
        "created_at": payload.created_at.map(|ts| ts.to_rfc3339()),
        "is_deleted": payload.is_deleted,
        "parts": payload.parts.iter().map(part_to_json).collect::<Vec<_>>(),
    })
}

pub fn forward_to_json(payload: &ForwardMessagePayload) -> Value {
    json!({
        "message_id": payload.message_id,
        "room_id": payload.room_id,
        "sender_id": payload.sender_id,
        "sender_username": payload.sender_username,
        "sender_nickname": payload.sender_nickname,
    })
}

fn quoted_to_proto(payload: &QuotedMessagePayload) -> ws::QuotedMessage {
    ws::QuotedMessage {
        id: payload.id.to_string(),
        room_id: payload.room_id.to_string(),
        sender_id: payload.sender_id.to_string(),
        sender_username: payload.sender_username.clone().unwrap_or_default(),
        sender_nickname: payload.sender_nickname.clone().unwrap_or_default(),
        sender_avatar_url: payload.sender_avatar_url.clone().unwrap_or_default(),
        content: payload.content.clone().unwrap_or_default(),
        message_type: payload.message_type.to_string(),
        created_at: payload
            .created_at
            .map(|ts| ts.to_rfc3339())
            .unwrap_or_default(),
        is_deleted: payload.is_deleted,
        parts: payload.parts.iter().map(ws::MessagePart::from).collect(),
    }
}

fn forward_to_proto(payload: &ForwardMessagePayload) -> ws::ForwardMessage {
    ws::ForwardMessage {
        message_id: payload.message_id.to_string(),
        room_id: payload.room_id.to_string(),
        sender_id: payload.sender_id.to_string(),
        sender_username: payload.sender_username.clone().unwrap_or_default(),
        sender_nickname: payload.sender_nickname.clone().unwrap_or_default(),
    }
}

fn part_to_json(part: &MessagePartEnvelope) -> Value {
    let attachment = part.attachment.as_ref().map(|att| {
        json!({
            "key": att.key.clone(),
            "name": att.name.clone(),
            "mime": att.mime.clone(),
            "size": att.size,
            "width": att.width,
            "height": att.height,
            "duration_ms": att.duration_ms,
            "thumbnail_key": att.thumbnail_key.clone(),
        })
    });

    json!({
        "position": part.position,
        "part_type": part.part_type.to_string(),
        "text": part.text,
        "attachment": attachment,
    })
}
