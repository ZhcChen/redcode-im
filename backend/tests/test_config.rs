use redcode_im_backend::database::Database;
use sqlx::{Pool, Postgres};
use std::env;

pub struct TestDatabase {
    pub pool: Pool<Postgres>,
}

impl TestDatabase {
    pub async fn new() -> Self {
        // 使用测试数据库连接字符串
        let _database_url = env::var("DATABASE_URL_TEST")
            .or_else(|_| env::var("DATABASE_URL"))
            .expect("DATABASE_URL or DATABASE_URL_TEST must be set");

        let database = Database::new()
            .await
            .expect("Failed to connect to test database");

        Self {
            pool: database.pool,
        }
    }

    pub async fn setup(&self) -> Result<(), sqlx::Error> {
        // 运行迁移
        sqlx::query("BEGIN").execute(&self.pool).await?;

        // 这里可以添加测试数据的初始化
        // 例如：创建测试用户、房间等

        sqlx::query("COMMIT").execute(&self.pool).await?;

        Ok(())
    }

    pub async fn cleanup(&self) -> Result<(), sqlx::Error> {
        // 清理测试数据
        sqlx::query("TRUNCATE TABLE users CASCADE")
            .execute(&self.pool)
            .await?;

        sqlx::query("TRUNCATE TABLE rooms CASCADE")
            .execute(&self.pool)
            .await?;

        sqlx::query("TRUNCATE TABLE messages CASCADE")
            .execute(&self.pool)
            .await?;

        sqlx::query("TRUNCATE TABLE room_members CASCADE")
            .execute(&self.pool)
            .await?;

        sqlx::query("TRUNCATE TABLE group_settings CASCADE")
            .execute(&self.pool)
            .await?;

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
    test_db
        .cleanup()
        .await
        .expect("Failed to cleanup test database");
}
