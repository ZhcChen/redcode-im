// 此模块已废弃，现在使用 database::user_store
// 保留此文件以供参考

/*
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use uuid::Uuid;
use chrono::Utc;

use crate::models::{User, UserStatus, CreateUserRequest};

// 内存用户存储 (已废弃，使用 database::user_store 替代)
pub struct UserStorage {
    users: Arc<RwLock<HashMap<String, User>>>,
    username_index: Arc<RwLock<HashMap<String, String>>>,
    email_index: Arc<RwLock<HashMap<String, String>>>,
}
*/
