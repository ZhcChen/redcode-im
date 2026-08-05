mod support;

use axum::http::StatusCode;
use serde_json::json;
use support::{body_json, bootstrap_admin_token, spawn_test_app, unique_username, TestApp};
use uuid::Uuid;

struct TestUser {
    id: Uuid,
    token: String,
}

async fn register_user(app: &TestApp, prefix: &str) -> TestUser {
    let username = unique_username(prefix);
    let body = json!({
        "username": username.clone(),
        "password": "pass123456",
        "nickname": username.clone(),
    })
    .to_string();
    let (status, response) = app.post_json("/auth/register", &body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let login = json!({
        "username": username,
        "password": "pass123456",
    })
    .to_string();
    let (status, response) = app.post_json("/auth/login", &login).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let body = body_json(&response);
    TestUser {
        id: Uuid::parse_str(body["user"]["id"].as_str().expect("user id")).expect("user UUID"),
        token: body["token"].as_str().expect("register token").to_string(),
    }
}

async fn create_room(app: &TestApp, owner: &TestUser, member: &TestUser) -> Uuid {
    let (status, response) = app
        .post_json_authed(
            "/rooms",
            &owner.token,
            &json!({
                "name": "Boundary integration",
                "description": "test",
                "room_type": "group",
                "member_ids": [member.id],
            })
            .to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    Uuid::parse_str(
        body_json(&response)["room"]["id"]
            .as_str()
            .expect("room id"),
    )
    .expect("room UUID")
}

/// U5 边界测试直接写 runtime，避免依赖 U6 门禁流程；门禁本身由
/// admin_e2ee_gate_integration 覆盖。
async fn set_runtime(app: &TestApp, _admin_token: &str, payload: &str) {
    let parsed: serde_json::Value = serde_json::from_str(payload).expect("runtime payload");
    let content_audit_mode = parsed["content_audit_mode"]
        .as_str()
        .expect("content_audit_mode");
    sqlx::query(
        r#"
        INSERT INTO general_settings (key, value, description)
        VALUES ('message_content_audit_mode', $1, '消息内容审计模式')
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
        "#,
    )
    .bind(content_audit_mode)
    .execute(&app.pool)
    .await
    .expect("set content audit mode");
}

#[tokio::test]
async fn e2ee_runtime_disables_search_forward_and_push_body() {
    let app = spawn_test_app().await;
    let admin_token = bootstrap_admin_token(&app).await;
    let alice = register_user(&app, "boundary-alice").await;
    let bob = register_user(&app, "boundary-bob").await;
    let room_id = create_room(&app, &alice, &bob).await;

    // 明文基线：发送正文后可被服务端搜索。
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &alice.token,
            &json!({ "content": "boundary searchable marker" }).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let message_id = body_json(&response)["message"]["id"]
        .as_str()
        .expect("message id")
        .to_string();
    let (status, response) = app
        .get_authed("/messages/search?query=boundary", &alice.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        body_json(&response)["results"]
            .as_array()
            .expect("results")
            .len(),
        1,
        "明文基线应可搜索到"
    );

    // E2EE 模式：搜索返回空、转发被拒绝。
    set_runtime(
        &app,
        &admin_token,
        r#"{"server_storage_mode":"persist","content_audit_mode":"e2ee"}"#,
    )
    .await;
    let (status, response) = app
        .get_authed("/messages/search?query=boundary", &alice.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        body_json(&response)["results"]
            .as_array()
            .expect("results")
            .len(),
        0,
        "E2EE 模式服务端搜索必须返回空"
    );
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages/forward"),
            &alice.token,
            &json!({ "original_message_id": message_id }).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert!(
        String::from_utf8_lossy(&response).contains("不支持转发"),
        "E2EE 模式转发必须明确失败"
    );

    // 恢复默认 runtime，避免污染测试栈后续用例。
    set_runtime(
        &app,
        &admin_token,
        r#"{"server_storage_mode":"persist","content_audit_mode":"plaintext"}"#,
    )
    .await;
}
