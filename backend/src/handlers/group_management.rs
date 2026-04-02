use axum::{
    extract::{Extension, Path, State},
    http::StatusCode,
    response::Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashSet};
use uuid::Uuid;

use tracing::{error, info};

use crate::database::{
    group_management_store::GroupManagementStore,
    models::{
        AppointAdminRequest, CreateRuleRequest, GroupAdmin, GroupDetailInfo, GroupInvitation,
        GroupMute, GroupOperationLog, GroupRule, GroupSettings, InviteToGroupRequest,
        JoinGroupRequest, JoinRequest, MemberRole, MuteUserRequest, ReviewJoinRequestRequest,
        UpdateGroupSettingsRequest, UpdateRuleRequest,
    },
    room_store::RoomStore,
};
use crate::error::AppError;
use crate::i18n::message::MessageParams;
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

fn group_validation_error(message_key: &'static str) -> AppError {
    AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn group_validation_error_with_params(
    message_key: &'static str,
    params: MessageParams,
) -> AppError {
    AppError::ValidationError(String::new()).with_message_key_and_params(message_key, Some(params))
}

fn group_invalid_token_error(message_key: &'static str) -> AppError {
    AppError::InvalidToken(String::new()).with_message_key(message_key)
}

fn group_forbidden_error(message_key: &'static str) -> AppError {
    AppError::Forbidden(String::new()).with_message_key(message_key)
}

fn group_not_found_error(message_key: &'static str) -> AppError {
    AppError::NotFound(String::new()).with_message_key(message_key)
}

fn parse_group_claim_user_id(subject: &str) -> Result<Uuid, AppError> {
    Uuid::parse_str(subject).map_err(|_| group_invalid_token_error("auth.token_subject_invalid"))
}

pub async fn get_group_settings(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<GroupSettingsResponse>, AppError> {
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    let settings = match store.get_group_settings(room_id).await? {
        Some(s) => s,
        None => {
            // 兼容历史群聊未生成设置记录的情况
            store.ensure_group_settings_row(room_id).await?;
            store
                .get_group_settings(room_id)
                .await?
                .ok_or_else(|| group_not_found_error("group.settings_not_found"))?
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.global_mute_update_forbidden"));
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以修改设置
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.settings_update_forbidden"));
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以创建群规
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.rule_create_forbidden"));
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以修改群规
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.rule_update_forbidden"));
    }

    let rule = store
        .update_rule(rule_id, request)
        .await?
        .ok_or_else(|| group_not_found_error("group.rule_not_found"))?;

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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以删除群规
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.rule_delete_forbidden"));
    }

    let deleted = store.delete_rule(rule_id).await?;
    if !deleted {
        return Err(group_not_found_error("group.rule_not_found"));
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以查看入群申请
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.join_request_list_forbidden"));
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以审批入群申请
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.join_request_review_forbidden"));
    }

    let status_copy = request.status;
    let join_request = store
        .review_join_request(request_id, user_id, request)
        .await?
        .ok_or_else(|| group_not_found_error("group.join_request_not_found_or_reviewed"))?;

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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 必须是群成员才能邀请（否则会导致非成员借助 member_can_invite 越权邀请）
    let room_store = RoomStore::new(state.database.pool());
    if !room_store.is_user_in_room(room_id, user_id).await? {
        return Err(group_forbidden_error("group.invite_membership_required"));
    }

    // 权限检查：只有群主、管理员或有邀请权限的成员可以邀请
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    let settings = store.get_group_settings(room_id).await?;

    if !can_manage {
        if let Some(settings) = settings {
            if !settings.member_can_invite {
                return Err(group_forbidden_error("group.member_invite_disabled"));
            }
        } else {
            return Err(group_forbidden_error(
                "group.invite_owner_or_admin_required",
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
    Path((room_id, invitation_id)): Path<(Uuid, Uuid)>,
    Json(payload): Json<serde_json::Value>, // { "status": "accepted" | "declined" }
) -> Result<StatusCode, AppError> {
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let status_str = payload
        .get("status")
        .and_then(|v| v.as_str())
        .ok_or_else(|| group_validation_error("group.invitation_status_required"))?;

    let status = match status_str {
        "accepted" => crate::database::models::InvitationStatus::Accepted,
        "declined" => crate::database::models::InvitationStatus::Declined,
        _ => return Err(group_validation_error("group.invitation_status_invalid")),
    };

    let store = GroupManagementStore::new(state.database.pool());
    let room_store = RoomStore::new(state.database.pool());

    let existing = store
        .get_invitation_by_id(invitation_id)
        .await?
        .ok_or_else(|| group_not_found_error("group.invitation_not_found"))?;

    if existing.room_id != room_id {
        return Err(group_not_found_error("group.invitation_not_found"));
    }

    if existing.invitee_id != user_id {
        return Err(group_forbidden_error("group.invitation_respond_forbidden"));
    }

    if existing.status != crate::database::models::InvitationStatus::Pending {
        return Err(group_not_found_error(
            "group.invitation_not_found_or_responded",
        ));
    }

    let invitation = store
        .respond_to_invitation(invitation_id, status)
        .await?
        .ok_or_else(|| group_not_found_error("group.invitation_not_found_or_responded"))?;

    // 如果接受了邀请，将用户添加到群组中
    if status == crate::database::models::InvitationStatus::Accepted {
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
    let operator_id = parse_group_claim_user_id(&claims.sub)?;

    if request.user_ids.is_empty() {
        return Err(group_validation_error("group.member_list_empty"));
    }

    let mut unique_ids = HashSet::new();
    let mut target_user_ids = Vec::new();
    for raw_id in request.user_ids.iter() {
        let trimmed = raw_id.trim();
        if trimmed.is_empty() {
            continue;
        }
        let user_id = Uuid::parse_str(trimmed).map_err(|_| {
            group_validation_error_with_params(
                "group.member_id_invalid",
                BTreeMap::from([("user_id".to_string(), trimmed.to_string())]),
            )
        })?;
        if user_id == operator_id {
            continue;
        }
        if unique_ids.insert(user_id) {
            target_user_ids.push(user_id);
        }
    }

    if target_user_ids.is_empty() {
        return Err(group_validation_error("group.member_list_no_valid_targets"));
    }

    let store = GroupManagementStore::new(state.database.pool());
    let can_manage = store.can_manage_group(room_id, operator_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.member_add_forbidden"));
    }

    let settings = store
        .get_or_create_group_settings(room_id)
        .await
        .map_err(|e| {
            error!("获取或创建群设置失败: {:?}", e);
            group_not_found_error("group.settings_not_found")
        })?;

    let current_count = store.count_active_members(room_id).await?;
    let remaining = settings.max_members as i64 - current_count;
    if remaining <= 0 {
        return Err(group_validation_error("group.member_limit_reached"));
    }
    if target_user_ids.len() as i64 > remaining {
        return Err(group_validation_error_with_params(
            "group.member_add_limit_exceeded",
            BTreeMap::from([("remaining_slots".to_string(), remaining.to_string())]),
        ));
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
    let operator_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());
    let can_manage = store.can_manage_group(room_id, operator_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.member_remove_forbidden"));
    }

    if store.is_group_owner(room_id, member_id).await? {
        return Err(group_forbidden_error("group.owner_cannot_be_removed"));
    }

    let room_store = RoomStore::new(state.database.pool());
    let removed = room_store.remove_member(room_id, member_id).await?;
    if !removed {
        return Err(group_not_found_error("group.member_not_in_room"));
    }

    let room_name = room_store
        .get_room(room_id)
        .await
        .map(|room| room.name)
        .unwrap_or_default();

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

    crate::services::push::enqueue_group_event(
        &state,
        vec![member_id],
        room_id,
        room_name,
        "kicked",
    )
    .await;

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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主可以任命管理员
    let is_owner = store.is_group_owner(room_id, user_id).await?;
    if !is_owner {
        return Err(group_forbidden_error("group.admin_appoint_forbidden"));
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主可以移除管理员
    let is_owner = store.is_group_owner(room_id, user_id).await?;
    if !is_owner {
        return Err(group_forbidden_error("group.admin_remove_forbidden"));
    }

    let removed = store.remove_admin(room_id, admin_id).await?;
    if !removed {
        return Err(group_not_found_error("group.admin_not_found"));
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以禁言用户
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.user_mute_forbidden"));
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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以解除禁言
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.user_unmute_forbidden"));
    }

    let unmuted = store.unmute_user(room_id, muted_user_id).await?;
    if !unmuted {
        return Err(group_not_found_error("group.muted_user_not_found"));
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
    Extension(claims): Extension<Claims>,
    Path(room_id): Path<Uuid>,
) -> Result<Json<ListMutedUsersResponse>, AppError> {
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以查看禁言列表
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.muted_user_list_forbidden"));
    }

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
    let user_id = parse_group_claim_user_id(&claims.sub)?;

    let store = GroupManagementStore::new(state.database.pool());

    // 权限检查：只有群主或管理员可以查看操作日志
    let can_manage = store.can_manage_group(room_id, user_id).await?;
    if !can_manage {
        return Err(group_forbidden_error("group.operation_logs_list_forbidden"));
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
        .ok_or_else(|| group_not_found_error("group.not_found"))?;

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

#[cfg(test)]
mod tests {
    #[test]
    fn test_group_management_push_titles_should_not_embed_legacy_chinese_literals() {
        let source = include_str!("group_management.rs");
        assert!(
            !source.contains("\u{4f60}\u{5df2}\u{88ab}\u{79fb}\u{51fa}\u{7fa4}\u{804a}"),
            "group_management push title should not embed legacy literal"
        );
    }

    #[test]
    fn test_group_management_remove_member_should_not_embed_legacy_room_name_fallback() {
        let source = include_str!("group_management.rs");
        let legacy = [
            ".unwrap_or_else(|_| \"",
            "\u{7fa4}\u{804a}",
            "\".to_string())",
        ]
        .concat();

        assert!(
            !source.contains(&legacy),
            "remove_group_member should not embed legacy room name fallback literal"
        );
    }
}
