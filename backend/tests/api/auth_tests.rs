//! 认证 API 测试
//!
//! 覆盖注册、登录、Token 验证等功能。

use super::common::{empty_request, json_request, read_json, read_text, test_router, test_state, unique_phone_username};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;

#[tokio::test]
async fn healthz_returns_ok() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/healthz", None))
        .await
        .expect("请求失败");

    let (status, text) = read_text(response).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(text, "ok");
}

#[tokio::test]
async fn auth_me_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/auth/me", None))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn register_login_get_me_flow() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 1) register
    let register_body = json!({
        "username": username,
        "email": "ignored@example.com",
        "password": password,
        "nickname": "集成测试用户"
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/register", None, register_body))
        .await
        .expect("请求失败");

    let (status, user) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "register 响应异常: {user}");
    let user_id = user
        .get("id")
        .and_then(|v| v.as_str())
        .expect("register 响应缺少 id")
        .to_string();

    // 2) login
    let login_body = json!({
        "username": username,
        "password": password
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/login", None, login_body))
        .await
        .expect("请求失败");

    let (status, login) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "login 响应异常: {login}");
    let token = login
        .get("token")
        .and_then(|v| v.as_str())
        .expect("login 响应缺少 token")
        .to_string();

    // 3) auth/me
    let response = app
        .oneshot(empty_request(Method::GET, "/auth/me", Some(&token)))
        .await
        .expect("请求失败");

    let (status, me) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        me.get("id").and_then(|v| v.as_str()),
        Some(user_id.as_str())
    );
}

#[tokio::test]
async fn login_wrong_password_returns_401() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // register
    let register_body = json!({
        "username": username,
        "email": "ignored@example.com",
        "password": password,
        "nickname": "测试用户"
    });
    let _ = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/register", None, register_body))
        .await
        .expect("请求失败");

    // login with wrong password
    let login_body = json!({
        "username": username,
        "password": "WrongPassword123"
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/login", None, login_body))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn login_nonexistent_user_returns_401() {
    let state = test_state().await;
    let app = test_router(state);

    let login_body = json!({
        "username": "nonexistent_user_12345",
        "password": "AnyPassword123"
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/login", None, login_body))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn invalid_token_returns_401() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/auth/me", Some("invalid_token_here")))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// Token 刷新测试
// Note: refresh token 功能需要确认 API 响应结构，暂时跳过
// ============================================================================

// 以下测试暂时跳过：
// - refresh_token_success: 需要确认 login 响应是否包含 refreshToken
// - refresh_token_invalid_fails: 需要确认 refresh 端点行为

// ============================================================================
// 注册验证测试
// ============================================================================

#[tokio::test]
async fn register_duplicate_username_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 第一次注册
    let register_body = json!({
        "username": username,
        "email": "ignored@example.com",
        "password": password,
        "nickname": "测试用户"
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/register", None, register_body.clone()))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::OK);

    // 第二次注册相同用户名
    let response = app
        .oneshot(json_request(Method::POST, "/auth/register", None, register_body))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::CONFLICT,
        "重复用户名应返回 409"
    );
}

#[tokio::test]
async fn register_short_password_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();

    let register_body = json!({
        "username": username,
        "email": "ignored@example.com",
        "password": "123",
        "nickname": "测试用户"
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/register", None, register_body))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "短密码应返回 400"
    );
}

#[tokio::test]
async fn register_empty_username_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let register_body = json!({
        "username": "",
        "email": "ignored@example.com",
        "password": "Test123456",
        "nickname": "测试用户"
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/register", None, register_body))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "空用户名应返回 400"
    );
}
