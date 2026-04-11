//! RedCode IM Backend
//!
//! 一个基于 Rust + Axum + PostgreSQL + Redis 的即时通讯后端服务

pub mod auth;
pub mod constants;
pub mod crypto;
pub mod database;
pub mod error;
pub mod handlers;
pub mod id;
pub mod logging;
pub mod middleware;
pub mod models;
pub mod proto;
pub mod redis;
pub mod routes;
pub mod services;
pub mod storage;
pub mod utils;
pub mod websocket;

// Re-export commonly used types
pub use error::{AppError, ErrorResponse};
pub use models::*;

pub use crate::database::Database;
pub use crate::redis::RedisManager;

use logging::LogStore;
use std::sync::Arc;

/// 应用状态
#[derive(Clone)]
pub struct AppState {
    pub database: database::Database,
    pub redis: redis::RedisManager,
    pub node_id: String,
    pub log_store: Arc<dyn LogStore>,
    pub connection_manager: std::sync::Arc<websocket::ConnectionManager>,
}

/// 创建应用路由
pub fn create_routes() -> axum::Router<AppState> {
    routes::create_routes()
}
