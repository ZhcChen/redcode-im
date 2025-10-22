use crate::database::models::{FriendRequest, FriendRequestStatus, Friendship};
use crate::database::Database;
use crate::error::AppError;
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
            return Err(AppError::ValidationError(
                "不能向自己发送好友请求".to_string(),
            ));
        }

        if self.are_already_friends(requester_id, addressee_id).await? {
            return Err(AppError::AlreadyExists(
                "双方已经是好友，无法重复添加".to_string(),
            ));
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
                    return Err(AppError::AlreadyExists("好友请求正在处理中".to_string()));
                }
                FriendRequestStatus::Accepted => {
                    return Err(AppError::AlreadyExists("双方已经是好友".to_string()));
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
            INSERT INTO friend_requests (requester_id, addressee_id, message, status)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (requester_id, addressee_id)
            DO UPDATE SET
                status = EXCLUDED.status,
                message = EXCLUDED.message,
                created_at = NOW(),
                responded_at = NULL
            RETURNING id, requester_id, addressee_id, status, message, created_at, responded_at
            "#,
        )
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
            return Err(AppError::ValidationError(
                "响应请求时状态必须为同意或拒绝".to_string(),
            ));
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
                return Err(AppError::NotFound(format!(
                    "好友请求 {} 不存在",
                    request_id
                )));
            }
        };

        if request.addressee_id != responder_id {
            return Err(AppError::Forbidden("没有权限处理该好友请求".to_string()));
        }

        if request.status != FriendRequestStatus::Pending {
            return Err(AppError::ValidationError("该好友请求已处理".to_string()));
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
                INSERT INTO friendships (user_a_id, user_b_id)
                VALUES ($1, $2)
                ON CONFLICT (user_a_id, user_b_id) DO NOTHING
                "#,
            )
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
                CASE WHEN f.user_a_id = $1 THEN f.user_b_id ELSE f.user_a_id END AS friend_user_id
            FROM friendships f
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
}

/// 好友请求方向
#[derive(Copy, Clone)]
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
