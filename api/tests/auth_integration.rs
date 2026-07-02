mod support;

use axum::http::StatusCode;
use support::{body_json, spawn_test_app, unique_email};

/// 邮箱注册 → 密码登录 → 带 token 访问 /auth/me，全链路 happy path。
#[tokio::test]
async fn register_then_login_then_me_succeeds() {
    let app = spawn_test_app().await;
    let email = unique_email("auth");

    let reg_body = format!(r#"{{"email":"{email}","password":"pass123456","nickname":"{email}"}}"#);
    let (status, body) = app.post_json("/auth/register", &reg_body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "register: {}",
        String::from_utf8_lossy(&body)
    );
    let reg = body_json(&body);
    assert!(reg["id"].as_str().is_some(), "register 应返回 id");
    assert_eq!(reg["email"].as_str().unwrap_or_default(), email);

    let login_body = format!(r#"{{"email":"{email}","password":"pass123456"}}"#);
    let (status, body) = app.post_json("/auth/login", &login_body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "login: {}",
        String::from_utf8_lossy(&body)
    );
    let login = body_json(&body);
    let token = login["token"].as_str().expect("login 应返回 token");
    assert!(!token.is_empty());
    assert!(
        login["refresh_token"].as_str().is_some(),
        "应返回 refresh_token"
    );

    let (status, _b) = app.get_authed("/auth/me", token).await;
    assert_eq!(status, StatusCode::OK, "带 token 访问 /auth/me 应 200");
}

/// 邮箱注册不应把完整邮箱直接塞入 username，避免长邮箱触发数据库 username 长度限制。
#[tokio::test]
async fn register_with_long_email_generates_short_username() {
    let app = spawn_test_app().await;
    let email = format!(
        "long_email_{}@example.test",
        "abcdefghijklmnopqrstuvwxyz0123456789"
    );

    let reg_body = format!(r#"{{"email":"{email}","password":"pass123456","nickname":"long"}}"#);
    let (status, body) = app.post_json("/auth/register", &reg_body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "register: {}",
        String::from_utf8_lossy(&body)
    );
    let reg = body_json(&body);
    assert_eq!(reg["email"].as_str().unwrap_or_default(), email);
    let username = reg["username"].as_str().expect("username");
    assert_ne!(username, email);
    assert!(username.len() <= 50, "username too long: {username}");

    let login_body = format!(r#"{{"email":"{email}","password":"pass123456"}}"#);
    let (status, body) = app.post_json("/auth/login", &login_body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "login: {}",
        String::from_utf8_lossy(&body)
    );
    assert!(body_json(&body)["token"].as_str().is_some());
}

/// 错误密码登录被拒（401 或 400）。
#[tokio::test]
async fn login_with_wrong_password_is_rejected() {
    let app = spawn_test_app().await;
    let email = unique_email("auth");

    let reg_body = format!(r#"{{"email":"{email}","password":"pass123456","nickname":"{email}"}}"#);
    let (status, _b) = app.post_json("/auth/register", &reg_body).await;
    assert_eq!(status, StatusCode::OK);

    let bad = format!(r#"{{"email":"{email}","password":"wrong-password"}}"#);
    let (status, _b) = app.post_json("/auth/login", &bad).await;
    assert!(
        status == StatusCode::UNAUTHORIZED || status == StatusCode::BAD_REQUEST,
        "错误密码应被拒，实际 {status}"
    );
}

/// 未携带 token 访问受保护路由 → 401。
#[tokio::test]
async fn auth_me_without_token_is_unauthorized() {
    let app = spawn_test_app().await;
    let (status, _b) = app.get("/auth/me").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
}
