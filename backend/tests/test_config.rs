use sqlx::postgres::PgPoolOptions;
use sqlx::{Pool, Postgres};
use std::env;
use std::time::Duration;

pub struct TestDatabase {
    pub pool: Pool<Postgres>,
}

impl TestDatabase {
    pub async fn new() -> Self {
        // 加载 .env 文件
        dotenvy::dotenv().ok();

        // 使用测试数据库连接字符串
        let database_url = env::var("DATABASE_URL_TEST")
            .or_else(|_| env::var("DATABASE_URL"))
            .expect("DATABASE_URL or DATABASE_URL_TEST must be set");

        // 直接创建连接池，不运行迁移（假设数据库已初始化）
        // 增加连接数和超时配置以应对并发测试
        let pool = PgPoolOptions::new()
            .max_connections(10)
            .min_connections(1)
            .acquire_timeout(Duration::from_secs(30))
            .idle_timeout(Duration::from_secs(60))
            .connect(&database_url)
            .await
            .expect("Failed to connect to test database");

        Self { pool }
    }

    pub async fn setup(&self) -> Result<(), sqlx::Error> {
        // 测试数据初始化（如果需要）
        Ok(())
    }

    pub async fn cleanup(&self) -> Result<(), sqlx::Error> {
        // 不再清空整个表，测试使用唯一 ID 隔离
        Ok(())
    }
}

pub async fn setup_test_db() -> TestDatabase {
    let test_db = TestDatabase::new().await;
    test_db
        .setup()
        .await
        .expect("Failed to setup test database");
    test_db
}

pub async fn cleanup_test_db(test_db: &TestDatabase) {
    // 测试使用唯一 ID 隔离：目前不做全量清理；保留钩子以便需要时扩展。
    test_db
        .cleanup()
        .await
        .expect("Failed to cleanup test database");
}
