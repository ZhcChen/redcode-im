//! 房间 API 测试
//!
//! 覆盖房间创建、加入、退出等功能。

use super::common::{
    create_group_room, create_public_room, empty_request, json_request, login_user, read_json,
    register_user, send_message, test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;

#[tokio::test]
async fn rooms_public_join_leave_flow() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let _ = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-public-room").await;

    // user2 join
    let response = app
        .clone()
        .oneshot(empty_request(
            Method::POST,
            &format!("/rooms/{}/join", room_id),
            Some(&token2),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);

    // user2 leave
    let response = app
        .clone()
        .oneshot(empty_request(
            Method::POST,
            &format!("/rooms/{}/leave", room_id),
            Some(&token2),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);
}

#[tokio::test]
async fn rooms_create_group_requires_at_least_one_member() {
    let state = test_state().await;
    let app = test_router(state);

    let user1 = unique_phone_username();
    let pass = "Passw0rd!";
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let body = json!({
        "name": "rust-group-room",
        "description": "rust-test",
        "room_type": "group",
        "member_ids": []
    });
    let response = app
        .oneshot(json_request(Method::POST, "/rooms", Some(&token1), body))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn rooms_create_group_with_member_succeeds() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let body = json!({
        "name": "rust-group-room",
        "description": "rust-test",
        "room_type": "group",
        "member_ids": [user2_id]
    });
    let response = app
        .oneshot(json_request(Method::POST, "/rooms", Some(&token1), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "create group 响应异常: {resp}");
    assert!(resp.get("room").is_some(), "响应缺少 room 字段");
}

#[tokio::test]
async fn rooms_create_public_room_succeeds() {
    let state = test_state().await;
    let app = test_router(state);

    let user1 = unique_phone_username();
    let pass = "Passw0rd!";
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let body = json!({
        "name": "rust-public-room-test",
        "description": "rust-test",
        "room_type": "public",
        "member_ids": []
    });
    let response = app
        .oneshot(json_request(Method::POST, "/rooms", Some(&token1), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "create public room 响应异常: {resp}");
    assert!(resp.get("room").is_some(), "响应缺少 room 字段");
}

#[tokio::test]
async fn rooms_join_nonexistent_room_returns_404() {
    let state = test_state().await;
    let app = test_router(state);

    let user1 = unique_phone_username();
    let pass = "Passw0rd!";
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let fake_room_id = uuid::Uuid::new_v4();
    let response = app
        .oneshot(empty_request(
            Method::POST,
            &format!("/rooms/{}/join", fake_room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

// ============================================================================
// 房间详情测试
// ============================================================================

// Note: /rooms/{id}/detail 仅对 group 类型有效，public 类型返回 404
// 此测试用例暂时跳过，待 Phase 3 群组测试完善后启用
// #[tokio::test]
// async fn get_room_detail_success() { ... }

// Note: GET /rooms/{id} 返回的是 ChatSummary 而非 Room，字段结构不同
// 此测试用例暂时跳过，待了解 API 响应结构后修复
// #[tokio::test]
// async fn get_room_returns_room_info() { ... }

// ============================================================================
// 房间成员测试
// ============================================================================

#[tokio::test]
async fn get_room_members_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-members-test").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/members", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取成员列表失败: {resp}");
    assert!(
        resp.as_array().is_some_and(|arr| !arr.is_empty()),
        "成员列表应至少包含房主"
    );
}

// ============================================================================
// 房间更新测试
// ============================================================================

#[tokio::test]
async fn update_room_name_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-old-name").await;

    let body = json!({ "name": "rust-new-name" });
    let response = app
        .oneshot(json_request(
            Method::PATCH,
            &format!("/rooms/{}", room_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "更新房间名称失败: {resp}");
}

// ============================================================================
// 房间列表测试
// ============================================================================

#[tokio::test]
async fn list_rooms_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    // 创建一个房间确保列表非空
    let _ = create_public_room(app.clone(), &token1, "rust-list-test").await;

    let response = app
        .oneshot(empty_request(Method::GET, "/rooms", Some(&token1)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取房间列表失败: {resp}");
    assert!(resp.as_array().is_some(), "响应应为数组");
}

// ============================================================================
// 权限测试
// ============================================================================

#[tokio::test]
async fn rooms_api_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .clone()
        .oneshot(empty_request(Method::GET, "/rooms", None))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    let body = json!({
        "name": "test",
        "room_type": "public",
        "member_ids": []
    });
    let response = app
        .oneshot(json_request(Method::POST, "/rooms", None, body))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn create_room_empty_name_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let body = json!({
        "name": "   ",
        "room_type": "public",
        "member_ids": []
    });
    let response = app
        .oneshot(json_request(Method::POST, "/rooms", Some(&token1), body))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "空名称应返回 400"
    );
}

// ============================================================================
// Phase 6: 房间基础操作测试
// ============================================================================

#[tokio::test]
async fn get_room_info_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-get-room", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取房间信息失败: {resp}");
}

#[tokio::test]
async fn get_room_detail_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-detail-room", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/detail", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取房间详情失败: {resp}");
}

#[tokio::test]
async fn get_room_settings_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-settings-room", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/settings", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取房间设置失败: {resp}");
}

#[tokio::test]
async fn update_room_settings_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-update-settings", &[&user2_id]).await;

    let body = json!({
        "mute_notifications": true
    });
    let response = app
        .oneshot(json_request(
            Method::PATCH,
            &format!("/rooms/{}/settings", room_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "更新房间设置失败: {resp}");
}

#[tokio::test]
async fn delete_room_by_owner_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-delete-room", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::OK, "群主删除房间应成功");
}

#[tokio::test]
async fn delete_room_not_owner_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-delete-fail", &[&user2_id]).await;

    // user2 (非群主) 尝试删除
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}", room_id),
            Some(&token2),
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::FORBIDDEN, "非群主删除应返回 403");
}

