use sqlx::{PgPool, Row};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use crate::database::models::{Message, MessageType};

pub struct MessageStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> MessageStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self { Self { pool } }

    pub async fn create_message(
        &self,
        room_id: Uuid,
        sender_id: Uuid,
        content: String,
        message_type: MessageType,
    ) -> Result<Message, sqlx::Error> {
        let rec = sqlx::query_as::<_, Message>(
            "INSERT INTO messages (room_id, sender_id, content, message_type)
             VALUES ($1, $2, $3, $4)
             RETURNING id, room_id, sender_id, content, message_type, created_at, updated_at",
        )
        .bind(room_id)
        .bind(sender_id)
        .bind(content)
        .bind(message_type)
        .fetch_one(self.pool)
        .await?;
        Ok(rec)
    }

    pub async fn get_room_messages(
        &self,
        room_id: Uuid,
        limit: i64,
    ) -> Result<Vec<Message>, sqlx::Error> {
        let rows = sqlx::query_as::<_, Message>(
            "SELECT id, room_id, sender_id, content, message_type, created_at, updated_at
             FROM messages WHERE room_id = $1
             ORDER BY created_at DESC
             LIMIT $2",
        )
        .bind(room_id)
        .bind(limit)
        .fetch_all(self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn user_in_room(&self, room_id: Uuid, user_id: Uuid) -> Result<bool, sqlx::Error> {
        let exists: Option<(Uuid,)> = sqlx::query_as(
            "SELECT user_id FROM room_members WHERE room_id = $1 AND user_id = $2 LIMIT 1",
        )
        .bind(room_id)
        .bind(user_id)
        .fetch_optional(self.pool)
        .await?;
        Ok(exists.is_some())
    }
}
