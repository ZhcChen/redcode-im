//! 好友 API 测试
//!
//! 覆盖好友申请、响应、列表、备注、删除等功能。

use super::common::{
    empty_request, json_request, login_user, read_json, register_user, test_router, test_state,
    unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;

// ============================================================================
// 好友申请测试
// ============================================================================

#[tokio::test]
async fn send_friend_request_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let user2_id = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;

    let body = json!({
        "target_user_id": user2_id,
        "message": "Hi, let's be friends!"
    });
    let response = app
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "发送好友申请失败: {resp}");
    assert!(resp.get("id").is_some(), "响应缺少 id 字段");
    assert_eq!(
        resp.get("status").and_then(|v| v.as_str()),
        Some("pending"),
        "申请状态应为 pending"
    );
}

#[tokio::test]
async fn send_friend_request_to_self_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let user1_id = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let body = json!({
        "target_user_id": user1_id,
        "message": "Hi"
    });
    let response = app
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "不应允许给自己发送好友申请"
    );
}

#[tokio::test]
async fn send_friend_request_to_nonexistent_user_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let fake_user_id = uuid::Uuid::new_v4().to_string();
    let body = json!({
        "target_user_id": fake_user_id,
        "message": "Hi"
    });
    let response = app
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::NOT_FOUND,
        "向不存在的用户发送申请应返回 404"
    );
}

// ============================================================================
// 好友申请响应测试
// ============================================================================

#[tokio::test]
async fn respond_friend_request_accept() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let user2_id = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    // user1 发送好友申请
    let body = json!({
        "target_user_id": user2_id,
        "message": "Hi!"
    });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    let request_id = resp.get("id").and_then(|v| v.as_str()).unwrap();

    // user2 接受申请
    let body = json!({ "action": "accept" });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/friends/requests/{}/respond", request_id),
            Some(&token2),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "接受好友申请失败: {resp}");
    assert_eq!(
        resp.get("status").and_then(|v| v.as_str()),
        Some("accepted"),
        "申请状态应为 accepted"
    );
}

#[tokio::test]
async fn respond_friend_request_decline() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let user2_id = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    // user1 发送好友申请
    let body = json!({
        "target_user_id": user2_id,
        "message": "Hi!"
    });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    let request_id = resp.get("id").and_then(|v| v.as_str()).unwrap();

    // user2 拒绝申请
    let body = json!({ "action": "decline" });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/friends/requests/{}/respond", request_id),
            Some(&token2),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "拒绝好友申请失败: {resp}");
    assert_eq!(
        resp.get("status").and_then(|v| v.as_str()),
        Some("declined"),
        "申请状态应为 declined"
    );
}

// ============================================================================
// 好友列表测试
// ============================================================================

#[tokio::test]
async fn list_friends_empty() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/friends", Some(&token1)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        resp.as_array().is_some_and(|arr| arr.is_empty()),
        "新用户好友列表应为空"
    );
}

#[tokio::test]
async fn list_friends_after_accept() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let user2_id = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    // user1 发送好友申请
    let body = json!({
        "target_user_id": user2_id,
        "message": "Hi!"
    });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (_, resp) = read_json(response).await;
    let request_id = resp.get("id").and_then(|v| v.as_str()).unwrap();

    // user2 接受申请
    let body = json!({ "action": "accept" });
    let _ = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/friends/requests/{}/respond", request_id),
            Some(&token2),
            body,
        ))
        .await
        .expect("请求失败");

    // user1 查看好友列表
    let response = app
        .clone()
        .oneshot(empty_request(Method::GET, "/friends", Some(&token1)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        resp.as_array().is_some_and(|arr| arr.len() == 1),
        "好友列表应有 1 个好友"
    );
}

