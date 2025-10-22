use crate::database::models::{Message, MessageType, MessageWithSender};
use sqlx::PgPool;
use uuid::Uuid;

pub struct MessageStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> MessageStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

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
             RETURNING id, room_id, sender_id, content, message_type, created_at, updated_at, deleted_at",
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
    ) -> Result<Vec<MessageWithSender>, sqlx::Error> {
        let rows = sqlx::query_as::<_, MessageWithSender>(
            r#"
             SELECT
                 m.id,
                 m.room_id,
                 m.sender_id,
                 m.content,
                 m.message_type,
                 m.created_at,
                 m.updated_at,
                 m.deleted_at,
                 u.username AS sender_username,
                 u.nickname AS sender_nickname,
                 u.avatar_url AS sender_avatar_url
             FROM messages m
             JOIN users u ON u.id = m.sender_id
             WHERE m.room_id = $1
               AND m.deleted_at IS NULL
             ORDER BY m.created_at DESC
             LIMIT $2
            "#,
        )
        .bind(room_id)
        .bind(limit)
        .fetch_all(self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn get_message(&self, message_id: Uuid) -> Result<Option<Message>, sqlx::Error> {
        let row = sqlx::query_as::<_, Message>(
            "SELECT id, room_id, sender_id, content, message_type, created_at, updated_at, deleted_at
             FROM messages WHERE id = $1",
        )
        .bind(message_id)
        .fetch_optional(self.pool)
        .await?;
        Ok(row)
    }

    pub async fn get_room_messages_paged(
        &self,
        room_id: Uuid,
        limit: i64,
        before: Option<Uuid>,
        since: Option<Uuid>,
    ) -> Result<Vec<MessageWithSender>, sqlx::Error> {
        if let Some(before_id) = before {
            if let Some(m) = self.get_message(before_id).await? {
                let rows = sqlx::query_as::<_, MessageWithSender>(
                    r#"
                     SELECT
                         m.id,
                         m.room_id,
                         m.sender_id,
                         m.content,
                         m.message_type,
                         m.created_at,
                         m.updated_at,
                         m.deleted_at,
                         u.username AS sender_username,
                         u.nickname AS sender_nickname,
                         u.avatar_url AS sender_avatar_url
                     FROM messages m
                     JOIN users u ON u.id = m.sender_id
                     WHERE m.room_id = $1
                       AND m.deleted_at IS NULL
                       AND m.created_at < $2
                     ORDER BY m.created_at DESC
                     LIMIT $3
                    "#,
                )
                .bind(room_id)
                .bind(m.created_at)
                .bind(limit)
                .fetch_all(self.pool)
                .await?;
                return Ok(rows);
            }
        }
        if let Some(since_id) = since {
            if let Some(m) = self.get_message(since_id).await? {
                let rows = sqlx::query_as::<_, MessageWithSender>(
                    r#"
                     SELECT
                         m.id,
                         m.room_id,
                         m.sender_id,
                         m.content,
                         m.message_type,
                         m.created_at,
                         m.updated_at,
                         m.deleted_at,
                         u.username AS sender_username,
                         u.nickname AS sender_nickname,
                         u.avatar_url AS sender_avatar_url
                     FROM messages m
                     JOIN users u ON u.id = m.sender_id
                     WHERE m.room_id = $1
                       AND m.deleted_at IS NULL
                       AND m.created_at > $2
                     ORDER BY m.created_at ASC
                     LIMIT $3
                    "#,
                )
                .bind(room_id)
                .bind(m.created_at)
                .bind(limit)
                .fetch_all(self.pool)
                .await?;
                let mut rows = rows;
                rows.reverse();
                return Ok(rows);
            }
        }
        self.get_room_messages(room_id, limit).await
    }

    pub async fn get_message_with_sender(
        &self,
        message_id: Uuid,
    ) -> Result<Option<MessageWithSender>, sqlx::Error> {
        let row = sqlx::query_as::<_, MessageWithSender>(
            r#"
             SELECT
                 m.id,
                 m.room_id,
                 m.sender_id,
                 m.content,
                 m.message_type,
                 m.created_at,
                 m.updated_at,
                 m.deleted_at,
                 u.username AS sender_username,
                 u.nickname AS sender_nickname,
                 u.avatar_url AS sender_avatar_url
             FROM messages m
             JOIN users u ON u.id = m.sender_id
             WHERE m.id = $1
            "#,
        )
        .bind(message_id)
        .fetch_optional(self.pool)
        .await?;
        Ok(row)
    }

    pub async fn user_in_room(&self, room_id: Uuid, user_id: Uuid) -> Result<bool, sqlx::Error> {
        let exists: Option<(Uuid,)> = sqlx::query_as(
            "SELECT user_id FROM room_members
             WHERE room_id = $1 AND user_id = $2 AND deleted_at IS NULL
             LIMIT 1",
        )
        .bind(room_id)
        .bind(user_id)
        .fetch_optional(self.pool)
        .await?;
        Ok(exists.is_some())
    }
}
