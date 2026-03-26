use crate::database::models::{FriendRequest, FriendRequestStatus, Friendship};
use crate::database::Database;
use crate::error::AppError;
use crate::i18n::message::MessageParams;
use sqlx::{query_as, query_scalar, PgPool, Postgres, QueryBuilder, Row};
use uuid::Uuid;

/// 好友存储
#[derive(Clone)]
pub struct FriendStore {
    database: Database,
}

/// 好友关系列表项
pub struct FriendshipRecord {
    pub friendship: Friendship,
    pub friend_user_id: Uuid,
    pub friend_remark: Option<String>,
}

impl FriendStore {
    pub fn new(database: Database) -> Self {
        Self { database }
    }

    fn pool(&self) -> &PgPool {
        &self.database.pool
    }

    /// 创建好友请求
    pub async fn create_request(
        &self,
        requester_id: Uuid,
        addressee_id: Uuid,
        message: Option<String>,
    ) -> Result<FriendRequest, AppError> {
        if requester_id == addressee_id {
            return Err(friend_validation_error(
                "friend.cannot_send_request_to_self",
            ));
        }

        if self.are_already_friends(requester_id, addressee_id).await? {
            return Err(friend_already_exists_error("friend.already_friends"));
        }

        let pool = self.pool();

        if let Some(existing) = query_as::<_, FriendRequest>(
            r#"
            SELECT id, requester_id, addressee_id, status, message, created_at, responded_at
            FROM friend_requests
            WHERE (requester_id = $1 AND addressee_id = $2)
               OR (requester_id = $2 AND addressee_id = $1)
            ORDER BY created_at DESC
            LIMIT 1
            "#,
        )
        .bind(requester_id)
        .bind(addressee_id)
        .fetch_optional(pool)
        .await?
        {
            match existing.status {
                FriendRequestStatus::Pending => {
                    return Err(friend_already_exists_error("friend.request_pending"));
                }
                FriendRequestStatus::Accepted => {
                    return Err(friend_already_exists_error("friend.already_friends"));
                }
                FriendRequestStatus::Declined => {
                    // 已拒绝的请求，如果由同一请求人再次发起，更新为新的 Pending
                    if existing.requester_id == requester_id {
                        let updated = query_as::<_, FriendRequest>(
                            r#"
                            UPDATE friend_requests
                            SET status = $3,
                                message = $2,
                                created_at = NOW(),
                                responded_at = NULL
                            WHERE id = $1
                            RETURNING id, requester_id, addressee_id, status, message, created_at, responded_at
                            "#,
                        )
                        .bind(existing.id)
                        .bind(message.clone())
                        .bind(FriendRequestStatus::Pending)
                        .fetch_one(pool)
                        .await?;

                        return Ok(updated);
                    }
                }
            }
        }

        let inserted = query_as::<_, FriendRequest>(
            r#"
            INSERT INTO friend_requests (id, requester_id, addressee_id, message, status)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (requester_id, addressee_id)
            DO UPDATE SET
                status = EXCLUDED.status,
                message = EXCLUDED.message,
                created_at = NOW(),
                responded_at = NULL
            RETURNING id, requester_id, addressee_id, status, message, created_at, responded_at
            "#,
        )
        .bind(crate::id::generate())
        .bind(requester_id)
        .bind(addressee_id)
        .bind(message)
        .bind(FriendRequestStatus::Pending)
        .fetch_one(pool)
        .await?;

        Ok(inserted)
    }

    /// 列出好友请求
    pub async fn list_requests(
        &self,
        user_id: Uuid,
        direction: Option<FriendRequestDirection>,
        status: Option<FriendRequestStatus>,
    ) -> Result<Vec<FriendRequest>, AppError> {
        let mut query = QueryBuilder::<Postgres>::new(
            "SELECT id, requester_id, addressee_id, status, message, created_at, responded_at \
             FROM friend_requests WHERE (requester_id = ",
        );
        query.push_bind(user_id);
        query.push(" OR addressee_id = ");
        query.push_bind(user_id);
        query.push(")");

        if let Some(direction) = direction {
            match direction {
                FriendRequestDirection::Incoming => {
                    query.push(" AND addressee_id = ");
                    query.push_bind(user_id);
                }
                FriendRequestDirection::Outgoing => {
                    query.push(" AND requester_id = ");
                    query.push_bind(user_id);
                }
            }
        }

        if let Some(status) = status {
            query.push(" AND status = ");
            query.push_bind(status);
        }

        query.push(" ORDER BY created_at DESC");

        let requests = query
            .build_query_as::<FriendRequest>()
            .fetch_all(self.pool())
            .await?;

        Ok(requests)
    }

