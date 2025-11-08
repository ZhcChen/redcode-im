mod protocol;
pub use protocol::{RoomCreatedPayload, ServerPush};

use axum::extract::{
    ws::{Message, WebSocket, WebSocketUpgrade},
    State,
};
use axum::{http::StatusCode, response::IntoResponse};
use base64::Engine;
use futures_util::{SinkExt, StreamExt};
use prost::Message as _;
use serde::Deserialize;
use serde_json::json;
use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
};
use tokio::sync::{mpsc, RwLock};
use uuid::Uuid;

use crate::{auth, proto::ws, AppState};
use protocol::{ConnectionFormat, OutboundFrame};
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
    pub format: ConnectionFormat,
    pub sender: mpsc::UnboundedSender<OutboundFrame>,
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
    Auth { token: String },
    Join { room_id: Uuid },
    Leave { room_id: Uuid },
    Ping,
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
            None => Err("missing payload".to_string()),
        }
    }
}

async fn handle_client_event(
    event: ClientEvent,
    conn_id: &str,
    format: ConnectionFormat,
    connection_manager: Arc<ConnectionManager>,
    out_tx: &mpsc::UnboundedSender<OutboundFrame>,
    pubsub_cmd_tx: &mpsc::UnboundedSender<PubSubCmd>,
) -> Result<(), String> {
    match event {
        ClientEvent::Auth { token } => match auth::verify_token(&token) {
            Ok(claims) => {
                let user_id = claims.sub.clone();
                connection_manager
                    .register_connection(
                        conn_id.to_string(),
                        user_id.clone(),
                        format,
                        out_tx.clone(),
                    )
                    .await;

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
            connection_manager.update_ping(conn_id).await;
            let _ = out_tx.send(ServerPush::Pong.encode(format));
            Ok(())
        }
    }
}

// WebSocket处理函数
pub async fn handle_socket(state: AppState, socket: WebSocket, format: ConnectionFormat) {
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
                            format,
                            connection_manager.clone(),
                            &out_tx,
                            &pubsub_cmd_tx,
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
                                    format,
                                    connection_manager.clone(),
                                    &out_tx,
                                    &pubsub_cmd_tx,
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
                connection_manager.update_ping(&conn_id).await;
                let _ = out_tx.send(ServerPush::Pong.encode(format));
            }
            Message::Pong(_) => {
                connection_manager.update_ping(&conn_id).await;
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
                return Ok(
                    ws.on_upgrade(move |socket| handle_socket(state, socket, connection_format))
                );
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
    Ok(ws.on_upgrade(move |socket| handle_socket(state, socket, connection_format)))
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
