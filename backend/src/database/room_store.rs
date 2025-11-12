use chrono::Utc;
use sqlx::{PgConnection, PgPool, Row};
use uuid::Uuid;

use crate::database::models::{
    ChatSummaryRow, MemberRole, Room, RoomMember, RoomType, UserRoomPin,
};

pub struct RoomStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> RoomStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    pub async fn create_room(
        &self,
        owner_id: Uuid,
        name: String,
        description: Option<String>,
        room_type: Option<RoomType>,
    ) -> Result<Room, sqlx::Error> {
        self.create_room_with_members(owner_id, name, description, room_type, &[])
            .await
    }

    pub async fn create_room_with_members(
        &self,
        owner_id: Uuid,
        name: String,
        description: Option<String>,
        room_type: Option<RoomType>,
        member_ids: &[Uuid],
    ) -> Result<Room, sqlx::Error> {
        let mut tx = self.pool.begin().await?;
        let rt = room_type.unwrap_or(RoomType::Group);
        let room_id = crate::id::generate();

        let rec = sqlx::query_as::<_, Room>(
            r#"
            INSERT INTO rooms (id, name, description, room_type, owner_id)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, name, description, avatar_url, room_type, owner_id, created_at, updated_at, deleted_at
            "#,
        )
        .bind(room_id)
        .bind(name)
        .bind(description)
        .bind(rt.clone())
        .bind(owner_id)
        .fetch_one(&mut *tx)
        .await?;

        // 房主默认加入并设为 Owner
        let _ = upsert_member_conn(tx.as_mut(), rec.id, owner_id, MemberRole::Owner).await?;

        // 其他初始成员加入群组
        for member_id in member_ids {
            if *member_id == owner_id {
                continue;
            }
            let _ = upsert_member_conn(tx.as_mut(), rec.id, *member_id, MemberRole::Member).await?;
        }

        tx.commit().await?;

        Ok(rec)
    }

    pub async fn find_private_room(
        &self,
        user_a: Uuid,
        user_b: Uuid,
    ) -> Result<Option<Room>, sqlx::Error> {
        let (first, second) = if user_a <= user_b {
            (user_a, user_b)
        } else {
            (user_b, user_a)
        };

        let room = sqlx::query_as::<_, Room>(
            r#"
            SELECT r.id, r.name, r.description, r.avatar_url, r.room_type, r.owner_id, r.created_at, r.updated_at, r.deleted_at
            FROM rooms r
            JOIN room_members m1 ON m1.room_id = r.id AND m1.user_id = $1
            JOIN room_members m2 ON m2.room_id = r.id AND m2.user_id = $2
            WHERE r.room_type = $3 AND r.deleted_at IS NULL
            ORDER BY r.created_at DESC
            LIMIT 1
            "#,
        )
        .bind(first)
        .bind(second)
        .bind(RoomType::Private)
        .fetch_optional(self.pool)
        .await?;

        Ok(room)
    }

    pub async fn ensure_private_room(
        &self,
        user_a: Uuid,
        user_b: Uuid,
        name: String,
    ) -> Result<Room, sqlx::Error> {
        if let Some(room) = self.find_private_room(user_a, user_b).await? {
            if room.name != name {
                let updated = sqlx::query_as::<_, Room>(
                    r#"
                    UPDATE rooms
                    SET name = $2, updated_at = NOW()
                    WHERE id = $1
                    RETURNING id, name, description, avatar_url, room_type, owner_id, created_at, updated_at, deleted_at
                    "#,
                )
                .bind(room.id)
                .bind(&name)
                .fetch_one(self.pool)
                .await?;

                let _ = self
                    .add_member(updated.id, user_a, Some(MemberRole::Owner))
                    .await?;
                let _ = self
                    .add_member(updated.id, user_b, Some(MemberRole::Member))
                    .await?;
                return Ok(updated);
            }

            let _ = self
                .add_member(room.id, user_a, Some(MemberRole::Owner))
                .await?;
            let _ = self
                .add_member(room.id, user_b, Some(MemberRole::Member))
                .await?;
            return Ok(room);
        }

        let room = self
            .create_room(user_a, name.clone(), None, Some(RoomType::Private))
            .await?;
        let _ = self
            .add_member(room.id, user_b, Some(MemberRole::Member))
            .await?;
        Ok(room)
    }

    pub async fn add_member(
        &self,
        room_id: Uuid,
        user_id: Uuid,
        role: Option<MemberRole>,
    ) -> Result<RoomMember, sqlx::Error> {
        let role = role.unwrap_or(MemberRole::Member);
        let mut conn = self.pool.acquire().await?;
        upsert_member_conn(conn.as_mut(), room_id, user_id, role).await
    }

    pub async fn remove_member(&self, room_id: Uuid, user_id: Uuid) -> Result<bool, sqlx::Error> {
        let res = sqlx::query(
            r#"UPDATE room_members SET deleted_at = NOW() WHERE room_id = $1 AND user_id = $2 AND deleted_at IS NULL"#,
        )
        .bind(room_id)
        .bind(user_id)
        .execute(self.pool)
        .await?;
        Ok(res.rows_affected() > 0)
    }

    pub async fn is_user_in_room(
        &self,
        room_id: Uuid,
        user_id: Uuid,
    ) -> Result<bool, sqlx::Error> {
        let exists: Option<(Uuid,)> = sqlx::query_as(
            r#"
            SELECT user_id
            FROM room_members
            WHERE room_id = $1 AND user_id = $2 AND deleted_at IS NULL
            LIMIT 1
            "#,
        )
        .bind(room_id)
        .bind(user_id)
        .fetch_optional(self.pool)
        .await?;

        Ok(exists.is_some())
    }

    pub async fn list_members(&self, room_id: Uuid) -> Result<Vec<RoomMember>, sqlx::Error> {
        let rows = sqlx::query_as::<_, RoomMember>(
            r#"
            SELECT id,
                   room_id,
                   user_id,
                   role,
                   joined_at,
                   deleted_at,
                   last_read_at,
                   last_read_message_id
            FROM room_members
            WHERE room_id = $1 AND deleted_at IS NULL
            ORDER BY joined_at ASC
            "#,
        )
        .bind(room_id)
        .fetch_all(self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn list_user_rooms(&self, user_id: Uuid) -> Result<Vec<Room>, sqlx::Error> {
        let rows = sqlx::query_as::<_, Room>(
            r#"
            SELECT r.id, r.name, r.description, r.avatar_url, r.room_type, r.owner_id, r.created_at, r.updated_at, r.deleted_at
            FROM rooms r
            JOIN room_members rm ON rm.room_id = r.id AND rm.deleted_at IS NULL
            WHERE rm.user_id = $1 AND r.deleted_at IS NULL
            ORDER BY r.updated_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn ensure_favorite_room(&self, user_id: Uuid) -> Result<Room, sqlx::Error> {
        loop {
            let mut tx = self.pool.begin().await?;

            if let Some(room) = sqlx::query_as::<_, Room>(
                r#"
                SELECT id, name, description, avatar_url, room_type, owner_id, created_at, updated_at, deleted_at
                FROM rooms
                WHERE owner_id = $1
                  AND room_type = $2
                  AND deleted_at IS NULL
                LIMIT 1
                "#,
            )
            .bind(user_id)
            .bind(RoomType::Favorite)
            .fetch_optional(&mut *tx)
            .await?
            {
                let _ =
                    upsert_member_conn(tx.as_mut(), room.id, user_id, MemberRole::Owner).await?;
                tx.commit().await?;
                return Ok(room);
            }

            let insert_result = sqlx::query_as::<_, Room>(
                r#"
                INSERT INTO rooms (id, name, description, room_type, owner_id)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING id, name, description, avatar_url, room_type, owner_id, created_at, updated_at, deleted_at
                "#,
            )
            .bind(crate::id::generate())
            .bind("收藏夹")
            .bind(Some("保存重要消息、文件与提醒的私人收藏夹".to_string()))
            .bind(RoomType::Favorite)
            .bind(user_id)
            .fetch_one(&mut *tx)
            .await;

            match insert_result {
                Ok(room) => {
                    let _ = upsert_member_conn(tx.as_mut(), room.id, user_id, MemberRole::Owner)
                        .await?;
                    tx.commit().await?;
                    return Ok(room);
                }
                Err(sqlx::Error::Database(db_err)) if db_err.code().as_deref() == Some("23505") => {
                    tx.rollback().await?;
                    continue;
                }
                Err(sqlx::Error::Database(db_err)) => {
                    tx.rollback().await?;
                    return Err(sqlx::Error::Database(db_err));
                }
                Err(other) => {
                    tx.rollback().await?;
                    return Err(other);
                }
            }
        }
    }

    pub async fn list_chat_summaries(
        &self,
        user_id: Uuid,
    ) -> Result<Vec<ChatSummaryRow>, sqlx::Error> {
        let rows = sqlx::query_as::<_, ChatSummaryRow>(
            r#"
            SELECT
                r.id AS room_id,
                r.name AS room_name,
                r.room_type AS room_type,
                r.description AS room_description,
                r.avatar_url AS room_avatar_url,
                CASE WHEN urp.id IS NOT NULL THEN TRUE ELSE FALSE END AS is_pinned,
                lm.id AS last_message_id,
                lm.content AS last_message_content,
                lm.message_type AS last_message_type,
                lm.created_at AS last_message_created_at,
                lm.sender_id AS last_message_sender_id,
                lm.sender_username AS last_message_sender_username,
                lm.sender_nickname AS last_message_sender_nickname,
                COALESCE(uc.unread_count, 0) AS unread_count,
                rm.last_read_message_id AS last_read_message_id,
                rm.last_read_at AS last_read_at,
                rm.notification_settings AS notification_settings,
                fu.friend_user_id AS friend_user_id,
                fu.friend_remark AS friend_remark,
                fu.friend_avatar_object_key AS friend_avatar_object_key
            FROM room_members rm
            JOIN rooms r ON rm.room_id = r.id
            LEFT JOIN user_room_pins urp
                ON urp.user_id = rm.user_id AND urp.room_id = r.id
            LEFT JOIN LATERAL (
                SELECT
                    m.id,
                    m.content,
                    m.message_type,
                    m.created_at,
                    m.sender_id,
                    u.username AS sender_username,
                    u.nickname AS sender_nickname
                FROM messages m
                JOIN users u ON u.id = m.sender_id
                WHERE m.room_id = r.id
                  AND m.deleted_at IS NULL
                ORDER BY m.created_at DESC
                LIMIT 1
            ) lm ON TRUE
            LEFT JOIN LATERAL (
                SELECT COUNT(*) AS unread_count
                FROM messages m2
                WHERE m2.room_id = r.id
                  AND m2.deleted_at IS NULL
                  AND m2.sender_id != rm.user_id
                  AND (rm.last_read_at IS NULL OR m2.created_at > rm.last_read_at)
            ) uc ON TRUE
            LEFT JOIN LATERAL (
                SELECT
                    rm2.user_id AS friend_user_id,
                    u2.avatar_object_key AS friend_avatar_object_key,
                    ufr.remark AS friend_remark
                FROM room_members rm2
                JOIN users u2 ON u2.id = rm2.user_id
                LEFT JOIN user_friend_remarks ufr
                    ON ufr.user_id = rm.user_id
                   AND ufr.friend_user_id = rm2.user_id
                WHERE rm2.room_id = r.id
                  AND rm2.user_id != $1
                  AND rm2.deleted_at IS NULL
                  AND r.room_type = $3
                LIMIT 1
            ) fu ON TRUE
            WHERE rm.user_id = $1
              AND rm.deleted_at IS NULL
              AND r.deleted_at IS NULL
            ORDER BY
                CASE WHEN urp.id IS NULL THEN 1 ELSE 0 END,
                CASE WHEN r.room_type = $2 THEN 0 ELSE 1 END,
                COALESCE(lm.created_at, r.updated_at, r.created_at) DESC
            "#,
        )
        .bind(user_id)
        .bind(RoomType::Favorite)
        .bind(RoomType::Private)
        .fetch_all(self.pool)
        .await?;

        Ok(rows)
    }

    pub async fn update_notification_settings(
        &self,
        room_id: Uuid,
        user_id: Uuid,
        notification_settings: crate::database::models::NotificationSetting,
    ) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            UPDATE room_members
            SET notification_settings = $1
            WHERE room_id = $2 AND user_id = $3 AND deleted_at IS NULL
            "#,
        )
        .bind(notification_settings)
        .bind(room_id)
        .bind(user_id)
        .execute(self.pool)
        .await?;

        Ok(())
    }

    pub async fn delete_chat(&self, room_id: Uuid, user_id: Uuid) -> Result<bool, sqlx::Error> {
        let mut tx = self.pool.begin().await?;

        // 首先检查用户是否有权限删除这个聊天（必须是房间成员）
        let member_check = sqlx::query(
            r#"
            SELECT COUNT(*) as count
            FROM room_members
            WHERE room_id = $1 AND user_id = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(room_id)
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await?;

        let count: i64 = member_check.get("count");
        if count == 0 {
            tx.rollback().await?;
            return Ok(false); // 用户不是房间成员，无权删除
        }

        // 软删除房间
        let room_result = sqlx::query(
            r#"
            UPDATE rooms
            SET deleted_at = NOW()
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(room_id)
        .execute(&mut *tx)
        .await?;

        // 软删除所有房间成员关系
        let members_result = sqlx::query(
            r#"
            UPDATE room_members
            SET deleted_at = NOW()
            WHERE room_id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(room_id)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;

        Ok(room_result.rows_affected() > 0)
    }

    pub async fn pin_room_for_user(&self, user_id: Uuid, room_id: Uuid) -> Result<UserRoomPin, sqlx::Error> {
        let record = sqlx::query_as::<_, UserRoomPin>(
            r#"
            INSERT INTO user_room_pins (user_id, room_id, pinned_at)
            VALUES ($1, $2, NOW())
            ON CONFLICT (user_id, room_id) DO UPDATE SET pinned_at = NOW()
            RETURNING id, user_id, room_id, pinned_at
            "#,
        )
        .bind(user_id)
        .bind(room_id)
        .fetch_one(self.pool)
        .await?;

        Ok(record)
    }

    pub async fn unpin_room_for_user(&self, user_id: Uuid, room_id: Uuid) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            r#"
            DELETE FROM user_room_pins WHERE user_id = $1 AND room_id = $2
            "#,
        )
        .bind(user_id)
        .bind(room_id)
        .execute(self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }
}

async fn upsert_member_conn(
    executor: &mut PgConnection,
    room_id: Uuid,
    user_id: Uuid,
    role: MemberRole,
) -> Result<RoomMember, sqlx::Error> {
    let joined_at = Utc::now();

    if let Some(existing) = sqlx::query_as::<_, RoomMember>(
        r#"
        UPDATE room_members
        SET role = $3,
            joined_at = $4,
            deleted_at = NULL
        WHERE room_id = $1 AND user_id = $2
        RETURNING id,
                  room_id,
                  user_id,
                  role,
                  joined_at,
                  deleted_at,
                  last_read_at,
                  last_read_message_id
        "#,
    )
    .bind(room_id)
    .bind(user_id)
    .bind(role.clone())
    .bind(joined_at)
    .fetch_optional(&mut *executor)
    .await?
    {
        return Ok(existing);
    }

    let inserted = sqlx::query_as::<_, RoomMember>(
        r#"
        INSERT INTO room_members (id, room_id, user_id, role, joined_at)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id,
                  room_id,
                  user_id,
                  role,
                  joined_at,
                  deleted_at,
                  last_read_at,
                  last_read_message_id
        "#,
    )
    .bind(crate::id::generate())
    .bind(room_id)
    .bind(user_id)
    .bind(role)
    .bind(joined_at)
    .fetch_one(&mut *executor)
    .await?;

    Ok(inserted)
}