    /// 响应好友请求
    pub async fn respond_request(
        &self,
        request_id: Uuid,
        responder_id: Uuid,
        new_status: FriendRequestStatus,
    ) -> Result<FriendRequest, AppError> {
        if new_status == FriendRequestStatus::Pending {
            return Err(friend_validation_error("friend.response_status_invalid"));
        }

        let pool = self.pool();

        let request = query_as::<_, FriendRequest>(
            r#"
            SELECT id, requester_id, addressee_id, status, message, created_at, responded_at
            FROM friend_requests
            WHERE id = $1
            "#,
        )
        .bind(request_id)
        .fetch_optional(pool)
        .await?;

        let request = match request {
            Some(req) => req,
            None => {
                return Err(friend_not_found_error_with_params(
                    "friend.request_not_found",
                    MessageParams::from([("request_id".to_string(), request_id.to_string())]),
                ));
            }
        };

        if request.addressee_id != responder_id {
            return Err(friend_forbidden_error("friend.request_permission_denied"));
        }

        if request.status != FriendRequestStatus::Pending {
            return Err(friend_request_already_processed_error());
        }

        let updated = query_as::<_, FriendRequest>(
            r#"
            UPDATE friend_requests
            SET status = $2,
                responded_at = NOW()
            WHERE id = $1
            RETURNING id, requester_id, addressee_id, status, message, created_at, responded_at
            "#,
        )
        .bind(request_id)
        .bind(&new_status)
        .fetch_one(pool)
        .await?;

        if new_status == FriendRequestStatus::Accepted {
            let (user_a, user_b) = sort_user_pair(request.requester_id, request.addressee_id);
            sqlx::query(
                r#"
                INSERT INTO friendships (id, user_a_id, user_b_id)
                VALUES ($1, $2, $3)
                ON CONFLICT (user_a_id, user_b_id) DO NOTHING
                "#,
            )
            .bind(crate::id::generate())
            .bind(user_a)
            .bind(user_b)
            .execute(pool)
            .await?;
        }

        Ok(updated)
    }

    pub async fn count_pending_incoming(&self, user_id: Uuid) -> Result<i64, AppError> {
        let count: i64 = query_scalar::<_, i64>(
            r#"
            SELECT COUNT(*)::BIGINT
            FROM friend_requests
            WHERE addressee_id = $1 AND status = $2
            "#,
        )
        .bind(user_id)
        .bind(FriendRequestStatus::Pending)
        .fetch_one(self.pool())
        .await?;

        Ok(count)
    }

