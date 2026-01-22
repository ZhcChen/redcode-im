//! GroupManagementStore 测试
//!
//! 覆盖群设置、群规、入群申请、邀请、管理员、禁言等功能。

use super::common::{setup_test_db, unique_email, unique_username};
use redcode_im_backend::database::group_management_store::GroupManagementStore;
use redcode_im_backend::database::models::{
    AppointAdminRequest, CreateRuleRequest, CreateUserRequest, JoinGroupRequest,
    JoinRequestStatus, MuteUserRequest, ReviewJoinRequestRequest, UpdateGroupSettingsRequest,
    UpdateRuleRequest,
};
use redcode_im_backend::database::room_store::RoomStore;
use redcode_im_backend::database::user_store::UserStore;
use redcode_im_backend::database::Database;
use sqlx::PgPool;
use uuid::Uuid;

/// 创建测试用户并返回用户 ID
async fn create_test_user(pool: &PgPool) -> Uuid {
    let store = UserStore::new(Database { pool: pool.clone() });
    let request = CreateUserRequest {
        username: unique_username(),
        email: unique_email(),
        password: "password123".to_string(),
        nickname: Some("Test User".to_string()),
    };
    store.create_user(request).await.unwrap().id
}

/// 创建测试群聊并返回房间 ID
async fn create_test_room(pool: &PgPool, owner_id: Uuid) -> Uuid {
    let store = RoomStore::new(pool);
    let room = store
        .create_room(owner_id, format!("room_{}", Uuid::new_v4().simple()), None, None)
        .await
        .unwrap();
    room.id
}

// ============================================================================
// 群设置测试
// ============================================================================

#[tokio::test]
async fn test_get_group_settings_not_exists() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let random_room_id = Uuid::new_v4();
    let result = store.get_group_settings(random_room_id).await;

    assert!(result.is_ok());
    assert!(result.unwrap().is_none(), "不存在的群设置应返回 None");
}

#[tokio::test]
async fn test_ensure_group_settings_row() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 确保设置行存在
    let result = store.ensure_group_settings_row(room_id).await;
    assert!(result.is_ok(), "确保设置行应成功");

    // 再次调用应该不会失败（幂等）
    let result = store.ensure_group_settings_row(room_id).await;
    assert!(result.is_ok(), "重复调用应成功");
}

#[tokio::test]
async fn test_update_group_settings() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    let request = UpdateGroupSettingsRequest {
        join_approval_required: Some(true),
        member_can_invite: Some(false),
        member_can_add_friends: Some(true),
        require_admin_to_add_friends: Some(true),
        max_members: Some(500),
    };

    let result = store.update_group_settings(room_id, request).await;
    assert!(result.is_ok(), "更新群设置应成功");

    let settings = result.unwrap();
    assert!(settings.join_approval_required);
    assert!(!settings.member_can_invite);
    assert!(settings.member_can_add_friends);
    assert!(settings.require_admin_to_add_friends);
    assert_eq!(settings.max_members, 500);
}

#[tokio::test]
async fn test_get_or_create_group_settings() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 获取或创建设置
    let result = store.get_or_create_group_settings(room_id).await;
    assert!(result.is_ok(), "获取或创建设置应成功");

    let settings = result.unwrap();
    assert_eq!(settings.room_id, room_id);
}

// ============================================================================
// 全局禁言测试
// ============================================================================

#[tokio::test]
async fn test_set_global_mute_state() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 启用全局禁言
    let result = store
        .set_global_mute_state(room_id, owner_id, true, Some("维护中".to_string()), Some(60))
        .await;

    assert!(result.is_ok(), "设置全局禁言应成功");
    let settings = result.unwrap();
    assert!(settings.global_mute_enabled);
    assert_eq!(settings.global_mute_reason, Some("维护中".to_string()));
    assert_eq!(settings.global_mute_set_by, Some(owner_id));
    assert!(settings.global_mute_until.is_some());
}

#[tokio::test]
async fn test_clear_global_mute() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 先启用禁言
    let _ = store
        .set_global_mute_state(room_id, owner_id, true, Some("测试".to_string()), None)
        .await
        .unwrap();

    // 清除禁言
    let result = store.clear_global_mute(room_id).await;
    assert!(result.is_ok(), "清除禁言应成功");

    let settings = result.unwrap();
    assert!(!settings.global_mute_enabled);
    assert!(settings.global_mute_reason.is_none());
    assert!(settings.global_mute_set_by.is_none());
    assert!(settings.global_mute_until.is_none());
}

