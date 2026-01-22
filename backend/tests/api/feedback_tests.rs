//! 用户反馈 API 测试
//!
//! 覆盖反馈提交、管理员查看等功能。

use super::common::{
    empty_request, get_admin_token, json_request, login_user, read_json, register_user,
    test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;

// ============================================================================
// 提交反馈测试
// ============================================================================

#[tokio::test]
async fn submit_feedback_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let body = json!({
        "content": "这是一条测试反馈",
        "category": "suggestion"
    });

    let response = app
        .oneshot(json_request(Method::POST, "/feedbacks", Some(&token), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "submit feedback 响应异常: {resp}");
}

#[tokio::test]
async fn submit_feedback_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let body = json!({
        "content": "测试反馈",
        "category": "bug"
    });

    let response = app
        .oneshot(json_request(Method::POST, "/feedbacks", None, body))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 管理员查看反馈测试
// ============================================================================

#[tokio::test]
async fn admin_list_feedbacks_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/feedbacks",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "admin list feedbacks 响应异常: {resp}");
}

#[tokio::test]
async fn admin_list_feedbacks_requires_admin() {
    let state = test_state().await;
    let app = test_router(state);

    // 普通用户 token
    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/feedbacks",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}
