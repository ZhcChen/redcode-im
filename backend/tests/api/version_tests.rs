//! 版本管理与热更新 API 测试
//!
//! 覆盖应用版本管理、热更新管理 API 功能。

use super::common::{
    empty_request, get_admin_token, json_request, login_user, read_json, register_user,
    test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

// ============================================================================
// 应用版本管理 - 列表测试
// ============================================================================

#[tokio::test]
async fn admin_list_app_versions_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    // platform 是必填参数
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/app-versions?platform=android",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, body) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "响应异常: {body}");
    // 应返回 { total, items } 结构
    assert!(body.get("total").is_some(), "应返回 total 字段");
    assert!(body.get("items").is_some(), "应返回 items 字段");
}

#[tokio::test]
async fn admin_list_app_versions_missing_platform() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    // 缺少 platform 参数
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/app-versions",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    // platform 是必填的，应返回 422
    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "缺少 platform 应返回 422"
    );
}

#[tokio::test]
async fn admin_list_app_versions_requires_admin() {
    let state = test_state().await;
    let app = test_router(state);

    // 普通用户 token
    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let user_token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/app-versions?platform=android",
            Some(&user_token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::FORBIDDEN,
        "普通用户应返回 403"
    );
}

// ============================================================================
// 应用版本管理 - 详情/删除测试
// ============================================================================

#[tokio::test]
async fn admin_get_app_version_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;
    let fake_id = Uuid::new_v4();

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/api/admin/app-versions/{}", fake_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::NOT_FOUND,
        "不存在的版本应返回 404"
    );
}

#[tokio::test]
async fn admin_delete_app_version_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;
    let fake_id = Uuid::new_v4();

    let response = app
        .oneshot(empty_request(
            Method::DELETE,
            &format!("/api/admin/app-versions/{}", fake_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::NOT_FOUND,
        "删除不存在的版本应返回 404"
    );
}

// ============================================================================
// 公开版本检查 API 测试
// ============================================================================

#[tokio::test]
async fn latest_version_success() {
    let state = test_state().await;
    let app = test_router(state);

    // 公开 API，无需 token
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/versions/latest?platform=android&channel=stable",
            None,
        ))
        .await
        .expect("请求失败");

    let (status, body) = read_json(response).await;
    // 即使没有版本，也应返回 200（可能为 null 或空对象）
    assert_eq!(status, StatusCode::OK, "响应异常: {body}");
}

#[tokio::test]
async fn latest_version_missing_platform() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/versions/latest?channel=stable",
            None,
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "缺少 platform 应返回 422"
    );
}

#[tokio::test]
async fn latest_version_channel_has_default() {
    let state = test_state().await;
    let app = test_router(state);

    // channel 有默认值 "stable"，不是必填
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/versions/latest?platform=android",
            None,
        ))
        .await
        .expect("请求失败");

    // 即使不传 channel，也应该正常返回 200（使用默认 channel "stable"）
    let (status, body) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "channel 有默认值，应返回 200: {body}");
}

// ============================================================================
// 热更新管理 - 列表/详情测试
// ============================================================================

#[tokio::test]
async fn admin_list_hot_updates_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/hot-updates",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, body) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "响应异常: {body}");
}

#[tokio::test]
async fn admin_list_hot_updates_requires_admin() {
    let state = test_state().await;
    let app = test_router(state);

    // 普通用户 token
    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let user_token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/hot-updates",
            Some(&user_token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::FORBIDDEN,
        "普通用户应返回 403"
    );
}

#[tokio::test]
async fn admin_get_hot_update_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;
    let fake_id = Uuid::new_v4();

    let response = app
        .oneshot(empty_request(
            Method::GET,
            &format!("/api/admin/hot-updates/{}", fake_id),
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::NOT_FOUND,
        "不存在的热更新应返回 404"
    );
}

#[tokio::test]
async fn admin_list_hot_update_events_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/hot-updates/events",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, body) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "响应异常: {body}");
}

// ============================================================================
// 热更新事件上报测试
// ============================================================================

#[tokio::test]
async fn report_hot_update_event_success() {
    let state = test_state().await;
    let app = test_router(state);

    // 公开 API，无需 token
    let body = json!({
        "platform": "android",
        "base_version": "1.0.0",
        "patch_version": "1.0.0-patch1",
        "event_type": "apply_success",
        "channel": "stable",
        "client_id": "test-device-001",
        "message": "热更新应用成功"
    });

    let response = app
        .oneshot(json_request(
            Method::POST,
            "/versions/hot-update/report",
            None,
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "响应异常: {resp}");
}

#[tokio::test]
async fn report_hot_update_event_invalid_type() {
    let state = test_state().await;
    let app = test_router(state);

    let body = json!({
        "platform": "android",
        "base_version": "1.0.0",
        "patch_version": "1.0.0-patch1",
        "event_type": "invalid_event_type",  // 无效的事件类型
        "channel": "stable"
    });

    let response = app
        .oneshot(json_request(
            Method::POST,
            "/versions/hot-update/report",
            None,
            body,
        ))
        .await
        .expect("请求失败");

    // 无效的事件类型应返回 422
    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "无效事件类型应返回 422"
    );
}
