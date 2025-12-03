use axum::{
    extract::{Extension, Path, State},
    http::StatusCode,
    response::Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use uuid::Uuid;

use tracing::{error, info};

use crate::database::{
    group_management_store::GroupManagementStore,
    models::{
        AppointAdminRequest, CreateAnnouncementRequest, CreateRuleRequest, GroupAdmin,
        GroupAnnouncement, GroupDetailInfo, GroupInvitation, GroupMute, GroupOperationLog,
        GroupRule, GroupSettings, InviteToGroupRequest, JoinGroupRequest, JoinRequest, MemberRole,
        MuteUserRequest, ReviewJoinRequestRequest, UpdateAnnouncementRequest,
        UpdateGroupSettingsRequest, UpdateRuleRequest,
    },
    room_store::RoomStore,
};
use crate::error::AppError;
use crate::models::Claims;
use crate::redis::models::{
    CacheKeys, GroupMemberChangeType, GroupMemberChangedPayload, GroupSettingsUpdatePayload,
    PubSubPayload,
};
use crate::AppState;

// ===== 群设置管理 API =====

#[derive(Serialize)]
pub struct GroupSettingsResponse {
    pub settings: GroupSettings,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub my_mute: Option<MyMuteInfo>,
}

/// 当前用户的个人禁言信息
#[derive(Debug, Clone, Serialize)]
pub struct MyMuteInfo {
    pub is_muted: bool,
    pub reason: Option<String>,
    pub muted_at: Option<DateTime<Utc>>,
    pub mute_until: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateGlobalMuteRequest {
    pub enabled: bool,
    pub reason: Option<String>,
    pub duration_minutes: Option<i64>,
}

pub async fn get_group_settings(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<GroupSettingsResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    let settings = match store.get_group_settings(room_id).await? {
        Some(s) => s,
        None => {
            // 兼容历史群聊未生成设置记录的情况
            store.ensure_group_settings_row(room_id).await?;
            store
                .get_group_settings(room_id)
                .await?
                .ok_or_else(|| AppError::NotFound("Group settings not found".to_string()))?
        }
    };

    // 查询当前用户的个人禁言状态
    let my_mute = if let Some(mute) = store.find_active_mute(room_id, user_id).await? {
        let mute_until = if mute.mute_duration_hours > 0 {
            Some(mute.muted_at + chrono::Duration::hours(mute.mute_duration_hours as i64))
        } else {
            None
        };
        Some(MyMuteInfo {
            is_muted: true,
            reason: mute.reason,
            muted_at: Some(mute.muted_at),
            mute_until,
        })
    } else {
        None
    };

    Ok(Json(GroupSettingsResponse { settings, my_mute }))
}

pub async fn update_global_mute(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<UpdateGlobalMuteRequest>,
) -> Result<Json<GroupSettingsResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can update mute status".to_string(),
        ));
    }

    let settings = store
        .set_global_mute_state(
            room_id,
            user_id,
            request.enabled,
            request.reason.clone(),
            request.duration_minutes,
        )
        .await?;

    let log_payload = {
        use serde_json::Value;
        let mut map = serde_json::Map::new();
        if let Some(reason) = &request.reason {
            map.insert("reason".to_string(), Value::String(reason.clone()));
        }
        if let Some(duration) = request.duration_minutes {
            map.insert(
                "duration_minutes".to_string(),
                Value::Number(duration.into()),
            );
        }
        if map.is_empty() {
            None
        } else {
            Some(Value::Object(map))
        }
    };

    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            if request.enabled {
                "enable_global_mute"
            } else {
                "disable_global_mute"
            },
            log_payload,
        )
        .await;

    // 广播群设置更新到所有群成员
    if let Err(e) = broadcast_group_settings_update(&state, &settings).await {
        error!("广播群禁言设置更新失败: {:?}", e);
    }

    // 管理员不会被禁言，所以 my_mute 为 None
    Ok(Json(GroupSettingsResponse {
        settings,
        my_mute: None,
    }))
}

pub async fn update_group_settings(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<UpdateGroupSettingsRequest>,
) -> Result<Json<GroupSettingsResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以修改设置
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can update settings".to_string(),
        ));
    }

    let settings = store.update_group_settings(room_id, request).await?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            "update_group_settings",
            Some(serde_json::to_value(&settings).unwrap_or_default()),
        )
        .await;

    // 广播群设置更新到所有群成员
    if let Err(e) = broadcast_group_settings_update(&state, &settings).await {
        error!("广播群设置更新失败: {:?}", e);
    }

    // 管理员不会被禁言，所以 my_mute 为 None
    Ok(Json(GroupSettingsResponse {
        settings,
        my_mute: None,
    }))
}

