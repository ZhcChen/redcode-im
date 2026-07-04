mod support;

use axum::body::Body;
use axum::http::StatusCode;
use support::{body_json, spawn_test_app};

const TEST_APNS_PRIVATE_KEY: &str = r#"-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg1gsW8p7m26JzSzqh
Xj7a8qzlgQr96B0XOgTxmPLQZ3mhRANCAASLhkavy/UiriTIjBnLK1B0ngJttikw
mN/fOb81W2J8TNvVe4bOgzZAGGWjZYIv/IdHh3Fya9fOEo7CRaKSZs0N
-----END PRIVATE KEY-----"#;

/// 公开的 bootstrap 状态：新库无管理员 → 要求 bootstrap。
#[tokio::test]
async fn bootstrap_status_required_on_fresh_db() {
    let app = spawn_test_app().await;
    let (status, body) = app.get("/api/admin/bootstrap/status").await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&body));
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

/// 旧版账号限制更新 payload 不包含 enable_email_auth 时，不应意外关闭邮箱兼容开关。
#[tokio::test]
async fn user_account_limit_update_without_email_auth_preserves_current_switch() {
    let app = spawn_test_app().await;

    let bootstrap_body = r#"{"username":"admin","password":"adminpass123","display_name":"Admin"}"#;
    let (status, body) = app
        .post_json("/api/admin/bootstrap/init", bootstrap_body)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "bootstrap: {}",
        String::from_utf8_lossy(&body)
    );
    let token = body_json(&body)["token"]
        .as_str()
        .expect("bootstrap token")
        .to_string();

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

    let legacy_payload = r#"{
        "enable_phone_validation": false,
        "enable_email_validation": false,
        "enable_length_validation": true,
        "min_length": 3,
        "max_length": 20,
        "enable_alphanumeric_validation": false
    }"#;
    let (status, body) = app
        .send(
            "PUT",
            "/api/admin/settings/user-account-limit",
            Some(&token),
            Body::from(legacy_payload),
            true,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "update user-account-limit: {}",
        String::from_utf8_lossy(&body)
    );
    let updated = body_json(&body);
    assert_eq!(updated["enable_email_auth"].as_bool(), Some(true));

    let value: String =
        sqlx::query_scalar("SELECT value FROM general_settings WHERE key = 'auth_email_enabled'")
            .fetch_one(&app.pool)
            .await
            .expect("读取邮箱兼容开关");
    assert_eq!(value, "1");
}

#[tokio::test]
async fn push_settings_supports_apns_provider_config() {
    let app = spawn_test_app().await;

    let bootstrap_body = r#"{"username":"admin","password":"adminpass123","display_name":"Admin"}"#;
    let (status, body) = app
        .post_json("/api/admin/bootstrap/init", bootstrap_body)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "bootstrap: {}",
        String::from_utf8_lossy(&body)
    );
    let token = body_json(&body)["token"]
        .as_str()
        .expect("bootstrap token")
        .to_string();

    let payload = serde_json::json!({
        "enabled": true,
        "team_id": "TEAMID1234",
        "key_id": "KEYID1234",
        "bundle_id": "com.redcode.im.iosapp",
        "environment": "sandbox",
        "private_key_p8": TEST_APNS_PRIVATE_KEY,
    })
    .to_string();
    let (status, body) = app
        .send(
            "PUT",
            "/api/admin/settings/push/providers/apns",
            Some(&token),
            Body::from(payload),
            true,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "upsert apns: {}",
        String::from_utf8_lossy(&body)
    );

    let saved = body_json(&body);
    assert_eq!(saved["provider"], "apns");
    assert_eq!(saved["platform"], "ios");
    assert_eq!(saved["enabled"], true);
    assert_eq!(saved["config_public"]["bundle_id"], "com.redcode.im.iosapp");
    assert_eq!(saved["config_public"]["environment"], "sandbox");
    assert_eq!(saved["has_secret"], true);
    assert!(saved["secret_fingerprint"]
        .as_str()
        .map(|v| !v.is_empty())
        .unwrap_or(false));
}
