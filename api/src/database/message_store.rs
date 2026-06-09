use crate::database::models::{
    Message, MessagePart, MessagePartType, MessageType, MessageWithSender, RoomPin,
};
use serde_json::Value;
use sqlx::{PgPool, Postgres, Transaction};
use std::collections::HashMap;
use uuid::Uuid;

pub struct MessageStore<'a> {
    pub pool: &'a PgPool,
}

pub struct NewMessagePart {
    pub position: i16,
    pub part_type: MessagePartType,
    pub text_content: Option<String>,
    pub attachment_key: Option<String>,
    pub attachment_name: Option<String>,
    pub attachment_mime: Option<String>,
    pub attachment_size: Option<i64>,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub duration_ms: Option<i32>,
    pub thumbnail_key: Option<String>,
    pub extra: Option<Value>,
}

async fn insert_message_parts(
    tx: &mut Transaction<'_, Postgres>,
    message_id: Uuid,
    parts: &[NewMessagePart],
) -> Result<(), sqlx::Error> {
    for part in parts {
        sqlx::query(
            "INSERT INTO message_parts (
                id,
                message_id,
                position,
                part_type,
                text_content,
                attachment_key,
                attachment_name,
                attachment_mime,
                attachment_size,
                width,
                height,
                duration_ms,
                thumbnail_key,
                extra
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)",
        )
        .bind(crate::id::generate())
        .bind(message_id)
        .bind(part.position)
        .bind(part.part_type)
        .bind(part.text_content.as_ref())
        .bind(part.attachment_key.as_ref())
        .bind(part.attachment_name.as_ref())
        .bind(part.attachment_mime.as_ref())
        .bind(part.attachment_size)
        .bind(part.width)
        .bind(part.height)
        .bind(part.duration_ms)
        .bind(part.thumbnail_key.as_ref())
        .bind(part.extra.as_ref())
        .execute(&mut **tx)
        .await?;
    }

    Ok(())
}