// ============================================================================
// 群规测试
// ============================================================================

#[tokio::test]
async fn test_create_rule() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    let request = CreateRuleRequest {
        title: "群规标题".to_string(),
        content: "群规内容详情".to_string(),
        order_index: Some(1),
    };

    let result = store.create_rule(room_id, owner_id, request).await;
    assert!(result.is_ok(), "创建群规应成功");

    let rule = result.unwrap();
    assert_eq!(rule.room_id, room_id);
    assert_eq!(rule.title, "群规标题");
    assert_eq!(rule.content, "群规内容详情");
    assert_eq!(rule.creator_id, owner_id);
    assert_eq!(rule.order_index, 1);
    assert!(rule.is_active);
}

#[tokio::test]
async fn test_list_rules() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 创建多条群规
    for i in 0..3 {
        let request = CreateRuleRequest {
            title: format!("规则 {}", i),
            content: format!("内容 {}", i),
            order_index: Some(i),
        };
        let _ = store.create_rule(room_id, owner_id, request).await.unwrap();
    }

    let result = store.list_rules(room_id).await;
    assert!(result.is_ok(), "列出群规应成功");
    assert_eq!(result.unwrap().len(), 3, "应该有 3 条群规");
}

#[tokio::test]
async fn test_update_rule() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 先创建群规
    let create_request = CreateRuleRequest {
        title: "原标题".to_string(),
        content: "原内容".to_string(),
        order_index: Some(0),
    };
    let rule = store.create_rule(room_id, owner_id, create_request).await.unwrap();

    // 更新群规
    let update_request = UpdateRuleRequest {
        title: Some("新标题".to_string()),
        content: Some("新内容".to_string()),
        order_index: Some(10),
        is_active: Some(false),
    };

    let result = store.update_rule(rule.id, update_request).await;
    assert!(result.is_ok(), "更新群规应成功");

    let updated = result.unwrap().unwrap();
    assert_eq!(updated.title, "新标题");
    assert_eq!(updated.content, "新内容");
    assert_eq!(updated.order_index, 10);
    assert!(!updated.is_active);
}

#[tokio::test]
async fn test_delete_rule() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 创建群规
    let create_request = CreateRuleRequest {
        title: "待删除".to_string(),
        content: "内容".to_string(),
        order_index: None,
    };
    let rule = store.create_rule(room_id, owner_id, create_request).await.unwrap();

    // 删除群规
    let result = store.delete_rule(rule.id).await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "删除应成功");

    // 再次删除应该返回 false
    let result = store.delete_rule(rule.id).await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "重复删除应返回 false");
}

// ============================================================================
// 入群申请测试
// ============================================================================

#[tokio::test]
async fn test_create_join_request() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let applicant_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    let request = JoinGroupRequest {
        message: Some("请求加入".to_string()),
    };

    let result = store.create_join_request(room_id, applicant_id, request).await;
    assert!(result.is_ok(), "创建入群申请应成功");

    let join_request = result.unwrap();
    assert_eq!(join_request.room_id, room_id);
    assert_eq!(join_request.applicant_id, applicant_id);
    assert_eq!(join_request.message, Some("请求加入".to_string()));
    assert_eq!(join_request.status, JoinRequestStatus::Pending);
}

#[tokio::test]
async fn test_list_join_requests() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 创建多个申请
    for _ in 0..3 {
        let applicant_id = create_test_user(&test_db.pool).await;
        let request = JoinGroupRequest {
            message: Some("申请加入".to_string()),
        };
        let _ = store.create_join_request(room_id, applicant_id, request).await.unwrap();
    }

    let result = store.list_join_requests(room_id).await;
    assert!(result.is_ok(), "列出申请应成功");
    assert_eq!(result.unwrap().len(), 3, "应有 3 个申请");
}

#[tokio::test]
async fn test_review_join_request_approve() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let applicant_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 创建申请
    let request = JoinGroupRequest {
        message: Some("申请加入".to_string()),
    };
    let join_request = store.create_join_request(room_id, applicant_id, request).await.unwrap();

    // 审批通过
    let review = ReviewJoinRequestRequest {
        status: JoinRequestStatus::Approved,
        review_message: Some("欢迎加入".to_string()),
    };

    let result = store.review_join_request(join_request.id, owner_id, review).await;
    assert!(result.is_ok(), "审批应成功");

    let reviewed = result.unwrap().unwrap();
    assert_eq!(reviewed.status, JoinRequestStatus::Approved);
    assert_eq!(reviewed.reviewer_id, Some(owner_id));
    assert_eq!(reviewed.review_message, Some("欢迎加入".to_string()));
    assert!(reviewed.reviewed_at.is_some());
}

