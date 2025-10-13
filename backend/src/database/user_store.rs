use crate::database::models::{User, CreateUserRequest, UpdateUserRequest, LoginRequest};
use crate::database::Database;
use bcrypt::{hash, verify, DEFAULT_COST};
use sqlx::Error;
use uuid::Uuid;
use chrono::Utc;

/// PostgreSQL 用户存储实现
pub struct UserStore {
    database: Database,
}

impl UserStore {
    /// 创建新的用户存储实例
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    /// 创建用户
    pub async fn create_user(&self, request: CreateUserRequest) -> Result<User, Error> {
        let password_hash = hash(&request.password, DEFAULT_COST)
            .map_err(|e| sqlx::Error::Io(std::io::Error::new(std::io::ErrorKind::Other, e)))?;

        let user_id = Uuid::new_v4();
        let now = Utc::now();

        let user = sqlx::query_as::<_, User>(
            r#"
            INSERT INTO users (id, username, email, password_hash, nickname, status, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, 'active', $6, $6)
            RETURNING id, username, email, password_hash, nickname, avatar_url, status, created_at, updated_at, deleted_at
            "#,
        )
        .bind(user_id)
        .bind(&request.username)
        .bind(&request.email)
        .bind(&password_hash)
        .bind(&request.nickname)
        .bind(now)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 根据用户名查找用户
    pub async fn find_by_username(&self, username: &str) -> Result<Option<User>, Error> {
        let user = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, status, created_at, updated_at, deleted_at
            FROM users
            WHERE username = $1 AND status = 'active' AND deleted_at IS NULL
            "#,
        )
        .bind(username)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 根据用户ID查找用户
    pub async fn find_by_id(&self, user_id: &Uuid) -> Result<Option<User>, Error> {
        let user = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, status, created_at, updated_at, deleted_at
            FROM users
            WHERE id = $1 AND status = 'active' AND deleted_at IS NULL
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 根据邮箱查找用户
    pub async fn find_by_email(&self, email: &str) -> Result<Option<User>, Error> {
        let user = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, status, created_at, updated_at, deleted_at
            FROM users
            WHERE email = $1 AND status = 'active' AND deleted_at IS NULL
            "#,
        )
        .bind(email)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 验证用户登录
    pub async fn authenticate(&self, request: LoginRequest) -> Result<Option<User>, Error> {
        if let Some(user) = self.find_by_username(&request.username).await? {
            if verify(&request.password, &user.password_hash).unwrap_or(false) {
                return Ok(Some(user));
            }
        }
        Ok(None)
    }

    /// 更新用户信息
    pub async fn update_user(&self, user_id: &Uuid, request: UpdateUserRequest) -> Result<Option<User>, Error> {
        let mut query = sqlx::QueryBuilder::new("UPDATE users SET updated_at = NOW()");
        let mut has_update = false;

        if let Some(nickname) = &request.nickname {
            query.push(", nickname = ");
            query.push_bind(nickname);
            has_update = true;
        }

        if let Some(avatar_url) = &request.avatar_url {
            query.push(", avatar_url = ");
            query.push_bind(avatar_url);
            has_update = true;
        }

        if let Some(status) = &request.status {
            query.push(", status = ");
            query.push_bind(status.to_string());
            has_update = true;
        }

        if !has_update {
            return self.find_by_id(user_id).await;
        }

        query.push(" WHERE id = ");
        query.push_bind(user_id);
        query.push(" AND status = 'active' AND deleted_at IS NULL");
        query.push(" RETURNING id, username, email, password_hash, nickname, avatar_url, status as \"status: _\", created_at, updated_at, deleted_at");

        let user = query
            .build_query_as::<User>()
            .fetch_optional(&self.database.pool)
            .await?;

        Ok(user)
    }

    /// 删除用户（软删除）
    pub async fn delete_user(&self, user_id: &Uuid) -> Result<bool, Error> {
        let result = sqlx::query(
            "UPDATE users SET status = 'inactive', deleted_at = NOW(), updated_at = NOW()
             WHERE id = $1 AND deleted_at IS NULL",
        )
        .bind(user_id)
        .execute(&self.database.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 检查用户名是否已存在
    pub async fn username_exists(&self, username: &str) -> Result<bool, Error> {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM users WHERE username = $1 AND status = 'active' AND deleted_at IS NULL)",
        )
        .bind(username)
        .fetch_one(&self.database.pool)
        .await
        .unwrap_or(false);

        Ok(exists)
    }

    /// 检查邮箱是否已存在
    pub async fn email_exists(&self, email: &str) -> Result<bool, Error> {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1 AND status = 'active' AND deleted_at IS NULL)",
        )
        .bind(email)
        .fetch_one(&self.database.pool)
        .await
        .unwrap_or(false);

        Ok(exists)
    }

    /// 获取用户总数
    pub async fn count_users(&self) -> Result<i64, Error> {
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM users WHERE status = 'active' AND deleted_at IS NULL",
        )
        .fetch_one(&self.database.pool)
        .await
        .unwrap_or(0);

        Ok(count)
    }
}