impl<'a> MessageStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    /// 校验某个 object_key 是否已被该房间内的消息引用（附件或缩略图）。
    ///
    /// 用途：生成附件下载链接时做访问控制，避免仅凭 object_key 即可下载任意文件。
    pub async fn room_has_message_object_key(
        &self,
        room_id: Uuid,
        object_key: &str,
    ) -> Result<bool, sqlx::Error> {
        let exists: Option<(i32,)> = sqlx::query_as(
            r#"
            SELECT 1
            FROM messages m
            JOIN message_parts p ON p.message_id = m.id
            WHERE m.room_id = $1
              AND m.deleted_at IS NULL
              AND (p.attachment_key = $2 OR p.thumbnail_key = $2)
            LIMIT 1
            "#,
        )
        .bind(room_id)
        .bind(object_key)
        .fetch_optional(self.pool)
        .await?;

        Ok(exists.is_some())
    }

    pub async fn create_message_with_parts(
        &self,
        room_id: Uuid,
        sender_id: Uuid,
        content_summary: String,
        message_type: MessageType,
        quoted_message_id: Option<Uuid>,
        parts: &[NewMessagePart],
    ) -> Result<Message, sqlx::Error> {
        let mut tx = self.pool.begin().await?;
        let message_id = crate::id::generate();

        let message = sqlx::query_as::<_, Message>(
            "INSERT INTO messages (id, room_id, sender_id, content, message_type, quoted_message_id)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING id, room_id, sender_id, content, encrypted_content, encryption_metadata, message_type, quoted_message_id,
                       forward_from_message_id, forward_from_room_id, forward_from_sender_id,
                       forward_from_sender_username, forward_from_sender_nickname,
                       created_at, updated_at, deleted_at",
        )
        .bind(message_id)
        .bind(room_id)
        .bind(sender_id)
        .bind(content_summary)
        .bind(message_type)
        .bind(quoted_message_id)
        .fetch_one(&mut *tx)
        .await?;

        if !parts.is_empty() {
            insert_message_parts(&mut tx, message_id, parts).await?;
        }

        tx.commit().await?;
        Ok(message)
    }

    pub async fn create_encrypted_message_with_parts(
        &self,
        room_id: Uuid,
        sender_id: Uuid,
        content_summary: String,
        encrypted_content: Vec<u8>,
        encryption_metadata: Option<Value>,
        message_type: MessageType,
        quoted_message_id: Option<Uuid>,
        parts: &[NewMessagePart],
    ) -> Result<Message, sqlx::Error> {
        let mut tx = self.pool.begin().await?;
        let message_id = crate::id::generate();

        let message = sqlx::query_as::<_, Message>(
            "INSERT INTO messages (
                id,
                room_id,
                sender_id,
                content,
                encrypted_content,
                encryption_metadata,
                message_type,
                quoted_message_id
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id, room_id, sender_id, content, encrypted_content, encryption_metadata, message_type, quoted_message_id,
                      forward_from_message_id, forward_from_room_id, forward_from_sender_id,
                      forward_from_sender_username, forward_from_sender_nickname,
                      created_at, updated_at, deleted_at",
        )
        .bind(message_id)
        .bind(room_id)
        .bind(sender_id)
        .bind(content_summary)
        .bind(encrypted_content)
        .bind(encryption_metadata)
        .bind(message_type)
        .bind(quoted_message_id)
        .fetch_one(&mut *tx)
        .await?;

        if !parts.is_empty() {
            insert_message_parts(&mut tx, message_id, parts).await?;
        }

        tx.commit().await?;
        Ok(message)
    }

    pub async fn create_message(
        &self,
        room_id: Uuid,
        sender_id: Uuid,
        content: String,
        message_type: MessageType,
        quoted_message_id: Option<Uuid>,
    ) -> Result<Message, sqlx::Error> {
        let parts = [NewMessagePart {
            position: 0,
            part_type: MessagePartType::Text,
            text_content: Some(content.clone()),
            attachment_key: None,
            attachment_name: None,
            attachment_mime: None,
            attachment_size: None,
            width: None,
            height: None,
            duration_ms: None,
            thumbnail_key: None,
            extra: None,
        }];

        self.create_message_with_parts(
            room_id,
            sender_id,
            content,
            message_type,
            quoted_message_id,
            &parts,
        )
        .await
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
                 m.encrypted_content,
                 m.encryption_metadata,
                 m.message_type,
                 m.quoted_message_id,
                 m.created_at,
                 m.updated_at,
                 m.deleted_at,
                 m.edited_at,
                 m.forward_from_message_id,
                 m.forward_from_room_id,
                 m.forward_from_sender_id,
                 m.forward_from_sender_username,
                 m.forward_from_sender_nickname,
                 u.username AS sender_username,
                 u.nickname AS sender_nickname,
                 u.avatar_url AS sender_avatar_url,
                 qm.room_id AS quoted_message_room_id,
                 qm.sender_id AS quoted_message_sender_id,
                 qu.username AS quoted_message_sender_username,
                 qu.nickname AS quoted_message_sender_nickname,
                 qu.avatar_url AS quoted_message_sender_avatar_url,
                 qm.content AS quoted_message_content,
                 qm.message_type AS quoted_message_type,
                 qm.created_at AS quoted_message_created_at,
                 qm.deleted_at AS quoted_message_deleted_at
             FROM messages m
             JOIN users u ON u.id = m.sender_id
             LEFT JOIN messages qm ON qm.id = m.quoted_message_id
             LEFT JOIN users qu ON qu.id = qm.sender_id
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

    pub async fn get_message_parts_map(
        &self,
        message_ids: &[Uuid],
    ) -> Result<HashMap<Uuid, Vec<MessagePart>>, sqlx::Error> {
        if message_ids.is_empty() {
            return Ok(HashMap::new());
        }

        let mut unique_ids: Vec<Uuid> = message_ids.to_vec();
        unique_ids.sort_unstable();
        unique_ids.dedup();

        let rows = sqlx::query_as::<_, MessagePart>(
            r#"
            SELECT
                id,
                message_id,
                position,
                part_type,
                text_content,
                attachment_key,
                attachment_name,
                attachment_mime,
                attachment_size,
                width,
                height,
                duration_ms,
                thumbnail_key,
                extra,
                created_at
            FROM message_parts
            WHERE message_id = ANY($1)
            ORDER BY message_id, position
            "#,
        )
        .bind(&unique_ids)
        .fetch_all(self.pool)
        .await?;

        let mut map: HashMap<Uuid, Vec<MessagePart>> = HashMap::new();
        for part in rows {
            map.entry(part.message_id).or_default().push(part);
        }
        Ok(map)
    }

    pub async fn get_message(&self, message_id: Uuid) -> Result<Option<Message>, sqlx::Error> {
        let row = sqlx::query_as::<_, Message>(
            "SELECT id, room_id, sender_id, content, encrypted_content, encryption_metadata, message_type, quoted_message_id,
                    forward_from_message_id, forward_from_room_id, forward_from_sender_id,
                    forward_from_sender_username, forward_from_sender_nickname,
                    created_at, updated_at, deleted_at
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
                         m.encrypted_content,
                         m.encryption_metadata,
                         m.message_type,
                         m.quoted_message_id,
                         m.created_at,
                         m.updated_at,
                         m.deleted_at,
                         m.edited_at,
                         m.forward_from_message_id,
                         m.forward_from_room_id,
                         m.forward_from_sender_id,
                         m.forward_from_sender_username,
                         m.forward_from_sender_nickname,
                         u.username AS sender_username,
                         u.nickname AS sender_nickname,
                         u.avatar_url AS sender_avatar_url,
                         qm.room_id AS quoted_message_room_id,
                         qm.sender_id AS quoted_message_sender_id,
                         qu.username AS quoted_message_sender_username,
                         qu.nickname AS quoted_message_sender_nickname,
                         qu.avatar_url AS quoted_message_sender_avatar_url,
                         qm.content AS quoted_message_content,
                         qm.message_type AS quoted_message_type,
                         qm.created_at AS quoted_message_created_at,
                         qm.deleted_at AS quoted_message_deleted_at
                     FROM messages m
                     JOIN users u ON u.id = m.sender_id
                     LEFT JOIN messages qm ON qm.id = m.quoted_message_id
                     LEFT JOIN users qu ON qu.id = qm.sender_id
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
                         m.encrypted_content,
                         m.encryption_metadata,
                         m.message_type,
                         m.quoted_message_id,
                         m.created_at,
                         m.updated_at,
                         m.deleted_at,
                         m.edited_at,
                         m.forward_from_message_id,
                         m.forward_from_room_id,
                         m.forward_from_sender_id,
                         m.forward_from_sender_username,
                         m.forward_from_sender_nickname,
                         u.username AS sender_username,
                         u.nickname AS sender_nickname,
                         u.avatar_url AS sender_avatar_url,
                         qm.room_id AS quoted_message_room_id,
                         qm.sender_id AS quoted_message_sender_id,
                         qu.username AS quoted_message_sender_username,
                         qu.nickname AS quoted_message_sender_nickname,
                         qu.avatar_url AS quoted_message_sender_avatar_url,
                         qm.content AS quoted_message_content,
                         qm.message_type AS quoted_message_type,
                         qm.created_at AS quoted_message_created_at,
                         qm.deleted_at AS quoted_message_deleted_at
                     FROM messages m
                     JOIN users u ON u.id = m.sender_id
                     LEFT JOIN messages qm ON qm.id = m.quoted_message_id
                     LEFT JOIN users qu ON qu.id = qm.sender_id
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
                 m.encrypted_content,
                 m.encryption_metadata,
                 m.message_type,
                 m.quoted_message_id,
                 m.created_at,
                 m.updated_at,
                 m.deleted_at,
                 m.edited_at,
                 m.forward_from_message_id,
                 m.forward_from_room_id,
                 m.forward_from_sender_id,
                 m.forward_from_sender_username,
                 m.forward_from_sender_nickname,
                 u.username AS sender_username,
                 u.nickname AS sender_nickname,
                 u.avatar_url AS sender_avatar_url,
                 qm.room_id AS quoted_message_room_id,
                 qm.sender_id AS quoted_message_sender_id,
                 qu.username AS quoted_message_sender_username,
                 qu.nickname AS quoted_message_sender_nickname,
                 qu.avatar_url AS quoted_message_sender_avatar_url,
                 qm.content AS quoted_message_content,
                 qm.message_type AS quoted_message_type,
                 qm.created_at AS quoted_message_created_at,
                 qm.deleted_at AS quoted_message_deleted_at
             FROM messages m
             JOIN users u ON u.id = m.sender_id
             LEFT JOIN messages qm ON qm.id = m.quoted_message_id
             LEFT JOIN users qu ON qu.id = qm.sender_id
            WHERE m.id = $1
           "#,
        )
        .bind(message_id)
        .fetch_optional(self.pool)
        .await?;
        Ok(row)
    }

    pub async fn create_forward_message(
        &self,
        target_room_id: Uuid,
        sender_id: Uuid,
        original: &MessageWithSender,
        original_parts: &[MessagePart],
    ) -> Result<Message, sqlx::Error> {
        let message_id = crate::id::generate();

        let (origin_message_id, origin_room_id, origin_sender_id, origin_username, origin_nickname) =
            if let Some(forward_id) = original.forward_from_message_id {
                (
                    forward_id,
                    original.forward_from_room_id.unwrap_or(original.room_id),
                    original
                        .forward_from_sender_id
                        .unwrap_or(original.sender_id),
                    original
                        .forward_from_sender_username
                        .clone()
                        .or_else(|| Some(original.sender_username.clone())),
                    original
                        .forward_from_sender_nickname
                        .clone()
                        .or_else(|| original.sender_nickname.clone()),
                )
            } else {
                (
                    original.id,
                    original.room_id,
                    original.sender_id,
                    Some(original.sender_username.clone()),
                    original.sender_nickname.clone(),
                )
            };

        let mut tx = self.pool.begin().await?;

        let rec = sqlx::query_as::<_, Message>(
            "INSERT INTO messages (
                id, room_id, sender_id, content, message_type, quoted_message_id,
                forward_from_message_id, forward_from_room_id, forward_from_sender_id,
                forward_from_sender_username, forward_from_sender_nickname
            ) VALUES ($1, $2, $3, $4, $5, NULL, $6, $7, $8, $9, $10)
            RETURNING id, room_id, sender_id, content, encrypted_content, encryption_metadata, message_type, quoted_message_id,
                      forward_from_message_id, forward_from_room_id, forward_from_sender_id,
                      forward_from_sender_username, forward_from_sender_nickname,
                      created_at, updated_at, deleted_at",
        )
        .bind(message_id)
        .bind(target_room_id)
        .bind(sender_id)
        .bind(&original.content)
        .bind(original.message_type)
        .bind(origin_message_id)
        .bind(origin_room_id)
        .bind(origin_sender_id)
        .bind(origin_username)
        .bind(origin_nickname)
        .fetch_one(&mut *tx)
        .await?;

        // 复制原消息的所有 parts（包括图片、视频、文件等附件）
        let parts: Vec<NewMessagePart> = if original_parts.is_empty() {
            // 如果没有 parts，创建一个文本 part
            vec![NewMessagePart {
                position: 0,
                part_type: MessagePartType::Text,
                text_content: Some(original.content.clone()),
                attachment_key: None,
                attachment_name: None,
                attachment_mime: None,
                attachment_size: None,
                width: None,
                height: None,
                duration_ms: None,
                thumbnail_key: None,
                extra: None,
            }]
        } else {
            // 复制原消息的所有 parts
            original_parts
                .iter()
                .map(|p| NewMessagePart {
                    position: p.position,
                    part_type: p.part_type,
                    text_content: p.text_content.clone(),
                    attachment_key: p.attachment_key.clone(),
                    attachment_name: p.attachment_name.clone(),
                    attachment_mime: p.attachment_mime.clone(),
                    attachment_size: p.attachment_size,
                    width: p.width,
                    height: p.height,
                    duration_ms: p.duration_ms,
                    thumbnail_key: p.thumbnail_key.clone(),
                    extra: p.extra.clone(),
                })
                .collect()
        };

        insert_message_parts(&mut tx, message_id, &parts).await?;

        tx.commit().await?;

        Ok(rec)
    }

    /// 获取房间内所有置顶记录（支持多条置顶）
    pub async fn get_room_pins(&self, room_id: Uuid) -> Result<Vec<RoomPin>, sqlx::Error> {
        let rows = sqlx::query_as::<_, RoomPin>(
            "SELECT room_id, message_id, pinned_by, pinned_at
             FROM room_pins
             WHERE room_id = $1
             ORDER BY pinned_at ASC",
        )
        .bind(room_id)
        .fetch_all(self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn upsert_room_pin(
        &self,
        room_id: Uuid,
        message_id: Uuid,
        pinned_by: Uuid,
    ) -> Result<RoomPin, sqlx::Error> {
        let row = sqlx::query_as::<_, RoomPin>(
            "INSERT INTO room_pins (room_id, message_id, pinned_by, pinned_at)
             VALUES ($1, $2, $3, NOW())
             ON CONFLICT ON CONSTRAINT room_pins_pkey
             DO UPDATE SET pinned_by = EXCLUDED.pinned_by,
                           pinned_at = NOW()
             RETURNING room_id, message_id, pinned_by, pinned_at",
        )
        .bind(room_id)
        .bind(message_id)
        .bind(pinned_by)
        .fetch_one(self.pool)
        .await?;
        Ok(row)
    }

    pub async fn remove_room_pin(
        &self,
        room_id: Uuid,
        message_id: Option<Uuid>,
    ) -> Result<u64, sqlx::Error> {
        let result = if let Some(msg_id) = message_id {
            sqlx::query("DELETE FROM room_pins WHERE room_id = $1 AND message_id = $2")
                .bind(room_id)
                .bind(msg_id)
                .execute(self.pool)
                .await?
        } else {
            sqlx::query("DELETE FROM room_pins WHERE room_id = $1")
                .bind(room_id)
                .execute(self.pool)
                .await?
        };
        Ok(result.rows_affected())
    }

    pub async fn mark_message_deleted(
        &self,
        message_id: Uuid,
    ) -> Result<Option<Message>, sqlx::Error> {
        let row = sqlx::query_as::<_, Message>(
            "UPDATE messages
             SET deleted_at = NOW()
             WHERE id = $1 AND deleted_at IS NULL
             RETURNING id, room_id, sender_id, content, encrypted_content, encryption_metadata, message_type, quoted_message_id,
                       forward_from_message_id, forward_from_room_id, forward_from_sender_id,
                       forward_from_sender_username, forward_from_sender_nickname,
                       created_at, updated_at, deleted_at",
        )
        .bind(message_id)
        .fetch_optional(self.pool)
        .await?;
        Ok(row)
    }

    /// 更新消息内容（编辑消息）
    pub async fn update_message_content(
        &self,
        message_id: Uuid,
        new_content: &str,
    ) -> Result<Option<Message>, sqlx::Error> {
        let row = sqlx::query_as::<_, Message>(
            "UPDATE messages
             SET content = $2, edited_at = NOW(), updated_at = NOW()
             WHERE id = $1 AND deleted_at IS NULL
             RETURNING id, room_id, sender_id, content, encrypted_content, encryption_metadata, message_type, quoted_message_id,
                       forward_from_message_id, forward_from_room_id, forward_from_sender_id,
                       forward_from_sender_username, forward_from_sender_nickname,
                       created_at, updated_at, deleted_at",
        )
        .bind(message_id)
        .bind(new_content)
        .fetch_optional(self.pool)
        .await?;
        Ok(row)
    }

    pub async fn mark_room_messages_deleted(&self, room_id: Uuid) -> Result<u64, sqlx::Error> {
        let result = sqlx::query(
            r#"
            UPDATE messages
            SET deleted_at = NOW()
            WHERE room_id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(room_id)
        .execute(self.pool)
        .await?;

        Ok(result.rows_affected())
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
