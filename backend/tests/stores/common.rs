//! 存储层测试共享工具
//!
//! 提供测试数据库连接、唯一 ID 生成等通用功能。

use once_cell::sync::OnceCell;
use redcode_im_backend::database::{self, Database};
use sqlx::postgres::PgPoolOptions;
use sqlx::{Pool, Postgres};
use std::env;
use std::time::Duration;
use uuid::Uuid;

static MIGRATIONS_READY: OnceCell<()> = OnceCell::new();

pub struct TestDatabase {
    pub pool: Pool<Postgres>,
}

impl TestDatabase {
    pub async fn new() -> Self {
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

        Self { pool }
    }

    pub fn database(&self) -> Database {
        Database {
            pool: self.pool.clone(),
        }
    }
}

pub async fn setup_test_db() -> TestDatabase {
    TestDatabase::new().await
}

// ============================================================================
// 唯一 ID 生成器
// ============================================================================

pub fn unique_username() -> String {
    format!("testuser_{}", Uuid::new_v4().simple())
}

pub fn unique_email() -> String {
    format!("test_{}@example.com", Uuid::new_v4().simple())
}

pub fn unique_phone() -> String {
    let suffix: u64 = rand::random::<u32>() as u64 % 100_000_000;
    format!("138{:08}", suffix)
}

pub fn unique_room_name() -> String {
    format!("room_{}", Uuid::new_v4().simple())
}
