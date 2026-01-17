use chrono::{Duration, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::database::models::{
    AppointAdminRequest, CreateRuleRequest, GroupAdmin, GroupDetailInfo, GroupInvitation,
    GroupMute, GroupOperationLog, GroupRule, GroupSettings, InvitationStatus, InviteToGroupRequest,
    JoinGroupRequest, JoinRequest, JoinRequestStatus, MuteUserRequest, ReviewJoinRequestRequest,
    UpdateGroupSettingsRequest, UpdateRuleRequest,
};

pub struct GroupManagementStore<'a> {
    pub pool: &'a PgPool,
}

impl<'a> GroupManagementStore<'a> {
    pub fn new(pool: &'a PgPool) -> Self {
        Self { pool }
    }

    // ===== 群设置管理 =====

    pub async fn get_group_settings(
        &self,
        room_id: Uuid,
    ) -> Result<Option<GroupSettings>, sqlx::Error> {
        let settings = sqlx::query_as::<_, GroupSettings>(
            r#"
            SELECT id, room_id, join_approval_required, member_can_invite,
                   member_can_add_friends, require_admin_to_add_friends, max_members,
                   global_mute_enabled, global_mute_until, global_mute_reason, global_mute_set_by,
                   created_at, updated_at
            FROM group_settings
            WHERE room_id = $1
            "#,
        )
        .bind(room_id)
        .fetch_optional(self.pool)
        .await?;

        if let Some(settings) = settings {
            if settings.global_mute_enabled {
                if let Some(until) = settings.global_mute_until {
                    if until <= Utc::now() {
                        let cleared = self.clear_global_mute(room_id).await?;
                        return Ok(Some(cleared));
                    }
                }
            }
            Ok(Some(settings))
        } else {
            Ok(None)
        }
    }

