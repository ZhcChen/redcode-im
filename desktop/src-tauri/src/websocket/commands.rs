//! Tauri WebSocket 命令接口（多账号版本）

use std::collections::HashMap;
use std::sync::Arc;
use tauri::{AppHandle, State};
use tokio::sync::RwLock;

use super::client::WebSocketClient;
use super::types::{ConnectionStatus, WebSocketParams};
use crate::logger;

/// WebSocket 客户端管理器（支持多账号）
pub struct WebSocketManager {
    /// 多个 WebSocket 客户端，按 user_id 索引
    clients: Arc<RwLock<HashMap<String, WebSocketClient>>>,
    /// 当前活跃账号的 user_id
    current_user_id: Arc<RwLock<Option<String>>>,
}

impl WebSocketManager {
    pub fn new() -> Self {
        Self {
            clients: Arc::new(RwLock::new(HashMap::new())),
            current_user_id: Arc::new(RwLock::new(None)),
        }
    }
}

/// 初始化 WebSocket 连接（为指定账号建立连接）
#[tauri::command]
pub async fn ws_connect(
    params: WebSocketParams,
    ws_url: String,
    app_handle: AppHandle,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    let user_id = params.user_id.clone();
    logger::log_message(format!(
        "[多账号WS] ws_connect 调用: user_id={}, ws_url={}",
        user_id, ws_url
    ));

    let mut clients = manager.clients.write().await;

    // 检查该账号是否已有连接
    if let Some(existing_client) = clients.get(&user_id) {
        let status = existing_client.get_status().await;
        if status == ConnectionStatus::Authenticated {
            logger::log_message(format!("[多账号WS] 账号 {} 已连接，跳过", user_id));
            // 更新当前活跃账号
            *manager.current_user_id.write().await = Some(user_id);
            return Ok(());
        }
        // 如果已存在但未认证，移除旧连接
        clients.remove(&user_id);
    }

    // 创建新客户端
    let mut client = WebSocketClient::new(ws_url, user_id.clone(), app_handle);

    // 连接
    client
        .connect(params)
        .await
        .map_err(|e| format!("WebSocket 连接失败: {:?}", e))?;

    // 保存客户端
    clients.insert(user_id.clone(), client);

    // 更新当前活跃账号
    *manager.current_user_id.write().await = Some(user_id.clone());

    logger::log_message(format!(
        "[多账号WS] 账号 {} 连接成功，当前连接数: {}",
        user_id,
        clients.len()
    ));

    Ok(())
}

/// 断开指定账号的 WebSocket 连接
#[tauri::command]
pub async fn ws_disconnect(
    user_id: Option<String>,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    logger::log_message(format!(
        "[多账号WS] ws_disconnect 调用: user_id={:?}",
        user_id
    ));

    let mut clients = manager.clients.write().await;

    if let Some(uid) = user_id {
        // 断开指定账号
        if let Some(mut client) = clients.remove(&uid) {
            client.disconnect().await;
            logger::log_message(format!(
                "[多账号WS] 账号 {} 已断开，剩余连接数: {}",
                uid,
                clients.len()
            ));
        }
    } else {
        // 断开当前活跃账号
        let current = manager.current_user_id.read().await.clone();
        if let Some(uid) = current {
            if let Some(mut client) = clients.remove(&uid) {
                client.disconnect().await;
                logger::log_message(format!(
                    "[多账号WS] 当前账号 {} 已断开，剩余连接数: {}",
                    uid,
                    clients.len()
                ));
            }
        }
    }

    Ok(())
}

/// 断开所有 WebSocket 连接
#[tauri::command]
pub async fn ws_disconnect_all(manager: State<'_, WebSocketManager>) -> Result<(), String> {
    logger::log_message("[多账号WS] ws_disconnect_all 调用");

    let mut clients = manager.clients.write().await;

    for (uid, mut client) in clients.drain() {
        client.disconnect().await;
        logger::log_message(format!("[多账号WS] 账号 {} 已断开", uid));
    }

    *manager.current_user_id.write().await = None;

    Ok(())
}

/// 设置当前活跃账号
#[tauri::command]
pub async fn ws_set_current_user(
    user_id: String,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    logger::log_message(format!(
        "[多账号WS] ws_set_current_user 调用: user_id={}",
        user_id
    ));

    *manager.current_user_id.write().await = Some(user_id);

    Ok(())
}

/// 加入房间（为指定账号或当前账号）
#[tauri::command]
pub async fn ws_join_room(
    room_id: String,
    user_id: Option<String>,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    let target_user_id = if let Some(uid) = user_id {
        uid
    } else {
        manager
            .current_user_id
            .read()
            .await
            .clone()
            .ok_or_else(|| "未设置当前账号".to_string())?
    };

    logger::log_message(format!(
        "[多账号WS] ws_join_room 调用: user_id={}, room_id={}",
        target_user_id, room_id
    ));

    let clients = manager.clients.read().await;

    if let Some(client) = clients.get(&target_user_id) {
        client
            .join_room(room_id)
            .await
            .map_err(|e| format!("加入房间失败: {:?}", e))?;
        Ok(())
    } else {
        Err(format!("账号 {} 的 WebSocket 未连接", target_user_id))
    }
}

