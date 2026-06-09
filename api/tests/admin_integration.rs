mod support;

use axum::http::StatusCode;
use support::{body_json, spawn_test_app};

/// 公开的 bootstrap 状态：新库无管理员 → 要求 bootstrap。
#[tokio::test]
async fn bootstrap_status_required_on_fresh_db() {
    let app = spawn_test_app().await;
    let (status, body) = app.get("/api/admin/bootstrap/status").await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&body)
    );
    let v = body_json(&body);
    // 兼容 snake_case / camelCase 序列化。
    let required = v["bootstrap_required"]
        .as_bool()
        .or_else(|| v["bootstrapRequired"].as_bool());
    assert_eq!(required, Some(true), "新库应要求 bootstrap: {v}");
}

/// 未鉴权访问管理员 API → 401。
#[tokio::test]
async fn admin_users_without_token_is_unauthorized() {
    let app = spawn_test_app().await;
    let (status, _b) = app.get("/api/admin/users").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
}
