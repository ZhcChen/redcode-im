//! WebSocket 客户端核心实现

use futures_util::{SinkExt, StreamExt};
use std::sync::Arc;
use std::time::Duration;
use tauri::Emitter;
use tokio::sync::{mpsc, RwLock};
use tokio::time::interval;
use tokio_tungstenite::{connect_async, tungstenite::Message};

use super::types::*;

/// WebSocket 客户端状态
struct ClientState {
    /// 连接状态
    status: ConnectionStatus,
    /// 重连次数
    reconnect_attempts: u32,
    /// 认证凭证
    auth_token: Option<String>,
    /// 用户ID
    user_id: Option<String>,
    /// 订阅的房间ID列表
    subscribed_rooms: Vec<String>,
    /// 待订阅的房间ID列表
    pending_rooms: Vec<String>,
}

impl Default for ClientState {
    fn default() -> Self {
        Self {
            status: ConnectionStatus::Disconnected,
            reconnect_attempts: 0,
            auth_token: None,
            user_id: None,
            subscribed_rooms: Vec::new(),
            pending_rooms: Vec::new(),
        }
    }
}

/// WebSocket 客户端
pub struct WebSocketClient {
    /// WebSocket URL
    ws_url: String,
    /// 客户端状态
    state: Arc<RwLock<ClientState>>,
    /// Tauri 应用句柄
    app_handle: tauri::AppHandle,
    /// 消息发送通道
    tx: Option<mpsc::UnboundedSender<Vec<u8>>>,
}

const PING_INTERVAL_SECS: u64 = 30;

impl WebSocketClient {
    /// 创建新的 WebSocket 客户端
    pub fn new(ws_url: String, app_handle: tauri::AppHandle) -> Self {
        Self {
            ws_url,
            state: Arc::new(RwLock::new(ClientState::default())),
            app_handle,
            tx: None,
        }
    }

    /// 连接到 WebSocket 服务器
    pub async fn connect(&mut self, params: WebSocketParams) -> Result<()> {
        // 检查是否已连接
        {
            let state = self.state.read().await;
            if state.status == ConnectionStatus::Authenticated
                && state.auth_token.as_ref() == Some(&params.token)
                && state.user_id.as_ref() == Some(&params.user_id)
            {
                return Ok(());
            }
        }

        // 保存认证信息
        {
            let mut state = self.state.write().await;
            state.auth_token = Some(params.token.clone());
            state.user_id = Some(params.user_id.clone());
            state.status = ConnectionStatus::Connecting;
        }

        // 开始连接
        self.start_connection().await
    }

    /// 启动连接
    async fn start_connection(&mut self) -> Result<()> {
        let url = format!("{}?format=proto", self.ws_url);

        println!("正在连接 WebSocket: {}", url);

        // 连接 WebSocket
        let (ws_stream, _) = connect_async(&url)
            .await
            .map_err(|e| WebSocketError::ConnectionError(e.to_string()))?;

        let (mut write, mut read) = ws_stream.split();

        // 创建消息发送通道
        let (tx, mut rx) = mpsc::unbounded_channel::<Vec<u8>>();
        self.tx = Some(tx);

        // 发送认证消息
        let state = self.state.read().await;
        if let Some(token) = &state.auth_token {
            let auth_data = ClientEventEncoder::encode_auth(token.clone())?;
            write
                .send(Message::Binary(auth_data))
                .await
                .map_err(|e| WebSocketError::SendError(e.to_string()))?;
        }
        drop(state);

        // 克隆引用用于任务
        let state_clone = Arc::clone(&self.state);
        let app_handle_clone = self.app_handle.clone();

        // 启动消息接收任务
        let state_for_read = Arc::clone(&self.state);
        let app_for_read = self.app_handle.clone();
        tokio::spawn(async move {
            while let Some(msg) = read.next().await {
                match msg {
                    Ok(Message::Binary(data)) => {
                        if let Err(e) =
                            Self::handle_binary_message(data, &state_for_read, &app_for_read).await
                        {
                            eprintln!("处理二进制消息失败: {:?}", e);
                        }
                    }
                    Ok(Message::Close(_)) => {
                        println!("WebSocket 连接关闭");
                        break;
                    }
                    Err(e) => {
                        eprintln!("WebSocket 读取错误: {:?}", e);
                        break;
                    }
                    _ => {}
                }
            }
        });

        // 启动消息发送任务
        tokio::spawn(async move {
            while let Some(data) = rx.recv().await {
                if let Err(e) = write.send(Message::Binary(data)).await {
                    eprintln!("WebSocket 发送错误: {:?}", e);
                    break;
                }
            }
        });

        // 启动心跳任务
        let tx_clone = self.tx.clone();
        tokio::spawn(async move {
            let mut timer = interval(Duration::from_secs(PING_INTERVAL_SECS));
            loop {
                timer.tick().await;
                if let Some(tx) = &tx_clone {
                    if let Ok(ping_data) = ClientEventEncoder::encode_ping() {
                        if tx.send(ping_data).is_err() {
                            break;
                        }
                    }
                }
            }
        });

        // 更新状态
        {
            let mut state = state_clone.write().await;
            state.reconnect_attempts = 0;
        }

        // 发送网络状态事件
        let _ = app_handle_clone.emit("network-state", true);

        Ok(())
    }

