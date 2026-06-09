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
    sync::Arc,
    time::Instant,
};
use tokio::sync::{mpsc, RwLock};
use uuid::Uuid;

use crate::{auth, database::room_store::RoomStore, proto::ws, services::geolocation, AppState};
use protocol::{ConnectionFormat, OutboundFrame};
use tracing::{debug, error, info, trace, warn};

const USER_ONLINE_TTL_SECONDS: u64 = 90;

// WebSocket连接管理器
pub struct ConnectionManager {
    // 用户ID -> 连接集合映射
    user_connections: Arc<RwLock<HashMap<String, HashMap<String, ConnectionInfo>>>>,
    // 连接ID -> 订阅房间映射
    connection_rooms: Arc<RwLock<HashMap<String, HashSet<Uuid>>>>,
    // 房间ID -> 订阅用户集合
    room_subscribers: Arc<RwLock<HashMap<Uuid, HashSet<String>>>>,
    // 输入态节流：key = "{conn_id}:{room_id}"
    typing_throttles: Arc<RwLock<HashMap<String, TypingThrottleInfo>>>,
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
    pub connected_at: chrono::DateTime<chrono::Utc>,
    pub last_ping: chrono::DateTime<chrono::Utc>,
    pub format: ConnectionFormat,
    pub sender: mpsc::UnboundedSender<OutboundFrame>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        Self {
            user_connections: Arc::new(RwLock::new(HashMap::new())),
            connection_rooms: Arc::new(RwLock::new(HashMap::new())),
            room_subscribers: Arc::new(RwLock::new(HashMap::new())),
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
        sender: mpsc::UnboundedSender<OutboundFrame>,
    ) {
        let mut user_conns = self.user_connections.write().await;
        let conn_info = ConnectionInfo {
            user_id: user_id.clone(),
            connected_at: chrono::Utc::now(),
            last_ping: chrono::Utc::now(),
            format,
            sender,
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

        // 查找并移除连接
        let mut rooms_to_leave = Vec::new();
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
                            }
                        }
                        rooms_to_leave.push(*room_id);
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

        info!("连接 {} 已注销，离开房间: {:?}", conn_id, rooms_to_leave);
        Some(rooms_to_leave)
    }

    // 订阅房间
    pub async fn subscribe_room(&self, conn_id: &str, room_id: Uuid) -> Result<(), String> {
        let user_conns = self.user_connections.read().await;
        let mut conn_rooms = self.connection_rooms.write().await;
        let mut room_subs = self.room_subscribers.write().await;

        // 检查连接是否存在
        let user_id = user_conns
            .iter()
            .find_map(|(user_id, conns)| conns.contains_key(conn_id).then(|| user_id.clone()))
            .ok_or_else(|| "连接未认证".to_string())?;

        // 添加到连接房间映射
        conn_rooms
            .entry(conn_id.to_string())
            .or_insert_with(HashSet::new)
            .insert(room_id);

        // 添加到房间订阅者映射
        room_subs
            .entry(room_id)
            .or_insert_with(HashSet::new)
            .insert(conn_id.to_string());

        info!("连接 {} (用户 {}) 订阅房间 {}", conn_id, user_id, room_id);
        Ok(())
    }

    // 取消订阅房间
    pub async fn unsubscribe_room(&self, conn_id: &str, room_id: Uuid) -> bool {
        let mut conn_rooms = self.connection_rooms.write().await;
        let mut room_subs = self.room_subscribers.write().await;

        let mut was_subscribed = false;

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
            }
        }

        if was_subscribed {
            info!("连接 {} 取消订阅房间 {}", conn_id, room_id);
        }
        was_subscribed
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
                    if let Ok(mut conn) = redis_manager
                        .get_session_client()
                        .get_multiplexed_async_connection()
                        .await
                    {
                        let key = crate::redis::models::CacheKeys::user_online_status(&user_uuid);
                        let _: redis::RedisResult<()> = conn
                            .set_ex(key, node_id.as_str(), USER_ONLINE_TTL_SECONDS)
                            .await;
                    }

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
                        info.sender.send(OutboundFrame::Text(text))
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
                        info.sender.send(OutboundFrame::Binary(bytes))
                    }
                };

                if let Err(err) = send_result {
                    tracing::debug!(
                        "向用户 {} 的连接 {} 发送事件失败: {}",
                        user_id,
                        conn_id,
                        err
                    );
                }
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
            None => Err("missing payload".to_string()),
        }
    }
}

