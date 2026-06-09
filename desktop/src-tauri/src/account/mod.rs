use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::{AppHandle, Manager};
use tokio::sync::Mutex;

/// 导入 backend 的模块
use redcode_im_api::crypto::TokenCrypto;
use redcode_im_api::database::account_store::{Account, AccountSettings, AccountStore};

/// 账号管理器状态
pub struct AccountManager {
    store: Arc<Mutex<Option<AccountStore>>>,
    crypto: Arc<Mutex<Option<TokenCrypto>>>,
}

impl AccountManager {
    pub fn new() -> Self {
        Self {
            store: Arc::new(Mutex::new(None)),
            crypto: Arc::new(Mutex::new(None)),
        }
    }

    /// 初始化账号存储
    pub async fn init(&self, app_handle: &AppHandle) -> Result<(), String> {
        let app_data_dir = app_handle
            .path()
            .app_data_dir()
            .map_err(|e| format!("获取应用数据目录失败: {}", e))?;

        let store = AccountStore::new(&app_data_dir)
            .await
            .map_err(|e| format!("初始化账号数据库失败: {}", e))?;

        let crypto =
            TokenCrypto::new(&app_data_dir).map_err(|e| format!("初始化加密器失败: {}", e))?;

        *self.store.lock().await = Some(store);
        *self.crypto.lock().await = Some(crypto);

        Ok(())
    }

    /// 检查是否已初始化
    async fn is_initialized(&self) -> bool {
        self.store.lock().await.is_some() && self.crypto.lock().await.is_some()
    }

    /// 添加账号（加密 token）
    pub async fn add_account(&self, account: AccountInput) -> Result<(), String> {
        if !self.is_initialized().await {
            return Err("账号管理器未初始化".to_string());
        }

        let store_guard = self.store.lock().await;
        let store = store_guard.as_ref().unwrap();

        let crypto_guard = self.crypto.lock().await;
        let crypto = crypto_guard.as_ref().unwrap();

        // 加密 token
        let encrypted_token = crypto
            .encrypt(&account.token)
            .map_err(|e| format!("加密 token 失败: {}", e))?;

        // 转换为 base64 便于存储
        let encrypted_token_base64 =
            base64::Engine::encode(&base64::engine::general_purpose::STANDARD, &encrypted_token);

        // 加密 refresh_token（可选）
        let encrypted_refresh_token_base64 = match account
            .refresh_token
            .as_deref()
            .map(str::trim)
            .filter(|token| !token.is_empty())
        {
            Some(refresh_token) => {
                let encrypted_refresh_token = crypto
                    .encrypt(refresh_token)
                    .map_err(|e| format!("加密 refresh_token 失败: {}", e))?;
                Some(base64::Engine::encode(
                    &base64::engine::general_purpose::STANDARD,
                    &encrypted_refresh_token,
                ))
            }
            None => None,
        };

        let now = chrono::Utc::now().timestamp();
        let db_account = Account {
            id: account.id,
            username: account.username,
            nickname: account.nickname,
            avatar: account.avatar,
            avatar_object_key: account.avatar_object_key,
            avatar_local_path: account.avatar_local_path,
            mobile: account.mobile,
            email: account.email,
            token: encrypted_token_base64,
            refresh_token: encrypted_refresh_token_base64,
            created_at: now,
            updated_at: now,
            sort_order: None, // 不设置 sort_order,由数据库层自动处理
        };

        store
            .add_account(&db_account)
            .await
            .map_err(|e| format!("添加账号失败: {}", e))?;

        Ok(())
    }

    /// 获取所有账号（解密 token）
    pub async fn get_all_accounts(&self) -> Result<Vec<AccountOutput>, String> {
        if !self.is_initialized().await {
            return Err("账号管理器未初始化".to_string());
        }

        let store_guard = self.store.lock().await;
        let store = store_guard.as_ref().unwrap();

        let crypto_guard = self.crypto.lock().await;
        let crypto = crypto_guard.as_ref().unwrap();

        let accounts = store
            .get_all_accounts()
            .await
            .map_err(|e| format!("获取账号列表失败: {}", e))?;

        let mut result = Vec::new();
        for account in accounts {
            // 解密 token
            let encrypted_bytes =
                base64::Engine::decode(&base64::engine::general_purpose::STANDARD, &account.token)
                    .map_err(|e| format!("解码 token 失败: {}", e))?;

            let decrypted_token = crypto
                .decrypt(&encrypted_bytes)
                .map_err(|e| format!("解密 token 失败: {}", e))?;

            // 解密 refresh_token（可选）
            let decrypted_refresh_token = match account
                .refresh_token
                .as_deref()
                .map(str::trim)
                .filter(|token| !token.is_empty())
            {
                Some(encrypted_refresh_token_base64) => {
                    let encrypted_refresh_bytes = base64::Engine::decode(
                        &base64::engine::general_purpose::STANDARD,
                        encrypted_refresh_token_base64,
                    )
                    .map_err(|e| format!("解码 refresh_token 失败: {}", e))?;
                    let refresh_token = crypto
                        .decrypt(&encrypted_refresh_bytes)
                        .map_err(|e| format!("解密 refresh_token 失败: {}", e))?;
                    Some(refresh_token)
                }
                None => None,
            };

            result.push(AccountOutput {
                id: account.id,
                username: account.username,
                nickname: account.nickname,
                avatar: account.avatar,
                avatar_object_key: account.avatar_object_key,
                avatar_local_path: account.avatar_local_path,
                mobile: account.mobile,
                email: account.email,
                token: decrypted_token,
                refresh_token: decrypted_refresh_token,
                created_at: account.created_at,
                updated_at: account.updated_at,
                sort_order: account.sort_order,
            });
        }

        Ok(result)
    }