#[tokio::test]
async fn test_has_approved_join_request() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let applicant_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 未申请时
    let result = store.has_approved_join_request(room_id, applicant_id).await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "未申请应返回 false");

    // 创建并通过申请
    let request = JoinGroupRequest { message: None };
    let join_request = store.create_join_request(room_id, applicant_id, request).await.unwrap();

    let review = ReviewJoinRequestRequest {
        status: JoinRequestStatus::Approved,
        review_message: None,
    };
    let _ = store.review_join_request(join_request.id, owner_id, review).await.unwrap();

    // 检查是否已通过
    let result = store.has_approved_join_request(room_id, applicant_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "已通过应返回 true");
}

// ============================================================================
// 群管理员测试
// ============================================================================

#[tokio::test]
async fn test_appoint_admin() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let member_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    let request = AppointAdminRequest {
        user_id: member_id.to_string(),
        role: "admin".to_string(),
        permissions: Some(vec!["manage_members".to_string(), "delete_messages".to_string()]),
    };

    let result = store.appoint_admin(room_id, owner_id, request).await;
    assert!(result.is_ok(), "任命管理员应成功");

    let admin = result.unwrap();
    assert_eq!(admin.room_id, room_id);
    assert_eq!(admin.admin_id, member_id);
    assert_eq!(admin.appointed_by, owner_id);
    assert_eq!(admin.role, "admin");
}

#[tokio::test]
async fn test_list_admins() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 任命多个管理员
    for _ in 0..2 {
        let member_id = create_test_user(&test_db.pool).await;
        let request = AppointAdminRequest {
            user_id: member_id.to_string(),
            role: "moderator".to_string(),
            permissions: None,
        };
        let _ = store.appoint_admin(room_id, owner_id, request).await.unwrap();
    }

    let result = store.list_admins(room_id).await;
    assert!(result.is_ok(), "列出管理员应成功");
    assert_eq!(result.unwrap().len(), 2, "应有 2 个管理员");
}

#[tokio::test]
async fn test_remove_admin() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let member_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 任命管理员
    let request = AppointAdminRequest {
        user_id: member_id.to_string(),
        role: "moderator".to_string(),
        permissions: None,
    };
    let _ = store.appoint_admin(room_id, owner_id, request).await.unwrap();

    // 移除管理员
    let result = store.remove_admin(room_id, member_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "移除应成功");

    // 再次移除应返回 false
    let result = store.remove_admin(room_id, member_id).await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "重复移除应返回 false");
}

// ============================================================================
// 群禁言测试
// ============================================================================

#[tokio::test]
async fn test_mute_user() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let member_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    let request = MuteUserRequest {
        user_id: member_id.to_string(),
        reason: Some("违规发言".to_string()),
        mute_duration_hours: Some(24),
    };

    let result = store.mute_user(room_id, owner_id, request).await;
    assert!(result.is_ok(), "禁言应成功");

    let mute = result.unwrap();
    assert_eq!(mute.room_id, room_id);
    assert_eq!(mute.user_id, member_id);
    assert_eq!(mute.muted_by, owner_id);
    assert_eq!(mute.reason, Some("违规发言".to_string()));
    assert_eq!(mute.mute_duration_hours, 24);
    assert!(mute.is_active);
}

#[tokio::test]
async fn test_find_active_mute() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let member_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 未禁言时
    let result = store.find_active_mute(room_id, member_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_none(), "未禁言应返回 None");

    // 禁言
    let request = MuteUserRequest {
        user_id: member_id.to_string(),
        reason: None,
        mute_duration_hours: Some(24),
    };
    let _ = store.mute_user(room_id, owner_id, request).await.unwrap();

    // 查找活跃禁言
    let result = store.find_active_mute(room_id, member_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap().is_some(), "应找到活跃禁言");
}

#[tokio::test]
async fn test_unmute_user() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let member_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 先禁言
    let request = MuteUserRequest {
        user_id: member_id.to_string(),
        reason: None,
        mute_duration_hours: Some(1),
    };
    let _ = store.mute_user(room_id, owner_id, request).await.unwrap();

    // 解除禁言
    let result = store.unmute_user(room_id, member_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "解禁应成功");

    // 确认已解禁
    let result = store.find_active_mute(room_id, member_id).await;
    assert!(result.unwrap().is_none(), "解禁后应找不到活跃禁言");
}