#[tokio::test]
async fn list_friend_requests_incoming() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let user2_id = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    // user1 发送好友申请
    let body = json!({
        "target_user_id": user2_id,
        "message": "Hi!"
    });
    let _ = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    // user2 查看收到的申请
    let response = app
        .clone()
        .oneshot(empty_request(
            Method::GET,
            "/friends/requests?direction=incoming&status=pending",
            Some(&token2),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        resp.as_array().is_some_and(|arr| !arr.is_empty()),
        "user2 应收到好友申请"
    );
}

// ============================================================================
// 好友备注测试
// ============================================================================

#[tokio::test]
async fn update_friend_remark_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let user2_id = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    // 建立好友关系
    let body = json!({ "target_user_id": user2_id, "message": "Hi!" });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");
    let (_, resp) = read_json(response).await;
    let request_id = resp.get("id").and_then(|v| v.as_str()).unwrap();

    let body = json!({ "action": "accept" });
    let _ = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/friends/requests/{}/respond", request_id),
            Some(&token2),
            body,
        ))
        .await
        .expect("请求失败");

    // user1 更新 user2 的备注
    let body = json!({ "remark": "我的好朋友" });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::PATCH,
            &format!("/friends/{}/remark", user2_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "更新备注失败: {resp}");
    assert_eq!(
        resp.get("remark").and_then(|v| v.as_str()),
        Some("我的好朋友"),
        "备注应更新成功"
    );
}

#[tokio::test]
async fn update_self_remark_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let user1_id = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let body = json!({ "remark": "自己" });
    let response = app
        .oneshot(json_request(
            Method::PATCH,
            &format!("/friends/{}/remark", user1_id),
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "不应允许给自己设置备注"
    );
}

// ============================================================================
// 删除好友测试
// ============================================================================

#[tokio::test]
async fn delete_friend_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let user2_id = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    // 建立好友关系
    let body = json!({ "target_user_id": user2_id, "message": "Hi!" });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            "/friends/requests",
            Some(&token1),
            body,
        ))
        .await
        .expect("请求失败");
    let (_, resp) = read_json(response).await;
    let request_id = resp.get("id").and_then(|v| v.as_str()).unwrap();

    let body = json!({ "action": "accept" });
    let _ = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/friends/requests/{}/respond", request_id),
            Some(&token2),
            body,
        ))
        .await
        .expect("请求失败");

    // user1 删除好友 user2
    let response = app
        .clone()
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/friends/{}", user2_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "删除好友失败: {resp}");
    assert_eq!(
        resp.get("success").and_then(|v| v.as_bool()),
        Some(true),
        "删除应成功"
    );
}

#[tokio::test]
async fn delete_nonexistent_friend_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let fake_user_id = uuid::Uuid::new_v4();
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/friends/{}", fake_user_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::NOT_FOUND,
        "删除不存在的好友应返回 404"
    );
}

// ============================================================================
// 私聊创建测试
// ============================================================================

#[tokio::test]
async fn ensure_private_chat_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let user2_id = register_user(app.clone(), &user2, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;

    // 创建私聊
    let response = app
        .clone()
        .oneshot(empty_request(
            Method::POST,
            &format!("/friends/{}/chat", user2_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "创建私聊失败: {resp}");
    assert!(resp.get("room_id").is_some(), "响应缺少 room_id");
    assert_eq!(
        resp.get("room_type").and_then(|v| v.as_str()),
        Some("private"),
        "房间类型应为 private"
    );
}

#[tokio::test]
async fn ensure_private_chat_with_self_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let user1_id = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let response = app
        .oneshot(empty_request(
            Method::POST,
            &format!("/friends/{}/chat", user1_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "不应允许与自己创建私聊"
    );
}

// ============================================================================
// 权限测试
// ============================================================================

#[tokio::test]
async fn friends_api_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .clone()
        .oneshot(empty_request(Method::GET, "/friends", None))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    let response = app
        .clone()
        .oneshot(empty_request(Method::GET, "/friends/requests", None))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    let body = json!({ "target_user_id": "test", "message": "hi" });
    let response = app
        .oneshot(json_request(Method::POST, "/friends/requests", None, body))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}