    /// 获取当前账号
    pub async fn get_current_account(&self) -> Result<Option<AccountOutput>, String> {
        if !self.is_initialized().await {
            return Err("账号管理器未初始化".to_string());
        }

        let store_guard = self.store.lock().await;
        let store = store_guard.as_ref().unwrap();

        let crypto_guard = self.crypto.lock().await;
        let crypto = crypto_guard.as_ref().unwrap();

        let account = store
            .get_current_account()
            .await
            .map_err(|e| format!("获取当前账号失败: {}", e))?;

        match account {
            Some(account) => {
                // 解密 token
                let encrypted_bytes = base64::Engine::decode(
                    &base64::engine::general_purpose::STANDARD,
                    &account.token,
                )
                .map_err(|e| format!("解码 token 失败: {}", e))?;

                let decrypted_token = crypto
                    .decrypt(&encrypted_bytes)
                    .map_err(|e| format!("解密 token 失败: {}", e))?;

                // 解密 refresh_token（可选）
                let decrypted_refresh_token = match account
                    .refresh_token
                    .as_deref()
                    .map(str::trim)
                    .filter(|token| !token.is_empty())
                {
                    Some(encrypted_refresh_token_base64) => {
                        let encrypted_refresh_bytes = base64::Engine::decode(
                            &base64::engine::general_purpose::STANDARD,
                            encrypted_refresh_token_base64,
                        )
                        .map_err(|e| format!("解码 refresh_token 失败: {}", e))?;
                        let refresh_token = crypto
                            .decrypt(&encrypted_refresh_bytes)
                            .map_err(|e| format!("解密 refresh_token 失败: {}", e))?;
                        Some(refresh_token)
                    }
                    None => None,
                };

                Ok(Some(AccountOutput {
                    id: account.id,
                    username: account.username,
                    nickname: account.nickname,
                    avatar: account.avatar,
                    avatar_object_key: account.avatar_object_key,
                    avatar_local_path: account.avatar_local_path,
                    mobile: account.mobile,
                    email: account.email,
                    token: decrypted_token,
                    refresh_token: decrypted_refresh_token,
                    created_at: account.created_at,
                    updated_at: account.updated_at,
                    sort_order: account.sort_order,
                }))
            }
            None => Ok(None),
        }
    }

    /// 设置当前账号
    pub async fn set_current_account(&self, account_id: String) -> Result<(), String> {
        if !self.is_initialized().await {
            return Err("账号管理器未初始化".to_string());
        }

        let store_guard = self.store.lock().await;
        let store = store_guard.as_ref().unwrap();

        store
            .set_current_account(&account_id)
            .await
            .map_err(|e| format!("设置当前账号失败: {}", e))?;
        Ok(())
    }

    /// 移除账号
    pub async fn remove_account(&self, account_id: String) -> Result<(), String> {
        if !self.is_initialized().await {
            return Err("账号管理器未初始化".to_string());
        }

        let store_guard = self.store.lock().await;
        let store = store_guard.as_ref().unwrap();

        store
            .remove_account(&account_id)
            .await
            .map_err(|e| format!("移除账号失败: {}", e))?;
        Ok(())
    }

    /// 更新账号未读数
    pub async fn update_unread_count(&self, account_id: String, count: i32) -> Result<(), String> {
        if !self.is_initialized().await {
            return Err("账号管理器未初始化".to_string());
        }

        let store_guard = self.store.lock().await;
        let store = store_guard.as_ref().unwrap();

        store
            .update_unread_count(&account_id, count)
            .await
            .map_err(|e| format!("更新未读数失败: {}", e))?;
        Ok(())
    }

    /// 获取账号设置
    pub async fn get_account_settings(
        &self,
        account_id: String,
    ) -> Result<Option<AccountSettings>, String> {
        if !self.is_initialized().await {
            return Err("账号管理器未初始化".to_string());
        }

        let store_guard = self.store.lock().await;
        let store = store_guard.as_ref().unwrap();

        store
            .get_account_settings(&account_id)
            .await
            .map_err(|e| format!("获取账号设置失败: {}", e))
    }

    /// 更新账号顺序
    pub async fn update_account_order(
        &self,
        account_orders: Vec<(String, i64)>,
    ) -> Result<(), String> {
        if !self.is_initialized().await {
            return Err("账号管理器未初始化".to_string());
        }

        let store_guard = self.store.lock().await;
        let store = store_guard.as_ref().unwrap();

        store
            .update_account_order(&account_orders)
            .await
            .map_err(|e| format!("更新账号顺序失败: {}", e))?;
        Ok(())
    }
}

/// 账号输入（添加账号时）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountInput {
    pub id: String,
    pub username: String,
    pub nickname: String,
    pub avatar: Option<String>,
    #[serde(default)]
    pub avatar_object_key: Option<String>,
    #[serde(default)]
    pub avatar_local_path: Option<String>,
    pub mobile: Option<String>,
    pub email: Option<String>,
    pub token: String, // 明文 token
    #[serde(default)]
    pub refresh_token: Option<String>, // 明文 refresh_token（可选）
}

/// 账号输出（返回给前端）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountOutput {
    pub id: String,
    pub username: String,
    pub nickname: String,
    pub avatar: Option<String>,
    pub avatar_object_key: Option<String>,
    pub avatar_local_path: Option<String>,
    pub mobile: Option<String>,
    pub email: Option<String>,
    pub token: String, // 解密后的 token
    #[serde(default)]
    pub refresh_token: Option<String>, // 解密后的 refresh_token（可选）
    pub created_at: i64,
    pub updated_at: i64,
    #[serde(default)]
    pub sort_order: Option<i64>, // 排序顺序
}

pub mod commands;