async fn handle_client_event(
    event: ClientEvent,
    conn_id: &str,
    client_addr: std::net::SocketAddr,
    format: ConnectionFormat,
    connection_manager: Arc<ConnectionManager>,
    out_tx: &mpsc::UnboundedSender<OutboundFrame>,
    pubsub_cmd_tx: &mpsc::UnboundedSender<PubSubCmd>,
    state: &AppState,
) -> Result<(), String> {
    match event {
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
                    if let Ok(mut conn) = state_clone
                        .redis
                        .get_session_client()
                        .get_multiplexed_async_connection()
                        .await
                    {
                        let key = crate::redis::models::CacheKeys::user_online_status(&user_uuid);
                        let _: redis::RedisResult<()> = conn
                            .set_ex(key, state_clone.node_id.as_str(), USER_ONLINE_TTL_SECONDS)
                            .await;
                    }

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
                let _ = out_tx.send(push.encode(format));

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

            connection_manager
                .subscribe_room(conn_id, room_id)
                .await
                .map_err(|err| {
                    error!("连接 {} 订阅房间 {} 失败: {}", conn_id, room_id, err);
                    err
                })?;

            let channel = format!("room:{}", room_id);
            let _ = pubsub_cmd_tx.send(PubSubCmd::Subscribe(channel));

            let push = ServerPush::Joined { room_id };
            let _ = out_tx.send(push.encode(format));
            info!("连接 {} 加入房间 {}", conn_id, room_id);

            Ok(())
        }
        ClientEvent::Leave { room_id } => {
            if connection_manager.unsubscribe_room(conn_id, room_id).await {
                let channel = format!("room:{}", room_id);
                let _ = pubsub_cmd_tx.send(PubSubCmd::Unsubscribe(channel));

                let push = ServerPush::Left { room_id };
                let _ = out_tx.send(push.encode(format));
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
            let _ = out_tx.send(ServerPush::Pong.encode(format));
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

            let mut conn = state
                .redis
                .get_pubsub_client()
                .get_multiplexed_async_connection()
                .await
                .map_err(|e| e.to_string())?;
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

    let (out_tx, mut out_rx) = mpsc::unbounded_channel::<OutboundFrame>();
    let out_tx_clone = out_tx.clone();
    let (pubsub_cmd_tx, mut pubsub_cmd_rx) = mpsc::unbounded_channel::<PubSubCmd>();

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

    let pubsub_client = state.redis.get_pubsub_client().clone();
    let conn_id_clone = conn_id.clone();
    let format_for_pubsub = format;
    let forward_task = tokio::spawn(async move {
        let mut pubsub = match pubsub_client.get_async_pubsub().await {
            Ok(ps) => ps,
            Err(e) => {
                error!("Redis PubSub 连接失败: {}", e);
                let _ = out_tx_clone.send(
                    ServerPush::Error {
                        message: "redis unavailable".to_string(),
                    }
                    .encode(format_for_pubsub),
                );
                return;
            }
        };
        let mut subscribed_channels: std::collections::HashSet<String> =
            std::collections::HashSet::new();

        async fn rebuild_pubsub(
            client: &redis::Client,
            current_channels: &std::collections::HashSet<String>,
        ) -> Option<redis::aio::PubSub> {
            match client.get_async_pubsub().await {
                Ok(mut new_pubsub) => {
                    for ch in current_channels {
                        if let Err(e) = new_pubsub.subscribe(&ch).await {
                            tracing::error!("重建后订阅频道失败 {}: {}", ch, e);
                        }
                    }
                    Some(new_pubsub)
                }
                Err(e) => {
                    tracing::error!("重建 PubSub 连接失败: {}", e);
                    None
                }
            }
        }

        loop {
            tokio::select! {
                Some(cmd) = pubsub_cmd_rx.recv() => {
                    match cmd {
                        PubSubCmd::Subscribe(channel) => {
                            match pubsub.subscribe(&channel).await {
                                Ok(_) => {
                                    subscribed_channels.insert(channel.clone());
                                    info!("连接 {} 订阅Redis频道: {}", conn_id_clone, channel);
                                }
                                Err(e) => {
                                    error!("订阅Redis频道失败 {}: {}", channel, e);
                                    let msg = e.to_string();
                                    if msg.contains("unexpected end of file") || msg.contains("Connection reset") {
                                        if let Some(new_ps) = rebuild_pubsub(&pubsub_client, &subscribed_channels).await {
                                            pubsub = new_ps;
                                            match pubsub.subscribe(&channel).await {
                                                Ok(_) => {
                                                    subscribed_channels.insert(channel.clone());
                                                    info!("连接 {} 订阅Redis频道(重试成功): {}", conn_id_clone, channel);
                                                }
                                                Err(e2) => {
                                                    error!("订阅Redis频道重试仍失败 {}: {}", channel, e2);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        PubSubCmd::Unsubscribe(channel) => {
                            match pubsub.unsubscribe(&channel).await {
                                Ok(_) => {
                                    subscribed_channels.remove(&channel);
                                    info!("连接 {} 取消订阅Redis频道: {}", conn_id_clone, channel);
                                }
                                Err(e) => {
                                    error!("取消订阅Redis频道失败 {}: {}", channel, e);
                                    let msg = e.to_string();
                                    if msg.contains("unexpected end of file") || msg.contains("Connection reset") {
                                        if let Some(new_ps) = rebuild_pubsub(&pubsub_client, &subscribed_channels).await {
                                            pubsub = new_ps;
                                            match pubsub.unsubscribe(&channel).await {
                                                Ok(_) => {
                                                    subscribed_channels.remove(&channel);
                                                    info!("连接 {} 取消订阅Redis频道(重试成功): {}", conn_id_clone, channel);
                                                }
                                                Err(e2) => {
                                                    error!("取消订阅Redis频道重试仍失败 {}: {}", channel, e2);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        PubSubCmd::Shutdown => {
                            break;
                        }
                    }
                }
                msg = async {
                    let mut on_msg = pubsub.on_message();
                    on_msg.next().await
                } => {
                    if let Some(msg) = msg {
                        let payload: Vec<u8> = match msg.get_payload() {
                            Ok(p) => p,
                            Err(err) => {
                                error!("读取Redis消息负载失败: {}", err);
                                continue;
                            }
                        };

                        let parsed = ws::PubSubEvent::decode(payload.as_ref())
                            .ok()
                            .and_then(|event| crate::redis::models::PubSubPayload::try_from(event).ok())
                            .or_else(|| {
                                match std::str::from_utf8(&payload) {
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
                                }
                            });

                        let Some(event) = parsed else {
                            continue;
                        };

                        let push = match event {
                            crate::redis::models::PubSubPayload::Message { data } => {
                                ServerPush::Message { data }
                            }
                            crate::redis::models::PubSubPayload::ReadReceipt { data } => {
                                ServerPush::MessageRead { data }
                            }
                            crate::redis::models::PubSubPayload::MessageUpdate { data } => {
                                ServerPush::MessageUpdate { data }
                            }
                            crate::redis::models::PubSubPayload::PinUpdate { data } => {
                                ServerPush::PinUpdate { data }
                            }
                            crate::redis::models::PubSubPayload::RoomUpdate { data } => {
                                ServerPush::RoomUpdated {
                                    data: RoomUpdatedPayload {
                                        room_id: data.room_id,
                                        room_name: data.room_name.clone(),
                                        room_type: data.room_type.clone(),
                                        avatar_url: data.avatar_url.clone(),
                                        avatar_object_key: data.avatar_object_key.clone(),
                                        description: data.description.clone(),
                                    },
                                }
                            }
                            crate::redis::models::PubSubPayload::GroupSettingsUpdate { data } => {
                                ServerPush::GroupSettingsUpdated {
                                    room_id: data.room_id,
                                    global_mute_enabled: data.global_mute_enabled,
                                    global_mute_reason: data.global_mute_reason.clone(),
                                    global_mute_until: data.global_mute_until.map(|ts| ts.to_rfc3339()),
                                    global_mute_set_by: data.global_mute_set_by.map(|id| id.to_string()),
                                }
                            }
                            crate::redis::models::PubSubPayload::GroupMemberChanged { data } => {
                                ServerPush::GroupMemberChanged {
                                    room_id: data.room_id,
                                    member_id: data.member_id,
                                    change_type: data.change_type.to_string(),
                                    new_role: data.new_role.clone(),
                                    operator_id: data.operator_id,
                                    reason: data.reason.clone(),
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
                        };

                        let frame = push.encode(format_for_pubsub);
                        let _ = out_tx_clone.send(frame);
                    }
                }
            }
        }
    });

    while let Some(Ok(msg)) = ws_receiver.next().await {
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
                            &pubsub_cmd_tx,
                            &state,
                        )
                        .await
                        {
                            let _ = out_tx.send(
                                ServerPush::Error {
                                    message: err.clone(),
                                }
                                .encode(format),
                            );
                            error!("处理客户端事件失败: {}", err);
                        }
                    }
                    Err(parse_err) => {
                        error!("无法解析WebSocket消息: {}，错误: {}", text, parse_err);
                        let err_text = format!("Parse error: {}", parse_err);
                        let _ = out_tx.send(
                            ServerPush::Error {
                                message: err_text.clone(),
                            }
                            .encode(format),
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
                                    &pubsub_cmd_tx,
                                    &state,
                                )
                                .await
                                {
                                    let _ = out_tx.send(
                                        ServerPush::Error {
                                            message: err.clone(),
                                        }
                                        .encode(format),
                                    );
                                    error!("处理客户端事件失败: {}", err);
                                }
                            }
                            Err(err) => {
                                error!("解析protobuf客户端事件失败: {}", err);
                                let _ = out_tx.send(
                                    ServerPush::Error {
                                        message: err.clone(),
                                    }
                                    .encode(format),
                                );
                            }
                        },
                        Err(decode_err) => {
                            error!("解码protobuf消息失败: {}", decode_err);
                            let err_text = format!("protobuf decode error: {}", decode_err);
                            let _ = out_tx.send(
                                ServerPush::Error {
                                    message: err_text.clone(),
                                }
                                .encode(format),
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
                    let _ = out_tx.send(frame);
                }
            }
            Message::Ping(_) => {
                connection_manager
                    .update_ping(&conn_id, client_addr.ip(), &state)
                    .await;
                let _ = out_tx.send(ServerPush::Pong.encode(format));
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

    let rooms = connection_manager.unregister_connection(&conn_id).await;

    if let Some(room_list) = rooms {
        for room_id in room_list {
            let channel = format!("room:{}", room_id);
            let _ = pubsub_cmd_tx.send(PubSubCmd::Unsubscribe(channel));
        }
    }

    let _ = pubsub_cmd_tx.send(PubSubCmd::Shutdown);

    info!("WebSocket连接 {} 已关闭", conn_id);

    let _ = forward_task.abort();
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

enum PubSubCmd {
    Subscribe(String),
    Unsubscribe(String),
    Shutdown,
}
