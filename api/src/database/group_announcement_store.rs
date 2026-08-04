use chrono::{DateTime, Utc};
use sqlx::{query_as, PgPool};
use uuid::Uuid;

use crate::database::Database;
use crate::error::AppError;

/// 群公告记录（每群至多一条，覆盖式更新）
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct GroupAnnouncementRecord {
    pub room_id: Uuid,
    pub content: String,
    pub created_by: Uuid,
    pub updated_by: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Clone)]
pub struct GroupAnnouncementStore {
    database: Database,
}

impl GroupAnnouncementStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    fn pool(&self) -> &PgPool {
        &self.database.pool
    }

    pub async fn get(&self, room_id: Uuid) -> Result<Option<GroupAnnouncementRecord>, AppError> {
        let record = query_as::<_, GroupAnnouncementRecord>(
            r#"
            SELECT room_id, content, created_by, updated_by, created_at, updated_at
            FROM group_announcements
            WHERE room_id = $1
            "#,
        )
        .bind(room_id)
        .fetch_optional(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(record)
    }

    pub async fn upsert(
        &self,
        room_id: Uuid,
        content: String,
        user_id: Uuid,
    ) -> Result<GroupAnnouncementRecord, AppError> {
        let record = query_as::<_, GroupAnnouncementRecord>(
            r#"
            INSERT INTO group_announcements (room_id, content, created_by, updated_by)
            VALUES ($1, $2, $3, $3)
            ON CONFLICT (room_id) DO UPDATE
                SET content = EXCLUDED.content,
                    updated_by = EXCLUDED.updated_by,
                    updated_at = NOW()
            RETURNING room_id, content, created_by, updated_by, created_at, updated_at
            "#,
        )
        .bind(room_id)
        .bind(content)
        .bind(user_id)
        .fetch_one(self.pool())
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(record)
    }

    pub async fn delete(&self, room_id: Uuid) -> Result<bool, AppError> {
        let result = sqlx::query("DELETE FROM group_announcements WHERE room_id = $1")
            .bind(room_id)
            .execute(self.pool())
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }
}