/// 离开房间（为指定账号或当前账号）
#[tauri::command]
pub async fn ws_leave_room(
    room_id: String,
    user_id: Option<String>,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    let target_user_id = if let Some(uid) = user_id {
        uid
    } else {
        manager
            .current_user_id
            .read()
            .await
            .clone()
            .ok_or_else(|| "未设置当前账号".to_string())?
    };

    logger::log_message(format!(
        "[多账号WS] ws_leave_room 调用: user_id={}, room_id={}",
        target_user_id, room_id
    ));

    let clients = manager.clients.read().await;

    if let Some(client) = clients.get(&target_user_id) {
        client
            .leave_room(room_id)
            .await
            .map_err(|e| format!("离开房间失败: {:?}", e))?;
        Ok(())
    } else {
        Err(format!("账号 {} 的 WebSocket 未连接", target_user_id))
    }
}

/// 设置正在输入状态（为指定账号或当前账号）
#[tauri::command]
pub async fn ws_typing(
    room_id: String,
    is_typing: bool,
    user_id: Option<String>,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    let target_user_id = if let Some(uid) = user_id {
        uid
    } else {
        manager
            .current_user_id
            .read()
            .await
            .clone()
            .ok_or_else(|| "未设置当前账号".to_string())?
    };

    let clients = manager.clients.read().await;
    if let Some(client) = clients.get(&target_user_id) {
        client
            .typing(room_id, is_typing)
            .await
            .map_err(|e| format!("发送 typing 事件失败: {:?}", e))?;
        Ok(())
    } else {
        Err(format!("账号 {} 的 WebSocket 未连接", target_user_id))
    }
}

/// 批量加入房间（为指定账号或当前账号）
#[tauri::command]
pub async fn ws_join_rooms(
    room_ids: Vec<String>,
    user_id: Option<String>,
    manager: State<'_, WebSocketManager>,
) -> Result<(), String> {
    let target_user_id = if let Some(uid) = user_id {
        uid
    } else {
        manager
            .current_user_id
            .read()
            .await
            .clone()
            .ok_or_else(|| "未设置当前账号".to_string())?
    };

    logger::log_message(format!(
        "[多账号WS] ws_join_rooms 调用: user_id={}, {} 个房间",
        target_user_id,
        room_ids.len()
    ));

    let clients = manager.clients.read().await;

    if let Some(client) = clients.get(&target_user_id) {
        for room_id in room_ids {
            client
                .join_room(room_id)
                .await
                .map_err(|e| format!("批量加入房间失败: {:?}", e))?;
        }
        Ok(())
    } else {
        Err(format!("账号 {} 的 WebSocket 未连接", target_user_id))
    }
}

/// 获取指定账号或当前账号的连接状态
#[tauri::command]
pub async fn ws_get_status(
    user_id: Option<String>,
    manager: State<'_, WebSocketManager>,
) -> Result<String, String> {
    let target_user_id = if let Some(uid) = user_id {
        Some(uid)
    } else {
        manager.current_user_id.read().await.clone()
    };

    let clients = manager.clients.read().await;

    if let Some(uid) = target_user_id {
        if let Some(client) = clients.get(&uid) {
            let status = client.get_status().await;
            Ok(status.to_string())
        } else {
            Ok(ConnectionStatus::Disconnected.to_string())
        }
    } else {
        Ok(ConnectionStatus::Disconnected.to_string())
    }
}

/// 获取所有账号的连接状态
#[tauri::command]
pub async fn ws_get_all_status(
    manager: State<'_, WebSocketManager>,
) -> Result<HashMap<String, String>, String> {
    let clients = manager.clients.read().await;
    let mut result = HashMap::new();

    for (user_id, client) in clients.iter() {
        let status = client.get_status().await;
        result.insert(user_id.clone(), status.to_string());
    }

    Ok(result)
}

/// 获取指定账号或当前账号的已订阅房间列表
#[tauri::command]
pub async fn ws_get_subscribed_rooms(
    user_id: Option<String>,
    manager: State<'_, WebSocketManager>,
) -> Result<Vec<String>, String> {
    let target_user_id = if let Some(uid) = user_id {
        Some(uid)
    } else {
        manager.current_user_id.read().await.clone()
    };

    let clients = manager.clients.read().await;

    if let Some(uid) = target_user_id {
        if let Some(client) = clients.get(&uid) {
            Ok(client.get_subscribed_rooms().await)
        } else {
            Ok(Vec::new())
        }
    } else {
        Ok(Vec::new())
    }
}

/// 获取当前连接的账号数量
#[tauri::command]
pub async fn ws_get_connected_count(manager: State<'_, WebSocketManager>) -> Result<usize, String> {
    let clients = manager.clients.read().await;
    Ok(clients.len())
}

/// 获取当前活跃账号 ID
#[tauri::command]
pub async fn ws_get_current_user(
    manager: State<'_, WebSocketManager>,
) -> Result<Option<String>, String> {
    Ok(manager.current_user_id.read().await.clone())
}
