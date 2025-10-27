use axum::extract::{
    ws::{Message, WebSocket, WebSocketUpgrade},
    State,
};
use axum::{http::StatusCode, response::IntoResponse};
use base64::Engine;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
};
use tokio::sync::{mpsc, RwLock};
use uuid::Uuid;

use crate::{auth, AppState};
use tracing::{error, info};

// WebSocket连接管理器
pub struct ConnectionManager {
    // 用户ID -> 连接集合映射
    user_connections: Arc<RwLock<HashMap<String, HashMap<String, ConnectionInfo>>>>,
    // 连接ID -> 订阅房间映射
    connection_rooms: Arc<RwLock<HashMap<String, HashSet<Uuid>>>>,
    // 房间ID -> 订阅用户集合
    room_subscribers: Arc<RwLock<HashMap<Uuid, HashSet<String>>>>,
}

// 连接信息
#[derive(Debug, Clone)]
pub struct ConnectionInfo {
    pub user_id: String,
    pub connected_at: chrono::DateTime<chrono::Utc>,
    pub last_ping: chrono::DateTime<chrono::Utc>,
    pub sender: mpsc::UnboundedSender<String>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        Self {
            user_connections: Arc::new(RwLock::new(HashMap::new())),
            connection_rooms: Arc::new(RwLock::new(HashMap::new())),
            room_subscribers: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    // 注册连接
    pub async fn register_connection(
        &self,
        conn_id: String,
        user_id: String,
        sender: mpsc::UnboundedSender<String>,
    ) {
        let mut user_conns = self.user_connections.write().await;
        let conn_info = ConnectionInfo {
            user_id: user_id.clone(),
            connected_at: chrono::Utc::now(),
            last_ping: chrono::Utc::now(),
            sender,
        };

        user_conns
            .entry(user_id.clone())
            .or_insert_with(HashMap::new)
            .insert(conn_id.clone(), conn_info);

        info!("用户 {} 的连接 {} 已注册", user_id, conn_id);
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

    // 心跳更新
    pub async fn update_ping(&self, conn_id: &str) -> bool {
        let mut user_conns = self.user_connections.write().await;
        for connections in user_conns.values_mut() {
            if let Some(conn_info) = connections.get_mut(conn_id) {
                conn_info.last_ping = chrono::Utc::now();
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

    // 获取房间订阅者数
    pub async fn get_room_subscriber_count(&self, room_id: Uuid) -> usize {
        let room_subs = self.room_subscribers.read().await;
        room_subs.get(&room_id).map(|subs| subs.len()).unwrap_or(0)
    }

    pub async fn send_to_user(&self, user_id: &str, payload: Value) {
        let message = payload.to_string();

        let user_conns = self.user_connections.read().await;
        if let Some(conns) = user_conns.get(user_id) {
            for (conn_id, info) in conns {
                if let Err(err) = info.sender.send(message.clone()) {
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
    Auth { token: String },
    Join { room_id: Uuid },
    Leave { room_id: Uuid },
    Ping,
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum ServerEvent<'a> {
    Authed {
        user_id: &'a str,
    },
    Joined {
        room_id: Uuid,
    },
    Left {
        room_id: Uuid,
    },
    Message {
        room_id: Uuid,
        payload: serde_json::Value,
    },
    Error {
        message: &'a str,
    },
    Pong,
}

// WebSocket处理函数
pub async fn handle_socket(state: AppState, socket: WebSocket) {
    let (mut ws_sender, mut ws_receiver) = socket.split();
    let conn_id = format!("conn_{}", uuid::Uuid::new_v4());

    // 使用全局ConnectionManager
    let connection_manager = state.connection_manager.clone();

    // Outgoing WS messages channel
    let (out_tx, mut out_rx) = mpsc::unbounded_channel::<String>();
    let out_tx_clone = out_tx.clone();

    // PubSub订阅管理channel
    let (pubsub_cmd_tx, mut pubsub_cmd_rx) = mpsc::unbounded_channel::<PubSubCmd>();

    // 发送任务
    let send_task = tokio::spawn(async move {
        while let Some(payload) = out_rx.recv().await {
            let _ = ws_sender.send(Message::Text(payload)).await;
        }
    });

    // PubSub管理任务
    let pubsub_client = state.redis.get_pubsub_client().clone();
    let conn_id_clone = conn_id.clone();
    let forward_task = tokio::spawn(async move {
        let conn = match pubsub_client.get_async_connection().await {
            Ok(c) => c,
            Err(_) => {
                let _ = out_tx_clone
                    .send(json!({"type":"error","message":"redis unavailable"}).to_string());
                return;
            }
        };
        let mut pubsub = conn.into_pubsub();

        // 当前连接下已订阅的频道（用于断线重建）
        let mut subscribed_channels: std::collections::HashSet<String> =
            std::collections::HashSet::new();

        // 便捷函数：在 EOF 等连接错误后重建 PubSub，并恢复订阅
        async fn rebuild_pubsub(
            client: &redis::Client,
            current_channels: &std::collections::HashSet<String>,
        ) -> Option<redis::aio::PubSub> {
            match client.get_async_connection().await {
                Ok(conn) => {
                    let mut new_pubsub = conn.into_pubsub();
                    // 尝试恢复已订阅频道
                    for ch in current_channels {
                        if let Err(e) = new_pubsub.subscribe(&ch).await {
                            tracing::error!("重建后订阅频道失败 {}: {}", ch, e);
                            // 若恢复任一频道失败，继续尝试其他频道，尽量恢复大部分
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
                // 处理订阅命令
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
                                    // 针对连接断开类错误进行重建并重试一次
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

                // 处理订阅消息
                msg = async {
                    let mut on_msg = pubsub.on_message();
                    on_msg.next().await
                } => {
                    if let Some(msg) = msg {
                        let payload: String = match msg.get_payload() {
                            Ok(p) => p,
                            Err(_) => continue
                        };

                        // 解析Redis Pub/Sub消息并转发给WebSocket
                        if let Ok(event) = serde_json::from_str::<crate::redis::models::PubSubPayload>(&payload) {
                            match event {
                                crate::redis::models::PubSubPayload::Message { data: redis_msg } => {
                                    let response = json!({
                                        "type": "message",
                                        "id": redis_msg.id,
                                        "message_id": redis_msg.id,
                                        "room_id": redis_msg.room_id,
                                        "sender_id": redis_msg.sender_id,
                                        "sender_username": redis_msg.sender_username,
                                        "sender_nickname": redis_msg.sender_nickname,
                                        "sender_avatar_url": redis_msg.sender_avatar_url,
                                        "content": redis_msg.content,
                                        "message_type": redis_msg.message_type,
                                        "quoted_message": redis_msg.quoted_message,
                                        "timestamp": redis_msg.timestamp
                                    });
                                    let _ = out_tx_clone.send(response.to_string());
                                }
                                crate::redis::models::PubSubPayload::ReadReceipt { data } => {
                                    let response = json!({
                                        "type": "message_read",
                                        "room_id": data.room_id,
                                        "message_id": data.message_id,
                                        "reader_id": data.reader_id,
                                        "read_at": data.read_at
                                    });
                                    let _ = out_tx_clone.send(response.to_string());
                                }
                            }
                        }
                    }
                }
            }
        }
    });

    // 处理WebSocket消息
    while let Some(Ok(msg)) = ws_receiver.next().await {
        match msg {
            Message::Text(text) => {
                info!("WebSocket收到消息: {}", text);
                if let Ok(parsed) = serde_json::from_str::<ClientEvent>(&text) {
                    match parsed {
                        ClientEvent::Auth { token } => {
                            match auth::verify_token(&token) {
                                Ok(claims) => {
                                    // 注册连接
                                    connection_manager
                                        .register_connection(
                                            conn_id.clone(),
                                            claims.sub.clone(),
                                            out_tx.clone(),
                                        )
                                        .await;

                                    let response = json!({
                                        "type": "authed",
                                        "user_id": claims.sub,
                                        "conn_id": conn_id
                                    });
                                    let _ = out_tx.send(response.to_string());

                                    info!(
                                        "WebSocket连接 {} 认证成功，用户: {}",
                                        conn_id, claims.sub
                                    );
                                }
                                Err(e) => {
                                    error!("WebSocket认证失败: {}", e);
                                    let response = json!({
                                        "type": "error",
                                        "message": "unauthorized"
                                    });
                                    let _ = out_tx.send(response.to_string());
                                }
                            }
                        }
                        ClientEvent::Join { room_id } => {
                            match connection_manager.subscribe_room(&conn_id, room_id).await {
                                Ok(()) => {
                                    // 订阅Redis Pub/Sub频道
                                    let channel = format!("room:{}", room_id);
                                    let _ = pubsub_cmd_tx.send(PubSubCmd::Subscribe(channel));

                                    let response = json!({
                                        "type": "joined",
                                        "room_id": room_id
                                    });
                                    let _ = out_tx.send(response.to_string());
                                    info!("连接 {} 加入房间 {}", conn_id, room_id);
                                }
                                Err(err) => {
                                    let response = json!({
                                        "type": "error",
                                        "message": err
                                    });
                                    let _ = out_tx.send(response.to_string());
                                }
                            }
                        }
                        ClientEvent::Leave { room_id } => {
                            if connection_manager.unsubscribe_room(&conn_id, room_id).await {
                                // 取消订阅Redis Pub/Sub频道
                                let channel = format!("room:{}", room_id);
                                let _ = pubsub_cmd_tx.send(PubSubCmd::Unsubscribe(channel));

                                let response = json!({
                                    "type": "left",
                                    "room_id": room_id
                                });
                                let _ = out_tx.send(response.to_string());
                                info!("连接 {} 离开房间 {}", conn_id, room_id);
                            }
                        }
                        ClientEvent::Ping => {
                            connection_manager.update_ping(&conn_id).await;
                            let response = json!({ "type": "pong" });
                            let _ = out_tx.send(response.to_string());
                        }
                    }
                } else {
                    // 无效的消息格式，记录错误和详细信息
                    let parse_error = serde_json::from_str::<ClientEvent>(&text).unwrap_err();
                    error!("无法解析WebSocket消息: {}，错误: {}", text, parse_error);
                    let response = json!({
                        "type": "error",
                        "message": format!("Parse error: {}", parse_error)
                    });
                    let _ = out_tx.send(response.to_string());
                }
            }
            Message::Binary(data) => {
                let response = json!({
                    "type": "binary",
                    "data": base64::engine::general_purpose::STANDARD.encode(&data)
                });
                let _ = out_tx.send(response.to_string());
            }
            Message::Ping(_) => {
                let response = json!({ "type": "pong" });
                let _ = out_tx.send(response.to_string());
            }
            Message::Pong(_) => {
                connection_manager.update_ping(&conn_id).await;
            }
            Message::Close(_) => {
                break;
            }
        }
    }

    // 清理连接
    let rooms = connection_manager.unregister_connection(&conn_id).await;

    // 取消订阅所有房间的Redis频道
    if let Some(room_list) = rooms {
        for room_id in room_list {
            let channel = format!("room:{}", room_id);
            let _ = pubsub_cmd_tx.send(PubSubCmd::Unsubscribe(channel));
        }
    }

    // 关闭PubSub任务
    let _ = pubsub_cmd_tx.send(PubSubCmd::Shutdown);

    info!("WebSocket连接 {} 已关闭", conn_id);

    // 关闭任务
    let _ = forward_task.abort();
    let _ = send_task.abort();
}

// WebSocket握手处理 - 增加认证检查
pub async fn handle_websocket_upgrade(
    State(state): State<AppState>,
    ws: WebSocketUpgrade,
    // 可选的查询参数中的token
    axum::extract::Query(params): axum::extract::Query<WsUpgradeParams>,
) -> Result<impl IntoResponse, StatusCode> {
    // 检查是否有token（可选的连接前认证）
    if let Some(ref token) = params.token {
        match auth::verify_token(token) {
            Ok(claims) => {
                info!("WebSocket握手认证成功，用户: {}", claims.sub);
                return Ok(ws.on_upgrade(move |socket| handle_socket(state, socket)));
            }
            Err(e) => {
                error!("WebSocket握手认证失败: {}", e);
                return Err(StatusCode::UNAUTHORIZED);
            }
        }
    }

    // 无token也允许连接，但需要在连接后通过Auth事件认证
    info!("WebSocket握手完成，等待客户端认证");
    Ok(ws.on_upgrade(move |socket| handle_socket(state, socket)))
}

#[derive(serde::Deserialize)]
pub struct WsUpgradeParams {
    pub token: Option<String>,
}

enum PubSubCmd {
    Subscribe(String),
    Unsubscribe(String),
    Shutdown,
}