// ===== 群公告管理 API =====

#[derive(Serialize)]
pub struct CreateAnnouncementResponse {
    pub announcement: GroupAnnouncement,
}

pub async fn create_announcement(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<CreateAnnouncementRequest>,
) -> Result<Json<CreateAnnouncementResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以发布公告
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can create announcements".to_string(),
        ));
    }

    let announcement = store.create_announcement(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            "create_announcement",
            Some(serde_json::json!({
                "announcement_id": announcement.id,
                "title": announcement.title
            })),
        )
        .await;

    Ok(Json(CreateAnnouncementResponse { announcement }))
}

#[derive(Serialize)]
pub struct ListAnnouncementsResponse {
    pub announcements: Vec<GroupAnnouncement>,
}

pub async fn list_announcements(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<ListAnnouncementsResponse>, AppError> {
    let store = GroupManagementStore::new(state.database.pool());
    let announcements = store.list_announcements(room_id).await?;

    Ok(Json(ListAnnouncementsResponse { announcements }))
}

pub async fn update_announcement(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, announcement_id)): Path<(Uuid, Uuid)>,
    Json(request): Json<UpdateAnnouncementRequest>,
) -> Result<Json<CreateAnnouncementResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以修改公告
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can update announcements".to_string(),
        ));
    }

    let announcement = store
        .update_announcement(announcement_id, request)
        .await?
        .ok_or_else(|| AppError::NotFound("Announcement not found".to_string()))?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            "update_announcement",
            Some(serde_json::json!({
                "announcement_id": announcement.id,
                "title": announcement.title
            })),
        )
        .await;

    Ok(Json(CreateAnnouncementResponse { announcement }))
}

pub async fn delete_announcement(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, announcement_id)): Path<(Uuid, Uuid)>,
) -> Result<StatusCode, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以删除公告
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can delete announcements".to_string(),
        ));
    }

    let deleted = store.delete_announcement(announcement_id).await?;
    if !deleted {
        return Err(AppError::NotFound("Announcement not found".to_string()));
    }

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            "delete_announcement",
            Some(serde_json::json!({
                "announcement_id": announcement_id
            })),
        )
        .await;

    Ok(StatusCode::NO_CONTENT)
}

// ===== 群规管理 API =====

#[derive(Serialize)]
pub struct CreateRuleResponse {
    pub rule: GroupRule,
}

pub async fn create_rule(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<CreateRuleRequest>,
) -> Result<Json<CreateRuleResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以创建群规
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can create rules".to_string(),
        ));
    }

    let rule = store.create_rule(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            "create_rule",
            Some(serde_json::json!({
                "rule_id": rule.id,
                "title": rule.title
            })),
        )
        .await;

    Ok(Json(CreateRuleResponse { rule }))
}

#[derive(Serialize)]
pub struct ListRulesResponse {
    pub rules: Vec<GroupRule>,
}

pub async fn list_rules(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<ListRulesResponse>, AppError> {
    let store = GroupManagementStore::new(state.database.pool());
    let rules = store.list_rules(room_id).await?;

    Ok(Json(ListRulesResponse { rules }))
}

pub async fn update_rule(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, rule_id)): Path<(Uuid, Uuid)>,
    Json(request): Json<UpdateRuleRequest>,
) -> Result<Json<CreateRuleResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以修改群规
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can update rules".to_string(),
        ));
    }

    let rule = store
        .update_rule(rule_id, request)
        .await?
        .ok_or_else(|| AppError::NotFound("Rule not found".to_string()))?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            "update_rule",
            Some(serde_json::json!({
                "rule_id": rule.id,
                "title": rule.title
            })),
        )
        .await;

    Ok(Json(CreateRuleResponse { rule }))
}

pub async fn delete_rule(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, rule_id)): Path<(Uuid, Uuid)>,
) -> Result<StatusCode, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以删除群规
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can delete rules".to_string(),
        ));
    }

    let deleted = store.delete_rule(rule_id).await?;
    if !deleted {
        return Err(AppError::NotFound("Rule not found".to_string()));
    }

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            "delete_rule",
            Some(serde_json::json!({
                "rule_id": rule_id
            })),
        )
        .await;

    Ok(StatusCode::NO_CONTENT)
}