    /// 处理二进制消息
    async fn handle_binary_message(
        data: Vec<u8>,
        state: &Arc<RwLock<ClientState>>,
        app_handle: &tauri::AppHandle,
    ) -> Result<()> {
        let event = ServerEventDecoder::decode(&data)?;

        if let Some(payload) = TauriEventPayload::from_server_event(event) {
            match &payload {
                TauriEventPayload::Authed { user_id, conn_id } => {
                    println!("认证成功: user_id={}, conn_id={}", user_id, conn_id);
                    let mut state_guard = state.write().await;
                    state_guard.status = ConnectionStatus::Authenticated;

                    drop(state_guard);
                }
                TauriEventPayload::Joined { room_id } => {
                    println!("已加入房间: {}", room_id);
                    let mut state_guard = state.write().await;
                    state_guard.subscribed_rooms.push(room_id.clone());
                    state_guard.pending_rooms.retain(|r| r != room_id);
                }
                TauriEventPayload::Left { room_id } => {
                    println!("已离开房间: {}", room_id);
                    let mut state_guard = state.write().await;
                    state_guard.subscribed_rooms.retain(|r| r != room_id);
                }
                _ => {}
            }

            // 发送事件到前端
            let _ = app_handle.emit("websocket-event", &payload);
        }

        Ok(())
    }

    /// 加入房间
    pub async fn join_room(&self, room_id: String) -> Result<()> {
        let mut state = self.state.write().await;

        // 检查是否已订阅
        if state.subscribed_rooms.contains(&room_id) {
            return Ok(());
        }

        // 添加到待订阅列表
        if !state.pending_rooms.contains(&room_id) {
            state.pending_rooms.push(room_id.clone());
        }

        // 如果已认证，立即发送加入消息
        if state.status == ConnectionStatus::Authenticated {
            if let Some(tx) = &self.tx {
                let join_data = ClientEventEncoder::encode_join(room_id)?;
                tx.send(join_data)
                    .map_err(|e| WebSocketError::SendError(e.to_string()))?;
            }
        }

        Ok(())
    }

    /// 离开房间
    pub async fn leave_room(&self, room_id: String) -> Result<()> {
        let mut state = self.state.write().await;

        // 从列表中移除
        state.subscribed_rooms.retain(|r| r != &room_id);
        state.pending_rooms.retain(|r| r != &room_id);

        // 发送离开消息
        if state.status == ConnectionStatus::Authenticated {
            if let Some(tx) = &self.tx {
                let leave_data = ClientEventEncoder::encode_leave(room_id)?;
                tx.send(leave_data)
                    .map_err(|e| WebSocketError::SendError(e.to_string()))?;
            }
        }

        Ok(())
    }

    /// 断开连接
    pub async fn disconnect(&mut self) {
        let mut state = self.state.write().await;
        state.status = ConnectionStatus::Disconnected;
        state.subscribed_rooms.clear();
        state.pending_rooms.clear();
        self.tx = None;

        // 发送网络状态事件
        let _ = self.app_handle.emit("network-state", false);
    }

    /// 获取连接状态
    pub async fn get_status(&self) -> ConnectionStatus {
        self.state.read().await.status
    }

    /// 获取订阅的房间列表
    pub async fn get_subscribed_rooms(&self) -> Vec<String> {
        self.state.read().await.subscribed_rooms.clone()
    }
}
