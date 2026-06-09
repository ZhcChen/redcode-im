use super::{AccountInput, AccountManager, AccountOutput};
use crate::http::client::HttpClientState;
use crate::http::commands::http_request;
use redcode_im_api::database::account_store::AccountSettings;
use serde::Serialize;
use tauri::State;

/// 账号数据加载结果
#[derive(Debug, Serialize)]
pub struct AccountLoadResult {
    pub chats: serde_json::Value,
    pub friend_requests: serde_json::Value,
}

/// 初始化账号管理器
#[tauri::command]
pub async fn account_init(
    manager: State<'_, AccountManager>,
    app: tauri::AppHandle,
) -> Result<(), String> {
    manager.init(&app).await
}

/// 添加账号
#[tauri::command]
pub async fn account_add(
    manager: State<'_, AccountManager>,
    account: AccountInput,
) -> Result<(), String> {
    manager.add_account(account).await
}

/// 获取所有账号
#[tauri::command]
pub async fn account_get_all(
    manager: State<'_, AccountManager>,
) -> Result<Vec<AccountOutput>, String> {
    manager.get_all_accounts().await
}

/// 获取当前账号
#[tauri::command]
pub async fn account_get_current(
    manager: State<'_, AccountManager>,
) -> Result<Option<AccountOutput>, String> {
    manager.get_current_account().await
}

/// 设置当前账号
#[tauri::command]
pub async fn account_set_current(
    manager: State<'_, AccountManager>,
    account_id: String,
) -> Result<(), String> {
    manager.set_current_account(account_id).await
}

/// 移除账号
#[tauri::command]
pub async fn account_remove(
    manager: State<'_, AccountManager>,
    account_id: String,
) -> Result<(), String> {
    manager.remove_account(account_id).await
}

/// 更新账号未读数
#[tauri::command]
pub async fn account_update_unread(
    manager: State<'_, AccountManager>,
    account_id: String,
    count: i32,
) -> Result<(), String> {
    manager.update_unread_count(account_id, count).await
}

/// 获取账号设置
#[tauri::command]
pub async fn account_get_settings(
    manager: State<'_, AccountManager>,
    account_id: String,
) -> Result<Option<AccountSettings>, String> {
    manager.get_account_settings(account_id).await
}

/// 更新账号顺序
#[tauri::command]
pub async fn account_update_order(
    manager: State<'_, AccountManager>,
    account_orders: Vec<(String, i64)>,
) -> Result<(), String> {
    manager.update_account_order(account_orders).await
}

/// 加载账号数据（并行加载聊天和好友请求）
#[tauri::command]
pub async fn account_load_data(
    http_state: State<'_, HttpClientState>,
    token: String,
) -> Result<AccountLoadResult, String> {
    // 并行加载聊天列表和好友请求
    let (chats_result, friend_requests_result) = tokio::join!(
        http_load_chats(&http_state, &token),
        http_load_friend_requests(&http_state, &token)
    );

    Ok(AccountLoadResult {
        chats: chats_result?,
        friend_requests: friend_requests_result?,
    })
}

/// 通过 HTTP 加载聊天列表
async fn http_load_chats(
    http_state: &State<'_, HttpClientState>,
    token: &str,
) -> Result<serde_json::Value, String> {
    let headers = Some(std::collections::HashMap::from([
        ("Authorization".to_string(), format!("Bearer {}", token)),
        ("Accept".to_string(), "application/json".to_string()),
    ]));

    let result = http_request(
        http_state.clone(),
        "GET".to_string(),
        "/chats".to_string(),
        None,
        None,
        headers,
        None,
        Some(15000),
        Some(3),
        Some(false),
        Some(false),
        Some(false),
    )
    .await
    .map_err(|e| format!("加载聊天列表失败: {}", e))?;

    serde_json::from_str(&result).map_err(|e| format!("解析聊天列表失败: {}", e))
}

/// 通过 HTTP 加载好友请求
async fn http_load_friend_requests(
    http_state: &State<'_, HttpClientState>,
    token: &str,
) -> Result<serde_json::Value, String> {
    let headers = Some(std::collections::HashMap::from([
        ("Authorization".to_string(), format!("Bearer {}", token)),
        ("Accept".to_string(), "application/json".to_string()),
    ]));

    let result = http_request(
        http_state.clone(),
        "GET".to_string(),
        "/friends/requests?direction=incoming&status=pending".to_string(),
        None,
        None,
        headers,
        None,
        Some(15000),
        Some(3),
        Some(false),
        Some(false),
        Some(false),
    )
    .await
    .map_err(|e| format!("加载好友请求失败: {}", e))?;

    serde_json::from_str(&result).map_err(|e| format!("解析好友请求失败: {}", e))
}
