use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use uuid::Uuid;
use chrono::Utc;

use crate::models::{User, UserStatus, CreateUserRequest};

// 内存用户存储 (生产环境应使用数据库)
pub struct UserStorage {
    users: Arc<RwLock<HashMap<String, User>>>,
    username_index: Arc<RwLock<HashMap<String, String>>>, // username -> user_id
    email_index: Arc<RwLock<HashMap<String, String>>>,    // email -> user_id
}

impl UserStorage {
    pub fn new() -> Self {
        Self {
            users: Arc::new(RwLock::new(HashMap::new())),
            username_index: Arc::new(RwLock::new(HashMap::new())),
            email_index: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    // 创建用户
    pub async fn create_user(&self, request: CreateUserRequest, password_hash: String) -> Result<User, String> {
        let mut users = self.users.write().await;
        let mut username_index = self.username_index.write().await;
        let mut email_index = self.email_index.write().await;

        // 检查用户名是否已存在
        if username_index.contains_key(&request.username) {
            return Err("Username already exists".to_string());
        }

        // 检查邮箱是否已存在
        if email_index.contains_key(&request.email) {
            return Err("Email already exists".to_string());
        }

        let user_id = Uuid::new_v4().to_string();
        let now = Utc::now();

        let user = User {
            id: user_id.clone(),
            username: request.username.clone(),
            email: request.email.clone(),
            password_hash,
            nickname: request.nickname,
            avatar_url: None,
            status: UserStatus::Active,
            created_at: now,
            updated_at: now,
        };

        // 存储用户数据
        users.insert(user_id.clone(), user.clone());
        username_index.insert(request.username, user_id.clone());
        email_index.insert(request.email, user_id);

        Ok(user)
    }

    // 根据用户名查找用户
    pub async fn find_by_username(&self, username: &str) -> Option<User> {
        let username_index = self.username_index.read().await;
        let users = self.users.read().await;

        if let Some(user_id) = username_index.get(username) {
            users.get(user_id).cloned()
        } else {
            None
        }
    }

    // 根据用户ID查找用户
    pub async fn find_by_id(&self, user_id: &str) -> Option<User> {
        let users = self.users.read().await;
        users.get(user_id).cloned()
    }

    // 根据邮箱查找用户
    pub async fn find_by_email(&self, email: &str) -> Option<User> {
        let email_index = self.email_index.read().await;
        let users = self.users.read().await;

        if let Some(user_id) = email_index.get(email) {
            users.get(user_id).cloned()
        } else {
            None
        }
    }

    // 更新用户信息
    pub async fn update_user(&self, user_id: &str, user: User) -> Result<(), String> {
        let mut users = self.users.write().await;

        if users.contains_key(user_id) {
            users.insert(user_id.to_string(), user);
            Ok(())
        } else {
            Err("User not found".to_string())
        }
    }

    // 删除用户
    pub async fn delete_user(&self, user_id: &str) -> Result<(), String> {
        let mut users = self.users.write().await;
        let mut username_index = self.username_index.write().await;
        let mut email_index = self.email_index.write().await;

        if let Some(user) = users.remove(user_id) {
            username_index.remove(&user.username);
            email_index.remove(&user.email);
            Ok(())
        } else {
            Err("User not found".to_string())
        }
    }
}

// 全局用户存储实例
lazy_static::lazy_static! {
    pub static ref USER_STORAGE: UserStorage = UserStorage::new();
}