    /// 列出好友列表
    pub async fn list_friendships(&self, user_id: Uuid) -> Result<Vec<FriendshipRecord>, AppError> {
        let rows = sqlx::query(
            r#"
            SELECT 
                f.id,
                f.user_a_id,
                f.user_b_id,
                f.created_at,
                CASE WHEN f.user_a_id = $1 THEN f.user_b_id ELSE f.user_a_id END AS friend_user_id,
                ufr.remark as friend_remark
            FROM friendships f
            LEFT JOIN user_friend_remarks ufr ON (
                ufr.user_id = $1 AND 
                ufr.friend_user_id = CASE WHEN f.user_a_id = $1 THEN f.user_b_id ELSE f.user_a_id END
            )
            WHERE f.user_a_id = $1 OR f.user_b_id = $1
            ORDER BY f.created_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(self.pool())
        .await?;

        let friendships = rows
            .into_iter()
            .map(|row| FriendshipRecord {
                friendship: Friendship {
                    id: row.get("id"),
                    user_a_id: row.get("user_a_id"),
                    user_b_id: row.get("user_b_id"),
                    created_at: row.get("created_at"),
                },
                friend_user_id: row.get("friend_user_id"),
                friend_remark: row.get("friend_remark"),
            })
            .collect();

        Ok(friendships)
    }

    async fn are_already_friends(&self, user_a: Uuid, user_b: Uuid) -> Result<bool, AppError> {
        let (first, second) = sort_user_pair(user_a, user_b);
        let exists: Option<(Uuid,)> = sqlx::query_as(
            "SELECT id FROM friendships WHERE user_a_id = $1 AND user_b_id = $2 LIMIT 1",
        )
        .bind(first)
        .bind(second)
        .fetch_optional(self.pool())
        .await?;
        Ok(exists.is_some())
    }

    /// 删除好友关系（包括双方备注）
    pub async fn delete_friendship(
        &self,
        user_id: Uuid,
        friend_user_id: Uuid,
    ) -> Result<bool, AppError> {
        if user_id == friend_user_id {
            return Err(friend_validation_error("friend.cannot_delete_self"));
        }

        let (first, second) = sort_user_pair(user_id, friend_user_id);
        let pool = self.pool();

        // 删除好友关系
        let result = sqlx::query(
            r#"
            DELETE FROM friendships
            WHERE user_a_id = $1 AND user_b_id = $2
            "#,
        )
        .bind(first)
        .bind(second)
        .execute(pool)
        .await?;

        if result.rows_affected() == 0 {
            // 不存在好友关系
            return Ok(false);
        }

        // 删除双方备注记录（如果有）
        sqlx::query(
            r#"
            DELETE FROM user_friend_remarks
            WHERE (user_id = $1 AND friend_user_id = $2)
               OR (user_id = $2 AND friend_user_id = $1)
            "#,
        )
        .bind(user_id)
        .bind(friend_user_id)
        .execute(pool)
        .await?;

        Ok(true)
    }

    /// 更新或创建好友备注
    pub async fn upsert_friend_remark(
        &self,
        user_id: Uuid,
        friend_user_id: Uuid,
        remark: Option<String>,
    ) -> Result<Option<String>, AppError> {
        // 验证好友关系
        if !self.are_already_friends(user_id, friend_user_id).await? {
            return Err(friend_validation_error("friend.not_friends"));
        }

        let pool = self.pool();

        // 如果备注为空或空字符串,删除备注记录
        if remark.as_ref().map(|s| s.trim().is_empty()).unwrap_or(true) {
            sqlx::query(
                r#"
                DELETE FROM user_friend_remarks
                WHERE user_id = $1 AND friend_user_id = $2
                "#,
            )
            .bind(user_id)
            .bind(friend_user_id)
            .execute(pool)
            .await?;
            return Ok(None);
        }

        // 更新或插入备注
        let result: Option<String> = sqlx::query_scalar(
            r#"
            INSERT INTO user_friend_remarks (user_id, friend_user_id, remark, updated_at)
            VALUES ($1, $2, $3, NOW())
            ON CONFLICT (user_id, friend_user_id)
            DO UPDATE SET
                remark = EXCLUDED.remark,
                updated_at = NOW()
            RETURNING remark
            "#,
        )
        .bind(user_id)
        .bind(friend_user_id)
        .bind(remark)
        .fetch_one(pool)
        .await?;

        Ok(result)
    }
}

fn friend_validation_error(message_key: &'static str) -> AppError {
    AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn friend_already_exists_error(message_key: &'static str) -> AppError {
    AppError::AlreadyExists(String::new()).with_message_key(message_key)
}

fn friend_not_found_error_with_params(
    message_key: &'static str,
    params: MessageParams,
) -> AppError {
    AppError::NotFound(String::new()).with_message_key_and_params(message_key, Some(params))
}

fn friend_forbidden_error(message_key: &'static str) -> AppError {
    AppError::Forbidden(String::new()).with_message_key(message_key)
}

fn friend_request_already_processed_error() -> AppError {
    friend_already_exists_error("friend.request_already_processed")
}

/// 好友请求方向
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum FriendRequestDirection {
    Incoming,
    Outgoing,
}

fn sort_user_pair(a: Uuid, b: Uuid) -> (Uuid, Uuid) {
    if a <= b {
        (a, b)
    } else {
        (b, a)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_request_already_processed_error_uses_conflict_semantics() {
        let error = friend_request_already_processed_error();
        assert_eq!(error.error_code(), 40901);
        assert_eq!(error.message_key(), "common.already_exists");
        assert_eq!(
            error.response_message_key(),
            "friend.request_already_processed"
        );
        assert_eq!(error.message_params(), None);
    }
}
