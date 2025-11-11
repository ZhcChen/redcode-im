//! WebSocket 客户端模块
//!
//! 负责与后端 WebSocket 服务的连接和通信
//!
//! 架构：
//! - types.rs - 类型定义和 Proto 封装
//! - client.rs - WebSocket 客户端核心逻辑
//! - commands.rs - Tauri 命令接口

pub mod client;
pub mod commands;
pub mod types;

pub use client::WebSocketClient;
pub use commands::*;
pub use types::*;
