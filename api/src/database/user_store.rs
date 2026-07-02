use crate::database::models::{
    CreateUserRequest, LoginRequest, UpdateUserRequest, User, UserStatus,
};
use crate::database::Database;
use bcrypt::{hash, verify};
use chrono::Utc;
use sqlx::{Error, Postgres, QueryBuilder};
use std::io;
use uuid::Uuid;

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
        let password_hash = hash_password_blocking(request.password.clone()).await?;

        let user_id = crate::id::generate();
        let now = Utc::now();

        let user = sqlx::query_as::<_, User>(
            r#"
            INSERT INTO users (id, username, email, password_hash, nickname, status, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
            RETURNING id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            "#,
        )
        .bind(user_id)
        .bind(&request.username)
        .bind(&request.email)
        .bind(&password_hash)
        .bind(&request.nickname)
        .bind(UserStatus::Active)
        .bind(now)
        .fetch_one(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 根据用户名查找用户
    pub async fn find_by_username(&self, username: &str) -> Result<Option<User>, Error> {
        let user = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            FROM users
            WHERE username = $1 AND status = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(username)
        .bind(UserStatus::Active)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 根据用户ID查找用户
    pub async fn find_by_id(&self, user_id: &Uuid) -> Result<Option<User>, Error> {
        let user = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            FROM users
            WHERE id = $1 AND status = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(user_id)
        .bind(UserStatus::Active)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 按ID查找用户（不受状态限制，用于管理员操作）
    pub async fn find_by_id_any_status(&self, user_id: &Uuid) -> Result<Option<User>, Error> {
        let user = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            FROM users
            WHERE id = $1 AND deleted_at IS NULL
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
            SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            FROM users
            WHERE email = $1 AND status = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(email)
        .bind(UserStatus::Active)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 按用户名查找用户（支持所有状态）
    pub async fn find_by_username_any_status(&self, username: &str) -> Result<Option<User>, Error> {
        let user = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            FROM users
            WHERE username = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(username)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 验证用户登录
    pub async fn authenticate(&self, request: LoginRequest) -> Result<Option<User>, Error> {
        let user = if !request.email.trim().is_empty() {
            self.find_by_email_any_status(request.email.trim()).await?
        } else {
            self.find_by_username_any_status(request.username.trim())
                .await?
        };

        if let Some(user) = user {
            if verify_password_blocking(request.password, user.password_hash.clone())
                .await
                .unwrap_or(false)
            {
                return Ok(Some(user));
            }
        }
        Ok(None)
    }

    /// 按邮箱查找用户（支持所有状态）
    pub async fn find_by_email_any_status(&self, email: &str) -> Result<Option<User>, Error> {
        let user = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            FROM users
            WHERE email = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(email)
        .fetch_optional(&self.database.pool)
        .await?;

        Ok(user)
    }

    /// 更新用户信息
    pub async fn update_user(
        &self,
        user_id: &Uuid,
        request: UpdateUserRequest,
    ) -> Result<Option<User>, Error> {
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

        if let Some(avatar_object_key) = &request.avatar_object_key {
            query.push(", avatar_object_key = ");
            query.push_bind(avatar_object_key);
            has_update = true;
        }

        if let Some(status) = &request.status {
            query.push(", status = ");
            query.push_bind(*status);
            has_update = true;
        }

        if !has_update {
            return self.find_by_id(user_id).await;
        }

        query.push(" WHERE id = ");
        query.push_bind(user_id);
        query.push(" AND status = ");
        query.push_bind(UserStatus::Active);
        query.push(" AND deleted_at IS NULL");
        query.push(" RETURNING id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at");

        let user = query
            .build_query_as::<User>()
            .fetch_optional(&self.database.pool)
            .await?;

        Ok(user)
    }

    /// 删除用户（软删除）
    pub async fn delete_user(&self, user_id: &Uuid) -> Result<bool, Error> {
        let result = sqlx::query(
            "UPDATE users SET status = $2, deleted_at = NOW(), updated_at = NOW()
             WHERE id = $1 AND deleted_at IS NULL",
        )
        .bind(user_id)
        .bind(UserStatus::Inactive)
        .execute(&self.database.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 检查用户名是否已存在
    pub async fn username_exists(&self, username: &str) -> Result<bool, Error> {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM users WHERE username = $1 AND status = $2 AND deleted_at IS NULL)",
        )
        .bind(username)
        .bind(UserStatus::Active)
        .fetch_one(&self.database.pool)
        .await
        .unwrap_or(false);

        Ok(exists)
    }

    /// 检查邮箱是否已存在
    pub async fn email_exists(&self, email: &str) -> Result<bool, Error> {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1 AND status = $2 AND deleted_at IS NULL)",
        )
        .bind(email)
        .bind(UserStatus::Active)
        .fetch_one(&self.database.pool)
        .await
        .unwrap_or(false);

        Ok(exists)
    }

    /// 统计用户总数
    #[allow(dead_code)] // 保留用于将来可能的功能
    pub async fn count_users(&self) -> Result<i64, Error> {
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM users WHERE status = $1 AND deleted_at IS NULL",
        )
        .bind(UserStatus::Active)
        .fetch_one(&self.database.pool)
        .await
        .unwrap_or(0);

        Ok(count)
    }

    /// 分页获取用户列表（可选状态与用户名筛选）
    pub async fn list_users(
        &self,
        page: usize,
        page_size: usize,
        status: Option<UserStatus>,
        username: Option<&str>,
    ) -> Result<(Vec<User>, i64), Error> {
        let page = page.max(1);
        let page_size = page_size.clamp(1, 100);
        let offset = ((page - 1) * page_size) as i64;

        let mut data_builder = QueryBuilder::<Postgres>::new(
            "SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at FROM users WHERE 1=1",
        );
        apply_user_filters(&mut data_builder, status.as_ref(), username);
        data_builder.push(" ORDER BY created_at DESC LIMIT ");
        data_builder.push_bind(page_size as i64);
        data_builder.push(" OFFSET ");
        data_builder.push_bind(offset);

        let users = data_builder
            .build_query_as::<User>()
            .fetch_all(&self.database.pool)
            .await?;

        let mut count_builder =
            QueryBuilder::<Postgres>::new("SELECT COUNT(*) FROM users WHERE deleted_at IS NULL");
        apply_user_filters(&mut count_builder, status.as_ref(), username);

        let total: i64 = count_builder
            .build_query_scalar()
            .fetch_one(&self.database.pool)
            .await?;

        Ok((users, total))
    }

    /// 更新用户密码
    pub async fn update_password(
        &self,
        user_id: &Uuid,
        new_password_hash: &str,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            "UPDATE users SET password_hash = $1, updated_at = NOW()
             WHERE id = $2 AND status = $3 AND deleted_at IS NULL",
        )
        .bind(new_password_hash)
        .bind(user_id)
        .bind(UserStatus::Active)
        .execute(&self.database.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 更新用户状态
    pub async fn update_user_status(
        &self,
        user_id: &Uuid,
        status: UserStatus,
    ) -> Result<bool, Error> {
        let result = sqlx::query(
            "UPDATE users SET status = $1, updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL",
        )
        .bind(status)
        .bind(user_id)
        .execute(&self.database.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 搜索用户（支持用户名、昵称、邮箱）
    pub async fn search_users(
        &self,
        keyword: &str,
        limit: i64,
        exclude_user_id: &Uuid,
    ) -> Result<Vec<User>, Error> {
        let pattern = format!("%{}%", keyword.to_lowercase());

        let users = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            FROM users
            WHERE deleted_at IS NULL
              AND status = $4
              AND id <> $1
              AND (
                    LOWER(username) LIKE $2
                 OR LOWER(email) LIKE $2
                 OR LOWER(COALESCE(nickname, '')) LIKE $2
              )
            ORDER BY username ASC
            LIMIT $3
            "#,
        )
        .bind(exclude_user_id)
        .bind(pattern)
        .bind(limit)
        .bind(UserStatus::Active)
        .fetch_all(&self.database.pool)
        .await?;

        Ok(users)
    }

    /// 根据一批用户ID获取用户列表
    pub async fn find_by_ids(&self, ids: &[Uuid]) -> Result<Vec<User>, Error> {
        if ids.is_empty() {
            return Ok(Vec::new());
        }

        let id_list: Vec<Uuid> = ids.iter().cloned().collect();

        let users = sqlx::query_as::<_, User>(
            r#"
            SELECT id, username, email, password_hash, nickname, avatar_url, avatar_object_key, status, created_at, updated_at, deleted_at
            FROM users
            WHERE id = ANY($1)
              AND deleted_at IS NULL
              AND status = $2
            "#,
        )
        .bind(id_list)
        .bind(UserStatus::Active)
        .fetch_all(&self.database.pool)
        .await?;

        Ok(users)
    }
}

async fn hash_password_blocking(password: String) -> Result<String, Error> {
    let cost = crate::auth::password_hash_cost();
    tokio::task::spawn_blocking(move || hash(password, cost))
        .await
        .map_err(sqlx_io_error)?
        .map_err(sqlx_io_error)
}

async fn verify_password_blocking(password: String, password_hash: String) -> Result<bool, Error> {
    tokio::task::spawn_blocking(move || verify(password, &password_hash))
        .await
        .map_err(sqlx_io_error)?
        .map_err(sqlx_io_error)
}

fn sqlx_io_error(error: impl std::fmt::Display) -> Error {
    Error::Io(io::Error::new(io::ErrorKind::Other, error.to_string()))
}

fn apply_user_filters(
    builder: &mut QueryBuilder<Postgres>,
    status: Option<&UserStatus>,
    username: Option<&str>,
) {
    if let Some(status) = status {
        builder.push(" AND status = ");
        builder.push_bind(*status);
    }

    if let Some(username) = username {
        let pattern = format!("%{}%", username.to_lowercase());
        builder.push(" AND (LOWER(username) LIKE ");
        builder.push_bind(pattern.clone());
        builder.push(" OR LOWER(email) LIKE ");
        builder.push_bind(pattern.clone());
        builder.push(" OR LOWER(COALESCE(nickname, '')) LIKE ");
        builder.push_bind(pattern);
        builder.push(")");
    }
}
