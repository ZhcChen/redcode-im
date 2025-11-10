use serde::{Deserialize, Serialize};
use sqlx::sqlite::{SqlitePool, SqlitePoolOptions};
use std::path::PathBuf;

/// 账号信息
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Account {
    pub id: String,
    pub username: String,
    pub nickname: String,
    pub avatar: Option<String>,
    pub mobile: Option<String>,
    pub email: Option<String>,
    pub token: String,  // 加密存储
    pub created_at: i64,
    pub updated_at: i64,
}

/// 账号设置
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct AccountSettings {
    pub account_id: String,
    pub unread_count: i32,
    pub last_active_at: Option<i64>,
}

/// 本地账号数据库（SQLite）
pub struct AccountStore {
    pool: SqlitePool,
}

impl AccountStore {
    /// 创建或打开账号数据库
    pub async fn new(app_data_dir: &PathBuf) -> Result<Self, Box<dyn std::error::Error>> {
        // 确保目录存在
        std::fs::create_dir_all(&app_data_dir)?;

        // 数据库文件路径
        let db_path = app_data_dir.join("accounts.db");
        let db_url = format!("sqlite:{}?mode=rwc", db_path.display());

        tracing::info!("账号数据库路径: {}", db_url);

        // 创建连接池
        let pool = SqlitePoolOptions::new()
            .max_connections(5)
            .connect(&db_url)
            .await?;

        let store = Self { pool };

        // 初始化表结构
        store.init_tables().await?;

        Ok(store)
    }

    /// 初始化数据库表
    async fn init_tables(&self) -> Result<(), sqlx::Error> {
        // 创建账号表
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY,
                username TEXT NOT NULL,
                nickname TEXT NOT NULL,
                avatar TEXT,
                mobile TEXT,
                email TEXT,
                token TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 创建当前账号表（单行表）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS current_account (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                account_id TEXT NOT NULL,
                FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
            )
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 创建账号设置表
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS account_settings (
                account_id TEXT PRIMARY KEY,
                unread_count INTEGER DEFAULT 0,
                last_active_at INTEGER,
                FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
            )
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 创建索引
        sqlx::query("CREATE INDEX IF NOT EXISTS idx_accounts_username ON accounts(username)")
            .execute(&self.pool)
            .await?;

        tracing::info!("账号数据库表初始化完成");
        Ok(())
    }

    /// 添加账号
    pub async fn add_account(&self, account: &Account) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            INSERT INTO accounts (id, username, nickname, avatar, mobile, email, token, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                username = excluded.username,
                nickname = excluded.nickname,
                avatar = excluded.avatar,
                mobile = excluded.mobile,
                email = excluded.email,
                token = excluded.token,
                updated_at = excluded.updated_at
            "#,
        )
        .bind(&account.id)
        .bind(&account.username)
        .bind(&account.nickname)
        .bind(&account.avatar)
        .bind(&account.mobile)
        .bind(&account.email)
        .bind(&account.token)
        .bind(account.created_at)
        .bind(account.updated_at)
        .execute(&self.pool)
        .await?;

        // 初始化账号设置
        sqlx::query(
            r#"
            INSERT INTO account_settings (account_id, unread_count, last_active_at)
            VALUES (?, 0, ?)
            ON CONFLICT(account_id) DO NOTHING
            "#,
        )
        .bind(&account.id)
        .bind(chrono::Utc::now().timestamp())
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    /// 获取所有账号
    pub async fn get_all_accounts(&self) -> Result<Vec<Account>, sqlx::Error> {
        let accounts = sqlx::query_as::<_, Account>(
            r#"
            SELECT id, username, nickname, avatar, mobile, email, token, created_at, updated_at
            FROM accounts
            ORDER BY created_at DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(accounts)
    }

    /// 根据 ID 获取账号
    pub async fn get_account_by_id(&self, account_id: &str) -> Result<Option<Account>, sqlx::Error> {
        let account = sqlx::query_as::<_, Account>(
            r#"
            SELECT id, username, nickname, avatar, mobile, email, token, created_at, updated_at
            FROM accounts
            WHERE id = ?
            "#,
        )
        .bind(account_id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(account)
    }

    /// 设置当前账号
    pub async fn set_current_account(&self, account_id: &str) -> Result<(), sqlx::Error> {
        // 检查账号是否存在
        let exists = sqlx::query("SELECT 1 FROM accounts WHERE id = ?")
            .bind(account_id)
            .fetch_optional(&self.pool)
            .await?
            .is_some();

        if !exists {
            return Err(sqlx::Error::RowNotFound);
        }

        // 插入或更新当前账号
        sqlx::query(
            r#"
            INSERT INTO current_account (id, account_id)
            VALUES (1, ?)
            ON CONFLICT(id) DO UPDATE SET account_id = excluded.account_id
            "#,
        )
        .bind(account_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    /// 获取当前账号
    pub async fn get_current_account(&self) -> Result<Option<Account>, sqlx::Error> {
        let account = sqlx::query_as::<_, Account>(
            r#"
            SELECT a.id, a.username, a.nickname, a.avatar, a.mobile, a.email, a.token, a.created_at, a.updated_at
            FROM accounts a
            INNER JOIN current_account c ON a.id = c.account_id
            WHERE c.id = 1
            "#,
        )
        .fetch_optional(&self.pool)
        .await?;

        Ok(account)
    }

    /// 删除账号
    pub async fn remove_account(&self, account_id: &str) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM accounts WHERE id = ?")
            .bind(account_id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    /// 更新账号未读数
    pub async fn update_unread_count(&self, account_id: &str, count: i32) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            UPDATE account_settings
            SET unread_count = ?
            WHERE account_id = ?
            "#,
        )
        .bind(count)
        .bind(account_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    /// 获取账号设置
    pub async fn get_account_settings(&self, account_id: &str) -> Result<Option<AccountSettings>, sqlx::Error> {
        let settings = sqlx::query_as::<_, AccountSettings>(
            r#"
            SELECT account_id, unread_count, last_active_at
            FROM account_settings
            WHERE account_id = ?
            "#,
        )
        .bind(account_id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(settings)
    }

    /// 更新最后活跃时间
    pub async fn update_last_active(&self, account_id: &str) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            UPDATE account_settings
            SET last_active_at = ?
            WHERE account_id = ?
            "#,
        )
        .bind(chrono::Utc::now().timestamp())
        .bind(account_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }
}
