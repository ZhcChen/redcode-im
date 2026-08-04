use chrono::{DateTime, Utc};
use sqlx::{query_as, query_scalar, FromRow, PgPool};
use uuid::Uuid;

use crate::database::models::MessageType;
use crate::database::Database;
use crate::error::AppError;

/// 收藏列表项（含消息基础信息）
#[derive(Debug, Clone, FromRow)]
pub struct FavoriteMessageRecord {
    pub message_id: Uuid,
    pub room_id: Uuid,
    pub sender_id: Uuid,
    pub content: String,
    pub message_type: MessageType,
    pub message_created_at: DateTime<Utc>,
    pub favorited_at: DateTime<Utc>,
}

#[derive(Clone)]
pub struct MessageFavoriteStore {
    database: Database,
}

impl MessageFavoriteStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    fn pool(&self) -> &PgPool {
        &self.database.pool
    }

    /// 收藏消息（幂等）。
    pub async fn favorite(
        &self,
        user_id: Uuid,
        room_id: Uuid,
        message_id: Uuid,
    ) -> Result<bool, AppError> {
        let result = sqlx::query(
            "INSERT INTO message_favorites (user_id, room_id, message_id)
             VALUES ($1, $2, $3)
             ON CONFLICT (user_id, message_id) DO NOTHING",
        )
        .bind(user_id)
        .bind(room_id)
        .bind(message_id)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }

    /// 取消收藏。返回是否删除成功。
    pub async fn unfavorite(
        &self,
        user_id: Uuid,
        message_id: Uuid,
    ) -> Result<bool, AppError> {
        let result = sqlx::query(
            "DELETE FROM message_favorites WHERE user_id = $1 AND message_id = $2",
        )
        .bind(user_id)
        .bind(message_id)
        .execute(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }

    /// 分页列出当前用户收藏的消息（按收藏时间倒序）。
    pub async fn list_favorites(
        &self,
        user_id: Uuid,
        limit: i64,
        offset: i64,
    ) -> Result<(Vec<FavoriteMessageRecord>, i64), AppError> {
        let rows = query_as::<_, FavoriteMessageRecord>(
            r#"
            SELECT mf.message_id, mf.room_id, m.sender_id, m.content,
                   m.message_type, m.created_at AS message_created_at,
                   mf.created_at AS favorited_at
            FROM message_favorites mf
            JOIN messages m ON m.id = mf.message_id
            WHERE mf.user_id = $1
            ORDER BY mf.created_at DESC
            LIMIT $2 OFFSET $3
            "#,
        )
        .bind(user_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        let total: i64 =
            query_scalar("SELECT COUNT(*) FROM message_favorites WHERE user_id = $1")
                .bind(user_id)
                .fetch_one(self.pool())
                .await
                .map_err(|e| AppError::DatabaseError(e))?;

        Ok((rows, total))
    }
}