#[tokio::test]
async fn test_list_muted_users() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 禁言多个用户
    for _ in 0..3 {
        let member_id = create_test_user(&test_db.pool).await;
        let request = MuteUserRequest {
            user_id: member_id.to_string(),
            reason: None,
            mute_duration_hours: Some(24),
        };
        let _ = store.mute_user(room_id, owner_id, request).await.unwrap();
    }

    let result = store.list_muted_users(room_id).await;
    assert!(result.is_ok(), "列出被禁言用户应成功");
    assert_eq!(result.unwrap().len(), 3, "应有 3 个被禁言用户");
}

// ============================================================================
// 操作日志测试
// ============================================================================

#[tokio::test]
async fn test_log_operation() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let target_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    let data = serde_json::json!({"action": "mute", "duration": 24});
    let result = store
        .log_operation(room_id, owner_id, Some(target_id), "mute_user", Some(data.clone()))
        .await;

    assert!(result.is_ok(), "记录操作日志应成功");

    let log = result.unwrap();
    assert_eq!(log.room_id, room_id);
    assert_eq!(log.operator_id, owner_id);
    assert_eq!(log.target_user_id, Some(target_id));
    assert_eq!(log.operation_type, "mute_user");
    assert_eq!(log.operation_data, Some(data));
}

#[tokio::test]
async fn test_list_operation_logs() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 记录多条日志
    for i in 0..5 {
        let _ = store
            .log_operation(room_id, owner_id, None, &format!("operation_{}", i), None)
            .await
            .unwrap();
    }

    // 列出日志（带分页）
    let result = store.list_operation_logs(room_id, Some(3), Some(0)).await;
    assert!(result.is_ok(), "列出日志应成功");
    assert_eq!(result.unwrap().len(), 3, "应返回 3 条日志");

    // 获取全部
    let result = store.list_operation_logs(room_id, None, None).await;
    assert!(result.is_ok());
    assert_eq!(result.unwrap().len(), 5, "应有 5 条日志");
}

// ============================================================================
// 权限检查测试
// ============================================================================

#[tokio::test]
async fn test_is_group_admin() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let member_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 未任命前
    let result = store.is_group_admin(room_id, member_id).await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "未任命应返回 false");

    // 任命管理员
    let request = AppointAdminRequest {
        user_id: member_id.to_string(),
        role: "moderator".to_string(),
        permissions: None,
    };
    let _ = store.appoint_admin(room_id, owner_id, request).await.unwrap();

    // 任命后
    let result = store.is_group_admin(room_id, member_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "任命后应返回 true");
}

#[tokio::test]
async fn test_is_group_owner() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let other_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    let result = store.is_group_owner(room_id, owner_id).await;
    assert!(result.is_ok());
    assert!(result.unwrap(), "群主应返回 true");

    let result = store.is_group_owner(room_id, other_id).await;
    assert!(result.is_ok());
    assert!(!result.unwrap(), "非群主应返回 false");
}

#[tokio::test]
async fn test_can_manage_group() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let admin_id = create_test_user(&test_db.pool).await;
    let member_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 群主可以管理
    let result = store.can_manage_group(room_id, owner_id).await;
    assert!(result.unwrap(), "群主应可以管理");

    // 普通成员不能管理
    let result = store.can_manage_group(room_id, member_id).await;
    assert!(!result.unwrap(), "普通成员不能管理");

    // 任命管理员后可以管理
    let request = AppointAdminRequest {
        user_id: admin_id.to_string(),
        role: "moderator".to_string(),
        permissions: None,
    };
    let _ = store.appoint_admin(room_id, owner_id, request).await.unwrap();

    let result = store.can_manage_group(room_id, admin_id).await;
    assert!(result.unwrap(), "管理员应可以管理");
}

// ============================================================================
// 群成员计数测试
// ============================================================================

#[tokio::test]
async fn test_count_active_members() {
    let test_db = setup_test_db().await;
    let store = GroupManagementStore::new(&test_db.pool);

    let owner_id = create_test_user(&test_db.pool).await;
    let room_id = create_test_room(&test_db.pool, owner_id).await;

    // 创建群时会添加群主为成员
    let result = store.count_active_members(room_id).await;
    assert!(result.is_ok(), "计数应成功");
    // 群主应该是成员
    assert!(result.unwrap() >= 1, "至少应有 1 个成员（群主）");
}