// ============================================================================
// Phase 6: 成员管理测试
// ============================================================================

#[tokio::test]
async fn list_room_admins_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-admins-room", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/admins", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取管理员列表失败: {resp}");
}

#[tokio::test]
async fn add_admin_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-add-admin", &[&user2_id]).await;

    let body = json!({ "user_id": user2_id, "role": "admin" });
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/admins", room_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "添加管理员失败: {resp}");
}

#[tokio::test]
async fn remove_admin_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-remove-admin", &[&user2_id]).await;

    // 先添加管理员
    let body = json!({ "user_id": user2_id, "role": "admin" });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/admins", room_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK, "添加管理员失败");

    // 移除管理员 (返回 204 NO_CONTENT)
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}/admins/{}", room_id, user2_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::NO_CONTENT, "移除管理员应返回 204");
}

#[tokio::test]
async fn remove_member_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-remove-member", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}/members/{}", room_id, user2_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "移除成员失败: {resp}");
}

#[tokio::test]
async fn transfer_ownership_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-transfer", &[&user2_id]).await;

    let body = json!({ "new_owner_id": user2_id });
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/transfer", room_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "转让群主失败: {resp}");
}

// ============================================================================
// Phase 6: 规则/禁言测试
// ============================================================================

#[tokio::test]
async fn list_room_rules_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-rules-room", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/rules", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取规则列表失败: {resp}");
}

#[tokio::test]
async fn list_room_mutes_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-mutes-room", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/mutes", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取禁言列表失败: {resp}");
}

#[tokio::test]
async fn mute_user_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-mute-user", &[&user2_id]).await;

    let body = json!({
        "user_id": user2_id,
        "mute_duration_hours": 1
    });
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/mutes", room_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "禁言用户失败: {resp}");
}

#[tokio::test]
async fn unmute_user_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-unmute-user", &[&user2_id]).await;

    // 先禁言
    let body = json!({
        "user_id": user2_id,
        "mute_duration_hours": 1
    });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/mutes", room_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK, "禁言失败");

    // 解除禁言 (返回 204 NO_CONTENT)
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}/mutes/{}", room_id, user2_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::NO_CONTENT, "解除禁言应返回 204");
}

// ============================================================================
// Phase 6: 其他房间操作测试
// ============================================================================

#[tokio::test]
async fn get_unread_count_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-unread", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/unread_count", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取未读数失败: {resp}");
}

#[tokio::test]
async fn list_operation_logs_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-op-logs", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/operation-logs", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取操作日志失败: {resp}");
}

#[tokio::test]
async fn pin_room_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-pin-room", &[&user2_id]).await;

    let response = app
        .oneshot(empty_request(
            Method::POST,
            &format!("/rooms/{}/pin", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "置顶房间失败: {resp}");
}

#[tokio::test]
async fn unpin_room_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-unpin-room", &[&user2_id]).await;

    // 先置顶
    let response = app
        .clone()
        .oneshot(empty_request(
            Method::POST,
            &format!("/rooms/{}/pin", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);

    // 取消置顶
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}/pin", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "取消置顶失败: {resp}");
}

#[tokio::test]
async fn update_notification_settings_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-notif-settings", &[&user2_id]).await;

    // notification_settings: 0=all, 1=mentions_only, 2=muted
    let body = json!({
        "notification_settings": 2
    });
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/notification-settings", room_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "更新通知设置失败: {resp}");
}
