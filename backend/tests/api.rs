//! API 集成测试入口
//!
//! 使用 Axum in-process 方式测试 HTTP API，无需启动真实服务器。
//!
//! 运行方式：
//! ```bash
//! # 全部 API 测试
//! cargo test --test api
//!
//! # 单个模块测试
//! cargo test --test api auth
//! cargo test --test api rooms
//! cargo test --test api messages
//! ```

#[path = "api/common.rs"]
mod common;
#[path = "api/auth_tests.rs"]
mod auth_tests;
#[path = "api/rooms_tests.rs"]
mod rooms_tests;
#[path = "api/messages_tests.rs"]
mod messages_tests;
#[path = "api/health_tests.rs"]
mod health_tests;
#[path = "api/settings_tests.rs"]
mod settings_tests;
#[path = "api/users_tests.rs"]
mod users_tests;
