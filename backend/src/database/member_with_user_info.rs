use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

use super::models::MemberRole;

/// 包含用户信息的房间成员
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RoomMemberWithUserInfo {
    pub user_id: Uuid,
    pub username: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub role: MemberRole,
    pub joined_at: Option<DateTime<Utc>>,
}

/// 从数据库行映射的临时结构
#[derive(FromRow)]
pub struct RoomMemberRow {
    user_id: Uuid,
    username: String,
    nickname: Option<String>,
    avatar_url: Option<String>,
    role: MemberRole,
    joined_at: Option<DateTime<Utc>>,
}

impl From<RoomMemberRow> for RoomMemberWithUserInfo {
    fn from(row: RoomMemberRow) -> Self {
        Self {
            user_id: row.user_id,
            username: row.username,
            nickname: row.nickname,
            avatar_url: row.avatar_url,
            role: row.role,
            joined_at: row.joined_at,
        }
    }
}
