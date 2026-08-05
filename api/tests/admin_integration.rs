mod support;

use axum::body::Body;
use axum::http::StatusCode;
use support::{body_json, bootstrap_admin_token, spawn_test_app};

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
    let token = bootstrap_admin_token(&app).await;

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
async fn message_runtime_settings_can_be_updated_and_read_publicly() {
    let app = spawn_test_app().await;
    let token = bootstrap_admin_token(&app).await;

    let (status, body) = app
        .get_authed("/api/admin/settings/message-runtime", &token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "admin settings default: {}",
        String::from_utf8_lossy(&body)
    );
    let admin_default = body_json(&body);
    assert_eq!(
        admin_default["server_storage_mode"].as_str(),
        Some("persist")
    );
    assert_eq!(
        admin_default["content_audit_mode"].as_str(),
        Some("plaintext")
    );

    let (status, body) = app.get("/settings/general").await;
    assert_eq!(
        status,
        StatusCode::OK,
        "public settings default: {}",
        String::from_utf8_lossy(&body)
    );
    let public = body_json(&body);
    assert_eq!(
        public["message_runtime"]["server_storage_mode"].as_str(),
        Some("persist")
    );
    assert_eq!(
        public["message_runtime"]["content_audit_mode"].as_str(),
        Some("plaintext")
    );

    let relay_payload = r#"{"server_storage_mode":"relay_only","content_audit_mode":"plaintext"}"#;
    let (status, body) = app
        .send(
            "PUT",
            "/api/admin/settings/message-runtime",
            None,
            Body::from(relay_payload),
            true,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::UNAUTHORIZED,
        "message runtime update should require admin token: {}",
        String::from_utf8_lossy(&body)
    );

    let (status, body) = app
        .put_json_authed("/api/admin/settings/message-runtime", &token, relay_payload)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "update message runtime: {}",
        String::from_utf8_lossy(&body)
    );
    let updated = body_json(&body);
    assert_eq!(updated["server_storage_mode"].as_str(), Some("relay_only"));
    assert_eq!(updated["content_audit_mode"].as_str(), Some("plaintext"));
    assert!(updated["updated_at"].as_str().is_some());
    assert!(updated["updated_by"].as_str().is_some());

    let (status, body) = app.get("/settings/general").await;
    assert_eq!(
        status,
        StatusCode::OK,
        "public settings after update: {}",
        String::from_utf8_lossy(&body)
    );
    let public = body_json(&body);
    assert_eq!(
        public["message_runtime"]["server_storage_mode"].as_str(),
        Some("relay_only")
    );
    assert_eq!(
        public["message_runtime"]["content_audit_mode"].as_str(),
        Some("plaintext")
    );

    let (status, body) = app
        .get_authed("/api/admin/settings/message-runtime", &token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "admin settings after update: {}",
        String::from_utf8_lossy(&body)
    );
    let admin_updated = body_json(&body);
    assert_eq!(
        admin_updated["server_storage_mode"].as_str(),
        Some("relay_only")
    );
    assert_eq!(
        admin_updated["content_audit_mode"].as_str(),
        Some("plaintext")
    );

    // E2EE 只能通过门禁启用，直接修改被拒绝。
    let direct_e2ee_payload = r#"{"server_storage_mode":"relay_only","content_audit_mode":"e2ee"}"#;
    let (status, body) = app
        .put_json_authed(
            "/api/admin/settings/message-runtime",
            &token,
            direct_e2ee_payload,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "direct e2ee switch must be rejected: {}",
        String::from_utf8_lossy(&body)
    );
    assert!(
        String::from_utf8_lossy(&body).contains("只能通过门禁预检"),
        "{}",
        String::from_utf8_lossy(&body)
    );

    let invalid_payload = r#"{"server_storage_mode":"archive","content_audit_mode":"plaintext"}"#;
    let (status, body) = app
        .put_json_authed(
            "/api/admin/settings/message-runtime",
            &token,
            invalid_payload,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "invalid runtime should be rejected: {}",
        String::from_utf8_lossy(&body)
    );

    let invalid_payload = r#"{"server_storage_mode":"persist","content_audit_mode":"unknown"}"#;
    let (status, body) = app
        .put_json_authed(
            "/api/admin/settings/message-runtime",
            &token,
            invalid_payload,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "invalid audit mode should be rejected: {}",
        String::from_utf8_lossy(&body)
    );

    let (status, body) = app
        .get_authed("/api/admin/settings/message-runtime", &token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "admin settings after invalid updates: {}",
        String::from_utf8_lossy(&body)
    );
    let after_invalid = body_json(&body);
    assert_eq!(
        after_invalid["server_storage_mode"].as_str(),
        Some("relay_only")
    );
    assert_eq!(
        after_invalid["content_audit_mode"].as_str(),
        Some("plaintext")
    );

    let (status, body) = app.get("/settings/general").await;
    assert_eq!(
        status,
        StatusCode::OK,
        "public settings after invalid updates: {}",
        String::from_utf8_lossy(&body)
    );
    let public_after_invalid = body_json(&body);
    assert_eq!(
        public_after_invalid["message_runtime"]["server_storage_mode"].as_str(),
        Some("relay_only")
    );
    assert_eq!(
        public_after_invalid["message_runtime"]["content_audit_mode"].as_str(),
        Some("plaintext")
    );
}

