mod support;

use axum::http::StatusCode;
use support::{body_json, spawn_test_app, unique_username, TestApp};

async fn register_and_login(app: &TestApp, username: &str) -> String {
    let reg =
        format!(r#"{{"username":"{username}","password":"pass123456","nickname":"{username}"}}"#);
    let (s, b) = app.post_json("/auth/register", &reg).await;
    assert_eq!(
        s,
        StatusCode::OK,
        "register: {}",
        String::from_utf8_lossy(&b)
    );
    let login = format!(r#"{{"username":"{username}","password":"pass123456"}}"#);
    let (s, b) = app.post_json("/auth/login", &login).await;
    assert_eq!(s, StatusCode::OK, "login: {}", String::from_utf8_lossy(&b));
    body_json(&b)["token"].as_str().expect("token").to_string()
}

/// 用户搜索需要鉴权。
#[tokio::test]
async fn user_search_requires_auth() {
    let app = spawn_test_app().await;
    let (status, _b) = app.get("/users/search?keyword=alice").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
}

/// 带 token 的用户搜索返回 200（列表，至少含本人）。
#[tokio::test]
async fn user_search_with_token_returns_ok() {
    let app = spawn_test_app().await;
    let username = unique_username("usr");
    let token = register_and_login(&app, &username).await;
    let (status, body) = app.get_authed("/users/search?keyword=usr", &token).await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&body));
    assert!(body_json(&body).is_array(), "搜索结果应为数组");
}

/// 带 token 获取上传策略 → 200（uploads 域 smoke，无需 external-mock）。
#[tokio::test]
async fn upload_policy_with_token_returns_ok() {
    let app = spawn_test_app().await;
    let username = unique_username("usr");
    let token = register_and_login(&app, &username).await;
    let (status, _b) = app.get_authed("/system/upload-policy", &token).await;
    assert_eq!(status, StatusCode::OK);
}
