//! 消息 API 测试
//!
//! 覆盖消息发送、列表查询、分页等功能。

use super::common::{
    create_public_room, empty_request, json_request, login_user, read_json, register_user,
    test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::{json, Value};
use tower::ServiceExt;
use uuid::Uuid;

#[tokio::test]
async fn messages_send_and_list_flow() {
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

    // user2 send message
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token2),
            json!({"content":"hello-from-user2"}),
        ))
        .await
        .expect("请求失败");
    let (status, msg_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "send message 响应异常: {msg_resp}");

    // list messages (user1)
    let response = app
        .clone()
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/messages?limit=10", room_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");
    let (status, messages) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list messages 响应异常: {messages}");
    assert!(
        messages.as_array().is_some_and(|arr| !arr.is_empty()),
        "预期 messages 非空: {messages}"
    );
}

#[tokio::test]
async fn messages_send_after_leave_returns_403() {
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

    // user2 send again => 403
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token2),
            json!({"content":"should-fail"}),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn list_messages_before_id_and_since_id_are_mutually_exclusive() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    // create group room with user2
    let body = json!({
        "name": "rust-group-room-2",
        "description": "rust-test",
        "room_type": "group",
        "member_ids": [user2_id]
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/rooms", Some(&token1), body))
        .await
        .expect("请求失败");
    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "create room 响应异常: {resp}");
    let room_id = resp
        .get("room")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("create room 响应缺少 room.id")
        .to_string();

    // send one message so the user is definitely a member and the route path is valid
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token2),
            json!({"content":"hello"}),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);

    // list with both before_id & since_id => 400
    let dummy = Uuid::new_v4();
    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!(
                "/rooms/{}/messages?limit=10&before_id={}&since_id={}",
                room_id, dummy, dummy
            ),
            Some(&token1),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn messages_list_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let fake_room_id = Uuid::new_v4();
    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/messages?limit=10", fake_room_id),
            None,
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn messages_send_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let fake_room_id = Uuid::new_v4();
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", fake_room_id),
            None,
            json!({"content":"test"}),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 消息删除/编辑/已读/反应/置顶测试
// Note: 这些测试需要了解准确的 API 响应结构，暂时跳过
// 待 Phase 3 完善后启用
// ============================================================================

// 以下测试暂时跳过：
// - delete_message_success: 需要确认删除端点路径
// - edit_message_success: 需要确认编辑端点路径
// - mark_messages_read_success: 需要确认已读端点请求格式
// - add_message_reaction_success: 需要确认反应端点路径
// - remove_message_reaction_success: 需要确认反应删除端点
// - pin_message_success: 需要确认置顶端点路径
// - unpin_message_success: 需要确认取消置顶端点
