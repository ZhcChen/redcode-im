//! 消息 API 测试
//!
//! 覆盖消息发送、列表查询、分页等功能。

use super::common::{
    create_group_room, create_public_room, empty_request, json_request, login_user, read_json,
    register_user, send_message, test_router, test_state, unique_phone_username,
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
// Phase 3 实现
// ============================================================================

#[tokio::test]
async fn delete_message_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-delete-msg-room").await;

    // 发送消息
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token1),
            json!({"content":"to-be-deleted"}),
        ))
        .await
        .expect("请求失败");
    let (status, msg_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "send message 响应异常: {msg_resp}");
    let message_id = msg_resp
        .get("message")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("响应缺少 message.id");

    // 删除消息
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}/messages/{}", room_id, message_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "delete message 响应异常: {resp}");
}

#[tokio::test]
async fn edit_message_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-edit-msg-room").await;

    // 发送消息
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token1),
            json!({"content":"original"}),
        ))
        .await
        .expect("请求失败");
    let (status, msg_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "send message 响应异常: {msg_resp}");
    let message_id = msg_resp
        .get("message")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("响应缺少 message.id");

    // 编辑消息
    let response = app
        .oneshot(json_request(
            Method::PATCH,
            &format!("/rooms/{}/messages/{}", room_id, message_id),
            Some(&token1),
            json!({"content":"edited"}),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "edit message 响应异常: {resp}");
}

#[tokio::test]
async fn mark_messages_read_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;

    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    // 创建群组房间
    let body = json!({
        "name": "rust-read-test",
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
    assert_eq!(status, StatusCode::OK);
    let room_id = resp
        .get("room")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("响应缺少 room.id");

    // user1 发送消息
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token1),
            json!({"content":"hello"}),
        ))
        .await
        .expect("请求失败");
    let (status, msg_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    let message_id = msg_resp
        .get("message")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("响应缺少 message.id");

    // user2 标记已读
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages/read", room_id),
            Some(&token2),
            json!({"message_id": message_id}),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "mark read 响应异常: {resp}");
}

#[tokio::test]
async fn add_message_reaction_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-reaction-room").await;

    // 发送消息
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token1),
            json!({"content":"react-me"}),
        ))
        .await
        .expect("请求失败");
    let (status, msg_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    let message_id = msg_resp
        .get("message")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("响应缺少 message.id");

    // 添加反应
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages/{}/reactions", room_id, message_id),
            Some(&token1),
            json!({"reaction_key": "👍"}),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "add reaction 响应异常: {resp}");
}

#[tokio::test]
async fn pin_message_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-pin-msg-room").await;

    // 发送消息
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token1),
            json!({"content":"pin-me"}),
        ))
        .await
        .expect("请求失败");
    let (status, msg_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    let message_id = msg_resp
        .get("message")
        .and_then(|v| v.get("id"))
        .and_then(Value::as_str)
        .expect("响应缺少 message.id");

    // 置顶消息
    let response = app
        .oneshot(empty_request(
            Method::POST,
            &format!("/rooms/{}/messages/{}/pin", room_id, message_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "pin message 响应异常: {resp}");
}

// ============================================================================
// Phase 6: 消息扩展测试
// ============================================================================

#[tokio::test]
async fn unpin_message_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-unpin-msg").await;
    let message_id = send_message(app.clone(), &token1, &room_id, "pin-then-unpin").await;

    // 先置顶
    let response = app
        .clone()
        .oneshot(empty_request(
            Method::POST,
            &format!("/rooms/{}/messages/{}/pin", room_id, message_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);

    // 取消置顶
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}/messages/{}/pin", room_id, message_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "取消置顶失败: {resp}");
}

#[tokio::test]
async fn remove_reaction_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-remove-reaction").await;
    let message_id = send_message(app.clone(), &token1, &room_id, "react-me").await;

    // 先添加反应
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages/{}/reactions", room_id, message_id),
            Some(&token1),
            json!({"reaction_key": "👍"}),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);

    // 移除反应 (使用 query 参数)
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/rooms/{}/messages/{}/reactions?reaction_key=%F0%9F%91%8D", room_id, message_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "移除反应失败: {resp}");
}

#[tokio::test]
async fn list_reactions_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();

    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_public_room(app.clone(), &token1, "rust-list-reactions").await;
    let message_id = send_message(app.clone(), &token1, &room_id, "react-list").await;

    // 添加反应
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages/{}/reactions", room_id, message_id),
            Some(&token1),
            json!({"reaction_key": "👍"}),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);

    // 获取反应列表
    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/messages/{}/reactions", room_id, message_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取反应列表失败: {resp}");
}

#[tokio::test]
async fn list_message_reads_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-read-list", &[&user2_id]).await;
    let message_id = send_message(app.clone(), &token1, &room_id, "read-me").await;

    // user2 标记已读
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages/read", room_id),
            Some(&token2),
            json!({"message_id": message_id}),
        ))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);

    // 获取已读列表
    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/rooms/{}/messages/{}/reads", room_id, message_id),
            Some(&token1),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取已读列表失败: {resp}");
}

#[tokio::test]
async fn mark_read_until_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;
    let token2 = login_user(app.clone(), &user2, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-read-until", &[&user2_id]).await;
    let message_id = send_message(app.clone(), &token1, &room_id, "read-until-me").await;

    // user2 批量标记已读
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages/read_until", room_id),
            Some(&token2),
            json!({"message_id": message_id}),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "批量已读失败: {resp}");
}

#[tokio::test]
async fn forward_message_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    // 创建两个房间
    let room1_id = create_group_room(app.clone(), &token1, "rust-forward-src", &[&user2_id]).await;
    let room2_id = create_group_room(app.clone(), &token1, "rust-forward-dst", &[&user2_id]).await;

    let message_id = send_message(app.clone(), &token1, &room1_id, "forward-me").await;

    // 转发消息到 room2
    let response = app
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages/forward", room2_id),
            Some(&token1),
            json!({
                "original_message_id": message_id
            }),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "转发消息失败: {resp}");
}

#[tokio::test]
async fn batch_delete_messages_success() {
    let state = test_state().await;
    let app = test_router(state);

    let pass = "Passw0rd!";
    let user1 = unique_phone_username();
    let user2 = unique_phone_username();

    let user2_id = register_user(app.clone(), &user2, pass).await;
    let _ = register_user(app.clone(), &user1, pass).await;
    let token1 = login_user(app.clone(), &user1, pass).await;

    let room_id = create_group_room(app.clone(), &token1, "rust-batch-delete", &[&user2_id]).await;
    let msg1 = send_message(app.clone(), &token1, &room_id, "delete-me-1").await;
    let msg2 = send_message(app.clone(), &token1, &room_id, "delete-me-2").await;

    // 批量删除
    let response = app
        .oneshot(json_request(
            Method::DELETE,
            &format!("/rooms/{}/messages", room_id),
            Some(&token1),
            json!({"message_ids": [msg1, msg2]}),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "批量删除失败: {resp}");
}
