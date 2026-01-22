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

    // API 可能返回 400 (验证失败) 或 409 (用户名冲突)
    let status = response.status();
    assert!(
        status == StatusCode::BAD_REQUEST || status == StatusCode::CONFLICT,
        "空用户名应返回 400 或 409，实际: {status}"
    );
}

// ============================================================================
// Phase 8: Token 刷新测试
// ============================================================================

#[tokio::test]
async fn refresh_token_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册
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

    // 登录获取 refresh_token
    let login_body = json!({
        "username": username,
        "password": password
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/login", None, login_body))
        .await
        .expect("请求失败");

    let (status, login_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);

    let refresh_token = login_resp
        .get("refresh_token")
        .and_then(|v| v.as_str())
        .expect("login 响应缺少 refresh_token");

    // 使用 refresh_token 刷新
    let refresh_body = json!({
        "refresh_token": refresh_token
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/refresh", None, refresh_body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "刷新 token 失败: {resp}");
    assert!(resp.get("token").is_some(), "响应缺少 token");
}

#[tokio::test]
async fn refresh_token_invalid_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let refresh_body = json!({
        "refresh_token": "invalid_refresh_token_here"
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/refresh", None, refresh_body))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::UNAUTHORIZED,
        "无效的 refresh_token 应返回 401"
    );
}

// ============================================================================
// Phase 8: 管理员 Token 刷新测试
// ============================================================================

#[tokio::test]
async fn admin_refresh_token_success() {
    let state = test_state().await;
    let app = test_router(state);

    // 初始化默认管理员
    let _ = app
        .clone()
        .oneshot(empty_request(Method::POST, "/api/admin/init-default-admin", None))
        .await
        .expect("请求失败");

    // 管理员登录（默认密码是 admin123）
    let login_body = json!({
        "username": "admin",
        "password": "admin123"
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/admin/login", None, login_body))
        .await
        .expect("请求失败");

    let (status, login_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "admin login 失败: {login_resp}");

    let refresh_token = login_resp
        .get("refresh_token")
        .and_then(|v| v.as_str())
        .expect("admin login 响应缺少 refresh_token");

    // 使用 refresh_token 刷新
    let refresh_body = json!({
        "refresh_token": refresh_token
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/admin/refresh", None, refresh_body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "admin 刷新 token 失败: {resp}");
    assert!(resp.get("token").is_some(), "响应缺少 token");
}

// ============================================================================
// Phase 8: 管理员密码修改测试
// ============================================================================

#[tokio::test]
async fn admin_change_password_success() {
    let state = test_state().await;
    let app = test_router(state);

    // 初始化默认管理员
    let _ = app
        .clone()
        .oneshot(empty_request(Method::POST, "/api/admin/init-default-admin", None))
        .await
        .expect("请求失败");

    // 先获取管理员 token
    let login_body = json!({
        "username": "admin",
        "password": "admin123"
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/admin/login", None, login_body))
        .await
        .expect("请求失败");

    let (status, login_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "admin login 失败: {login_resp}");
    let token = login_resp
        .get("token")
        .and_then(|v| v.as_str())
        .expect("login 响应缺少 token");

    // 创建一个新的管理员来测试密码修改（避免影响其他测试）
    let new_admin_body = json!({
        "username": format!("testadmin_{}", uuid::Uuid::new_v4().simple()),
        "email": format!("testadmin_{}@test.com", uuid::Uuid::new_v4().simple()),
        "password": "TestAdmin@123",
        "nickname": "测试管理员"
    });
    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            "/api/admin/admin-users",
            Some(token),
            new_admin_body.clone(),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "创建管理员失败: {resp}");

    // 用新管理员登录
    let new_username = new_admin_body.get("username").unwrap().as_str().unwrap();
    let new_login_body = json!({
        "username": new_username,
        "password": "TestAdmin@123"
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/admin/login", None, new_login_body))
        .await
        .expect("请求失败");

    let (status, login_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    let new_token = login_resp
        .get("token")
        .and_then(|v| v.as_str())
        .expect("login 响应缺少 token");

    // 修改新管理员的密码
    let change_body = json!({
        "old_password": "TestAdmin@123",
        "new_password": "NewTestAdmin@456"
    });
    let response = app
        .oneshot(json_request(
            Method::POST,
            "/auth/admin/me/password",
            Some(new_token),
            change_body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "修改管理员密码失败: {resp}");
}

// ============================================================================
// Phase 8: 管理员信息更新测试
// ============================================================================

#[tokio::test]
async fn admin_update_profile_success() {
    let state = test_state().await;
    let app = test_router(state);

    // 初始化默认管理员
    let _ = app
        .clone()
        .oneshot(empty_request(Method::POST, "/api/admin/init-default-admin", None))
        .await
        .expect("请求失败");

    // 管理员登录（默认密码是 admin123）
    let login_body = json!({
        "username": "admin",
        "password": "admin123"
    });
    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/auth/admin/login", None, login_body))
        .await
        .expect("请求失败");

    let (status, login_resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "admin login 失败: {login_resp}");
    let token = login_resp
        .get("token")
        .and_then(|v| v.as_str())
        .expect("login 响应缺少 token");

    // 更新管理员信息
    let update_body = json!({
        "nickname": "超级管理员"
    });
    let response = app
        .oneshot(json_request(
            Method::PATCH,
            "/auth/admin/me",
            Some(token),
            update_body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "更新管理员信息失败: {resp}");
}
