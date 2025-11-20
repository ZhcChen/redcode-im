//! WebSocket 类型定义和 Protocol Buffers 封装

use prost::Message;
use serde::{Deserialize, Serialize};
use std::fmt;

// 包含编译生成的 Proto 代码
#[allow(dead_code)]
pub mod ws {
    include!(concat!(env!("OUT_DIR"), "/ws.rs"));
}

/// 连接状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ConnectionStatus {
    Disconnected,
    Connecting,
    Authenticated,
}

impl fmt::Display for ConnectionStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Disconnected => write!(f, "disconnected"),
            Self::Connecting => write!(f, "connecting"),
            Self::Authenticated => write!(f, "authenticated"),
        }
    }
}

/// WebSocket 连接参数
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebSocketParams {
    pub user_id: String,
    pub token: String,
}

/// WebSocket 错误类型
#[derive(Debug, thiserror::Error)]
pub enum WebSocketError {
    #[error("WebSocket 连接错误: {0}")]
    ConnectionError(String),

    #[error("编码错误: {0}")]
    EncodeError(#[from] prost::EncodeError),

    #[error("解码错误: {0}")]
    DecodeError(#[from] prost::DecodeError),

    #[error("发送错误: {0}")]
    SendError(String),

    #[error("tokio-tungstenite 错误: {0}")]
    TungsteniteError(#[from] tokio_tungstenite::tungstenite::Error),
}

pub type Result<T> = std::result::Result<T, WebSocketError>;

/// 客户端事件编码器
pub struct ClientEventEncoder;

impl ClientEventEncoder {
    /// 编码认证消息
    pub fn encode_auth(token: String) -> Result<Vec<u8>> {
        let auth = ws::ClientAuth { token };
        let event = ws::ClientEvent {
            payload: Some(ws::client_event::Payload::Auth(auth)),
        };
        let mut buf = Vec::new();
        event.encode(&mut buf)?;
        Ok(buf)
    }

    /// 编码加入房间消息
    pub fn encode_join(room_id: String) -> Result<Vec<u8>> {
        let join = ws::ClientJoin { room_id };
        let event = ws::ClientEvent {
            payload: Some(ws::client_event::Payload::Join(join)),
        };
        let mut buf = Vec::new();
        event.encode(&mut buf)?;
        Ok(buf)
    }

    /// 编码离开房间消息
    pub fn encode_leave(room_id: String) -> Result<Vec<u8>> {
        let leave = ws::ClientLeave { room_id };
        let event = ws::ClientEvent {
            payload: Some(ws::client_event::Payload::Leave(leave)),
        };
        let mut buf = Vec::new();
        event.encode(&mut buf)?;
        Ok(buf)
    }

    /// 编码心跳消息
    pub fn encode_ping() -> Result<Vec<u8>> {
        let ping = ws::ClientPing {};
        let event = ws::ClientEvent {
            payload: Some(ws::client_event::Payload::Ping(ping)),
        };
        let mut buf = Vec::new();
        event.encode(&mut buf)?;
        Ok(buf)
    }
}

/// 服务器事件解码器
pub struct ServerEventDecoder;

impl ServerEventDecoder {
    /// 解码服务器事件
    pub fn decode(data: &[u8]) -> Result<ws::ServerEvent> {
        let event = ws::ServerEvent::decode(data)?;
        Ok(event)
    }
}

/// Tauri 事件负载（序列化为 JSON 发送给前端）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload")]
pub enum TauriEventPayload {
    /// 认证成功
    Authed { user_id: String, conn_id: String },
    /// 加入房间成功
    Joined { room_id: String },
    /// 离开房间
    Left { room_id: String },
    /// 收到消息
    Message(serde_json::Value),
    /// 消息已读
    MessageRead(serde_json::Value),
    /// 消息更新
    MessageUpdate(serde_json::Value),
    /// 置顶更新
    PinUpdate(serde_json::Value),
    /// 好友请求更新
    FriendRequestUpdate { pending_count: i32 },
    /// 房间创建
    RoomCreated(serde_json::Value),
    /// 用户被封禁
    UserBanned { user_id: String, reason: String },
    /// 错误
    Error { message: String },
    /// Pong
    Pong,
}

impl TauriEventPayload {
    /// 从 Proto ServerEvent 转换
    pub fn from_server_event(event: ws::ServerEvent) -> Option<Self> {
        match event.payload? {
            ws::server_event::Payload::Authed(authed) => Some(Self::Authed {
                user_id: authed.user_id,
                conn_id: authed.conn_id,
            }),
            ws::server_event::Payload::Joined(joined) => Some(Self::Joined {
                room_id: joined.room_id,
            }),
            ws::server_event::Payload::Left(left) => Some(Self::Left {
                room_id: left.room_id,
            }),
            ws::server_event::Payload::Message(msg) => {
                // 转换为 JSON - 只序列化基本类型
                let json = serde_json::json!({
                    "id": msg.id,
                    "message_id": msg.message_id,
                    "room_id": msg.room_id,
                    "sender_id": msg.sender_id,
                    "sender_username": msg.sender_username,
                    "sender_nickname": msg.sender_nickname,
                    "sender_avatar_url": msg.sender_avatar_url,
                    "content": msg.content,
                    "message_type": msg.message_type,
                    "timestamp": msg.timestamp,
                    // quoted_message 和 forward_message 是 Proto 类型,暂不序列化
                    // 前端会通过 HTTP API 获取完整消息详情
                });
                Some(Self::Message(json))
            }
            ws::server_event::Payload::MessageRead(read) => {
                let json = serde_json::json!({
                    "room_id": read.room_id,
                    "message_id": read.message_id,
                    "reader_id": read.reader_id,
                    "read_at": read.read_at,
                });
                Some(Self::MessageRead(json))
            }
            ws::server_event::Payload::MessageUpdate(update) => {
                let json = serde_json::json!({
                    "room_id": update.room_id,
                    "message_id": update.message_id,
                    "is_deleted": update.is_deleted,
                    "deleted_at": update.deleted_at,
                });
                Some(Self::MessageUpdate(json))
            }
            ws::server_event::Payload::PinUpdate(pin) => {
                let json = serde_json::json!({
                    "room_id": pin.room_id,
                    "message_id": pin.message_id,
                    "is_pinned": pin.is_pinned,
                    "pinned_at": pin.pinned_at,
                    "pinned_by": pin.pinned_by,
                });
                Some(Self::PinUpdate(json))
            }
            ws::server_event::Payload::FriendRequestUpdate(update) => {
                Some(Self::FriendRequestUpdate {
                    pending_count: update.pending_count,
                })
            }
            ws::server_event::Payload::RoomCreated(room) => {
                let json = serde_json::json!({
                    "room_id": room.room_id,
                    "room_name": room.room_name,
                    "room_type": room.room_type,
                    "initiator_id": room.initiator_id,
                    "owner_id": room.owner_id,
                    "description": room.description,
                    "avatar_url": room.avatar_url,
                    "created_at": room.created_at,
                });
                Some(Self::RoomCreated(json))
            }
            ws::server_event::Payload::UserBanned(banned) => Some(Self::UserBanned {
                user_id: banned.user_id,
                reason: banned.reason,
            }),
            ws::server_event::Payload::Error(err) => Some(Self::Error {
                message: err.message,
            }),
            ws::server_event::Payload::Pong(_) => Some(Self::Pong),
        }
    }
}
