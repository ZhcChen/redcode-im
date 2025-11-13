use serde::{Deserialize, Serialize};
use sqlx::sqlite::{SqlitePool, SqlitePoolOptions};
use std::path::PathBuf;

/// 账号信息
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[allow(dead_code)] // 保留用于桌面端应用
pub struct Account {
    pub id: String,
    pub username: String,
    pub nickname: String,
    pub avatar: Option<String>,
    pub avatar_object_key: Option<String>,
    pub avatar_local_path: Option<String>,
    pub mobile: Option<String>,
    pub email: Option<String>,
    pub token: String, // 加密存储
    pub created_at: i64,
    pub updated_at: i64,
    #[serde(default)]
    pub sort_order: Option<i64>, // 排序顺序
}

/// 账号设置
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[allow(dead_code)] // 保留用于桌面端应用
pub struct AccountSettings {
    pub account_id: String,
    pub unread_count: i32,
    pub last_active_at: Option<i64>,
}

/// 本地账号数据库（SQLite）
#[allow(dead_code)] // 保留用于桌面端应用
pub struct AccountStore {
    pool: SqlitePool,
}

impl AccountStore {
    /// 创建或打开账号数据库
    #[allow(dead_code)] // 保留用于桌面端应用
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
    #[allow(dead_code)] // 保留用于桌面端应用
    async fn init_tables(&self) -> Result<(), sqlx::Error> {
        // 创建账号表
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY,
                username TEXT NOT NULL,
                nickname TEXT NOT NULL,
                avatar TEXT,
                avatar_object_key TEXT,
                avatar_local_path TEXT,
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

        // 兼容旧版本：补充新增列
        self.ensure_account_column("avatar_object_key", "TEXT")
            .await?;
        self.ensure_account_column("avatar_local_path", "TEXT")
            .await?;
        self.ensure_account_column("sort_order", "INTEGER").await?;

        tracing::info!("账号数据库表初始化完成");
        Ok(())
    }

    #[allow(dead_code)] // 保留用于桌面端应用
    async fn ensure_account_column(
        &self,
        column_name: &str,
        definition: &str,
    ) -> Result<(), sqlx::Error> {
        let exists: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM pragma_table_info('accounts') WHERE name = ?")
                .bind(column_name)
                .fetch_one(&self.pool)
                .await?;

        if exists == 0 {
            let alter = format!(
                "ALTER TABLE accounts ADD COLUMN {} {}",
                column_name, definition
            );
            sqlx::query(&alter).execute(&self.pool).await?;
        }

        Ok(())
    }

    /// 添加账号
    #[allow(dead_code)] // 保留用于桌面端应用
    pub async fn add_account(&self, account: &Account) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            INSERT INTO accounts (id, username, nickname, avatar, avatar_object_key, avatar_local_path, mobile, email, token, created_at, updated_at, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, ?))
            ON CONFLICT(id) DO UPDATE SET
                username = excluded.username,
                nickname = excluded.nickname,
                avatar = excluded.avatar,
                avatar_object_key = excluded.avatar_object_key,
                avatar_local_path = excluded.avatar_local_path,
                mobile = excluded.mobile,
                email = excluded.email,
                token = excluded.token,
                updated_at = excluded.updated_at,
                sort_order = COALESCE(accounts.sort_order, excluded.sort_order)
            "#,
        )
        .bind(&account.id)
        .bind(&account.username)
        .bind(&account.nickname)
        .bind(&account.avatar)
        .bind(&account.avatar_object_key)
        .bind(&account.avatar_local_path)
        .bind(&account.mobile)
        .bind(&account.email)
        .bind(&account.token)
        .bind(account.created_at)
        .bind(account.updated_at)
        .bind(account.sort_order)
        .bind(account.created_at)
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
    #[allow(dead_code)] // 保留用于桌面端应用
    pub async fn get_all_accounts(&self) -> Result<Vec<Account>, sqlx::Error> {
        let accounts = sqlx::query_as::<_, Account>(
            r#"
            SELECT id, username, nickname, avatar, avatar_object_key, avatar_local_path, mobile, email, token, created_at, updated_at, sort_order
            FROM accounts
            ORDER BY COALESCE(sort_order, created_at) ASC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(accounts)
    }

    /// 根据 ID 获取账号
    #[allow(dead_code)] // 保留用于桌面端应用
    pub async fn get_account_by_id(
        &self,
        account_id: &str,
    ) -> Result<Option<Account>, sqlx::Error> {
        let account = sqlx::query_as::<_, Account>(
            r#"
            SELECT id, username, nickname, avatar, avatar_object_key, avatar_local_path, mobile, email, token, created_at, updated_at, sort_order
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
    #[allow(dead_code)] // 保留用于桌面端应用
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
    #[allow(dead_code)] // 保留用于桌面端应用
    pub async fn get_current_account(&self) -> Result<Option<Account>, sqlx::Error> {
        let account = sqlx::query_as::<_, Account>(
            r#"
            SELECT a.id, a.username, a.nickname, a.avatar, a.avatar_object_key, a.avatar_local_path, a.mobile, a.email, a.token, a.created_at, a.updated_at, a.sort_order
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
    #[allow(dead_code)] // 保留用于桌面端应用
    pub async fn remove_account(&self, account_id: &str) -> Result<(), sqlx::Error> {
        sqlx::query("DELETE FROM accounts WHERE id = ?")
            .bind(account_id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    /// 更新账号未读数
    #[allow(dead_code)] // 保留用于桌面端应用
    pub async fn update_unread_count(
        &self,
        account_id: &str,
        count: i32,
    ) -> Result<(), sqlx::Error> {
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
    #[allow(dead_code)] // 保留用于桌面端应用
    pub async fn get_account_settings(
        &self,
        account_id: &str,
    ) -> Result<Option<AccountSettings>, sqlx::Error> {
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
    #[allow(dead_code)] // 保留用于桌面端应用
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

    /// 更新账号顺序
    #[allow(dead_code)] // 保留用于桌面端应用
    pub async fn update_account_order(
        &self,
        account_orders: &[(String, i64)],
    ) -> Result<(), sqlx::Error> {
        let mut tx = self.pool.begin().await?;

        for (account_id, sort_order) in account_orders {
            sqlx::query(
                r#"
                UPDATE accounts
                SET sort_order = ?, updated_at = ?
                WHERE id = ?
                "#,
            )
            .bind(sort_order)
            .bind(chrono::Utc::now().timestamp())
            .bind(account_id)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }
}
