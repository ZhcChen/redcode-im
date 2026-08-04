mod protocol;
pub use protocol::{RoomCreatedPayload, RoomUpdatedPayload, ServerPush};

use axum::extract::{
    ws::{Message, WebSocket, WebSocketUpgrade},
    State,
};
use axum::{http::StatusCode, response::IntoResponse};
use base64::Engine;
use futures_util::{SinkExt, StreamExt};
use prost::Message as _;
use redis::AsyncCommands;
use serde::Deserialize;
use serde_json::json;
use std::{
    collections::{HashMap, HashSet},
    env,
    sync::Arc,
    time::{Duration, Instant},
};
use tokio::sync::{mpsc, mpsc::error::TrySendError, oneshot, watch, RwLock};
use uuid::Uuid;

use crate::{auth, database::room_store::RoomStore, proto::ws, services::geolocation, AppState};
use protocol::{ConnectionFormat, OutboundFrame};
use tracing::{debug, error, info, trace, warn};

const USER_ONLINE_TTL_SECONDS: u64 = 90;
const DEFAULT_WS_OUTBOUND_QUEUE_SIZE: usize = 1024;
const MAX_WS_OUTBOUND_QUEUE_SIZE: usize = 65_536;

// WebSocket连接管理器
pub struct ConnectionManager {
    // 用户ID -> 连接集合映射
    user_connections: Arc<RwLock<HashMap<String, HashMap<String, ConnectionInfo>>>>,
    // 连接ID -> 订阅房间映射
    connection_rooms: Arc<RwLock<HashMap<String, HashSet<Uuid>>>>,
    // 房间ID -> 订阅用户集合
    room_subscribers: Arc<RwLock<HashMap<Uuid, HashSet<String>>>>,
    // 扫码登录订阅：qr_id -> conn_id -> 连接信息（允许未认证连接订阅）
    qr_subscribers: Arc<RwLock<HashMap<Uuid, HashMap<String, ConnectionInfo>>>>,
    // 输入态节流：key = "{conn_id}:{room_id}"
    typing_throttles: Arc<RwLock<HashMap<String, TypingThrottleInfo>>>,
}

#[derive(Debug)]
enum PubSubHubCmd {
    SyncRoom {
        room_id: Uuid,
        channel: String,
        ack: oneshot::Sender<Result<(), String>>,
    },
}

/// 节点级 Redis Pub/Sub 订阅器。
///
/// 旧实现为每个 WebSocket 连接各自建立 Redis PubSub 连接；高并发 join 会迅速耗尽
/// 容器可用临时端口和 Redis 连接。这里改为每个 API 节点只保留一个订阅连接，连接级
/// join/leave 只更新本地订阅映射，跨节点消息由 hub 统一分发到本节点订阅者。
pub struct PubSubHub {
    cmd_tx: mpsc::UnboundedSender<PubSubHubCmd>,
}

impl PubSubHub {
    pub fn spawn(
        pubsub_client: redis::Client,
        connection_manager: Arc<ConnectionManager>,
    ) -> Arc<Self> {
        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel();
        let hub = Arc::new(Self { cmd_tx });

        tokio::spawn(run_pubsub_hub(pubsub_client, connection_manager, cmd_rx));

        hub
    }

    pub async fn sync_room(&self, room_id: Uuid) -> Result<(), String> {
        let channel = crate::redis::models::CacheKeys::pubsub_channel(&room_id);
        let (ack, rx) = oneshot::channel();
        self.cmd_tx
            .send(PubSubHubCmd::SyncRoom {
                room_id,
                channel,
                ack,
            })
            .map_err(|_| "pubsub hub unavailable".to_string())?;

        tokio::time::timeout(Duration::from_secs(3), rx)
            .await
            .map_err(|_| "pubsub hub sync timed out".to_string())?
            .map_err(|_| "pubsub hub stopped".to_string())?
    }
}

#[derive(Debug, Clone, Copy)]
struct TypingThrottleInfo {
    last_sent_at: Instant,
    last_is_typing: bool,
}