#[tokio::test]
async fn message_runtime_settings_update_rolls_back_on_partial_db_failure() {
    let app = spawn_test_app().await;
    let token = bootstrap_admin_token(&app).await;

    sqlx::query(
        r#"
        INSERT INTO general_settings (key, value, description)
        VALUES
            ('message_server_storage_mode', 'persist', 'original server storage mode'),
            ('message_content_audit_mode', 'plaintext', 'original content audit mode')
        "#,
    )
    .execute(&app.pool)
    .await
    .expect("seed original message runtime settings");

    sqlx::query(
        r#"
        CREATE OR REPLACE FUNCTION fail_message_content_audit_mode_for_test()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
            IF NEW.key = 'message_content_audit_mode' THEN
                RAISE EXCEPTION 'forced message runtime failure';
            END IF;
            RETURN NEW;
        END;
        $$;
        "#,
    )
    .execute(&app.pool)
    .await
    .expect("install forced failure function");
    sqlx::query(
        r#"
        CREATE TRIGGER fail_message_content_audit_mode_for_test
        BEFORE INSERT OR UPDATE ON general_settings
        FOR EACH ROW
        EXECUTE FUNCTION fail_message_content_audit_mode_for_test();
        "#,
    )
    .execute(&app.pool)
    .await
    .expect("install forced failure trigger");

    let relay_payload = r#"{"server_storage_mode":"relay_only","content_audit_mode":"plaintext"}"#;
    let (status, body) = app
        .put_json_authed("/api/admin/settings/message-runtime", &token, relay_payload)
        .await;
    assert_eq!(
        status,
        StatusCode::INTERNAL_SERVER_ERROR,
        "forced second setting failure should fail the update: {}",
        String::from_utf8_lossy(&body)
    );

    sqlx::query("DROP TRIGGER fail_message_content_audit_mode_for_test ON general_settings")
        .execute(&app.pool)
        .await
        .expect("drop forced failure trigger");
    sqlx::query("DROP FUNCTION fail_message_content_audit_mode_for_test()")
        .execute(&app.pool)
        .await
        .expect("drop forced failure function");

    let server_storage_value: String = sqlx::query_scalar(
        "SELECT value FROM general_settings WHERE key = 'message_server_storage_mode'",
    )
    .fetch_one(&app.pool)
    .await
    .expect("load server storage mode setting");
    assert_eq!(
        server_storage_value, "persist",
        "事务回滚后不应部分覆盖 server_storage_mode"
    );
    let content_audit_value: String = sqlx::query_scalar(
        "SELECT value FROM general_settings WHERE key = 'message_content_audit_mode'",
    )
    .fetch_one(&app.pool)
    .await
    .expect("load content audit mode setting");
    assert_eq!(
        content_audit_value, "plaintext",
        "事务回滚后不应部分覆盖 content_audit_mode"
    );

    let (status, body) = app.get("/settings/general").await;
    assert_eq!(
        status,
        StatusCode::OK,
        "public settings after failed transaction: {}",
        String::from_utf8_lossy(&body)
    );
    let public = body_json(&body);
    assert_eq!(
        public["message_runtime"]["server_storage_mode"].as_str(),
        Some("persist")
    );
    assert_eq!(
        public["message_runtime"]["content_audit_mode"].as_str(),
        Some("plaintext")
    );
}

#[tokio::test]
async fn push_settings_supports_apns_provider_config() {
    let app = spawn_test_app().await;
    let token = bootstrap_admin_token(&app).await;

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
