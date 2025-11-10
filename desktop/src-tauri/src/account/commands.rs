use super::{AccountInput, AccountManager, AccountOutput};
use redcode_im_backend::database::account_store::AccountSettings;
use tauri::State;

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
