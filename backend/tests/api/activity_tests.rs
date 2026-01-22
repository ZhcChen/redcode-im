//! 活动日志 API 测试
//!
//! 覆盖心跳、登录历史等功能。

use super::common::{
    empty_request, json_request, login_user, read_json, register_user, test_router, test_state,
    unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;

// ============================================================================
// 心跳测试
// ============================================================================

#[tokio::test]
async fn heartbeat_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // API 需要完整的心跳日志参数
    let body = json!({
        "user_id": user_id,
        "ip_address": "127.0.0.1",
        "connection_id": "test-connection-id",
        "user_agent": "TestAgent/1.0",
        "device_info": {"type": "desktop"}
    });

    let response = app
        .oneshot(json_request(
            Method::POST,
            "/activity/heartbeat",
            Some(&token),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "heartbeat 响应异常: {resp}");
}

#[tokio::test]
async fn heartbeat_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let body = json!({
        "user_id": "00000000-0000-0000-0000-000000000001",
        "ip_address": "127.0.0.1",
        "connection_id": "test"
    });

    let response = app
        .oneshot(json_request(Method::POST, "/activity/heartbeat", None, body))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 登录历史测试
// ============================================================================

#[tokio::test]
async fn get_login_history_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/users/{}/activity/login-history", user_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "get login history 响应异常: {resp}");
}

#[tokio::test]
async fn get_login_history_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/users/{}/activity/login-history", user_id),
            None,
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 心跳日志测试
// ============================================================================

#[tokio::test]
async fn get_heartbeat_logs_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/users/{}/activity/heartbeat-logs", user_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "get heartbeat logs 响应异常: {resp}");
}

// ============================================================================
// Phase 8: 登录/登出活动记录测试
// ============================================================================

#[tokio::test]
async fn record_login_activity_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let body = json!({
        "user_id": user_id,
        "ip_address": "192.168.1.100",
        "user_agent": "TestClient/1.0",
        "login_method": "password",
        "success": true,
        "device_info": {"platform": "test"}
    });

    let response = app
        .oneshot(json_request(Method::POST, "/activity/login", Some(&token), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "记录登录活动失败: {resp}");
    assert!(resp.get("id").is_some(), "响应缺少 id 字段");
}

#[tokio::test]
async fn record_logout_activity_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // 先创建登录记录
    let body = json!({
        "user_id": user_id,
        "ip_address": "192.168.1.100",
        "user_agent": "TestClient/1.0",
        "login_method": "password",
        "success": true
    });

    let response = app
        .clone()
        .oneshot(json_request(Method::POST, "/activity/login", Some(&token), body))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    let log_id = resp
        .get("id")
        .and_then(|v| v.as_str())
        .expect("响应缺少 id");

    // 记录登出
    let response = app
        .oneshot(empty_request(
            Method::POST,
            &format!("/activity/login/{}/logout", log_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::NO_CONTENT, "记录登出活动应返回 204");
}