    pub async fn ensure_group_settings_row(&self, room_id: Uuid) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            INSERT INTO group_settings (room_id)
            VALUES ($1)
            ON CONFLICT (room_id) DO NOTHING
            "#,
        )
        .bind(room_id)
        .execute(self.pool)
        .await?;

        Ok(())
    }

    pub async fn update_group_settings(
        &self,
        room_id: Uuid,
        request: UpdateGroupSettingsRequest,
    ) -> Result<GroupSettings, sqlx::Error> {
        self.ensure_group_settings_row(room_id).await?;

        let updated = sqlx::query_as::<_, GroupSettings>(
            r#"
            UPDATE group_settings
            SET join_approval_required = COALESCE($2, join_approval_required),
                member_can_invite = COALESCE($3, member_can_invite),
                member_can_add_friends = COALESCE($4, member_can_add_friends),
                require_admin_to_add_friends = COALESCE($5, require_admin_to_add_friends),
                max_members = COALESCE($6, max_members),
                updated_at = NOW()
            WHERE room_id = $1
            RETURNING id, room_id, join_approval_required, member_can_invite,
                     member_can_add_friends, require_admin_to_add_friends, max_members,
                     global_mute_enabled, global_mute_until, global_mute_reason, global_mute_set_by,
                     created_at, updated_at
            "#,
        )
        .bind(room_id)
        .bind(request.join_approval_required)
        .bind(request.member_can_invite)
        .bind(request.member_can_add_friends)
        .bind(request.require_admin_to_add_friends)
        .bind(request.max_members)
        .fetch_one(self.pool)
        .await?;

        Ok(updated)
    }

    pub async fn set_global_mute_state(
        &self,
        room_id: Uuid,
        set_by: Uuid,
        enabled: bool,
        reason: Option<String>,
        duration_minutes: Option<i64>,
    ) -> Result<GroupSettings, sqlx::Error> {
        self.ensure_group_settings_row(room_id).await?;

        let duration = duration_minutes.map(|value| value.max(0) as f64);

        let updated = sqlx::query_as::<_, GroupSettings>(
            r#"
            UPDATE group_settings
            SET global_mute_enabled = $2,
                global_mute_reason = CASE WHEN $2 THEN $3 ELSE NULL END,
                global_mute_set_by = CASE WHEN $2 THEN $4 ELSE NULL END,
                global_mute_until = CASE
                    WHEN $2 THEN
                        CASE WHEN $5 IS NOT NULL THEN NOW() + ($5 * INTERVAL '1 minute') ELSE NULL END
                    ELSE NULL
                END,
                updated_at = NOW()
            WHERE room_id = $1
            RETURNING id, room_id, join_approval_required, member_can_invite,
                     member_can_add_friends, require_admin_to_add_friends, max_members,
                     global_mute_enabled, global_mute_until, global_mute_reason, global_mute_set_by,
                     created_at, updated_at
            "#,
        )
        .bind(room_id)
        .bind(enabled)
        .bind(reason)
        .bind(set_by)
        .bind(duration)
        .fetch_one(self.pool)
        .await?;

        Ok(updated)
    }

    pub async fn clear_global_mute(&self, room_id: Uuid) -> Result<GroupSettings, sqlx::Error> {
        let cleared = sqlx::query_as::<_, GroupSettings>(
            r#"
            UPDATE group_settings
            SET global_mute_enabled = FALSE,
                global_mute_reason = NULL,
                global_mute_set_by = NULL,
                global_mute_until = NULL,
                updated_at = NOW()
            WHERE room_id = $1
            RETURNING id, room_id, join_approval_required, member_can_invite,
                     member_can_add_friends, require_admin_to_add_friends, max_members,
                     global_mute_enabled, global_mute_until, global_mute_reason, global_mute_set_by,
                     created_at, updated_at
            "#,
        )
        .bind(room_id)
        .fetch_one(self.pool)
        .await?;

        Ok(cleared)
    }

    // ===== 群规管理 =====

    pub async fn create_rule(
        &self,
        room_id: Uuid,
        creator_id: Uuid,
        request: CreateRuleRequest,
    ) -> Result<GroupRule, sqlx::Error> {
        let rule = sqlx::query_as::<_, GroupRule>(
            r#"
            INSERT INTO group_rules
            (room_id, title, content, creator_id, order_index)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, room_id, title, content, creator_id, order_index, is_active, created_at, updated_at
            "#,
        )
        .bind(room_id)
        .bind(request.title)
        .bind(request.content)
        .bind(creator_id)
        .bind(request.order_index.unwrap_or(0))
        .fetch_one(self.pool)
        .await?;

        Ok(rule)
    }

    pub async fn list_rules(&self, room_id: Uuid) -> Result<Vec<GroupRule>, sqlx::Error> {
        let rules = sqlx::query_as::<_, GroupRule>(
            r#"
            SELECT id, room_id, title, content, creator_id, order_index, is_active, created_at, updated_at
            FROM group_rules
            WHERE room_id = $1
            ORDER BY order_index ASC, created_at ASC
            "#,
        )
        .bind(room_id)
        .fetch_all(self.pool)
        .await?;

        Ok(rules)
    }

    pub async fn update_rule(
        &self,
        rule_id: Uuid,
        request: UpdateRuleRequest,
    ) -> Result<Option<GroupRule>, sqlx::Error> {
        let updated = sqlx::query_as::<_, GroupRule>(
            r#"
            UPDATE group_rules
            SET title = COALESCE($2, title),
                content = COALESCE($3, content),
                order_index = COALESCE($4, order_index),
                is_active = COALESCE($5, is_active),
                updated_at = NOW()
            WHERE id = $1
            RETURNING id, room_id, title, content, creator_id, order_index, is_active, created_at, updated_at
            "#,
        )
        .bind(rule_id)
        .bind(request.title)
        .bind(request.content)
        .bind(request.order_index)
        .bind(request.is_active)
        .fetch_optional(self.pool)
        .await?;

        Ok(updated)
    }

    pub async fn delete_rule(&self, rule_id: Uuid) -> Result<bool, sqlx::Error> {
        let result = sqlx::query("DELETE FROM group_rules WHERE id = $1")
            .bind(rule_id)
            .execute(self.pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    // ===== 入群申请管理 =====

    pub async fn create_join_request(
        &self,
        room_id: Uuid,
        applicant_id: Uuid,
        request: JoinGroupRequest,
    ) -> Result<JoinRequest, sqlx::Error> {
        let join_request = sqlx::query_as::<_, JoinRequest>(
            r#"
            INSERT INTO join_requests
            (room_id, applicant_id, message)
            VALUES ($1, $2, $3)
            ON CONFLICT (room_id, applicant_id)
            DO UPDATE SET
                message = EXCLUDED.message,
                status = 0,
                reviewer_id = NULL,
                review_message = NULL,
                created_at = NOW(),
                reviewed_at = NULL
            RETURNING id, room_id, applicant_id, message, status, reviewer_id, review_message, created_at, reviewed_at
            "#,
        )
        .bind(room_id)
        .bind(applicant_id)
        .bind(request.message)
        .fetch_one(self.pool)
        .await?;

        Ok(join_request)
    }

    pub async fn has_approved_join_request(
        &self,
        room_id: Uuid,
        applicant_id: Uuid,
    ) -> Result<bool, sqlx::Error> {
        let status: Option<JoinRequestStatus> = sqlx::query_scalar(
            r#"
            SELECT status
            FROM join_requests
            WHERE room_id = $1 AND applicant_id = $2
            LIMIT 1
            "#,
        )
        .bind(room_id)
        .bind(applicant_id)
        .fetch_optional(self.pool)
        .await?;

        Ok(matches!(status, Some(JoinRequestStatus::Approved)))
    }

    pub async fn list_join_requests(&self, room_id: Uuid) -> Result<Vec<JoinRequest>, sqlx::Error> {
        let requests = sqlx::query_as::<_, JoinRequest>(
            r#"
            SELECT id, room_id, applicant_id, message, status, reviewer_id, review_message, created_at, reviewed_at
            FROM join_requests
            WHERE room_id = $1
            ORDER BY created_at DESC
            "#,
        )
        .bind(room_id)
        .fetch_all(self.pool)
        .await?;

        Ok(requests)
    }

    pub async fn review_join_request(
        &self,
        request_id: Uuid,
        reviewer_id: Uuid,
        request: ReviewJoinRequestRequest,
    ) -> Result<Option<JoinRequest>, sqlx::Error> {
        let updated = sqlx::query_as::<_, JoinRequest>(
            r#"
            UPDATE join_requests
            SET status = $2,
                reviewer_id = $3,
                review_message = $4,
                reviewed_at = NOW()
            WHERE id = $1 AND status = 0
            RETURNING id, room_id, applicant_id, message, status, reviewer_id, review_message, created_at, reviewed_at
            "#,
        )
        .bind(request_id)
        .bind(request.status)
        .bind(reviewer_id)
        .bind(request.review_message)
        .fetch_optional(self.pool)
        .await?;

        Ok(updated)
    }

    /// 统计当前群成员数量（不含已删除）
    pub async fn count_active_members(&self, room_id: Uuid) -> Result<i64, sqlx::Error> {
        let count: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*) FROM room_members
            WHERE room_id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(room_id)
        .fetch_one(self.pool)
        .await?;

        Ok(count)
    }

    /// 获取群设置；若不存在则创建默认记录并返回
    pub async fn get_or_create_group_settings(
        &self,
        room_id: Uuid,
    ) -> Result<GroupSettings, sqlx::Error> {
        let settings = sqlx::query_as::<_, GroupSettings>(
            r#"
            INSERT INTO group_settings (room_id)
            VALUES ($1)
            ON CONFLICT (room_id) DO UPDATE SET updated_at = group_settings.updated_at
            RETURNING id, room_id, join_approval_required, member_can_invite,
                     member_can_add_friends, require_admin_to_add_friends, max_members,
                     global_mute_enabled, global_mute_until, global_mute_reason, global_mute_set_by,
                     created_at, updated_at
            "#,
        )
        .bind(room_id)
        .fetch_one(self.pool)
        .await?;

        Ok(settings)
    }

    // ===== 群聊邀请管理 =====

    pub async fn get_invitation_by_id(
        &self,
        invitation_id: Uuid,
    ) -> Result<Option<GroupInvitation>, sqlx::Error> {
        let invitation = sqlx::query_as::<_, GroupInvitation>(
            r#"
            SELECT id, room_id, inviter_id, invitee_id, message, status, invited_at, responded_at, expires_at
            FROM group_invitations
            WHERE id = $1
            "#,
        )
        .bind(invitation_id)
        .fetch_optional(self.pool)
        .await?;

        Ok(invitation)
    }

    pub async fn create_invitations(
        &self,
        room_id: Uuid,
        inviter_id: Uuid,
        request: InviteToGroupRequest,
    ) -> Result<Vec<GroupInvitation>, sqlx::Error> {
        let mut invitations = Vec::new();
        let expires_at = Utc::now() + chrono::Duration::days(7);

        for user_id_str in request.user_ids {
            if let Ok(user_id) = user_id_str.parse::<Uuid>() {
                let invitation = sqlx::query_as::<_, GroupInvitation>(
                    r#"
                    INSERT INTO group_invitations
                    (room_id, inviter_id, invitee_id, message, expires_at)
                    VALUES ($1, $2, $3, $4, $5)
                    ON CONFLICT (room_id, invitee_id)
                    DO UPDATE SET
                        message = EXCLUDED.message,
                        status = 0,
                        invited_at = NOW(),
                        responded_at = NULL,
                        expires_at = EXCLUDED.expires_at
                    RETURNING id, room_id, inviter_id, invitee_id, message, status, invited_at, responded_at, expires_at
                    "#,
                )
                .bind(room_id)
                .bind(inviter_id)
                .bind(user_id)
                .bind(&request.message)
                .bind(expires_at)
                .fetch_one(self.pool)
                .await?;

                invitations.push(invitation);
            }
        }

        Ok(invitations)
    }

    pub async fn respond_to_invitation(
        &self,
        invitation_id: Uuid,
        status: InvitationStatus,
    ) -> Result<Option<GroupInvitation>, sqlx::Error> {
        let updated = sqlx::query_as::<_, GroupInvitation>(
            r#"
            UPDATE group_invitations
            SET status = $2,
                responded_at = NOW()
            WHERE id = $1 AND status = 0
            RETURNING id, room_id, inviter_id, invitee_id, message, status, invited_at, responded_at, expires_at
            "#,
        )
        .bind(invitation_id)
        .bind(status)
        .fetch_optional(self.pool)
        .await?;

        Ok(updated)
    }

    // ===== 群管理员管理 =====

    pub async fn appoint_admin(
        &self,
        room_id: Uuid,
        appointed_by: Uuid,
        request: AppointAdminRequest,
    ) -> Result<GroupAdmin, sqlx::Error> {
        let admin_id = request
            .user_id
            .parse::<Uuid>()
            .map_err(|_| sqlx::Error::Protocol("Invalid user ID".to_string()))?;

        let admin = sqlx::query_as::<_, GroupAdmin>(
            r#"
            INSERT INTO group_admins
            (room_id, admin_id, appointed_by, role, permissions)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (room_id, admin_id)
            DO UPDATE SET
                role = EXCLUDED.role,
                permissions = EXCLUDED.permissions,
                appointed_by = EXCLUDED.appointed_by,
                appointed_at = NOW()
            RETURNING id, room_id, admin_id, appointed_by, role, permissions, appointed_at
            "#,
        )
        .bind(room_id)
        .bind(admin_id)
        .bind(appointed_by)
        .bind(request.role)
        .bind(request.permissions)
        .fetch_one(self.pool)
        .await?;

        Ok(admin)
    }

    pub async fn remove_admin(&self, room_id: Uuid, admin_id: Uuid) -> Result<bool, sqlx::Error> {
        let result = sqlx::query("DELETE FROM group_admins WHERE room_id = $1 AND admin_id = $2")
            .bind(room_id)
            .bind(admin_id)
            .execute(self.pool)
            .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn list_admins(&self, room_id: Uuid) -> Result<Vec<GroupAdmin>, sqlx::Error> {
        let admins = sqlx::query_as::<_, GroupAdmin>(
            r#"
            SELECT id, room_id, admin_id, appointed_by, role, permissions, appointed_at
            FROM group_admins
            WHERE room_id = $1
            ORDER BY appointed_at ASC
            "#,
        )
        .bind(room_id)
        .fetch_all(self.pool)
        .await?;

        Ok(admins)
    }

    // ===== 群禁言管理 =====

    pub async fn mute_user(
        &self,
        room_id: Uuid,
        muted_by: Uuid,
        request: MuteUserRequest,
    ) -> Result<GroupMute, sqlx::Error> {
        let user_id = request
            .user_id
            .parse::<Uuid>()
            .map_err(|_| sqlx::Error::Protocol("Invalid user ID".to_string()))?;

        let mute = sqlx::query_as::<_, GroupMute>(
            r#"
            INSERT INTO group_mutes
            (room_id, user_id, muted_by, reason, mute_duration_hours)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (room_id, user_id)
            DO UPDATE SET
                muted_by = EXCLUDED.muted_by,
                reason = EXCLUDED.reason,
                mute_duration_hours = EXCLUDED.mute_duration_hours,
                muted_at = NOW(),
                unmuted_at = NULL,
                is_active = TRUE
            RETURNING id, room_id, user_id, muted_by, reason, mute_duration_hours, muted_at, unmuted_at, is_active
            "#,
        )
        .bind(room_id)
        .bind(user_id)
        .bind(muted_by)
        .bind(request.reason)
        .bind(request.mute_duration_hours.unwrap_or(24))
        .fetch_one(self.pool)
        .await?;

        Ok(mute)
    }

    pub async fn unmute_user(&self, room_id: Uuid, user_id: Uuid) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            r#"
            UPDATE group_mutes
            SET is_active = FALSE,
                unmuted_at = NOW()
            WHERE room_id = $1 AND user_id = $2 AND is_active = TRUE
            "#,
        )
        .bind(room_id)
        .bind(user_id)
        .execute(self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    pub async fn find_active_mute(
        &self,
        room_id: Uuid,
        user_id: Uuid,
    ) -> Result<Option<GroupMute>, sqlx::Error> {
        let mute = sqlx::query_as::<_, GroupMute>(
            r#"
            SELECT id, room_id, user_id, muted_by, reason, mute_duration_hours, muted_at, unmuted_at, is_active
            FROM group_mutes
            WHERE room_id = $1 AND user_id = $2 AND is_active = TRUE
            LIMIT 1
            "#,
        )
        .bind(room_id)
        .bind(user_id)
        .fetch_optional(self.pool)
        .await?;

        if let Some(mute) = mute {
            if mute.mute_duration_hours > 0 {
                let expire_at = mute.muted_at + Duration::hours(mute.mute_duration_hours as i64);
                if expire_at <= Utc::now() {
                    let _ = self.unmute_user(room_id, user_id).await?;
                    return Ok(None);
                }
            }
            return Ok(Some(mute));
        }

        Ok(None)
    }

    pub async fn list_muted_users(&self, room_id: Uuid) -> Result<Vec<GroupMute>, sqlx::Error> {
        let mutes = sqlx::query_as::<_, GroupMute>(
            r#"
            SELECT id, room_id, user_id, muted_by, reason, mute_duration_hours, muted_at, unmuted_at, is_active
            FROM group_mutes
            WHERE room_id = $1 AND is_active = TRUE
            ORDER BY muted_at DESC
            "#,
        )
        .bind(room_id)
        .fetch_all(self.pool)
        .await?;

        Ok(mutes)
    }

    // ===== 操作日志管理 =====

    pub async fn log_operation(
        &self,
        room_id: Uuid,
        operator_id: Uuid,
        target_user_id: Option<Uuid>,
        operation_type: &str,
        operation_data: Option<serde_json::Value>,
    ) -> Result<GroupOperationLog, sqlx::Error> {
        let log = sqlx::query_as::<_, GroupOperationLog>(
            r#"
            INSERT INTO group_operation_logs
            (room_id, operator_id, target_user_id, operation_type, operation_data)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id, room_id, operator_id, target_user_id, operation_type, operation_data, created_at
            "#,
        )
        .bind(room_id)
        .bind(operator_id)
        .bind(target_user_id)
        .bind(operation_type)
        .bind(operation_data)
        .fetch_one(self.pool)
        .await?;

        Ok(log)
    }

    pub async fn list_operation_logs(
        &self,
        room_id: Uuid,
        limit: Option<i64>,
        offset: Option<i64>,
    ) -> Result<Vec<GroupOperationLog>, sqlx::Error> {
        let logs = sqlx::query_as::<_, GroupOperationLog>(
            r#"
            SELECT id, room_id, operator_id, target_user_id, operation_type, operation_data, created_at
            FROM group_operation_logs
            WHERE room_id = $1
            ORDER BY created_at DESC
            LIMIT $2 OFFSET $3
            "#,
        )
        .bind(room_id)
        .bind(limit.unwrap_or(50))
        .bind(offset.unwrap_or(0))
        .fetch_all(self.pool)
        .await?;

        Ok(logs)
    }

    // ===== 群聊详情查询 =====

    pub async fn get_group_detail_info(
        &self,
        room_id: Uuid,
    ) -> Result<Option<GroupDetailInfo>, sqlx::Error> {
        let info = sqlx::query_as::<_, GroupDetailInfo>(
            r#"
            SELECT * FROM group_detail_view
            WHERE id = $1
            "#,
        )
        .bind(room_id)
        .fetch_optional(self.pool)
        .await?;

        Ok(info)
    }

    // ===== 权限检查辅助方法 =====

    pub async fn is_group_admin(&self, room_id: Uuid, user_id: Uuid) -> Result<bool, sqlx::Error> {
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM group_admins WHERE room_id = $1 AND admin_id = $2",
        )
        .bind(room_id)
        .bind(user_id)
        .fetch_one(self.pool)
        .await?;

        Ok(count > 0)
    }

    pub async fn is_group_owner(&self, room_id: Uuid, user_id: Uuid) -> Result<bool, sqlx::Error> {
        let owner_id: Option<Uuid> =
            sqlx::query_scalar("SELECT owner_id FROM rooms WHERE id = $1 AND deleted_at IS NULL")
                .bind(room_id)
                .fetch_one(self.pool)
                .await?;

        Ok(owner_id == Some(user_id))
    }

    pub async fn can_manage_group(
        &self,
        room_id: Uuid,
        user_id: Uuid,
    ) -> Result<bool, sqlx::Error> {
        // 检查是否是群主或管理员
        let is_owner = self.is_group_owner(room_id, user_id).await?;
        if is_owner {
            return Ok(true);
        }

        let is_admin = self.is_group_admin(room_id, user_id).await?;
        Ok(is_admin)
    }
}