// ===== 入群申请管理 API =====

#[derive(Serialize)]
pub struct CreateJoinRequestResponse {
    pub request: JoinRequest,
}

pub async fn create_join_request(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<JoinGroupRequest>,
) -> Result<Json<CreateJoinRequestResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());
    let join_request = store.create_join_request(room_id, user_id, request).await?;

    Ok(Json(CreateJoinRequestResponse {
        request: join_request,
    }))
}

#[derive(Serialize)]
pub struct ListJoinRequestsResponse {
    pub requests: Vec<JoinRequest>,
}

pub async fn list_join_requests(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<ListJoinRequestsResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以查看入群申请
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can view join requests".to_string(),
        ));
    }

    let requests = store.list_join_requests(room_id).await?;

    Ok(Json(ListJoinRequestsResponse { requests }))
}

pub async fn review_join_request(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, request_id)): Path<(Uuid, Uuid)>,
    Json(request): Json<ReviewJoinRequestRequest>,
) -> Result<Json<CreateJoinRequestResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以审批入群申请
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can review join requests".to_string(),
        ));
    }

    let status_copy = request.status;
    let join_request = store
        .review_join_request(request_id, user_id, request)
        .await?
        .ok_or_else(|| {
            AppError::NotFound("Join request not found or already reviewed".to_string())
        })?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            Some(join_request.applicant_id),
            "review_join_request",
            Some(serde_json::json!({
                "request_id": request_id,
                "status": status_copy,
                "applicant_id": join_request.applicant_id
            })),
        )
        .await;

    Ok(Json(CreateJoinRequestResponse {
        request: join_request,
    }))
}

// ===== 群聊邀请管理 API =====

#[derive(Serialize)]
pub struct CreateInvitationsResponse {
    pub invitations: Vec<GroupInvitation>,
}

pub async fn create_invitations(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<InviteToGroupRequest>,
) -> Result<Json<CreateInvitationsResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主、管理员或有邀请权限的成员可以邀请
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    let settings = store.get_group_settings(room_id).await?;

    if !can_manage {
        if let Some(settings) = settings {
            if !settings.member_can_invite {
                return Err(AppError::Forbidden(
                    "Group members cannot invite users".to_string(),
                ));
            }
        } else {
            return Err(AppError::Forbidden(
                "Only group owner or admin can invite users".to_string(),
            ));
        }
    }

    let invitations = store.create_invitations(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            None,
            "create_invitations",
            Some(serde_json::json!({
                "invitation_count": invitations.len(),
                "invitee_ids": invitations.iter().map(|i| i.invitee_id).collect::<Vec<_>>()
            })),
        )
        .await;

    Ok(Json(CreateInvitationsResponse { invitations }))
}

pub async fn respond_to_invitation(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(invitation_id): Path<Uuid>,
    Json(payload): Json<serde_json::Value>, // { "status": "accepted" | "declined" }
) -> Result<StatusCode, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let status_str = payload
        .get("status")
        .and_then(|v| v.as_str())
        .ok_or_else(|| AppError::ValidationError("Status is required".to_string()))?;

    let status = match status_str {
        "accepted" => crate::database::models::InvitationStatus::Accepted,
        "declined" => crate::database::models::InvitationStatus::Declined,
        _ => return Err(AppError::ValidationError("Invalid status".to_string())),
    };

    let store = GroupManagementStore::new(state.database.pool());

    let invitation = store
        .respond_to_invitation(invitation_id, status)
        .await?
        .ok_or_else(|| {
            AppError::NotFound("Invitation not found or already responded".to_string())
        })?;

    // 如果接受了邀请，将用户添加到群组中
    if status == crate::database::models::InvitationStatus::Accepted {
        use crate::database::room_store::RoomStore;
        let room_store = RoomStore::new(state.database.pool());
        let _ = room_store
            .add_member(invitation.room_id, user_id, None)
            .await?;
    }

    // 记录操作日志
    let _ = store
        .log_operation(
            invitation.room_id,
            user_id,
            None,
            "respond_to_invitation",
            Some(serde_json::json!({
                "invitation_id": invitation_id,
                "status": status_str,
                "inviter_id": invitation.inviter_id
            })),
        )
        .await;

    Ok(StatusCode::NO_CONTENT)
}

