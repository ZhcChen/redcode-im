mod api_test_utils;

use api_test_utils::{empty_request, json_request, read_json, read_text, test_router, test_state};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

fn unique_phone_username() -> String {
    // 生成一个看起来像手机号的用户名（满足默认手机号校验）。
    let n = (Uuid::new_v4().as_u128() % 100_000_000) as u64; // 8 位
    format!("138{:08}", n)
}

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
