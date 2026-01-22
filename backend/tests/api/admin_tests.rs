//! Admin API 测试
//!
//! 覆盖管理后台 API 功能。

use super::common::{
    empty_request, get_admin_token, json_request, login_user, read_json, register_user,
    test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

// ============================================================================
// 管理员认证测试
// ============================================================================

#[tokio::test]
async fn admin_login_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app).await;
    assert!(!token.is_empty(), "admin token 不应为空");
}

#[tokio::test]
async fn admin_login_wrong_password_fails() {
    let state = test_state().await;
    let app = test_router(state);

    // 先初始化管理员
    let _ = super::common::init_default_admin(app.clone()).await;

    let login_body = json!({
        "username": "admin",
        "password": "wrong_password"
    });
    let response = app
        .oneshot(json_request(Method::POST, "/auth/admin/login", None, login_body))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn admin_me_requires_admin_token() {
    let state = test_state().await;
    let app = test_router(state);

    // 无 token
    let response = app
        .clone()
        .oneshot(empty_request(Method::GET, "/auth/admin/me", None))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    // 普通用户 token
    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let user_token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(Method::GET, "/auth/admin/me", Some(&user_token)))
        .await
        .expect("请求失败");
    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn admin_me_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/auth/admin/me", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "admin me 响应异常: {resp}");
    assert!(resp.get("username").is_some(), "响应缺少 username");
}

// ============================================================================
// 仪表盘统计测试
// ============================================================================

#[tokio::test]
async fn dashboard_stats_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/dashboard/stats", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "dashboard stats 响应异常: {resp}");
}

#[tokio::test]
async fn dashboard_storage_stats_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/dashboard/storage-stats", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "storage stats 响应异常: {resp}");
}

#[tokio::test]
async fn dashboard_emoji_stats_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/dashboard/emoji-stats", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "emoji stats 响应异常: {resp}");
}

#[tokio::test]
async fn dashboard_requires_admin() {
    let state = test_state().await;
    let app = test_router(state);

    // 普通用户 token
    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let user_token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/dashboard/stats", Some(&user_token)))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}

// ============================================================================
// 用户管理测试
// ============================================================================

#[tokio::test]
async fn admin_list_users_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/users", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list users 响应异常: {resp}");
    assert!(resp.get("users").is_some() || resp.as_array().is_some(), "响应格式异常");
}

#[tokio::test]
async fn admin_get_user_detail_success() {
    let state = test_state().await;
    let app = test_router(state);

    // 创建一个普通用户
    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/api/admin/users/{}", user_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "get user detail 响应异常: {resp}");
}

#[tokio::test]
async fn admin_get_user_detail_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;
    let fake_id = Uuid::new_v4();

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/api/admin/users/{}", fake_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn admin_create_user_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;
    let username = unique_phone_username();

    let body = json!({
        "username": username,
        "email": format!("{}@test.com", username),
        "password": "Test123456",
        "nickname": "Admin Created User"
    });

    let response = app
        .oneshot(json_request(Method::POST, "/api/admin/users", Some(&token), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "create user 响应异常: {resp}");
}

#[tokio::test]
async fn admin_update_user_status_success() {
    let state = test_state().await;
    let app = test_router(state);

    // 创建用户
    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;

    let token = get_admin_token(app.clone()).await;

    let body = json!({
        "status": "inactive"
    });

    let response = app
        .oneshot(json_request(
            Method::PATCH,
            &format!("/api/admin/users/{}/status", user_id),
            Some(&token),
            body,
        ))
        .await
        .expect("请求失败");

    // API 可能返回空响应体
    assert!(response.status().is_success(), "update user status 失败");
}

// ============================================================================
// 管理员用户管理测试
// ============================================================================

#[tokio::test]
async fn admin_list_admin_users_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/admin-users", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list admin users 响应异常: {resp}");
}

// ============================================================================
// 权限角色测试
// ============================================================================

#[tokio::test]
async fn admin_get_permissions_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/permissions", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "get permissions 响应异常: {resp}");
}

#[tokio::test]
async fn admin_list_roles_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/roles", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list roles 响应异常: {resp}");
}

// ============================================================================
// 文件管理测试
// ============================================================================

#[tokio::test]
async fn admin_list_files_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/files", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list files 响应异常: {resp}");
}

#[tokio::test]
async fn admin_get_file_stats_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/files/stats", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "file stats 响应异常: {resp}");
}

#[tokio::test]
async fn admin_delete_file_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;
    let fake_id = Uuid::new_v4();

    // 使用 json_request 以确保 Content-Type 正确
    let response = app
        .oneshot(json_request(
            Method::DELETE,
            &format!("/api/admin/files/{}", fake_id),
            Some(&token),
            json!({}),
        ))
        .await
        .expect("请求失败");

    // API 可能返回 200 (幂等删除) 或 404
    let status = response.status();
    assert!(
        status == StatusCode::OK || status == StatusCode::NOT_FOUND,
        "delete file 响应异常: {status}"
    );
}

// ============================================================================
// 系统设置测试
// ============================================================================

#[tokio::test]
async fn admin_get_captcha_setting_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/settings/captcha", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "captcha setting 响应异常: {resp}");
}

#[tokio::test]
async fn admin_list_storage_providers_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/storage-providers", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "storage providers 响应异常: {resp}");
}

#[tokio::test]
async fn admin_get_default_storage_provider_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/storage-providers/default", Some(&token)))
        .await
        .expect("请求失败");

    // 可能没有默认 provider，200 或 404 都可接受
    let status = response.status();
    assert!(
        status == StatusCode::OK || status == StatusCode::NOT_FOUND,
        "default storage provider 响应异常: {}",
        status
    );
}

// ============================================================================
// Token 管理测试
// ============================================================================

#[tokio::test]
async fn admin_list_tokens_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/ipinfo-tokens", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list tokens 响应异常: {resp}");
}

// ============================================================================
// 系统日志测试
// ============================================================================

#[tokio::test]
async fn admin_list_logs_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/logs", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "list logs 响应异常: {resp}");
}

#[tokio::test]
async fn admin_get_log_stats_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/logs/stats", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "log stats 响应异常: {resp}");
}

// ============================================================================
// 数据统计测试
// ============================================================================

#[tokio::test]
async fn admin_get_data_statistics_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/api/dashboard/statistics", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "data statistics 响应异常: {resp}");
}