// ===== 群成员管理 API =====

#[derive(Debug, Deserialize)]
pub struct AddGroupMembersRequest {
    pub user_ids: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct AddGroupMembersResponse {
    pub success: bool,
    pub added_user_ids: Vec<Uuid>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub skipped_user_ids: Vec<Uuid>,
}

pub async fn add_group_members(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<AddGroupMembersRequest>,
) -> Result<Json<AddGroupMembersResponse>, AppError> {
    let operator_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    if request.user_ids.is_empty() {
        return Err(AppError::ValidationError(
            "待添加成员列表不能为空".to_string(),
        ));
    }

    let mut unique_ids = HashSet::new();
    let mut target_user_ids = Vec::new();
    for raw_id in request.user_ids.iter() {
        let trimmed = raw_id.trim();
        if trimmed.is_empty() {
            continue;
        }
        let user_id = Uuid::parse_str(trimmed)
            .map_err(|_| AppError::ValidationError(format!("无效的用户ID: {}", trimmed)))?;
        if user_id == operator_id {
            continue;
        }
        if unique_ids.insert(user_id) {
            target_user_ids.push(user_id);
        }
    }

    if target_user_ids.is_empty() {
        return Err(AppError::ValidationError(
            "没有有效的待添加成员".to_string(),
        ));
    }

    let store = GroupManagementStore::new(state.database.pool());
    let can_manage = store.can_manage_group(room_id, operator_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can add members".to_string(),
        ));
    }

    let settings = match store.get_group_settings(room_id).await? {
        Some(s) => s,
        None => {
            store.ensure_group_settings_row(room_id).await?;
            store
                .get_group_settings(room_id)
                .await?
                .ok_or_else(|| AppError::NotFound("Group settings not found".to_string()))?
        }
    };

    let current_count = store.count_active_members(room_id).await?;
    let remaining = settings.max_members as i64 - current_count;
    if remaining <= 0 {
        return Err(AppError::ValidationError("群成员已达到上限".to_string()));
    }
    if target_user_ids.len() as i64 > remaining {
        return Err(AppError::ValidationError(format!(
            "可添加成员数量超出上限，仅剩 {} 个名额",
            remaining
        )));
    }

    let room_store = RoomStore::new(state.database.pool());
    let mut added_user_ids = Vec::new();
    let mut skipped_user_ids = Vec::new();

    for user_id in target_user_ids {
        if room_store.is_user_in_room(room_id, user_id).await? {
            skipped_user_ids.push(user_id);
            continue;
        }

        let _ = room_store
            .add_member(room_id, user_id, Some(MemberRole::Member))
            .await?;
        added_user_ids.push(user_id);

        if let Err(e) = broadcast_group_member_changed(
            &state,
            room_id,
            user_id,
            GroupMemberChangeType::Joined,
            None,
            Some(operator_id),
            None,
            None,
        )
        .await
        {
            error!("广播群成员加入事件失败: {}", e);
        }
    }

    let _ = store
        .log_operation(
            room_id,
            operator_id,
            None,
            "add_members",
            Some(serde_json::json!({
                "added": added_user_ids,
                "skipped": skipped_user_ids
            })),
        )
        .await;

    Ok(Json(AddGroupMembersResponse {
        success: true,
        added_user_ids,
        skipped_user_ids,
    }))
}

#[derive(Debug, Serialize)]
pub struct RemoveGroupMemberResponse {
    pub success: bool,
}

pub async fn remove_group_member(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, member_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<RemoveGroupMemberResponse>, AppError> {
    let operator_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());
    let can_manage = store.can_manage_group(room_id, operator_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can remove members".to_string(),
        ));
    }

    if store.is_group_owner(room_id, member_id).await? {
        return Err(AppError::Forbidden("无法移除群主".to_string()));
    }

    let room_store = RoomStore::new(state.database.pool());
    let removed = room_store.remove_member(room_id, member_id).await?;
    if !removed {
        return Err(AppError::NotFound(
            "User is not a member of this room".to_string(),
        ));
    }

    let _ = store
        .log_operation(room_id, operator_id, Some(member_id), "remove_member", None)
        .await;

    if let Err(e) = broadcast_group_member_changed(
        &state,
        room_id,
        member_id,
        GroupMemberChangeType::Kicked,
        None,
        Some(operator_id),
        None,
        None,
    )
    .await
    {
        error!("广播群成员移除事件失败: {}", e);
    }

    Ok(Json(RemoveGroupMemberResponse { success: true }))
}

