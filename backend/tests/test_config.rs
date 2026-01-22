//! 测试配置 - E2EE 测试适配层
//!
//! 为 e2ee_key_store_tests 提供兼容的测试工具函数。

use once_cell::sync::OnceCell;
use redcode_im_backend::database::{self, Database};
use sqlx::postgres::PgPoolOptions;
use sqlx::{Pool, Postgres};
use std::env;
use std::time::Duration;

static MIGRATIONS_READY: OnceCell<()> = OnceCell::new();

pub async fn setup_test_db() -> Database {
    dotenvy::dotenv().ok();

    let database_url = env::var("DATABASE_URL_TEST")
        .or_else(|_| env::var("DATABASE_URL"))
        .expect("DATABASE_URL or DATABASE_URL_TEST must be set");

    let pool = PgPoolOptions::new()
        .max_connections(10)
        .min_connections(1)
        .acquire_timeout(Duration::from_secs(30))
        .idle_timeout(Duration::from_secs(60))
        .connect(&database_url)
        .await
        .expect("Failed to connect to test database");

    // 仅执行一次迁移
    if MIGRATIONS_READY.set(()).is_ok() {
        let database = database::Database { pool: pool.clone() };
        database.migrate().await.expect("数据库迁移失败");
    }

    Database { pool }
}

pub async fn cleanup_test_db(_db: &Database) {
    // 测试结束后的清理（可选）
    // 当前实现：不做任何清理，让连接池自动回收
}
