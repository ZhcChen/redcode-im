//! 消息搜索 API 测试
//!
//! 覆盖消息搜索、搜索建议、热门搜索等功能。

use super::common::{
    create_public_room, empty_request, json_request, login_user, read_json, register_user,
    test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;

// ============================================================================
// 消息搜索测试
// ============================================================================

#[tokio::test]
async fn search_messages_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // 创建房间并发送消息
    let room_id = create_public_room(app.clone(), &token, "test-search-room").await;

    let _ = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            &format!("/rooms/{}/messages", room_id),
            Some(&token),
            json!({"content": "hello world test message"}),
        ))
        .await
        .expect("请求失败");

    // 搜索消息 (API 使用 query 参数)
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/messages/search?query=hello",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "search messages 响应异常: {resp}");
}

#[tokio::test]
async fn search_messages_empty_result() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // 搜索不存在的关键词 (API 使用 query 参数)
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/messages/search?query=nonexistentkeyword12345",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "search empty result 响应异常: {resp}");
}

#[tokio::test]
async fn search_messages_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/messages/search?query=test",
            None,
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 搜索建议测试
// ============================================================================

#[tokio::test]
async fn search_suggestions_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // API 使用 prefix 参数
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/messages/search/suggestions?prefix=test",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "search suggestions 响应异常: {resp}");
}

// ============================================================================
// 热门搜索测试
// ============================================================================

#[tokio::test]
async fn search_trending_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/messages/search/trending",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "search trending 响应异常: {resp}");
}