// ===== 群管理员管理 API =====

#[derive(Serialize)]
pub struct AppointAdminResponse {
    pub admin: GroupAdmin,
}

pub async fn appoint_admin(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<AppointAdminRequest>,
) -> Result<Json<AppointAdminResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主可以任命管理员
    let is_owner = store.is_group_owner(room_id, user_id).await?;
    if !is_owner {
        return Err(AppError::Forbidden(
            "Only group owner can appoint admins".to_string(),
        ));
    }

    let admin = store.appoint_admin(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            Some(admin.admin_id),
            "appoint_admin",
            Some(serde_json::json!({
                "admin_id": admin.admin_id,
                "role": admin.role
            })),
        )
        .await;

    // 广播群成员角色变更
    if let Err(e) = broadcast_group_member_changed(
        &state,
        room_id,
        admin.admin_id,
        GroupMemberChangeType::RoleChanged,
        Some(admin.role.clone()),
        Some(user_id),
        None,
        None,
    )
    .await
    {
        error!("广播群成员角色变更失败: {}", e);
    }

    Ok(Json(AppointAdminResponse { admin }))
}

pub async fn remove_admin(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, admin_id)): Path<(Uuid, Uuid)>,
) -> Result<StatusCode, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主可以移除管理员
    let is_owner = store.is_group_owner(room_id, user_id).await?;
    if !is_owner {
        return Err(AppError::Forbidden(
            "Only group owner can remove admins".to_string(),
        ));
    }

    let removed = store.remove_admin(room_id, admin_id).await?;
    if !removed {
        return Err(AppError::NotFound("Admin not found".to_string()));
    }

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            Some(admin_id),
            "remove_admin",
            Some(serde_json::json!({
                "admin_id": admin_id
            })),
        )
        .await;

    // 广播群成员角色变更（降为普通成员）
    if let Err(e) = broadcast_group_member_changed(
        &state,
        room_id,
        admin_id,
        GroupMemberChangeType::RoleChanged,
        Some("member".to_string()),
        Some(user_id),
        None,
        None,
    )
    .await
    {
        error!("广播群成员角色变更失败: {}", e);
    }

    Ok(StatusCode::NO_CONTENT)
}

#[derive(Serialize)]
pub struct ListAdminsResponse {
    pub admins: Vec<GroupAdmin>,
}

pub async fn list_admins(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<ListAdminsResponse>, AppError> {
    let store = GroupManagementStore::new(state.database.pool());
    let admins = store.list_admins(room_id).await?;

    Ok(Json(ListAdminsResponse { admins }))
}

// ===== 群禁言管理 API =====

#[derive(Serialize)]
pub struct MuteUserResponse {
    pub mute: GroupMute,
}

pub async fn mute_user(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    Json(request): Json<MuteUserRequest>,
) -> Result<Json<MuteUserResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以禁言用户
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can mute users".to_string(),
        ));
    }

    let mute = store.mute_user(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            Some(mute.user_id),
            "mute_user",
            Some(serde_json::json!({
                "muted_user_id": mute.user_id,
                "reason": mute.reason,
                "duration_hours": mute.mute_duration_hours
            })),
        )
        .await;

    // 广播群成员被禁言
    let mute_until = if mute.mute_duration_hours > 0 {
        Some(mute.muted_at + chrono::Duration::hours(mute.mute_duration_hours as i64))
    } else {
        None
    };
    if let Err(e) = broadcast_group_member_changed(
        &state,
        room_id,
        mute.user_id,
        GroupMemberChangeType::Muted,
        None,
        Some(user_id),
        mute.reason.clone(),
        mute_until,
    )
    .await
    {
        error!("广播群成员禁言失败: {}", e);
    }

    Ok(Json(MuteUserResponse { mute }))
}

