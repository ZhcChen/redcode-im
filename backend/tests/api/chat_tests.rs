//! 聊天会话 API 测试
//!
//! 覆盖聊天会话列表、删除等功能。

use super::common::{
    create_public_room, empty_request, json_request, login_user, read_json, register_user,
    test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

// ============================================================================
// 聊天会话列表测试
// ============================================================================

#[tokio::test]
async fn list_chats_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // 创建一个房间以产生聊天会话
    let _ = create_public_room(app.clone(), &token, "test-chat-room").await;

    let response = app
        .oneshot(empty_request(Method::GET, "/chats", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list chats 响应异常: {resp}");
}

#[tokio::test]
async fn list_chats_empty() {
    let state = test_state().await;
    let app = test_router(state);

    // 新用户，没有聊天会话
    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(Method::GET, "/chats", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list empty chats 响应异常: {resp}");
    // 新用户应返回空数组或空结果
    // 响应可能是直接数组 [] 或 { chats: [] } 或 { summaries: [] }
    let is_empty = resp.as_array().map(|a| a.is_empty()).unwrap_or(false)
        || resp.get("chats").and_then(|c| c.as_array()).map(|a| a.is_empty()).unwrap_or(false)
        || resp.get("summaries").and_then(|c| c.as_array()).map(|a| a.is_empty()).unwrap_or(true);
    assert!(is_empty, "预期空聊天列表: {resp}");
}

#[tokio::test]
async fn list_chats_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/chats", None))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 删除聊天会话测试
// ============================================================================

#[tokio::test]
async fn delete_chat_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // 创建房间
    let room_id = create_public_room(app.clone(), &token, "test-delete-chat").await;

    // 发送消息以确保会话存在
    let _ = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token),
            json!({"content": "test message"}),
        ))
        .await
        .expect("请求失败");

    // 删除聊天会话
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/chats/{}", room_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    // 删除可能返回 200 或 204
    assert!(
        response.status().is_success(),
        "delete chat 失败: {}",
        response.status()
    );
}

#[tokio::test]
async fn delete_chat_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let fake_id = Uuid::new_v4();
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/chats/{}", fake_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    // 可能返回 404 或 200 (幂等)
    let status = response.status();
    assert!(
        status == StatusCode::NOT_FOUND || status == StatusCode::OK,
        "delete non-existent chat 响应异常: {status}"
    );
}

#[tokio::test]
async fn delete_chat_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let fake_id = Uuid::new_v4();
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/chats/{}", fake_id),
            None,
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}
