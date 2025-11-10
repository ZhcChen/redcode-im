use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::{AppHandle, Manager, State};
use tokio::sync::Mutex;

/// 导入 backend 的模块
use redcode_im_backend::crypto::TokenCrypto;
use redcode_im_backend::database::account_store::{Account, AccountSettings, AccountStore};

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

        let crypto = TokenCrypto::new(&app_data_dir)
            .map_err(|e| format!("初始化加密器失败: {}", e))?;

        *self.store.lock().await = Some(store);
        *self.crypto.lock().await = Some(crypto);

        Ok(())
    }

    /// 获取存储实例
    async fn get_store(&self) -> Result<AccountStore, String> {
        self.store
            .lock()
            .await
            .as_ref()
            .cloned()
            .ok_or_else(|| "账号管理器未初始化".to_string())
    }

    /// 获取加密器
    async fn get_crypto(&self) -> Result<TokenCrypto, String> {
        self.crypto
            .lock()
            .await
            .as_ref()
            .cloned()
            .ok_or_else(|| "加密器未初始化".to_string())
    }

    /// 添加账号（加密 token）
    pub async fn add_account(&self, account: AccountInput) -> Result<(), String> {
        let store = self.get_store().await?;
        let crypto = self.get_crypto().await?;

        // 加密 token
        let encrypted_token = crypto
            .encrypt(&account.token)
            .map_err(|e| format!("加密 token 失败: {}", e))?;

        // 转换为 base64 便于存储
        let encrypted_token_base64 = base64::Engine::encode(
            &base64::engine::general_purpose::STANDARD,
            &encrypted_token,
        );

        let now = chrono::Utc::now().timestamp();
        let db_account = Account {
            id: account.id,
            username: account.username,
            nickname: account.nickname,
            avatar: account.avatar,
            mobile: account.mobile,
            email: account.email,
            token: encrypted_token_base64,
            created_at: now,
            updated_at: now,
        };

        store
            .add_account(&db_account)
            .await
            .map_err(|e| format!("添加账号失败: {}", e))?;

        Ok(())
    }

    /// 获取所有账号（解密 token）
    pub async fn get_all_accounts(&self) -> Result<Vec<AccountOutput>, String> {
        let store = self.get_store().await?;
        let crypto = self.get_crypto().await?;

        let accounts = store
            .get_all_accounts()
            .await
            .map_err(|e| format!("获取账号列表失败: {}", e))?;

        let mut result = Vec::new();
        for account in accounts {
            // 解密 token
            let encrypted_bytes = base64::Engine::decode(
                &base64::engine::general_purpose::STANDARD,
                &account.token,
            )
            .map_err(|e| format!("解码 token 失败: {}", e))?;

            let decrypted_token = crypto
                .decrypt(&encrypted_bytes)
                .map_err(|e| format!("解密 token 失败: {}", e))?;

            result.push(AccountOutput {
                id: account.id,
                username: account.username,
                nickname: account.nickname,
                avatar: account.avatar,
                mobile: account.mobile,
                email: account.email,
                token: decrypted_token,
                created_at: account.created_at,
                updated_at: account.updated_at,
            });
        }

        Ok(result)
    }

    /// 获取当前账号
    pub async fn get_current_account(&self) -> Result<Option<AccountOutput>, String> {
        let store = self.get_store().await?;
        let crypto = self.get_crypto().await?;

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

                Ok(Some(AccountOutput {
                    id: account.id,
                    username: account.username,
                    nickname: account.nickname,
                    avatar: account.avatar,
                    mobile: account.mobile,
                    email: account.email,
                    token: decrypted_token,
                    created_at: account.created_at,
                    updated_at: account.updated_at,
                }))
            }
            None => Ok(None),
        }
    }

    /// 设置当前账号
    pub async fn set_current_account(&self, account_id: String) -> Result<(), String> {
        let store = self.get_store().await?;
        store
            .set_current_account(&account_id)
            .await
            .map_err(|e| format!("设置当前账号失败: {}", e))?;
        Ok(())
    }

    /// 移除账号
    pub async fn remove_account(&self, account_id: String) -> Result<(), String> {
        let store = self.get_store().await?;
        store
            .remove_account(&account_id)
            .await
            .map_err(|e| format!("移除账号失败: {}", e))?;
        Ok(())
    }

    /// 更新账号未读数
    pub async fn update_unread_count(&self, account_id: String, count: i32) -> Result<(), String> {
        let store = self.get_store().await?;
        store
            .update_unread_count(&account_id, count)
            .await
            .map_err(|e| format!("更新未读数失败: {}", e))?;
        Ok(())
    }

    /// 获取账号设置
    pub async fn get_account_settings(&self, account_id: String) -> Result<Option<AccountSettings>, String> {
        let store = self.get_store().await?;
        store
            .get_account_settings(&account_id)
            .await
            .map_err(|e| format!("获取账号设置失败: {}", e))
    }
}

/// 账号输入（添加账号时）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountInput {
    pub id: String,
    pub username: String,
    pub nickname: String,
    pub avatar: Option<String>,
    pub mobile: Option<String>,
    pub email: Option<String>,
    pub token: String, // 明文 token
}

/// 账号输出（返回给前端）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountOutput {
    pub id: String,
    pub username: String,
    pub nickname: String,
    pub avatar: Option<String>,
    pub mobile: Option<String>,
    pub email: Option<String>,
    pub token: String, // 解密后的 token
    pub created_at: i64,
    pub updated_at: i64,
}

pub mod commands;