pub async fn unmute_user(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path((room_id, muted_user_id)): Path<(Uuid, Uuid)>,
) -> Result<StatusCode, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以解除禁言
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can unmute users".to_string(),
        ));
    }

    let unmuted = store.unmute_user(room_id, muted_user_id).await?;
    if !unmuted {
        return Err(AppError::NotFound("User is not muted".to_string()));
    }

    // 记录操作日志
    let _ = store
        .log_operation(
            room_id,
            user_id,
            Some(muted_user_id),
            "unmute_user",
            Some(serde_json::json!({
                "unmuted_user_id": muted_user_id
            })),
        )
        .await;

    // 广播群成员解除禁言
    if let Err(e) = broadcast_group_member_changed(
        &state,
        room_id,
        muted_user_id,
        GroupMemberChangeType::Unmuted,
        None,
        Some(user_id),
        None,
        None,
    )
    .await
    {
        error!("广播群成员解除禁言失败: {}", e);
    }

    Ok(StatusCode::NO_CONTENT)
}

#[derive(Serialize)]
pub struct ListMutedUsersResponse {
    pub mutes: Vec<GroupMute>,
}

pub async fn list_muted_users(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<ListMutedUsersResponse>, AppError> {
    let store = GroupManagementStore::new(state.database.pool());
    let mutes = store.list_muted_users(room_id).await?;

    Ok(Json(ListMutedUsersResponse { mutes }))
}

// ===== 操作日志管理 API =====

#[derive(Serialize)]
pub struct ListOperationLogsResponse {
    pub logs: Vec<GroupOperationLog>,
    pub total: i64,
}

pub async fn list_operation_logs(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
    axum::extract::Query(params): axum::extract::Query<ListOperationLogsParams>,
) -> Result<Json<ListOperationLogsResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以查看操作日志
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(AppError::Forbidden(
            "Only group owner or admin can view operation logs".to_string(),
        ));
    }

    let logs = store
        .list_operation_logs(room_id, params.limit, params.offset)
        .await?;
    let total = logs.len() as i64;

    Ok(Json(ListOperationLogsResponse {
        logs,
        total, // 简化实现，实际应该查询总数
    }))
}

#[derive(Deserialize)]
pub struct ListOperationLogsParams {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

// ===== 群聊详情 API =====

#[derive(Serialize)]
pub struct GroupDetailResponse {
    pub info: GroupDetailInfo,
}

pub async fn get_group_detail(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<GroupDetailResponse>, AppError> {
    let store = GroupManagementStore::new(state.database.pool());

    let info = store
        .get_group_detail_info(room_id)
        .await?
        .ok_or_else(|| AppError::NotFound("Group not found".to_string()))?;

    Ok(Json(GroupDetailResponse { info }))
}

/// 广播群设置更新到房间内的所有连接
pub async fn broadcast_group_settings_update(
    state: &AppState,
    settings: &GroupSettings,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let payload = GroupSettingsUpdatePayload {
        room_id: settings.room_id,
        global_mute_enabled: settings.global_mute_enabled,
        global_mute_reason: settings.global_mute_reason.clone(),
        global_mute_until: settings.global_mute_until,
        global_mute_set_by: settings.global_mute_set_by,
    };

    let channel = CacheKeys::pubsub_channel(&settings.room_id);
    let encoded = PubSubPayload::GroupSettingsUpdate { data: payload }.encode_protobuf();

    let mut conn = state
        .redis
        .get_pubsub_client()
        .get_multiplexed_async_connection()
        .await?;

    let subscriber_count: i64 = redis::AsyncCommands::publish(&mut conn, &channel, encoded).await?;

    info!(
        "群设置更新已广播到房间 {} ({} 个订阅者)",
        settings.room_id, subscriber_count
    );

    Ok(())
}

/// 广播群成员变更到房间内的所有连接
pub async fn broadcast_group_member_changed(
    state: &AppState,
    room_id: Uuid,
    member_id: Uuid,
    change_type: GroupMemberChangeType,
    new_role: Option<String>,
    operator_id: Option<Uuid>,
    reason: Option<String>,
    until: Option<DateTime<Utc>>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let payload = GroupMemberChangedPayload {
        room_id,
        member_id,
        change_type,
        new_role,
        operator_id,
        reason,
        until,
    };

    let channel = CacheKeys::pubsub_channel(&room_id);
    let encoded = PubSubPayload::GroupMemberChanged { data: payload }.encode_protobuf();

    let mut conn = state
        .redis
        .get_pubsub_client()
        .get_multiplexed_async_connection()
        .await?;

    let subscriber_count: i64 = redis::AsyncCommands::publish(&mut conn, &channel, encoded).await?;

    info!(
        "群成员变更已广播到房间 {} ({} 个订阅者)",
        room_id, subscriber_count
    );

    Ok(())
}
