//! 存储层集成测试入口
//!
//! 按业务域拆分为独立模块，便于维护和并行测试。
//!
//! 运行方式：
//! ```bash
//! # 全部 store 测试（注意：需要单线程执行避免连接池耗尽）
//! cargo test --test stores -- --test-threads=1
//!
//! # 单个 store 测试
//! cargo test --test stores user_store
//! cargo test --test stores friend_store
//! cargo test --test stores room_store
//! cargo test --test stores message_store
//! cargo test --test stores settings_store
//! cargo test --test stores group_management_store
//! cargo test --test stores message_reaction_store
//! cargo test --test stores message_read_store
//! cargo test --test stores report_store
//! ```

#[path = "stores/common.rs"]
mod common;
#[path = "stores/friend_store_tests.rs"]
mod friend_store_tests;
#[path = "stores/group_management_store_tests.rs"]
mod group_management_store_tests;
#[path = "stores/message_reaction_store_tests.rs"]
mod message_reaction_store_tests;
#[path = "stores/message_read_store_tests.rs"]
mod message_read_store_tests;
#[path = "stores/message_store_tests.rs"]
mod message_store_tests;
#[path = "stores/report_store_tests.rs"]
mod report_store_tests;
#[path = "stores/room_store_tests.rs"]
mod room_store_tests;
#[path = "stores/settings_store_tests.rs"]
mod settings_store_tests;
#[path = "stores/user_store_tests.rs"]
mod user_store_tests;
