//! 设置 API 测试
//!
//! 覆盖 `handlers/settings.rs` 中的公开设置接口。

use super::common::{empty_request, read_json, test_router, test_state};
use axum::http::{Method, StatusCode};
use tower::ServiceExt;

#[tokio::test]
async fn get_general_settings_returns_app_name() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/settings/general", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        json.get("app_name").is_some(),
        "响应应包含 app_name 字段"
    );
}

#[tokio::test]
async fn get_app_name_returns_app_name() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/settings/app-name", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        json.get("app_name").is_some(),
        "响应应包含 app_name 字段"
    );
}

#[tokio::test]
async fn get_captcha_setting_returns_config() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/settings/captcha", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    assert!(
        json.get("require_captcha_for_login").is_some(),
        "响应应包含 require_captcha_for_login 字段"
    );
}

#[tokio::test]
async fn get_privacy_policy_returns_document() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/settings/privacy-policy", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);

    // 验证文档结构
    assert_eq!(
        json.get("key").and_then(|v| v.as_str()),
        Some("privacy_policy"),
        "key 应为 privacy_policy"
    );
    assert!(json.get("title").is_some(), "响应应包含 title 字段");
    assert!(json.get("content").is_some(), "响应应包含 content 字段");
    assert!(json.get("updated_at").is_some(), "响应应包含 updated_at 字段");
}

#[tokio::test]
async fn get_user_agreement_returns_document() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/settings/user-agreement", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);

    // 验证文档结构
    assert_eq!(
        json.get("key").and_then(|v| v.as_str()),
        Some("user_agreement"),
        "key 应为 user_agreement"
    );
    assert!(json.get("title").is_some(), "响应应包含 title 字段");
    assert!(json.get("content").is_some(), "响应应包含 content 字段");
    assert!(json.get("updated_at").is_some(), "响应应包含 updated_at 字段");
}
