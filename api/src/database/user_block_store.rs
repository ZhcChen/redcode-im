use chrono::{DateTime, Utc};
use sqlx::{query_as, query_scalar, PgPool};
use uuid::Uuid;

use crate::database::Database;
use crate::error::AppError;

/// 黑名单列表项（含被拉黑用户的公开信息）
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct BlockedUserRecord {
    pub blocked_id: Uuid,
    pub username: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub signature: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// 用户黑名单存储
#[derive(Clone)]
pub struct UserBlockStore {
    database: Database,
}

impl UserBlockStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    fn pool(&self) -> &PgPool {
        &self.database.pool
    }

    /// 拉黑用户（幂等）。返回是否为新插入。
    pub async fn block_user(
        &self,
        blocker_id: Uuid,
        blocked_id: Uuid,
    ) -> Result<bool, AppError> {
        if blocker_id == blocked_id {
            return Err(AppError::ValidationError(
                "不能拉黑自己".to_string(),
            ));
        }

        let result = sqlx::query(
            "INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1, $2)
             ON CONFLICT (blocker_id, blocked_id) DO NOTHING",
        )
        .bind(blocker_id)
        .bind(blocked_id)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }

    /// 取消拉黑。返回是否删除成功。
    pub async fn unblock_user(
        &self,
        blocker_id: Uuid,
        blocked_id: Uuid,
    ) -> Result<bool, AppError> {
        let result = sqlx::query(
            "DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2",
        )
        .bind(blocker_id)
        .bind(blocked_id)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }

    /// 单向拉黑判断：blocker 是否拉黑了 blocked。
    pub async fn is_blocked(&self, blocker_id: Uuid, blocked_id: Uuid) -> Result<bool, AppError> {
        let exists: bool = query_scalar(
            "SELECT EXISTS(SELECT 1 FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2)",
        )
        .bind(blocker_id)
        .bind(blocked_id)
        .fetch_one(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(exists)
    }

    /// 双向拉黑判断：任一方向拉黑即视为阻断。
    pub async fn is_mutually_blocked(
        &self,
        user_a: Uuid,
        user_b: Uuid,
    ) -> Result<bool, AppError> {
        let exists: bool = query_scalar(
            "SELECT EXISTS(
                SELECT 1 FROM user_blocks
                WHERE (blocker_id = $1 AND blocked_id = $2)
                   OR (blocker_id = $2 AND blocked_id = $1)
             )",
        )
        .bind(user_a)
        .bind(user_b)
        .fetch_one(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(exists)
    }

    /// 分页列出当前用户拉黑的对象（含公开资料）。
    pub async fn list_blocked(
        &self,
        blocker_id: Uuid,
        limit: i64,
        offset: i64,
    ) -> Result<(Vec<BlockedUserRecord>, i64), AppError> {
        let rows = query_as::<_, BlockedUserRecord>(
            r#"
            SELECT ub.blocked_id, u.username, u.nickname, u.avatar_url, u.signature, ub.created_at
            FROM user_blocks ub
            JOIN users u ON u.id = ub.blocked_id
            WHERE ub.blocker_id = $1
            ORDER BY ub.created_at DESC
            LIMIT $2 OFFSET $3
            "#,
        )
        .bind(blocker_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        let total: i64 = query_scalar("SELECT COUNT(*) FROM user_blocks WHERE blocker_id = $1")
            .bind(blocker_id)
            .fetch_one(self.pool())
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

        Ok((rows, total))
    }
}