// 连接信息
#[derive(Debug, Clone)]
pub struct ConnectionInfo {
    #[allow(dead_code)]
    pub user_id: String,
    #[allow(dead_code)]
    pub device_id: Option<String>,
    #[allow(dead_code)]
    pub connected_at: chrono::DateTime<chrono::Utc>,
    pub last_ping: chrono::DateTime<chrono::Utc>,
    pub format: ConnectionFormat,
    pub sender: mpsc::Sender<OutboundFrame>,
    shutdown_tx: watch::Sender<()>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        Self {
            user_connections: Arc::new(RwLock::new(HashMap::new())),
            connection_rooms: Arc::new(RwLock::new(HashMap::new())),
            room_subscribers: Arc::new(RwLock::new(HashMap::new())),
            qr_subscribers: Arc::new(RwLock::new(HashMap::new())),
            typing_throttles: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    // 通过连接ID获取对应的用户ID（如果已认证）
    pub async fn get_user_id_by_conn(&self, conn_id: &str) -> Option<String> {
        let user_conns = self.user_connections.read().await;
        for (user_id, connections) in user_conns.iter() {
            if connections.contains_key(conn_id) {
                return Some(user_id.clone());
            }
        }
        None
    }

    // 注册连接
    pub async fn register_connection(
        &self,
        conn_id: String,
        user_id: String,
        _client_ip: std::net::IpAddr,
        format: ConnectionFormat,
        sender: mpsc::Sender<OutboundFrame>,
        device_id: Option<String>,
        shutdown_tx: watch::Sender<()>,
    ) {
        let mut user_conns = self.user_connections.write().await;
        let conn_info = ConnectionInfo {
            user_id: user_id.clone(),
            device_id,
            connected_at: chrono::Utc::now(),
            last_ping: chrono::Utc::now(),
            format,
            sender,
            shutdown_tx,
        };

        user_conns
            .entry(user_id.clone())
            .or_insert_with(HashMap::new)
            .insert(conn_id.clone(), conn_info);

        info!(
            "用户 {} 的连接 {} 已注册（格式: {}）",
            user_id,
            conn_id,
            format.as_str()
        );
    }

    // 注销连接
    pub async fn unregister_connection(&self, conn_id: &str) -> Option<Vec<Uuid>> {
        let mut user_conns = self.user_connections.write().await;
        let mut conn_rooms = self.connection_rooms.write().await;
        let mut room_subs = self.room_subscribers.write().await;
        let mut qr_subs = self.qr_subscribers.write().await;

        for conns in qr_subs.values_mut() {
            conns.remove(conn_id);
        }
        qr_subs.retain(|_, conns| !conns.is_empty());

        // 查找并移除连接；只返回本节点不再有订阅者的房间，供 Redis Hub 取消订阅。
        let mut empty_rooms = Vec::new();
        let mut user_to_remove: Option<String> = None;

        for (user_id, connections) in user_conns.iter_mut() {
            if connections.contains_key(conn_id) {
                connections.remove(conn_id);

                // 获取该连接订阅的房间
                if let Some(rooms) = conn_rooms.remove(conn_id) {
                    for room_id in &rooms {
                        // 从房间订阅者中移除用户
                        if let Some(subscribers) = room_subs.get_mut(room_id) {
                            subscribers.remove(conn_id);
                            if subscribers.is_empty() {
                                room_subs.remove(room_id);
                                empty_rooms.push(*room_id);
                            }
                        }
                    }
                }
                // 标记需要清理的用户
                if connections.is_empty() {
                    user_to_remove = Some(user_id.clone());
                }
                break;
            }
        }

        // 清理空用户记录
        if let Some(user_id) = user_to_remove {
            user_conns.remove(&user_id);
        }

        drop(room_subs);
        drop(conn_rooms);
        drop(user_conns);

        let typing_prefix = format!("{conn_id}:");
        self.typing_throttles
            .write()
            .await
            .retain(|key, _| !key.starts_with(&typing_prefix));

        info!("连接 {} 已注销，节点空房间: {:?}", conn_id, empty_rooms);
        Some(empty_rooms)
    }

    /// 撤销设备时断开该设备在当前节点的全部 WebSocket 连接。
    ///
    /// 只触发与 `device_id` 匹配的连接退出；连接在收到推送的 error 消息后由
    /// `handle_socket` 统一清理订阅关系。
    pub async fn disconnect_device(&self, user_id: &str, device_id: &str) {
        let conn_ids: Vec<String> = {
            let user_conns = self.user_connections.read().await;
            user_conns
                .get(user_id)
                .map(|conns| {
                    conns
                        .iter()
                        .filter(|(_, info)| info.device_id.as_deref() == Some(device_id))
                        .map(|(conn_id, _)| conn_id.clone())
                        .collect()
                })
                .unwrap_or_default()
        };

        for conn_id in conn_ids {
            let shutdown_tx = {
                let user_conns = self.user_connections.read().await;
                user_conns
                    .get(user_id)
                    .and_then(|conns| conns.get(&conn_id))
                    .map(|info| info.shutdown_tx.clone())
            };
            if let Some(tx) = shutdown_tx {
                let _ = tx.send(());
            }
        }
    }

    // 订阅房间
    pub async fn subscribe_room(&self, conn_id: &str, room_id: Uuid) -> Result<bool, String> {
        let user_conns = self.user_connections.read().await;
        let mut conn_rooms = self.connection_rooms.write().await;
        let mut room_subs = self.room_subscribers.write().await;

        // 检查连接是否存在
        let user_id = user_conns
            .iter()
            .find_map(|(user_id, conns)| conns.contains_key(conn_id).then(|| user_id.clone()))
            .ok_or_else(|| "连接未认证".to_string())?;

        // 添加到连接房间映射
        let inserted_conn_room = conn_rooms
            .entry(conn_id.to_string())
            .or_insert_with(HashSet::new)
            .insert(room_id);

        // 添加到房间订阅者映射
        let subscribers = room_subs.entry(room_id).or_insert_with(HashSet::new);
        let was_empty = subscribers.is_empty();
        subscribers.insert(conn_id.to_string());

        info!("连接 {} (用户 {}) 订阅房间 {}", conn_id, user_id, room_id);
        Ok(was_empty && inserted_conn_room)
    }

    // 取消订阅房间
    pub async fn unsubscribe_room(&self, conn_id: &str, room_id: Uuid) -> Option<bool> {
        let mut conn_rooms = self.connection_rooms.write().await;
        let mut room_subs = self.room_subscribers.write().await;

        let mut was_subscribed = false;
        let mut room_became_empty = false;

        // 从连接房间映射中移除
        if let Some(rooms) = conn_rooms.get_mut(conn_id) {
            was_subscribed = rooms.remove(&room_id);
            if rooms.is_empty() {
                conn_rooms.remove(conn_id);
            }
        }

        // 从房间订阅者中移除
        if let Some(subscribers) = room_subs.get_mut(&room_id) {
            subscribers.remove(conn_id);
            if subscribers.is_empty() {
                room_subs.remove(&room_id);
                room_became_empty = true;
            }
        }

        if was_subscribed {
            info!("连接 {} 取消订阅房间 {}", conn_id, room_id);
            Some(room_became_empty)
        } else {
            None
        }
    }

    pub async fn is_connection_subscribed_to_room(&self, conn_id: &str, room_id: Uuid) -> bool {
        let conn_rooms = self.connection_rooms.read().await;
        conn_rooms
            .get(conn_id)
            .map(|rooms| rooms.contains(&room_id))
            .unwrap_or(false)
    }

    pub async fn can_emit_typing(&self, conn_id: &str, room_id: Uuid, is_typing: bool) -> bool {
        // 允许的最小间隔（同一连接、同一房间、同一状态）
        const THROTTLE_MS: u64 = 1200;

        let key = format!("{}:{}", conn_id, room_id);
        let mut throttles = self.typing_throttles.write().await;

        let now = Instant::now();
        if let Some(entry) = throttles.get_mut(&key) {
            // 状态发生变化（true <-> false）允许立即发送
            if entry.last_is_typing != is_typing {
                entry.last_is_typing = is_typing;
                entry.last_sent_at = now;
                return true;
            }

            if now.duration_since(entry.last_sent_at).as_millis() >= THROTTLE_MS as u128 {
                entry.last_sent_at = now;
                return true;
            }

            return false;
        }

        throttles.insert(
            key,
            TypingThrottleInfo {
                last_sent_at: now,
                last_is_typing: is_typing,
            },
        );
        true
    }

    // 获取房间订阅者
    pub async fn get_room_subscribers(&self, room_id: Uuid) -> Vec<String> {
        let room_subs = self.room_subscribers.read().await;
        room_subs
            .get(&room_id)
            .map(|subs| subs.iter().cloned().collect())
            .unwrap_or_default()
    }

    // 获取用户的所有连接
    pub async fn get_user_connections(&self, user_id: &str) -> Vec<String> {
        let user_conns = self.user_connections.read().await;
        user_conns
            .get(user_id)
            .map(|conns| conns.keys().cloned().collect())
            .unwrap_or_default()
    }

    // 心跳更新 - 记录客户端IP
    pub async fn update_ping(
        &self,
        conn_id: &str,
        client_ip: std::net::IpAddr,
        state: &AppState,
    ) -> bool {
        let mut user_conns = self.user_connections.write().await;
        for connections in user_conns.values_mut() {
            if let Some(conn_info) = connections.get_mut(conn_id) {
                conn_info.last_ping = chrono::Utc::now();

                // 异步更新Redis会话心跳信息和记录心跳日志（不阻塞心跳响应）
                let user_id = conn_info.user_id.clone();
                let client_ip = client_ip.clone();
                let redis_manager = state.redis.clone();
                let node_id = state.node_id.clone();
                let database = state.database.clone();
                // let connection_id = conn_id.to_string();
                tokio::spawn(async move {
                    let user_uuid = match uuid::Uuid::parse_str(&user_id) {
                        Ok(uuid) => uuid,
                        Err(_) => return,
                    };

                    // 跨节点在线态：用于 Push 的 skip_if_online 去重
                    let mut conn = redis_manager.get_session_connection();
                    let key = crate::redis::models::CacheKeys::user_online_status(&user_uuid);
                    let _: redis::RedisResult<()> = conn
                        .set_ex(key, node_id.as_str(), USER_ONLINE_TTL_SECONDS)
                        .await;

                    // 获取会话管理器并更新心跳和IP
                    let session_manager = redis_manager.get_session_manager(node_id.clone());
                    if let Err(e) = session_manager
                        .update_session_heartbeat_with_ip(&user_uuid, client_ip)
                        .await
                    {
                        tracing::debug!("更新Redis会话心跳失败: {}", e);
                    }

                    // 检查用户IP是否变化，如果变化则更新地理位置
                    let ip_changed =
                        if let Some(geolocation_service) = geolocation::get_geolocation_service() {
                            geolocation_service
                                .has_user_ip_changed(&user_uuid, &client_ip.to_string())
                                .await
                                .unwrap_or(true)
                        } else {
                            false // 服务未启用，不处理地理位置
                        };

                    // 检查IP地理位置解析功能是否启用
                    let geolocation_enabled =
                        geolocation::is_ip_geolocation_enabled(&database).await;

                    if ip_changed && geolocation_enabled {
                        // 异步查询和更新地理位置
                        let user_uuid_clone = user_uuid;
                        let client_ip_clone = client_ip.to_string();
                        tokio::spawn(async move {
                            if let Some(geolocation_service) =
                                geolocation::get_geolocation_service()
                            {
                                info!("检测到用户 {} IP变化: {}", user_uuid_clone, client_ip_clone);
                                match geolocation_service
                                    .query_ip_geolocation(&client_ip_clone)
                                    .await
                                {
                                    Ok(Some(mut geolocation)) => {
                                        geolocation.user_id = user_uuid_clone;
                                        if let Err(e) = geolocation_service
                                            .update_user_geolocation(
                                                &user_uuid_clone,
                                                &client_ip_clone,
                                                &geolocation,
                                            )
                                            .await
                                        {
                                            warn!("更新用户地理位置失败: {}", e);
                                        } else {
                                            info!(
                                                "成功更新用户 {} 的地理位置: {:?}, {:?}",
                                                user_uuid_clone,
                                                geolocation.city,
                                                geolocation.country
                                            );
                                        }
                                    }
                                    Ok(None) => {
                                        warn!("无法获取IP {} 的地理位置信息", client_ip_clone);
                                    }
                                    Err(e) => {
                                        error!("查询地理位置时发生错误: {}", e);
                                    }
                                }
                            }
                        });
                    } else {
                        // IP没有变化，静默跳过
                        trace!("用户 {} IP未变化，跳过地理位置更新", user_uuid);
                    }
                });

                return true;
            }
        }
        false
    }

    // 获取在线用户数
    pub async fn get_online_user_count(&self) -> usize {
        let user_conns = self.user_connections.read().await;
        user_conns.len()
    }

    pub async fn is_user_online(&self, user_id: &str) -> bool {
        let user_conns = self.user_connections.read().await;
        user_conns
            .get(user_id)
            .map(|conns| !conns.is_empty())
            .unwrap_or(false)
    }

    // 获取房间订阅者数
    pub async fn get_room_subscriber_count(&self, room_id: Uuid) -> usize {
        let room_subs = self.room_subscribers.read().await;
        room_subs.get(&room_id).map(|subs| subs.len()).unwrap_or(0)
    }

    // 获取当前节点上的活跃房间数（有订阅者的房间）
    pub async fn get_active_room_count(&self) -> usize {
        let room_subs = self.room_subscribers.read().await;
        room_subs.len()
    }

    pub async fn send_to_user(&self, user_id: &str, payload: ServerPush) {
        let payload = Arc::new(payload);
        let mut json_cache: Option<String> = None;
        let mut proto_cache: Option<Vec<u8>> = None;

        let user_conns = self.user_connections.read().await;
        if let Some(conns) = user_conns.get(user_id) {
            for (conn_id, info) in conns {
                let send_result = match info.format {
                    ConnectionFormat::Json => {
                        let text = match &json_cache {
                            Some(cached) => cached.clone(),
                            None => {
                                let encoded = payload.as_ref().to_json_string();
                                json_cache = Some(encoded);
                                json_cache.as_ref().unwrap().clone()
                            }
                        };
                        try_send_outbound(
                            &info.sender,
                            OutboundFrame::Text(text),
                            &format!("user:{user_id}/conn:{conn_id}"),
                        )
                    }
                    ConnectionFormat::Protobuf => {
                        let bytes = match &proto_cache {
                            Some(cached) => cached.clone(),
                            None => {
                                let encoded = payload.as_ref().to_protobuf_bytes();
                                proto_cache = Some(encoded);
                                proto_cache.as_ref().unwrap().clone()
                            }
                        };
                        try_send_outbound(
                            &info.sender,
                            OutboundFrame::Binary(bytes),
                            &format!("user:{user_id}/conn:{conn_id}"),
                        )
                    }
                };

                if !send_result {
                    tracing::debug!(
                        "向用户 {} 的连接 {} 投递 WebSocket 事件失败",
                        user_id,
                        conn_id
                    );
                }
            }
        }
    }

    pub async fn send_to_room(&self, room_id: Uuid, payload: ServerPush) {
        let subscriber_ids = self.get_room_subscribers(room_id).await;
        if subscriber_ids.is_empty() {
            return;
        }

        let payload = Arc::new(payload);
        let mut json_cache: Option<String> = None;
        let mut proto_cache: Option<Vec<u8>> = None;

        let user_conns = self.user_connections.read().await;
        for conn_id in subscriber_ids {
            let Some(info) = user_conns
                .values()
                .find_map(|connections| connections.get(&conn_id))
            else {
                continue;
            };

            let send_result = match info.format {
                ConnectionFormat::Json => {
                    let text = match &json_cache {
                        Some(cached) => cached.clone(),
                        None => {
                            let encoded = payload.as_ref().to_json_string();
                            json_cache = Some(encoded);
                            json_cache.as_ref().unwrap().clone()
                        }
                    };
                    try_send_outbound(
                        &info.sender,
                        OutboundFrame::Text(text),
                        &format!("room:{room_id}/conn:{conn_id}"),
                    )
                }
                ConnectionFormat::Protobuf => {
                    let bytes = match &proto_cache {
                        Some(cached) => cached.clone(),
                        None => {
                            let encoded = payload.as_ref().to_protobuf_bytes();
                            proto_cache = Some(encoded);
                            proto_cache.as_ref().unwrap().clone()
                        }
                    };
                    try_send_outbound(
                        &info.sender,
                        OutboundFrame::Binary(bytes),
                        &format!("room:{room_id}/conn:{conn_id}"),
                    )
                }
            };

            if !send_result {
                tracing::debug!(
                    "向房间 {} 的连接 {} 投递 WebSocket 事件失败",
                    room_id,
                    conn_id
                );
            }
        }
    }

    /// 订阅扫码登录会话（无需认证）。
    pub async fn subscribe_qr(
        &self,
        qr_id: Uuid,
        conn_id: String,
        info: ConnectionInfo,
    ) {
        let mut qr_subs = self.qr_subscribers.write().await;
        qr_subs
            .entry(qr_id)
            .or_insert_with(HashMap::new)
            .insert(conn_id, info);
    }

    /// 向扫码会话订阅连接推送状态（JSON/protobuf 双格式）。
    pub async fn send_to_qr(&self, qr_id: Uuid, payload: ServerPush) {
        let qr_subs = self.qr_subscribers.read().await;
        let Some(conns) = qr_subs.get(&qr_id) else {
            return;
        };

        let payload = Arc::new(payload);
        let mut json_cache: Option<String> = None;
        let mut proto_cache: Option<Vec<u8>> = None;

        for (conn_id, info) in conns {
            let send_result = match info.format {
                ConnectionFormat::Json => {
                    let text = match &json_cache {
                        Some(cached) => cached.clone(),
                        None => {
                            let encoded = payload.as_ref().to_json_string();
                            json_cache = Some(encoded);
                            json_cache.as_ref().unwrap().clone()
                        }
                    };
                    try_send_outbound(
                        &info.sender,
                        OutboundFrame::Text(text),
                        &format!("qr:{qr_id}/conn:{conn_id}"),
                    )
                }
                ConnectionFormat::Protobuf => {
                    let bytes = match &proto_cache {
                        Some(cached) => cached.clone(),
                        None => {
                            let encoded = payload.as_ref().to_protobuf_bytes();
                            proto_cache = Some(encoded);
                            proto_cache.as_ref().unwrap().clone()
                        }
                    };
                    try_send_outbound(
                        &info.sender,
                        OutboundFrame::Binary(bytes),
                        &format!("qr:{qr_id}/conn:{conn_id}"),
                    )
                }
            };
            if !send_result {
                tracing::debug!("qr 推送失败 conn={conn_id}");
            }
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ClientEvent {
    Auth {
        token: String,
    },
    Join {
        room_id: Uuid,
    },
    Leave {
        room_id: Uuid,
    },
    Ping,
    Typing {
        room_id: Uuid,
        #[serde(alias = "isTyping")]
        is_typing: bool,
    },
    QrSubscribe {
        qr_id: Uuid,
    },
}

impl TryFrom<ws::ClientEvent> for ClientEvent {
    type Error = String;

    fn try_from(value: ws::ClientEvent) -> Result<Self, Self::Error> {
        use ws::client_event::Payload;

        match value.payload {
            Some(Payload::Auth(auth)) => Ok(ClientEvent::Auth { token: auth.token }),
            Some(Payload::Join(join)) => Ok(ClientEvent::Join {
                room_id: Uuid::parse_str(&join.room_id)
                    .map_err(|_| "invalid room_id".to_string())?,
            }),
            Some(Payload::Leave(leave)) => Ok(ClientEvent::Leave {
                room_id: Uuid::parse_str(&leave.room_id)
                    .map_err(|_| "invalid room_id".to_string())?,
            }),
            Some(Payload::Ping(_)) => Ok(ClientEvent::Ping),
            Some(Payload::Typing(typing)) => Ok(ClientEvent::Typing {
                room_id: Uuid::parse_str(&typing.room_id)
                    .map_err(|_| "invalid room_id".to_string())?,
                is_typing: typing.is_typing,
            }),
            Some(Payload::QrSubscribe(sub)) => Ok(ClientEvent::QrSubscribe {
                qr_id: Uuid::parse_str(&sub.qr_id).map_err(|_| "invalid qr_id".to_string())?,
            }),
            None => Err("missing payload".to_string()),
        }
    }
}

fn ws_outbound_queue_size_from_env() -> usize {
    env::var("WS_OUTBOUND_QUEUE_SIZE")
        .ok()
        .and_then(|value| value.trim().parse::<usize>().ok())
        .filter(|value| *value > 0)
        .map(|value| value.min(MAX_WS_OUTBOUND_QUEUE_SIZE))
        .unwrap_or(DEFAULT_WS_OUTBOUND_QUEUE_SIZE)
}

fn try_send_outbound(
    sender: &mpsc::Sender<OutboundFrame>,
    frame: OutboundFrame,
    conn_label: &str,
) -> bool {
    match sender.try_send(frame) {
        Ok(()) => true,
        Err(TrySendError::Full(_)) => {
            warn!("WebSocket 出站队列已满，丢弃本次推送: conn={}", conn_label);
            false
        }
        Err(TrySendError::Closed(_)) => {
            debug!("WebSocket 出站队列已关闭: conn={}", conn_label);
            false
        }
    }
}

fn room_id_for_pubsub_payload(payload: &crate::redis::models::PubSubPayload) -> Uuid {
    match payload {
        crate::redis::models::PubSubPayload::Message { data } => data.room_id,
        crate::redis::models::PubSubPayload::ReadReceipt { data } => data.room_id,
        crate::redis::models::PubSubPayload::MessageUpdate { data } => data.room_id,
        crate::redis::models::PubSubPayload::PinUpdate { data } => data.room_id,
        crate::redis::models::PubSubPayload::RoomUpdate { data } => data.room_id,
        crate::redis::models::PubSubPayload::GroupSettingsUpdate { data } => data.room_id,
        crate::redis::models::PubSubPayload::GroupMemberChanged { data } => data.room_id,
        crate::redis::models::PubSubPayload::RoomHistoryCleared { data } => data.room_id,
        crate::redis::models::PubSubPayload::ReactionUpdate { data } => data.room_id,
        crate::redis::models::PubSubPayload::TypingUpdate { data } => data.room_id,
    }
}

fn server_push_for_pubsub_payload(payload: crate::redis::models::PubSubPayload) -> ServerPush {
    match payload {
        crate::redis::models::PubSubPayload::Message { data } => ServerPush::Message { data },
        crate::redis::models::PubSubPayload::ReadReceipt { data } => {
            ServerPush::MessageRead { data }
        }
        crate::redis::models::PubSubPayload::MessageUpdate { data } => {
            ServerPush::MessageUpdate { data }
        }
        crate::redis::models::PubSubPayload::PinUpdate { data } => ServerPush::PinUpdate { data },
        crate::redis::models::PubSubPayload::RoomUpdate { data } => ServerPush::RoomUpdated {
            data: RoomUpdatedPayload {
                room_id: data.room_id,
                room_name: data.room_name,
                room_type: data.room_type,
                avatar_url: data.avatar_url,
                avatar_object_key: data.avatar_object_key,
                description: data.description,
            },
        },
        crate::redis::models::PubSubPayload::GroupSettingsUpdate { data } => {
            ServerPush::GroupSettingsUpdated {
                room_id: data.room_id,
                global_mute_enabled: data.global_mute_enabled,
                global_mute_reason: data.global_mute_reason,
                global_mute_until: data.global_mute_until.map(|ts| ts.to_rfc3339()),
                global_mute_set_by: data.global_mute_set_by.map(|id| id.to_string()),
            }
        }
        crate::redis::models::PubSubPayload::GroupMemberChanged { data } => {
            ServerPush::GroupMemberChanged {
                room_id: data.room_id,
                member_id: data.member_id,
                change_type: data.change_type.to_string(),
                new_role: data.new_role,
                operator_id: data.operator_id,
                reason: data.reason,
                until: data.until.map(|ts| ts.to_rfc3339()),
            }
        }
        crate::redis::models::PubSubPayload::RoomHistoryCleared { data } => {
            ServerPush::RoomHistoryCleared {
                room_id: data.room_id,
                cleared_by: data.cleared_by,
                cleared_at: data.cleared_at.to_rfc3339(),
            }
        }
        crate::redis::models::PubSubPayload::ReactionUpdate { data } => {
            ServerPush::ReactionUpdate { data }
        }
        crate::redis::models::PubSubPayload::TypingUpdate { data } => {
            ServerPush::TypingUpdate { data }
        }
    }
}

fn decode_pubsub_payload(payload: &[u8]) -> Option<crate::redis::models::PubSubPayload> {
    ws::PubSubEvent::decode(payload)
        .ok()
        .and_then(|event| crate::redis::models::PubSubPayload::try_from(event).ok())
        .or_else(|| match std::str::from_utf8(payload) {
            Ok(text) => match serde_json::from_str::<crate::redis::models::PubSubPayload>(text) {
                Ok(event) => Some(event),
                Err(err) => {
                    error!("解析Redis消息失败: {}", err);
                    None
                }
            },
            Err(err) => {
                error!("Redis 消息不是有效的 UTF-8: {}", err);
                None
            }
        })
}

async fn rebuild_pubsub(
    client: &redis::Client,
    current_channels: &HashSet<String>,
) -> Option<redis::aio::PubSub> {
    match client.get_async_pubsub().await {
        Ok(mut new_pubsub) => {
            for ch in current_channels {
                if let Err(e) = new_pubsub.subscribe(ch).await {
                    error!("重建后订阅频道失败 {}: {}", ch, e);
                }
            }
            Some(new_pubsub)
        }
        Err(e) => {
            error!("重建 PubSub 连接失败: {}", e);
            None
        }
    }
}

async fn run_pubsub_hub(
    pubsub_client: redis::Client,
    connection_manager: Arc<ConnectionManager>,
    mut cmd_rx: mpsc::UnboundedReceiver<PubSubHubCmd>,
) {
    let mut pubsub = match pubsub_client.get_async_pubsub().await {
        Ok(ps) => ps,
        Err(e) => {
            error!("Redis PubSub Hub 连接失败: {}", e);
            return;
        }
    };
    let mut subscribed_channels: HashSet<String> = HashSet::new();

    loop {
        tokio::select! {
            Some(cmd) = cmd_rx.recv() => {
                let PubSubHubCmd::SyncRoom { room_id, channel, ack } = cmd;
                let has_local_subscribers = connection_manager.get_room_subscriber_count(room_id).await > 0;
                let mut sync_result = Ok(());

                if has_local_subscribers && !subscribed_channels.contains(&channel) {
                    match pubsub.subscribe(&channel).await {
                        Ok(_) => {
                            subscribed_channels.insert(channel.clone());
                            info!("节点级 Redis PubSub 订阅频道: {}", channel);
                        }
                        Err(e) => {
                            error!("节点级 Redis PubSub 订阅失败 {}: {}", channel, e);
                            sync_result = Err(e.to_string());
                            if let Some(new_ps) = rebuild_pubsub(&pubsub_client, &subscribed_channels).await {
                                pubsub = new_ps;
                            }
                        }
                    }
                } else if !has_local_subscribers && subscribed_channels.contains(&channel) {
                    match pubsub.unsubscribe(&channel).await {
                        Ok(_) => {
                            subscribed_channels.remove(&channel);
                            info!("节点级 Redis PubSub 取消订阅频道: {}", channel);
                        }
                        Err(e) => {
                            error!("节点级 Redis PubSub 取消订阅失败 {}: {}", channel, e);
                            sync_result = Err(e.to_string());
                            if let Some(new_ps) = rebuild_pubsub(&pubsub_client, &subscribed_channels).await {
                                pubsub = new_ps;
                            }
                        }
                    }
                }
                let _ = ack.send(sync_result);
            }
            msg = async {
                let mut on_msg = pubsub.on_message();
                on_msg.next().await
            } => {
                let Some(msg) = msg else {
                    if let Some(new_ps) = rebuild_pubsub(&pubsub_client, &subscribed_channels).await {
                        pubsub = new_ps;
                    }
                    continue;
                };

                let payload: Vec<u8> = match msg.get_payload() {
                    Ok(p) => p,
                    Err(err) => {
                        error!("读取Redis消息负载失败: {}", err);
                        continue;
                    }
                };

                let Some(event) = decode_pubsub_payload(&payload) else {
                    continue;
                };
                let room_id = room_id_for_pubsub_payload(&event);
                let push = server_push_for_pubsub_payload(event);
                connection_manager.send_to_room(room_id, push).await;
            }
        }
    }
}

async fn handle_client_event(
    event: ClientEvent,
    conn_id: &str,
    client_addr: std::net::SocketAddr,
    format: ConnectionFormat,
    connection_manager: Arc<ConnectionManager>,
    out_tx: &mpsc::Sender<OutboundFrame>,
    shutdown_tx: &watch::Sender<()>,
    state: &AppState,
) -> Result<(), String> {
    match event {
        ClientEvent::QrSubscribe { qr_id } => {
            let info = ConnectionInfo {
                user_id: String::new(),
                device_id: None,
                connected_at: chrono::Utc::now(),
                last_ping: chrono::Utc::now(),
                format,
                sender: out_tx.clone(),
                shutdown_tx: shutdown_tx.clone(),
            };
            connection_manager
                .subscribe_qr(qr_id, conn_id.to_string(), info)
                .await;
            Ok(())
        }
        ClientEvent::Auth { token } => match auth::verify_token(&token) {
            Ok(claims) => {
                let user_id = claims.sub.clone();
                connection_manager
                    .register_connection(
                        conn_id.to_string(),
                        user_id.clone(),
                        client_addr.ip(),
                        format,
                        out_tx.clone(),
                        claims.device_id.clone(),
                        shutdown_tx.clone(),
                    )
                    .await;

                // 异步记录用户登录历史和初始化地理位置
                let user_id_clone = user_id.clone();
                let client_ip_clone = client_addr.ip().to_string();
                let state_clone = state.clone();
                tokio::spawn(async move {
                    let user_uuid = match uuid::Uuid::parse_str(&user_id_clone) {
                        Ok(uuid) => uuid,
                        Err(_) => return,
                    };

                    // 跨节点在线态：用于 Push 的 skip_if_online 去重
                    let mut conn = state_clone.redis.get_session_connection();
                    let key = crate::redis::models::CacheKeys::user_online_status(&user_uuid);
                    let _: redis::RedisResult<()> = conn
                        .set_ex(key, state_clone.node_id.as_str(), USER_ONLINE_TTL_SECONDS)
                        .await;

                    // 记录登录历史
                    let login_request = crate::handlers::activity_logs::CreateLoginHistoryRequest {
                        user_id: user_uuid,
                        ip_address: client_ip_clone.clone(),
                        user_agent: None,
                        login_method: "websocket".to_string(),
                        success: true,
                        failure_reason: None,
                        device_info: Some(serde_json::json!({
                            "connection_format": "json",
                            "node_id": state_clone.node_id
                        })),
                    };

                    if let Err(e) = sqlx::query(
                        r#"
                        INSERT INTO user_login_history (user_id, ip_address, user_agent, login_method, success, failure_reason, device_info)
                        VALUES ($1, $2::inet, $3, $4, $5, $6, $7)
                        "#,
                    )
                    .bind(login_request.user_id)
                    .bind(&login_request.ip_address)
                    .bind(&login_request.user_agent)
                    .bind(&login_request.login_method)
                    .bind(login_request.success)
                    .bind(&login_request.failure_reason)
                    .bind(&login_request.device_info)
                    .execute(&state_clone.database.pool)
                    .await {
                        tracing::warn!("记录用户登录历史失败: {}", e);
                    }

                    // 初始化或更新用户地理位置（如果地理位置服务启用）
                    let should_update_geolocation =
                        if let Some(geolocation_service) = geolocation::get_geolocation_service() {
                            geolocation_service
                                .has_user_ip_changed(&user_uuid, &client_ip_clone)
                                .await
                                .unwrap_or(true)
                        } else {
                            false
                        };

                    // 检查IP地理位置解析功能是否启用
                    let geolocation_enabled =
                        geolocation::is_ip_geolocation_enabled(&state_clone.database).await;

                    if should_update_geolocation && geolocation_enabled {
                        // 需要初始化地理位置
                        let user_uuid_clone = user_uuid;
                        let client_ip_clone_2 = client_ip_clone.clone();
                        tokio::spawn(async move {
                            if let Some(geolocation_service) =
                                geolocation::get_geolocation_service()
                            {
                                match geolocation_service
                                    .query_ip_geolocation(&client_ip_clone_2)
                                    .await
                                {
                                    Ok(Some(mut geolocation)) => {
                                        geolocation.user_id = user_uuid_clone;
                                        if let Err(e) = geolocation_service
                                            .update_user_geolocation(
                                                &user_uuid_clone,
                                                &client_ip_clone_2,
                                                &geolocation,
                                            )
                                            .await
                                        {
                                            warn!("初始化用户地理位置失败: {}", e);
                                        } else {
                                            info!(
                                                "成功初始化用户 {} 的地理位置: {:?}, {:?}",
                                                user_uuid_clone,
                                                geolocation.city,
                                                geolocation.country
                                            );
                                        }
                                    }
                                    Ok(None) => {
                                        debug!("无法获取用户 {} 初始地理位置信息", user_uuid_clone);
                                    }
                                    Err(e) => {
                                        warn!("查询用户初始地理位置时发生错误: {}", e);
                                    }
                                }
                            }
                        });
                    }
                });

                let push = ServerPush::Authed {
                    user_id: user_id.clone(),
                    conn_id: conn_id.to_string(),
                };
                try_send_outbound(out_tx, push.encode(format), conn_id);

                info!(
                    "WebSocket连接 {} 认证成功，用户: {} (格式: {})",
                    conn_id,
                    user_id,
                    format.as_str()
                );

                Ok(())
            }
            Err(e) => {
                error!("WebSocket认证失败: {}", e);
                Err("unauthorized".to_string())
            }
        },
        ClientEvent::Join { room_id } => {
            // 校验该连接所属用户是否为房间成员，防止订阅不属于自己的房间
            let user_id = connection_manager
                .get_user_id_by_conn(conn_id)
                .await
                .ok_or_else(|| "连接未认证".to_string())?;

            let user_uuid = Uuid::parse_str(&user_id).map_err(|_| "invalid user_id".to_string())?;

            let room_store = RoomStore::new(state.database.pool());
            let is_member = room_store
                .is_user_in_room(room_id, user_uuid)
                .await
                .map_err(|err| {
                    error!(
                        "检查用户 {} 是否在房间 {} 时出错: {}",
                        user_id, room_id, err
                    );
                    "internal error".to_string()
                })?;

            if !is_member {
                error!(
                    "用户 {} 尝试通过连接 {} 订阅不属于自己的房间 {}",
                    user_id, conn_id, room_id
                );
                return Err("forbidden: not a member of this room".to_string());
            }

            let should_sync_redis = connection_manager
                .subscribe_room(conn_id, room_id)
                .await
                .map_err(|err| {
                    error!("连接 {} 订阅房间 {} 失败: {}", conn_id, room_id, err);
                    err
                })?;

            if should_sync_redis {
                if let Err(err) = state.pubsub_hub.sync_room(room_id).await {
                    let _ = connection_manager.unsubscribe_room(conn_id, room_id).await;
                    return Err(err);
                }
            }

            let push = ServerPush::Joined { room_id };
            try_send_outbound(out_tx, push.encode(format), conn_id);
            info!("连接 {} 加入房间 {}", conn_id, room_id);

            Ok(())
        }
        ClientEvent::Leave { room_id } => {
            if let Some(should_unsubscribe_redis) =
                connection_manager.unsubscribe_room(conn_id, room_id).await
            {
                if should_unsubscribe_redis {
                    if let Err(err) = state.pubsub_hub.sync_room(room_id).await {
                        warn!("同步 Redis PubSub 取消订阅失败: {}", err);
                    }
                }

                let push = ServerPush::Left { room_id };
                try_send_outbound(out_tx, push.encode(format), conn_id);
                info!("连接 {} 离开房间 {}", conn_id, room_id);
                Ok(())
            } else {
                Err("not subscribed".to_string())
            }
        }
        ClientEvent::Ping => {
            connection_manager
                .update_ping(conn_id, client_addr.ip(), state)
                .await;
            try_send_outbound(out_tx, ServerPush::Pong.encode(format), conn_id);
            Ok(())
        }
        ClientEvent::Typing { room_id, is_typing } => {
            // 必须已认证
            let user_id = connection_manager
                .get_user_id_by_conn(conn_id)
                .await
                .ok_or_else(|| "连接未认证".to_string())?;

            let user_uuid = Uuid::parse_str(&user_id).map_err(|_| "invalid user_id".to_string())?;

            // 必须已加入该房间（Join 时已做过“房间成员校验”，这里避免每次 typing 都查 DB）
            if !connection_manager
                .is_connection_subscribed_to_room(conn_id, room_id)
                .await
            {
                return Err("not subscribed".to_string());
            }

            // 节流：同一状态 1.2s 内只广播一次（状态变化允许立即发送）
            if !connection_manager
                .can_emit_typing(conn_id, room_id, is_typing)
                .await
            {
                return Ok(());
            }

            // typing=true 时携带超时，客户端据此自动过期
            let expires_in_ms: i32 = if is_typing { 6000 } else { 0 };

            let payload = crate::redis::models::TypingUpdatePayload {
                room_id,
                user_id: user_uuid,
                is_typing,
                expires_in_ms,
            };

            let channel = crate::redis::models::CacheKeys::pubsub_channel(&room_id);
            let encoded = crate::redis::models::PubSubPayload::TypingUpdate { data: payload }
                .encode_protobuf();

            let mut conn = state.redis.get_pubsub_connection();
            let _subscriber_count: i64 = conn
                .publish(&channel, encoded)
                .await
                .map_err(|e| e.to_string())?;

            Ok(())
        }
    }
}

// WebSocket处理函数
pub async fn handle_socket(
    state: AppState,
    socket: WebSocket,
    client_addr: std::net::SocketAddr,
    format: ConnectionFormat,
) {
    // let redis_manager = state.redis.clone();
    let (mut ws_sender, mut ws_receiver) = socket.split();
    let conn_id = format!("conn_{}", Uuid::new_v4());

    let connection_manager = state.connection_manager.clone();

    let outbound_queue_size = ws_outbound_queue_size_from_env();
    let (out_tx, mut out_rx) = mpsc::channel::<OutboundFrame>(outbound_queue_size);
    let (shutdown_tx, mut shutdown_rx) = watch::channel(());

    let send_task = tokio::spawn(async move {
        while let Some(frame) = out_rx.recv().await {
            let result = match frame {
                OutboundFrame::Text(text) => ws_sender.send(Message::Text(text.into())).await,
                OutboundFrame::Binary(bytes) => ws_sender.send(Message::Binary(bytes.into())).await,
            };
            if let Err(err) = result {
                tracing::debug!("WebSocket发送失败: {}", err);
                break;
            }
        }
    });

    loop {
        tokio::select! {
            msg = ws_receiver.next() => {
                let Some(Ok(msg)) = msg else { break; };
                match msg {
                    Message::Text(text) => {
                        info!("WebSocket收到文本消息: {}", text);
                        match serde_json::from_str::<ClientEvent>(&text) {
                            Ok(event) => {
                                if let Err(err) = handle_client_event(
                                    event,
                                    &conn_id,
                                    client_addr,
                                    format,
                                    connection_manager.clone(),
                                    &out_tx,
                                    &shutdown_tx,
                                    &state,
                                )
                                .await
                                {
                                    try_send_outbound(
                                        &out_tx,
                                        ServerPush::Error {
                                            message: err.clone(),
                                        }
                                        .encode(format),
                                        &conn_id,
                                    );
                                    error!("处理客户端事件失败: {}", err);
                                }
                            }
                            Err(parse_err) => {
                                error!("无法解析WebSocket消息: {}，错误: {}", text, parse_err);
                                let err_text = format!("Parse error: {}", parse_err);
                                try_send_outbound(
                                    &out_tx,
                                    ServerPush::Error {
                                        message: err_text.clone(),
                                    }
                                    .encode(format),
                                    &conn_id,
                                );
                            }
                        }
                    }
                    Message::Binary(data) => {
                        if format == ConnectionFormat::Protobuf {
                            match ws::ClientEvent::decode(data.as_ref()) {
                                Ok(pb_event) => match ClientEvent::try_from(pb_event) {
                                    Ok(event) => {
                                        if let Err(err) = handle_client_event(
                                            event,
                                            &conn_id,
                                            client_addr,
                                            format,
                                            connection_manager.clone(),
                                            &out_tx,
                                            &shutdown_tx,
                                            &state,
                                        )
                                        .await
                                        {
                                            try_send_outbound(
                                                &out_tx,
                                                ServerPush::Error {
                                                    message: err.clone(),
                                                }
                                                .encode(format),
                                                &conn_id,
                                            );
                                            error!("处理客户端事件失败: {}", err);
                                        }
                                    }
                                    Err(err) => {
                                        error!("解析protobuf客户端事件失败: {}", err);
                                        try_send_outbound(
                                            &out_tx,
                                            ServerPush::Error {
                                                message: err.clone(),
                                            }
                                            .encode(format),
                                            &conn_id,
                                        );
                                    }
                                },
                                Err(decode_err) => {
                                    error!("解码protobuf消息失败: {}", decode_err);
                                    let err_text = format!("protobuf decode error: {}", decode_err);
                                    try_send_outbound(
                                        &out_tx,
                                        ServerPush::Error {
                                            message: err_text.clone(),
                                        }
                                        .encode(format),
                                        &conn_id,
                                    );
                                }
                            }
                        } else {
                            let encoded = base64::engine::general_purpose::STANDARD.encode(&data);
                            let frame = OutboundFrame::Text(
                                json!({
                                    "type": "binary",
                                    "data": encoded
                                })
                                .to_string(),
                            );
                            try_send_outbound(&out_tx, frame, &conn_id);
                        }
                    }
                    Message::Ping(_) => {
                        connection_manager
                            .update_ping(&conn_id, client_addr.ip(), &state)
                            .await;
                        try_send_outbound(&out_tx, ServerPush::Pong.encode(format), &conn_id);
                    }
                    Message::Pong(_) => {
                        connection_manager
                            .update_ping(&conn_id, client_addr.ip(), &state)
                            .await;
                    }
                    Message::Close(_) => {
                        break;
                    }
                }
            }
            _ = shutdown_rx.changed() => {
                try_send_outbound(
                    &out_tx,
                    ServerPush::Error {
                        message: "设备已被撤销，连接即将关闭".to_string(),
                    }
                    .encode(format),
                    &conn_id,
                );
                break;
            }
        }
    }

    let rooms = connection_manager.unregister_connection(&conn_id).await;

    if let Some(room_list) = rooms {
        for room_id in room_list {
            if let Err(err) = state.pubsub_hub.sync_room(room_id).await {
                warn!("关闭连接时同步 Redis PubSub 订阅失败: {}", err);
            }
        }
    }

    info!("WebSocket连接 {} 已关闭", conn_id);

    let _ = send_task.abort();
}

// WebSocket握手处理 - 增加认证检查
pub async fn handle_websocket_upgrade(
    State(state): State<AppState>,
    ws: WebSocketUpgrade,
    axum::extract::ConnectInfo(client_addr): axum::extract::ConnectInfo<std::net::SocketAddr>,
    // 可选的查询参数中的token
    axum::extract::Query(params): axum::extract::Query<WsUpgradeParams>,
) -> Result<impl IntoResponse, StatusCode> {
    let connection_format = ConnectionFormat::from_query(params.format.as_deref());

    // 检查是否有token（可选的连接前认证）
    if let Some(ref token) = params.token {
        match auth::verify_token(token) {
            Ok(claims) => {
                info!(
                    "WebSocket握手认证成功，用户: {}，格式: {}",
                    claims.sub,
                    connection_format.as_str()
                );
                return Ok(ws.on_upgrade(move |socket| {
                    handle_socket(state, socket, client_addr, connection_format)
                }));
            }
            Err(e) => {
                error!("WebSocket握手认证失败: {}", e);
                return Err(StatusCode::UNAUTHORIZED);
            }
        }
    }

    // 无token也允许连接，但需要在连接后通过Auth事件认证
    info!(
        "WebSocket握手完成（未提前认证），等待客户端认证，格式: {}",
        connection_format.as_str()
    );
    Ok(ws.on_upgrade(move |socket| handle_socket(state, socket, client_addr, connection_format)))
}

#[derive(serde::Deserialize)]
pub struct WsUpgradeParams {
    pub token: Option<String>,
    pub format: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Mutex, OnceLock};

    fn env_lock() -> &'static Mutex<()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
    }

    struct EnvGuard(Option<String>);

    impl EnvGuard {
        fn set(value: Option<&str>) -> Self {
            let previous = env::var("WS_OUTBOUND_QUEUE_SIZE").ok();
            match value {
                Some(value) => env::set_var("WS_OUTBOUND_QUEUE_SIZE", value),
                None => env::remove_var("WS_OUTBOUND_QUEUE_SIZE"),
            }
            Self(previous)
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            match &self.0 {
                Some(value) => env::set_var("WS_OUTBOUND_QUEUE_SIZE", value),
                None => env::remove_var("WS_OUTBOUND_QUEUE_SIZE"),
            }
        }
    }

    #[test]
    fn outbound_queue_size_defaults_when_env_missing_or_invalid() {
        let _lock = env_lock().lock().expect("env lock poisoned");

        let _guard = EnvGuard::set(None);
        assert_eq!(
            ws_outbound_queue_size_from_env(),
            DEFAULT_WS_OUTBOUND_QUEUE_SIZE
        );
        drop(_guard);

        let _guard = EnvGuard::set(Some("0"));
        assert_eq!(
            ws_outbound_queue_size_from_env(),
            DEFAULT_WS_OUTBOUND_QUEUE_SIZE
        );
        drop(_guard);

        let _guard = EnvGuard::set(Some("not-a-number"));
        assert_eq!(
            ws_outbound_queue_size_from_env(),
            DEFAULT_WS_OUTBOUND_QUEUE_SIZE
        );
    }

    #[test]
    fn outbound_queue_size_reads_env_and_caps_upper_bound() {
        let _lock = env_lock().lock().expect("env lock poisoned");

        let _guard = EnvGuard::set(Some("2048"));
        assert_eq!(ws_outbound_queue_size_from_env(), 2048);
        drop(_guard);

        let _guard = EnvGuard::set(Some("999999"));
        assert_eq!(
            ws_outbound_queue_size_from_env(),
            MAX_WS_OUTBOUND_QUEUE_SIZE
        );
    }

    #[test]
    fn try_send_outbound_returns_false_when_queue_is_full() {
        let (tx, _rx) = mpsc::channel::<OutboundFrame>(1);
        assert!(try_send_outbound(
            &tx,
            OutboundFrame::Text("first".to_string()),
            "test"
        ));
        assert!(!try_send_outbound(
            &tx,
            OutboundFrame::Text("second".to_string()),
            "test"
        ));
    }

    #[tokio::test]
    async fn disconnect_device_triggers_only_matching_device_connections() {
        let manager = Arc::new(ConnectionManager::new());
        let (tx_a, _rx_a) = mpsc::channel::<OutboundFrame>(8);
        let (tx_b, _rx_b) = mpsc::channel::<OutboundFrame>(8);
        let (shutdown_a_tx, shutdown_a_rx) = watch::channel(());
        let (shutdown_b_tx, shutdown_b_rx) = watch::channel(());
        let ip = "127.0.0.1".parse().unwrap();

        manager
            .register_connection(
                "conn_a".to_string(),
                "user_1".to_string(),
                ip,
                ConnectionFormat::Json,
                tx_a,
                Some("device_a".to_string()),
                shutdown_a_tx,
            )
            .await;
        manager
            .register_connection(
                "conn_b".to_string(),
                "user_1".to_string(),
                ip,
                ConnectionFormat::Json,
                tx_b,
                Some("device_b".to_string()),
                shutdown_b_tx,
            )
            .await;

        manager.disconnect_device("user_1", "device_a").await;

        assert!(shutdown_a_rx.has_changed().expect("watch 未关闭"));
        assert!(!shutdown_b_rx.has_changed().expect("watch 未关闭"));
    }
}
