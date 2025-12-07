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

/// 带用户标识的事件包装（用于多账号场景）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserEventWrapper {
    /// 事件所属的用户ID
    pub user_id: String,
    /// 事件负载
    #[serde(flatten)]
    pub event: TauriEventPayload,
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
    /// 房间信息更新
    RoomUpdated(serde_json::Value),
    /// 用户被封禁
    UserBanned { user_id: String, reason: String },
    /// 群被解散
    GroupDissolved { room_id: String },
    /// 群主变更
    GroupOwnerTransferred {
        room_id: String,
        old_owner_id: String,
        new_owner_id: String,
    },
    /// 群设置更新
    GroupSettingsUpdated(serde_json::Value),
    /// 群成员变更
    GroupMemberChanged(serde_json::Value),
    /// 好友资料更新
    FriendProfileUpdated(serde_json::Value),
    /// 好友关系删除
    FriendshipDeleted { user_id: String },
    /// 房间历史清除
    RoomHistoryCleared(serde_json::Value),
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
                // 转换 parts
                let parts: Vec<serde_json::Value> = msg
                    .parts
                    .iter()
                    .map(|part| {
                        let attachment = part.attachment.as_ref().map(|att| {
                            serde_json::json!({
                                "key": att.key,
                                "name": att.name,
                                "mime": att.mime,
                                "size": att.size,
                                "width": att.width,
                                "height": att.height,
                                "duration_ms": att.duration_ms,
                                "thumbnail_key": att.thumbnail_key,
                            })
                        });
                        serde_json::json!({
                            "position": part.position,
                            "part_type": part.part_type,
                            "text": part.text,
                            "attachment": attachment,
                        })
                    })
                    .collect();

                // 转换 quoted_message
                let quoted_message = msg.quoted_message.as_ref().map(|quoted| {
                    let quoted_parts: Vec<serde_json::Value> = quoted
                        .parts
                        .iter()
                        .map(|part| {
                            let attachment = part.attachment.as_ref().map(|att| {
                                serde_json::json!({
                                    "key": att.key,
                                    "name": att.name,
                                    "mime": att.mime,
                                    "size": att.size,
                                    "width": att.width,
                                    "height": att.height,
                                    "duration_ms": att.duration_ms,
                                    "thumbnail_key": att.thumbnail_key,
                                })
                            });
                            serde_json::json!({
                                "position": part.position,
                                "part_type": part.part_type,
                                "text": part.text,
                                "attachment": attachment,
                            })
                        })
                        .collect();
                    serde_json::json!({
                        "id": quoted.id,
                        "room_id": quoted.room_id,
                        "sender_id": quoted.sender_id,
                        "sender_username": quoted.sender_username,
                        "sender_nickname": quoted.sender_nickname,
                        "sender_avatar_url": quoted.sender_avatar_url,
                        "content": quoted.content,
                        "message_type": quoted.message_type,
                        "created_at": quoted.created_at,
                        "is_deleted": quoted.is_deleted,
                        "parts": quoted_parts,
                    })
                });

                // 转换 forward_message
                let forward_message = msg.forward_message.as_ref().map(|forward| {
                    serde_json::json!({
                        "message_id": forward.message_id,
                        "room_id": forward.room_id,
                        "sender_id": forward.sender_id,
                        "sender_username": forward.sender_username,
                        "sender_nickname": forward.sender_nickname,
                    })
                });

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
                    "quoted_message": quoted_message,
                    "forward_message": forward_message,
                    "parts": parts,
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
            ws::server_event::Payload::RoomUpdated(room) => {
                let json = serde_json::json!({
                    "room_id": room.room_id,
                    "room_name": room.room_name,
                    "room_type": room.room_type,
                    "avatar_url": room.avatar_url,
                    "avatar_object_key": room.avatar_object_key,
                    "description": room.description,
                });
                Some(Self::RoomUpdated(json))
            }
            ws::server_event::Payload::UserBanned(banned) => Some(Self::UserBanned {
                user_id: banned.user_id,
                reason: banned.reason,
            }),
            ws::server_event::Payload::GroupDissolved(dissolved) => Some(Self::GroupDissolved {
                room_id: dissolved.room_id,
            }),
            ws::server_event::Payload::GroupOwnerTransferred(transferred) => {
                Some(Self::GroupOwnerTransferred {
                    room_id: transferred.room_id,
                    old_owner_id: transferred.old_owner_id,
                    new_owner_id: transferred.new_owner_id,
                })
            }
            ws::server_event::Payload::GroupSettingsUpdated(settings) => {
                let json = serde_json::json!({
                    "room_id": settings.room_id,
                    "global_mute_enabled": settings.global_mute_enabled,
                    "global_mute_reason": settings.global_mute_reason,
                    "global_mute_until": settings.global_mute_until,
                    "global_mute_set_by": settings.global_mute_set_by,
                });
                Some(Self::GroupSettingsUpdated(json))
            }
            ws::server_event::Payload::GroupMemberChanged(member) => {
                let json = serde_json::json!({
                    "room_id": member.room_id,
                    "member_id": member.member_id,
                    "change_type": member.change_type,
                    "new_role": member.new_role,
                    "operator_id": member.operator_id,
                });
                Some(Self::GroupMemberChanged(json))
            }
            ws::server_event::Payload::FriendProfileUpdated(profile) => {
                let json = serde_json::json!({
                    "user_id": profile.user_id,
                    "nickname": profile.nickname,
                    "avatar_url": profile.avatar_url,
                    "avatar_object_key": profile.avatar_object_key,
                });
                Some(Self::FriendProfileUpdated(json))
            }
            ws::server_event::Payload::FriendshipDeleted(deleted) => {
                Some(Self::FriendshipDeleted {
                    user_id: deleted.user_id,
                })
            }
            ws::server_event::Payload::RoomHistoryCleared(cleared) => {
                let json = serde_json::json!({
                    "room_id": cleared.room_id,
                    "cleared_at": cleared.cleared_at,
                    "cleared_by": cleared.cleared_by,
                });
                Some(Self::RoomHistoryCleared(json))
            }
            ws::server_event::Payload::Error(err) => Some(Self::Error {
                message: err.message,
            }),
            ws::server_event::Payload::Pong(_) => Some(Self::Pong),
        }
    }
}
