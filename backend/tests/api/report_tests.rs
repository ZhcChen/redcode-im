//! 举报 API 测试
//!
//! 覆盖举报创建、附件上传、管理员查看等功能。

use super::common::{
    create_public_room, empty_request, get_admin_token, json_request, login_user, read_json,
    register_user, test_router, test_state, unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

// ============================================================================
// 创建举报测试
// ============================================================================

#[tokio::test]
async fn create_report_requires_attachment() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let user_id = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // API 要求至少 1 张截图，空附件应返回 400
    let body = json!({
        "target_type": "user",
        "target_id": user_id,
        "content": "测试举报内容",
        "attachment_keys": []
    });

    let response = app
        .oneshot(json_request(Method::POST, "/reports", Some(&token), body))
        .await
        .expect("请求失败");

    // 无附件应返回 400 (业务规则：必须上传截图)
    assert_eq!(response.status(), StatusCode::BAD_REQUEST, "无附件举报应返回 400");
}

#[tokio::test]
async fn create_report_missing_fields() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    // 缺少必填字段
    let body = json!({
        "description": "测试举报"
    });

    let response = app
        .oneshot(json_request(Method::POST, "/reports", Some(&token), body))
        .await
        .expect("请求失败");

    // 应返回 400 或 422
    let status = response.status();
    assert!(
        status == StatusCode::BAD_REQUEST || status == StatusCode::UNPROCESSABLE_ENTITY,
        "missing fields 应返回错误: {status}"
    );
}

#[tokio::test]
async fn create_report_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let body = json!({
        "target_type": "user",
        "target_id": Uuid::new_v4().to_string(),
        "reason": "spam"
    });

    let response = app
        .oneshot(json_request(Method::POST, "/reports", None, body))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 附件上传测试
// ============================================================================

#[tokio::test]
async fn get_attachment_signature_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let body = json!({
        "filename": "evidence.png",
        "content_type": "image/png",
        "file_size": 1024
    });

    let response = app
        .oneshot(json_request(
            Method::POST,
            "/reports/attachments/signature",
            Some(&token),
            body,
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "get attachment signature 响应异常: {resp}");
}

#[tokio::test]
async fn get_attachment_signature_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let body = json!({
        "filename": "evidence.png",
        "content_type": "image/png",
        "file_size": 1024
    });

    let response = app
        .oneshot(json_request(
            Method::POST,
            "/reports/attachments/signature",
            None,
            body,
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

// ============================================================================
// 管理员举报查看测试
// ============================================================================

#[tokio::test]
async fn admin_list_reports_success() {
    let state = test_state().await;
    let app = test_router(state);

    let token = get_admin_token(app.clone()).await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/reports",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "admin list reports 响应异常: {resp}");
}

#[tokio::test]
async fn admin_list_reports_requires_admin() {
    let state = test_state().await;
    let app = test_router(state);

    // 普通用户 token
    let username = unique_phone_username();
    let _ = register_user(app.clone(), &username, "Test123456").await;
    let token = login_user(app.clone(), &username, "Test123456").await;

    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/api/admin/reports",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn admin_list_reports_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/api/admin/reports", None))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}
