use crate::database::models::{MessageRead, User};
use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

pub struct MessageReadStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> MessageReadStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn mark_message_read(
        &self,
        message_id: Uuid,
        user_id: Uuid,
        room_id: Uuid,
    ) -> Result<MessageRead, sqlx::Error> {
        let record_id = crate::id::generate();
        let rec = sqlx::query_as::<_, MessageRead>(
            "INSERT INTO message_reads (id, message_id, user_id, room_id)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (message_id, user_id) DO UPDATE SET read_at = NOW()
             RETURNING id, message_id, user_id, room_id, read_at",
        )
        .bind(record_id)
        .bind(message_id)
        .bind(user_id)
        .bind(room_id)
        .fetch_one(self.pool)
        .await?;

        sqlx::query(
            "UPDATE room_members
             SET last_read_at = NOW(), last_read_message_id = $1
             WHERE room_id = $2 AND user_id = $3 AND deleted_at IS NULL",
        )
        .bind(message_id)
        .bind(room_id)
        .bind(user_id)
        .execute(self.pool)
        .await?;

        Ok(rec)
    }

    pub async fn mark_messages_read_until(
        &self,
        room_id: Uuid,
        user_id: Uuid,
        until_message_id: Uuid,
    ) -> Result<i64, sqlx::Error> {
        let message_time: Option<(DateTime<Utc>,)> =
            sqlx::query_as("SELECT created_at FROM messages WHERE id = $1")
                .bind(until_message_id)
                .fetch_optional(self.pool)
                .await?;

        if let Some((created_at,)) = message_time {
            let mut tx = self.pool.begin().await?;

            let message_ids: Vec<Uuid> = sqlx::query_scalar(
                "SELECT m.id
                 FROM messages m
                 WHERE m.room_id = $1
                   AND m.created_at <= $2
                   AND m.deleted_at IS NULL
                   AND NOT EXISTS (
                       SELECT 1 FROM message_reads mr
                       WHERE mr.message_id = m.id AND mr.user_id = $3
                   )",
            )
            .bind(room_id)
            .bind(created_at)
            .bind(user_id)
            .fetch_all(&mut *tx)
            .await?;

            let mut inserted: u64 = 0;
            for mid in message_ids {
                let result = sqlx::query(
                    "INSERT INTO message_reads (id, message_id, user_id, room_id)
                     VALUES ($1, $2, $3, $4)
                     ON CONFLICT (message_id, user_id) DO NOTHING",
                )
                .bind(crate::id::generate())
                .bind(mid)
                .bind(user_id)
                .bind(room_id)
                .execute(&mut *tx)
                .await?;

                inserted += result.rows_affected();
            }

            sqlx::query(
                "UPDATE room_members
                 SET last_read_at = NOW(), last_read_message_id = $1
                 WHERE room_id = $2 AND user_id = $3 AND deleted_at IS NULL",
            )
            .bind(until_message_id)
            .bind(room_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;

            tx.commit().await?;

            Ok(inserted as i64)
        } else {
            Ok(0)
        }
    }

    pub async fn get_message_read_users(
        &self,
        message_id: Uuid,
    ) -> Result<Vec<(User, DateTime<Utc>)>, sqlx::Error> {
        let rows = sqlx::query_as::<
            _,
            (
                Uuid,
                String,
                String,
                String,
                Option<String>,
                Option<String>,
                Option<String>,
                crate::database::models::UserStatus,
                DateTime<Utc>,
                DateTime<Utc>,
                Option<DateTime<Utc>>,
                DateTime<Utc>,
            ),
        >(
            "SELECT u.id, u.username, u.email, u.password_hash, u.nickname, u.avatar_url, u.avatar_object_key,
                    u.status, u.created_at, u.updated_at, u.deleted_at, mr.read_at
             FROM message_reads mr
             INNER JOIN users u ON mr.user_id = u.id
             WHERE mr.message_id = $1
             ORDER BY mr.read_at ASC",
        )
        .bind(message_id)
        .fetch_all(self.pool)
        .await?;

        let result = rows
            .into_iter()
            .map(|row| {
                let user = User {
                    id: row.0,
                    username: row.1,
                    email: row.2,
                    password_hash: row.3,
                    nickname: row.4,
                    avatar_url: row.5,
                    avatar_object_key: row.6,
                    status: row.7,
                    created_at: row.8,
                    updated_at: row.9,
                    deleted_at: row.10,
                };
                (user, row.11)
            })
            .collect();

        Ok(result)
    }

    pub async fn get_unread_count(&self, room_id: Uuid, user_id: Uuid) -> Result<i64, sqlx::Error> {
        let last_read_time: Option<(Option<DateTime<Utc>>,)> = sqlx::query_as(
            "SELECT last_read_at FROM room_members
             WHERE room_id = $1 AND user_id = $2 AND deleted_at IS NULL",
        )
        .bind(room_id)
        .bind(user_id)
        .fetch_optional(self.pool)
        .await?;

        if let Some((Some(last_read_at),)) = last_read_time {
            let count: (i64,) = sqlx::query_as(
                "SELECT COUNT(*) FROM messages
                 WHERE room_id = $1
                   AND created_at > $2
                   AND sender_id != $3
                   AND deleted_at IS NULL",
            )
            .bind(room_id)
            .bind(last_read_at)
            .bind(user_id)
            .fetch_one(self.pool)
            .await?;
            Ok(count.0)
        } else {
            let count: (i64,) = sqlx::query_as(
                "SELECT COUNT(*) FROM messages
                 WHERE room_id = $1
                   AND sender_id != $2
                   AND deleted_at IS NULL",
            )
            .bind(room_id)
            .bind(user_id)
            .fetch_one(self.pool)
            .await?;
            Ok(count.0)
        }
    }

    pub async fn get_all_unread_counts(
        &self,
        user_id: Uuid,
    ) -> Result<Vec<(Uuid, i64, Option<Uuid>, Option<DateTime<Utc>>)>, sqlx::Error> {
        let rows = sqlx::query_as::<_, (Uuid, i64, Option<Uuid>, Option<DateTime<Utc>>)>(
            "SELECT rm.room_id,
                    COALESCE(
                        (SELECT COUNT(*)
                         FROM messages m
                         WHERE m.room_id = rm.room_id
                           AND m.sender_id != $1
                           AND m.deleted_at IS NULL
                           AND (rm.last_read_at IS NULL OR m.created_at > rm.last_read_at)
                        ), 0
                    ) as unread_count,
                    rm.last_read_message_id,
                    rm.last_read_at
             FROM room_members rm
             WHERE rm.user_id = $1 AND rm.deleted_at IS NULL
             ORDER BY unread_count DESC",
        )
        .bind(user_id)
        .fetch_all(self.pool)
        .await?;
        Ok(rows)
    }
}
