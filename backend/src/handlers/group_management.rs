use axum::{
    extract::{Path, State, Extension},
    response::Json,
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::{
    models::{
        GroupSettings, GroupAnnouncement, GroupRule, JoinRequest, GroupInvitation,
        GroupAdmin, GroupOperationLog, GroupMute, CreateAnnouncementRequest,
        UpdateAnnouncementRequest, CreateRuleRequest, UpdateRuleRequest,
        UpdateGroupSettingsRequest, JoinGroupRequest, ReviewJoinRequestRequest,
        InviteToGroupRequest, AppointAdminRequest, MuteUserRequest, GroupDetailInfo
    },
    group_management_store::GroupManagementStore,
};
use crate::error::AppError;
use crate::models::Claims;
use crate::AppState;

// ===== 群设置管理 API =====

#[derive(Serialize)]
pub struct GroupSettingsResponse {
    pub settings: GroupSettings,
}

pub async fn get_group_settings(
    State(state): State<AppState>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<GroupSettingsResponse>, AppError> {
    let store = GroupManagementStore::new(state.database.pool());

    let settings = store.get_group_settings(room_id).await?
        .ok_or_else(|| AppError::NotFound("Group settings not found".to_string()))?;

    Ok(Json(GroupSettingsResponse { settings }))
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
        return Err(AppError::Forbidden("Only group owner or admin can update settings".to_string()));
    }

    let settings = store.update_group_settings(room_id, request).await?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        None,
        "update_group_settings",
        Some(serde_json::to_value(&settings).unwrap_or_default()),
    ).await;

    Ok(Json(GroupSettingsResponse { settings }))
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
        return Err(AppError::Forbidden("Only group owner or admin can create announcements".to_string()));
    }

    let announcement = store.create_announcement(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        None,
        "create_announcement",
        Some(serde_json::json!({
            "announcement_id": announcement.id,
            "title": announcement.title
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner or admin can update announcements".to_string()));
    }

    let announcement = store.update_announcement(announcement_id, request).await?
        .ok_or_else(|| AppError::NotFound("Announcement not found".to_string()))?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        None,
        "update_announcement",
        Some(serde_json::json!({
            "announcement_id": announcement.id,
            "title": announcement.title
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner or admin can delete announcements".to_string()));
    }

    let deleted = store.delete_announcement(announcement_id).await?;
    if !deleted {
        return Err(AppError::NotFound("Announcement not found".to_string()));
    }

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        None,
        "delete_announcement",
        Some(serde_json::json!({
            "announcement_id": announcement_id
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner or admin can create rules".to_string()));
    }

    let rule = store.create_rule(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        None,
        "create_rule",
        Some(serde_json::json!({
            "rule_id": rule.id,
            "title": rule.title
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner or admin can update rules".to_string()));
    }

    let rule = store.update_rule(rule_id, request).await?
        .ok_or_else(|| AppError::NotFound("Rule not found".to_string()))?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        None,
        "update_rule",
        Some(serde_json::json!({
            "rule_id": rule.id,
            "title": rule.title
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner or admin can delete rules".to_string()));
    }

    let deleted = store.delete_rule(rule_id).await?;
    if !deleted {
        return Err(AppError::NotFound("Rule not found".to_string()));
    }

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        None,
        "delete_rule",
        Some(serde_json::json!({
            "rule_id": rule_id
        })),
    ).await;

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

    Ok(Json(CreateJoinRequestResponse { request: join_request }))
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
        return Err(AppError::Forbidden("Only group owner or admin can view join requests".to_string()));
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
        return Err(AppError::Forbidden("Only group owner or admin can review join requests".to_string()));
    }

    let status_copy = request.status;
    let join_request = store.review_join_request(request_id, user_id, request).await?
        .ok_or_else(|| AppError::NotFound("Join request not found or already reviewed".to_string()))?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        Some(join_request.applicant_id),
        "review_join_request",
        Some(serde_json::json!({
            "request_id": request_id,
            "status": status_copy,
            "applicant_id": join_request.applicant_id
        })),
    ).await;

    Ok(Json(CreateJoinRequestResponse { request: join_request }))
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
                return Err(AppError::Forbidden("Group members cannot invite users".to_string()));
            }
        } else {
            return Err(AppError::Forbidden("Only group owner or admin can invite users".to_string()));
        }
    }

    let invitations = store.create_invitations(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        None,
        "create_invitations",
        Some(serde_json::json!({
            "invitation_count": invitations.len(),
            "invitee_ids": invitations.iter().map(|i| i.invitee_id).collect::<Vec<_>>()
        })),
    ).await;

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

    let status_str = payload.get("status")
        .and_then(|v| v.as_str())
        .ok_or_else(|| AppError::ValidationError("Status is required".to_string()))?;

    let status = match status_str {
        "accepted" => crate::database::models::InvitationStatus::Accepted,
        "declined" => crate::database::models::InvitationStatus::Declined,
        _ => return Err(AppError::ValidationError("Invalid status".to_string())),
    };

    let store = GroupManagementStore::new(state.database.pool());

    let invitation = store.respond_to_invitation(invitation_id, status).await?
        .ok_or_else(|| AppError::NotFound("Invitation not found or already responded".to_string()))?;

    // 如果接受了邀请，将用户添加到群组中
    if status == crate::database::models::InvitationStatus::Accepted {
        use crate::database::room_store::RoomStore;
        let room_store = RoomStore::new(state.database.pool());
        let _ = room_store.add_member(invitation.room_id, user_id, None).await?;
    }

    // 记录操作日志
    let _ = store.log_operation(
        invitation.room_id,
        user_id,
        None,
        "respond_to_invitation",
        Some(serde_json::json!({
            "invitation_id": invitation_id,
            "status": status_str,
            "inviter_id": invitation.inviter_id
        })),
    ).await;

    Ok(StatusCode::NO_CONTENT)
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
        return Err(AppError::Forbidden("Only group owner can appoint admins".to_string()));
    }

    let admin = store.appoint_admin(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        Some(admin.admin_id),
        "appoint_admin",
        Some(serde_json::json!({
            "admin_id": admin.admin_id,
            "role": admin.role
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner can remove admins".to_string()));
    }

    let removed = store.remove_admin(room_id, admin_id).await?;
    if !removed {
        return Err(AppError::NotFound("Admin not found".to_string()));
    }

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        Some(admin_id),
        "remove_admin",
        Some(serde_json::json!({
            "admin_id": admin_id
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner or admin can mute users".to_string()));
    }

    let mute = store.mute_user(room_id, user_id, request).await?;

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        Some(mute.user_id),
        "mute_user",
        Some(serde_json::json!({
            "muted_user_id": mute.user_id,
            "reason": mute.reason,
            "duration_hours": mute.mute_duration_hours
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner or admin can unmute users".to_string()));
    }

    let unmuted = store.unmute_user(room_id, muted_user_id).await?;
    if !unmuted {
        return Err(AppError::NotFound("User is not muted".to_string()));
    }

    // 记录操作日志
    let _ = store.log_operation(
        room_id,
        user_id,
        Some(muted_user_id),
        "unmute_user",
        Some(serde_json::json!({
            "unmuted_user_id": muted_user_id
        })),
    ).await;

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
        return Err(AppError::Forbidden("Only group owner or admin can view operation logs".to_string()));
    }

    let logs = store.list_operation_logs(room_id, params.limit, params.offset).await?;
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

    let info = store.get_group_detail_info(room_id).await?
        .ok_or_else(|| AppError::NotFound("Group not found".to_string()))?;

    Ok(Json(GroupDetailResponse { info }))
}