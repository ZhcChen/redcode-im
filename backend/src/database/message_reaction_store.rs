use crate::database::models::{MessageReaction, MessageReactionSummary};
use sqlx::{PgPool, Row};
use uuid::Uuid;

pub struct MessageReactionStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> MessageReactionStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    /// 添加或恢复反应（toggle：如果已存在且已删除，则恢复；如果不存在，则创建）
    pub async fn add_reaction(
        &self,
        message_id: Uuid,
        user_id: Uuid,
        reaction_key: &str,
    ) -> Result<MessageReaction, sqlx::Error> {
        // 先尝试恢复已删除的记录
        let restored = sqlx::query_as::<_, MessageReaction>(
            r#"
            UPDATE message_reactions
            SET deleted_at = NULL, created_at = NOW()
            WHERE message_id = $1 AND user_id = $2 AND reaction_key = $3 AND deleted_at IS NOT NULL
            RETURNING id, message_id, user_id, reaction_key, created_at, deleted_at
            "#,
        )
        .bind(message_id)
        .bind(user_id)
        .bind(reaction_key)
        .fetch_optional(self.pool)
        .await?;

        if let Some(reaction) = restored {
            return Ok(reaction);
        }

        // 如果已存在且未删除，直接返回
        let existing = sqlx::query_as::<_, MessageReaction>(
            r#"
            SELECT id, message_id, user_id, reaction_key, created_at, deleted_at
            FROM message_reactions
            WHERE message_id = $1 AND user_id = $2 AND reaction_key = $3 AND deleted_at IS NULL
            "#,
        )
        .bind(message_id)
        .bind(user_id)
        .bind(reaction_key)
        .fetch_optional(self.pool)
        .await?;

        if let Some(reaction) = existing {
            return Ok(reaction);
        }

        // 创建新记录
        let id = crate::id::generate();
        let reaction = sqlx::query_as::<_, MessageReaction>(
            r#"
            INSERT INTO message_reactions (id, message_id, user_id, reaction_key)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (message_id, user_id, reaction_key) DO UPDATE
            SET deleted_at = NULL, created_at = NOW()
            RETURNING id, message_id, user_id, reaction_key, created_at, deleted_at
            "#,
        )
        .bind(id)
        .bind(message_id)
        .bind(user_id)
        .bind(reaction_key)
        .fetch_one(self.pool)
        .await?;

        Ok(reaction)
    }

    /// 删除反应（软删除）
    pub async fn remove_reaction(
        &self,
        message_id: Uuid,
        user_id: Uuid,
        reaction_key: &str,
    ) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            r#"
            UPDATE message_reactions
            SET deleted_at = NOW()
            WHERE message_id = $1 AND user_id = $2 AND reaction_key = $3 AND deleted_at IS NULL
            "#,
        )
        .bind(message_id)
        .bind(user_id)
        .bind(reaction_key)
        .execute(self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 获取消息的所有反应聚合结果
    pub async fn get_reaction_summaries(
        &self,
        message_id: Uuid,
        current_user_id: Option<Uuid>,
    ) -> Result<Vec<MessageReactionSummary>, sqlx::Error> {
        let rows = sqlx::query(
            r#"
            SELECT 
                reaction_key,
                COUNT(*)::bigint as count,
                array_agg(user_id ORDER BY created_at) as user_ids
            FROM message_reactions
            WHERE message_id = $1 AND deleted_at IS NULL
            GROUP BY reaction_key
            ORDER BY count DESC, reaction_key
            "#,
        )
        .bind(message_id)
        .fetch_all(self.pool)
        .await?;

        let mut summaries = Vec::new();
        for row in rows {
            let reaction_key: String = row.get("reaction_key");
            let count: i64 = row.get("count");
            let user_ids: Vec<Uuid> = row.get("user_ids");

            let has_self = current_user_id
                .map(|uid| user_ids.contains(&uid))
                .unwrap_or(false);

            summaries.push(MessageReactionSummary {
                reaction_key,
                count,
                user_ids,
                has_self,
            });
        }

        Ok(summaries)
    }

    /// 检查用户是否对消息有特定反应
    pub async fn has_reaction(
        &self,
        message_id: Uuid,
        user_id: Uuid,
        reaction_key: &str,
    ) -> Result<bool, sqlx::Error> {
        let exists: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM message_reactions
                WHERE message_id = $1 AND user_id = $2 AND reaction_key = $3 AND deleted_at IS NULL
            )
            "#,
        )
        .bind(message_id)
        .bind(user_id)
        .bind(reaction_key)
        .fetch_one(self.pool)
        .await?;

        Ok(exists)
    }

    /// 获取用户对消息的所有反应
    pub async fn get_user_reactions(
        &self,
        message_id: Uuid,
        user_id: Uuid,
    ) -> Result<Vec<String>, sqlx::Error> {
        let reactions: Vec<String> = sqlx::query_scalar(
            r#"
            SELECT reaction_key
            FROM message_reactions
            WHERE message_id = $1 AND user_id = $2 AND deleted_at IS NULL
            ORDER BY created_at
            "#,
        )
        .bind(message_id)
        .bind(user_id)
        .fetch_all(self.pool)
        .await?;

        Ok(reactions)
    }
}

