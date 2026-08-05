mod support;

use axum::http::StatusCode;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use chrono::{Duration, Utc};
use ed25519_dalek::SigningKey;
use serde_json::{json, Value};
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

fn device_request(
    device_id: Uuid,
    label: &str,
    marker: u8,
    key: &SigningKey,
    platform: &str,
    version: &str,
) -> Value {
    json!({
        "device_id": device_id,
        "device_label": label,
        "root_public_key": BASE64_STANDARD.encode([11; 32]),
        "root_fingerprint": BASE64_STANDARD.encode([12; 32]),
        "credential": BASE64_STANDARD.encode(vec![marker; 128]),
        "credential_fingerprint": BASE64_STANDARD.encode([marker; 32]),
        "approval_public_key": BASE64_STANDARD.encode(key.verifying_key().to_bytes()),
        "protocol_version": 1,
        "client_platform": platform,
        "client_version": version,
        "client_build": "gate-test-1",
    })
}

async fn register_device(app: &TestApp, user: &TestUser, request: &Value) -> Value {
    let (status, response) = app
        .post_json_authed("/e2ee/mls/devices", &user.token, &request.to_string())
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    body_json(&response)
}

fn package_body(packages: &[(Uuid, Vec<u8>)]) -> String {
    json!({
        "packages": packages.iter().map(|(id, key_package)| json!({
            "id": id,
            "package_ref": BASE64_STANDARD.encode(id.as_bytes()),
            "key_package": BASE64_STANDARD.encode(key_package),
            "protocol_version": 1,
            "expires_at": Utc::now() + Duration::hours(1),
        })).collect::<Vec<_>>(),
    })
    .to_string()
}

