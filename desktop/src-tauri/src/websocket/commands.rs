//! Tauri WebSocket 命令接口

use std::sync::Arc;
use tauri::{AppHandle, State};
use tokio::sync::RwLock;

use super::client::WebSocketClient;
use super::types::{ConnectionStatus, WebSocketParams};
use crate::logger;

/// WebSocket 客户端管理器
pub struct WebSocketManager {
    client: Arc<RwLock<Option<WebSocketClient>>>,
}

impl WebSocketManager {
    pub fn new() -> Self {
        Self {
            client: Arc::new(RwLock::new(None)),
        }
    }
}

/// 初始化 WebSocket 连接
#[tauri::command]
pub async fn ws_connect(
    params: WebSocketParams,
    ws_url: String,
    app_handle: AppHandle,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    logger::log_message(format!(
        "ws_connect 调用: user_id={}, ws_url={}",
        params.user_id, ws_url
    ));

    let mut client_guard = manager.client.write().await;

    // 创建或获取客户端
    let client = if let Some(existing_client) = client_guard.as_mut() {
        existing_client
    } else {
        let new_client = WebSocketClient::new(ws_url, app_handle);
        *client_guard = Some(new_client);
        client_guard.as_mut().unwrap()
    };

    // 连接
    client
        .connect(params)
        .await
        .map_err(|e| format!("WebSocket 连接失败: {:?}", e))?;

    Ok(())
}

/// 断开 WebSocket 连接
#[tauri::command]
pub async fn ws_disconnect(manager: State<'_, WebSocketManager>) -> Result<(), String> {
    logger::log_message("ws_disconnect 调用");

    let mut client_guard = manager.client.write().await;

    if let Some(client) = client_guard.as_mut() {
        client.disconnect().await;
    }

    *client_guard = None;

    Ok(())
}

/// 加入房间
#[tauri::command]
pub async fn ws_join_room(
    room_id: String,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    logger::log_message(format!("ws_join_room 调用: room_id={}", room_id));

    let client_guard = manager.client.read().await;

    if let Some(client) = client_guard.as_ref() {
        client
            .join_room(room_id)
            .await
            .map_err(|e| format!("加入房间失败: {:?}", e))?;
        Ok(())
    } else {
        Err("WebSocket 未连接".to_string())
    }
}

/// 离开房间
#[tauri::command]
pub async fn ws_leave_room(
    room_id: String,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    logger::log_message(format!("ws_leave_room 调用: room_id={}", room_id));

    let client_guard = manager.client.read().await;

    if let Some(client) = client_guard.as_ref() {
        client
            .leave_room(room_id)
            .await
            .map_err(|e| format!("离开房间失败: {:?}", e))?;
        Ok(())
    } else {
        Err("WebSocket 未连接".to_string())
    }
}

/// 批量加入房间
#[tauri::command]
pub async fn ws_join_rooms(
    room_ids: Vec<String>,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    logger::log_message(format!("ws_join_rooms 调用: {} 个房间", room_ids.len()));

    let client_guard = manager.client.read().await;

    if let Some(client) = client_guard.as_ref() {
        for room_id in room_ids {
            client
                .join_room(room_id)
                .await
                .map_err(|e| format!("批量加入房间失败: {:?}", e))?;
        }
        Ok(())
    } else {
        Err("WebSocket 未连接".to_string())
    }
}

/// 获取连接状态
#[tauri::command]
pub async fn ws_get_status(manager: State<'_, WebSocketManager>) -> Result<String, String> {
    let client_guard = manager.client.read().await;

    if let Some(client) = client_guard.as_ref() {
        let status = client.get_status().await;
        Ok(status.to_string())
    } else {
        Ok(ConnectionStatus::Disconnected.to_string())
    }
}

/// 获取已订阅的房间列表
#[tauri::command]
pub async fn ws_get_subscribed_rooms(
    manager: State<'_, WebSocketManager>,
) -> Result<Vec<String>, String> {
    let client_guard = manager.client.read().await;

    if let Some(client) = client_guard.as_ref() {
        Ok(client.get_subscribed_rooms().await)
    } else {
        Ok(Vec::new())
    }
}
