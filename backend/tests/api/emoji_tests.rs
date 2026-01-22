//! 表情包 API 测试
//!
//! 覆盖表情包查询、添加、移除等功能。

use super::common::{
    empty_request, json_request, login_user, read_json, register_user, test_router, test_state,
    unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

// ============================================================================
// 表情包列表测试
// ============================================================================

#[tokio::test]
async fn list_available_emoji_packs_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/emoji-packs/available",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list available emoji packs 响应异常: {resp}");
}

#[tokio::test]
async fn search_emoji_packs_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/emoji-packs/search?keyword=test",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "search emoji packs 响应异常: {resp}");
}

#[tokio::test]
async fn search_emoji_packs_empty_keyword() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/emoji-packs/search?keyword=",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    // 空关键词可能返回 200 (全部) 或 400
    let status = response.status();
    assert!(
        status == StatusCode::OK || status == StatusCode::BAD_REQUEST,
        "search empty keyword 响应异常: {status}"
    );
}

#[tokio::test]
async fn list_my_emoji_packs_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(Method::GET, "/emoji-packs/my", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list my emoji packs 响应异常: {resp}");
}

// ============================================================================
// 表情包添加/移除测试
// ============================================================================

#[tokio::test]
async fn add_emoji_pack_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let fake_id = Uuid::new_v4();
    let response = app
        .oneshot(empty_request(
            Method::POST,
            &format!("/emoji-packs/{}/add", fake_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    // 不存在的表情包返回 404
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn remove_emoji_pack_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let fake_id = Uuid::new_v4();
    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/emoji-packs/{}/remove", fake_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    // 移除不存在的可能返回 200 (幂等) 或 404
    let status = response.status();
    assert!(
        status == StatusCode::OK || status == StatusCode::NOT_FOUND,
        "remove emoji pack 响应异常: {status}"
    );
}

// ============================================================================
// 认证测试
// ============================================================================

#[tokio::test]
async fn emoji_packs_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    // 无 token 访问
    let response = app
        .oneshot(empty_request(Method::GET, "/emoji-packs/available", None))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn my_emoji_packs_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/emoji-packs/my", None))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 下载 URL 测试
// ============================================================================

#[tokio::test]
async fn get_emoji_download_url_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // API 使用 Query 参数
    let response = app
        .oneshot(empty_request(
            Method::POST,
            "/emoji-packs/download-url?object_key=emojis/test.zip",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    // 可能因存储服务未配置返回错误，但不应是 500
    let status = response.status();
    assert!(
        status != StatusCode::INTERNAL_SERVER_ERROR,
        "get download url 响应异常: {status}"
    );
}