async fn publish_inventory(app: &TestApp, user: &TestUser, device_id: Uuid, count: usize) {
    let packages: Vec<(Uuid, Vec<u8>)> = (0..count)
        .map(|index| (Uuid::new_v4(), vec![70 + index as u8; 256]))
        .collect();
    let (status, response) = app
        .post_json_authed(
            &format!("/e2ee/mls/devices/{device_id}/key-packages"),
            &user.token,
            &package_body(&packages),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
}

async fn approve_security_review(app: &TestApp) {
    sqlx::query("UPDATE e2ee_runtime_gate SET security_review_approved = TRUE")
        .execute(&app.pool)
        .await
        .expect("approve security review");
}

async fn gate_uri(app: &TestApp, admin_token: &str, action: &str) -> Value {
    let (status, response) = app
        .post_json_authed(
            &format!("/api/admin/settings/message-runtime/e2ee/{action}"),
            admin_token,
            "{}",
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    body_json(&response)
}

#[tokio::test]
async fn e2ee_gate_blocks_active_until_readiness_is_met() {
    let app = spawn_test_app().await;
    let admin_token = bootstrap_admin_token(&app).await;
    let alice = register_user(&app, "gate-alice").await;
    let bob = register_user(&app, "gate-bob").await;

    let (status, response) = app
        .get_authed(
            "/api/admin/settings/message-runtime/e2ee/gate",
            &admin_token,
        )
        .await;
    assert_eq!(status, StatusCode::OK);
    let gate = body_json(&response);
    assert_eq!(gate["state"], "plaintext");
    assert_eq!(gate["readiness"]["ready"], false);
    assert!(gate["readiness"]["blocking_reasons"]
        .as_array()
        .expect("blocking reasons")
        .iter()
        .any(|reason| reason
            .as_str()
            .unwrap_or("")
            .contains("没有已激活的 E2EE 设备")));
    assert!(gate["readiness"]["blocking_reasons"]
        .as_array()
        .expect("blocking reasons")
        .iter()
        .any(|reason| reason.as_str().unwrap_or("") == "安全审查未通过"));

    // prepare 只记录预检，不改变发送模式；阻断存在时 active 拒绝。
    let prepared = gate_uri(&app, &admin_token, "prepare").await;
    assert_eq!(prepared["state"], "prepare");
    assert_eq!(prepared["content_audit_mode"], "plaintext");
    assert_eq!(prepared["readiness"]["ready"], false);
    let (status, response) = app
        .post_json_authed(
            "/api/admin/settings/message-runtime/e2ee/active",
            &admin_token,
            "{}",
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert!(
        String::from_utf8_lossy(&response).contains("readiness 未通过"),
        "{}",
        String::from_utf8_lossy(&response)
    );

    // 两台达标 active 设备 + 库存满足低水位 + 安全审查通过后可以 active。
    let alice_device = Uuid::new_v4();
    let bob_device = Uuid::new_v4();
    register_device(
        &app,
        &alice,
        &device_request(
            alice_device,
            "Alice H5",
            41,
            &SigningKey::from_bytes(&[21; 32]),
            "h5",
            "0.1.0",
        ),
    )
    .await;
    register_device(
        &app,
        &bob,
        &device_request(
            bob_device,
            "Bob Android",
            51,
            &SigningKey::from_bytes(&[31; 32]),
            "android",
            "0.2.1",
        ),
    )
    .await;
    publish_inventory(&app, &alice, alice_device, 12).await;
    publish_inventory(&app, &bob, bob_device, 12).await;
    approve_security_review(&app).await;

    let prepared = gate_uri(&app, &admin_token, "prepare").await;
    assert_eq!(prepared["readiness"]["active_devices"], 2);
    assert_eq!(prepared["readiness"]["compliant_devices"], 2);
    assert_eq!(prepared["readiness"]["coverage_percent"], 100);
    assert_eq!(prepared["readiness"]["ready"], true);

    let active = gate_uri(&app, &admin_token, "active").await;
    assert_eq!(active["state"], "active");
    assert_eq!(active["content_audit_mode"], "e2ee");

    // active 后旧客户端（无 E2EE 设备）明文发送被拒绝。
    let (status, response) = app
        .post_json_authed(
            "/rooms",
            &alice.token,
            &json!({
                "name": "Gate room",
                "description": "test",
                "room_type": "group",
                "member_ids": [bob.id],
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
    let room_id = body_json(&response)["room"]["id"]
        .as_str()
        .expect("room id")
        .to_string();
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &alice.token,
            &json!({ "content": "plaintext must be rejected" }).to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert!(
        String::from_utf8_lossy(&response).contains("后台已开启加密发送"),
        "{}",
        String::from_utf8_lossy(&response)
    );

    // 回滚只影响新发送：模式回到 plaintext，明文发送恢复，门禁状态复位。
    let rolled_back = gate_uri(&app, &admin_token, "rollback").await;
    assert_eq!(rolled_back["state"], "plaintext");
    assert_eq!(rolled_back["content_audit_mode"], "plaintext");
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &alice.token,
            &json!({ "content": "plaintext again" }).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
}

#[tokio::test]
async fn e2ee_gate_recomputes_readiness_when_active() {
    let app = spawn_test_app().await;
    let admin_token = bootstrap_admin_token(&app).await;
    let alice = register_user(&app, "gate-recheck-alice").await;
    let bob = register_user(&app, "gate-recheck-bob").await;

    let alice_device = Uuid::new_v4();
    let bob_device = Uuid::new_v4();
    register_device(
        &app,
        &alice,
        &device_request(
            alice_device,
            "Alice H5",
            41,
            &SigningKey::from_bytes(&[22; 32]),
            "h5",
            "0.1.0",
        ),
    )
    .await;
    register_device(
        &app,
        &bob,
        &device_request(
            bob_device,
            "Bob Android",
            51,
            &SigningKey::from_bytes(&[32; 32]),
            "android",
            "0.1.0",
        ),
    )
    .await;
    publish_inventory(&app, &alice, alice_device, 12).await;
    publish_inventory(&app, &bob, bob_device, 12).await;
    approve_security_review(&app).await;
    gate_uri(&app, &admin_token, "prepare").await;

    // prepare 通过后新增低版本设备：active 重新校验并拒绝。
    let carol = register_user(&app, "gate-recheck-carol").await;
    let old_device = Uuid::new_v4();
    register_device(
        &app,
        &carol,
        &device_request(
            old_device,
            "Carol Old H5",
            61,
            &SigningKey::from_bytes(&[42; 32]),
            "h5",
            "0.0.9",
        ),
    )
    .await;
    let (status, response) = app
        .post_json_authed(
            "/api/admin/settings/message-runtime/e2ee/active",
            &admin_token,
            "{}",
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert!(
        String::from_utf8_lossy(&response).contains("设备覆盖不足"),
        "{}",
        String::from_utf8_lossy(&response)
    );

    // 客户端升级后（模拟版本号变更）active 重新校验通过。
    sqlx::query("UPDATE e2ee_devices SET client_version = '0.1.0' WHERE id = $1")
        .bind(old_device)
        .execute(&app.pool)
        .await
        .expect("upgrade device version");
    publish_inventory(&app, &carol, old_device, 12).await;
    let active = gate_uri(&app, &admin_token, "active").await;
    assert_eq!(active["state"], "active");
    assert_eq!(active["content_audit_mode"], "e2ee");
}

#[tokio::test]
async fn e2ee_gate_rejects_direct_mode_switch_and_pending_devices() {
    let app = spawn_test_app().await;
    let admin_token = bootstrap_admin_token(&app).await;
    let alice = register_user(&app, "gate-direct-alice").await;

    // Admin 不能直接 PUT e2ee 绕过门禁。
    let (status, response) = app
        .put_json_authed(
            "/api/admin/settings/message-runtime",
            &admin_token,
            r#"{"server_storage_mode":"persist","content_audit_mode":"e2ee"}"#,
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert!(
        String::from_utf8_lossy(&response).contains("只能通过门禁预检"),
        "{}",
        String::from_utf8_lossy(&response)
    );

    // 待批准设备阻断 readiness。
    let first = Uuid::new_v4();
    let second = Uuid::new_v4();
    register_device(
        &app,
        &alice,
        &device_request(
            first,
            "Alice H5",
            41,
            &SigningKey::from_bytes(&[24; 32]),
            "h5",
            "0.1.0",
        ),
    )
    .await;
    register_device(
        &app,
        &alice,
        &device_request(
            second,
            "Alice iPad",
            42,
            &SigningKey::from_bytes(&[25; 32]),
            "ios",
            "0.1.0",
        ),
    )
    .await;
    publish_inventory(&app, &alice, first, 12).await;
    approve_security_review(&app).await;
    let prepared = gate_uri(&app, &admin_token, "prepare").await;
    assert_eq!(prepared["readiness"]["pending_approval_devices"], 1);
    assert_eq!(prepared["readiness"]["ready"], false);
    assert!(prepared["readiness"]["blocking_reasons"]
        .as_array()
        .expect("blocking reasons")
        .iter()
        .any(|reason| reason.as_str().unwrap_or("").contains("待批准设备")));
}

#[tokio::test]
async fn e2ee_gate_rejects_low_key_package_inventory() {
    let app = spawn_test_app().await;
    let admin_token = bootstrap_admin_token(&app).await;
    let alice = register_user(&app, "gate-inventory-alice").await;
    let device_id = Uuid::new_v4();
    register_device(
        &app,
        &alice,
        &device_request(
            device_id,
            "Alice H5",
            41,
            &SigningKey::from_bytes(&[26; 32]),
            "h5",
            "0.1.0",
        ),
    )
    .await;
    // 只发布 3 个 KeyPackage，低于低水位 10。
    publish_inventory(&app, &alice, device_id, 3).await;
    approve_security_review(&app).await;
    let prepared = gate_uri(&app, &admin_token, "prepare").await;
    assert_eq!(prepared["readiness"]["low_inventory_devices"], 1);
    assert_eq!(prepared["readiness"]["ready"], false);
    assert!(prepared["readiness"]["blocking_reasons"]
        .as_array()
        .expect("blocking reasons")
        .iter()
        .any(|reason| reason
            .as_str()
            .unwrap_or("")
            .contains("KeyPackage 库存低于低水位")));
}

#[tokio::test]
async fn admin_data_cleanup_removes_e2ee_user_fixtures_but_keeps_gate() {
    let app = spawn_test_app().await;
    let admin_token = bootstrap_admin_token(&app).await;
    let alice = register_user(&app, "cleanup-alice").await;
    let bob = register_user(&app, "cleanup-bob").await;

    // 创建房间并注册设备/KeyPackage，提交一条 commit 控制消息。
    let (status, response) = app
        .post_json_authed(
            "/rooms",
            &alice.token,
            &json!({
                "name": "Cleanup E2EE room",
                "description": "test",
                "room_type": "group",
                "member_ids": [bob.id],
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
    let room_id = body_json(&response)["room"]["id"]
        .as_str()
        .expect("room id")
        .to_string();

    let device_id = Uuid::new_v4();
    register_device(
        &app,
        &alice,
        &device_request(
            device_id,
            "Cleanup H5",
            41,
            &SigningKey::from_bytes(&[27; 32]),
            "h5",
            "0.1.0",
        ),
    )
    .await;
    publish_inventory(&app, &alice, device_id, 4).await;

    let (status, response) = app
        .get_authed(&format!("/rooms/{room_id}/e2ee/epoch"), &alice.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    let revision = body_json(&response)["membership_revision"]
        .as_i64()
        .expect("membership revision");
    let control_id = Uuid::new_v4();
    let mut envelope = b"RCML".to_vec();
    envelope.extend_from_slice(&1_u16.to_be_bytes());
    envelope.push(2);
    envelope.extend_from_slice(&48_u32.to_be_bytes());
    envelope.extend_from_slice(&vec![0x55; 48]);
    let commit = json!({
        "id": control_id,
        "epoch": 1,
        "membership_revision": revision,
        "sender_device_id": device_id,
        "recipient_device_id": null,
        "content_type": "commit",
        "envelope": BASE64_STANDARD.encode(envelope),
        "idempotency_key": Uuid::new_v4(),
    });
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &commit.to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );

    // 旧版 X3DH 表无外键，手工插入夹具验证 cleanup 显式清理。
    sqlx::query(
        "INSERT INTO e2ee_identity_keys (user_id, device_id, public_key) VALUES ($1, $2, $3)",
    )
    .bind(alice.id)
    .bind(device_id.to_string())
    .bind(vec![0x71u8; 32])
    .execute(&app.pool)
    .await
    .expect("insert legacy identity key");
    sqlx::query(
        "INSERT INTO e2ee_signed_pre_keys (user_id, device_id, key_id, public_key, signature, expires_at)
         VALUES ($1, $2, 1, $3, $4, NOW() + interval '1 hour')",
    )
    .bind(alice.id)
    .bind(device_id.to_string())
    .bind(vec![0x72u8; 32])
    .bind(vec![0x73u8; 64])
    .execute(&app.pool)
    .await
    .expect("insert legacy signed pre key");
    sqlx::query(
        "INSERT INTO e2ee_one_time_pre_keys (user_id, device_id, key_id, public_key)
         VALUES ($1, $2, 1, $3)",
    )
    .bind(alice.id)
    .bind(device_id.to_string())
    .bind(vec![0x74u8; 32])
    .execute(&app.pool)
    .await
    .expect("insert legacy one-time pre key");

    // 执行 Admin 全量清理。
    let (status, response) = app
        .post_json_authed("/admin/data/cleanup/all", &admin_token, "{}")
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let result = body_json(&response);
    assert_eq!(result["success"], true, "{result}");
    let cleaned = result["cleaned_tables"]
        .as_array()
        .expect("cleaned tables")
        .iter()
        .map(|value| value.as_str().unwrap_or(""))
        .collect::<Vec<_>>();
    for table in [
        "e2ee_control_receipts",
        "e2ee_control_messages",
        "e2ee_key_packages",
        "e2ee_devices",
        "e2ee_account_identities",
        "e2ee_room_epochs",
        "e2ee_identity_keys",
        "e2ee_signed_pre_keys",
        "e2ee_one_time_pre_keys",
    ] {
        assert!(cleaned.contains(&table), "缺少清理表 {table}: {result}");
    }

    for table in [
        "e2ee_control_receipts",
        "e2ee_control_messages",
        "e2ee_key_packages",
        "e2ee_devices",
        "e2ee_account_identities",
        "e2ee_room_epochs",
        "e2ee_identity_keys",
        "e2ee_signed_pre_keys",
        "e2ee_one_time_pre_keys",
        "messages",
        "message_parts",
        "rooms",
        "room_members",
        "users",
    ] {
        let count: i64 = sqlx::query_scalar(format!("SELECT COUNT(*) FROM {table}").as_str())
            .fetch_one(&app.pool)
            .await
            .expect("count cleaned table");
        assert_eq!(count, 0, "{table} 清理后应无残留");
    }

    // 门禁单行表属于部署配置，清理用户数据后保留。
    let gate_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM e2ee_runtime_gate")
        .fetch_one(&app.pool)
        .await
        .expect("count gate rows");
    assert_eq!(gate_count, 1, "e2ee_runtime_gate 应保留单行配置");
}
