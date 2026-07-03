mod support;

use axum::http::StatusCode;
use support::{body_json, spawn_test_app, unique_username};

async fn enable_email_auth(app: &support::TestApp) {
    sqlx::query(
        r#"
        INSERT INTO general_settings (key, value, description, updated_at)
        VALUES ('auth_email_enabled', '1', '测试启用邮箱注册/登录兼容能力', NOW())
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
        "#,
    )
    .execute(&app.pool)
    .await
    .expect("启用邮箱注册/登录兼容能力");
}

/// 普通账号注册 → 密码登录 → 带 token 访问 /auth/me，全链路 happy path。
#[tokio::test]
async fn register_then_login_then_me_succeeds() {
    let app = spawn_test_app().await;
    let username = unique_username("auth");

    let reg_body =
        format!(r#"{{"username":"{username}","password":"pass123456","nickname":"{username}"}}"#);
    let (status, body) = app.post_json("/auth/register", &reg_body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "register: {}",
        String::from_utf8_lossy(&body)
    );
    let reg = body_json(&body);
    assert!(reg["id"].as_str().is_some(), "register 应返回 id");
    assert_eq!(reg["username"].as_str().unwrap_or_default(), username);
    assert!(
        reg["email"]
            .as_str()
            .unwrap_or_default()
            .ends_with("@account.redcode.local"),
        "普通账号注册应使用内部邮箱占位，不依赖真实邮箱资源"
    );

    let login_body = format!(r#"{{"username":"{username}","password":"pass123456"}}"#);
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

/// 旧邮箱注册兼容：不应把完整邮箱直接塞入 username，避免长邮箱触发数据库 username 长度限制。
#[tokio::test]
async fn register_with_long_email_generates_short_username() {
    let app = spawn_test_app().await;
    enable_email_auth(&app).await;
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

/// 默认关闭邮箱注册/登录：测试主线不依赖真实邮箱资源。
#[tokio::test]
async fn email_registration_is_disabled_by_default() {
    let app = spawn_test_app().await;
    let reg_body = r#"{"email":"disabled@example.test","password":"pass123456"}"#;
    let (status, body) = app.post_json("/auth/register", reg_body).await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "email register should be disabled: {}",
        String::from_utf8_lossy(&body)
    );

    let login_body = r#"{"email":"disabled@example.test","password":"pass123456"}"#;
    let (status, body) = app.post_json("/auth/login", login_body).await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "email login should be disabled: {}",
        String::from_utf8_lossy(&body)
    );
}

/// 错误密码登录被拒（401 或 400）。
#[tokio::test]
async fn login_with_wrong_password_is_rejected() {
    let app = spawn_test_app().await;
    let username = unique_username("auth");

    let reg_body =
        format!(r#"{{"username":"{username}","password":"pass123456","nickname":"{username}"}}"#);
    let (status, _b) = app.post_json("/auth/register", &reg_body).await;
    assert_eq!(status, StatusCode::OK);

    let bad = format!(r#"{{"username":"{username}","password":"wrong-password"}}"#);
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
