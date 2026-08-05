mod support;

use axum::body::Body;
use axum::http::StatusCode;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use chrono::{Duration, Utc};
use ed25519_dalek::{Signer, SigningKey};
use redcode_im_api::handlers::e2ee::device_approval_payload;
use serde_json::{json, Value};
use support::{body_json, spawn_test_app, unique_username, TestApp};
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

fn device_request(device_id: Uuid, label: &str, marker: u8, key: &SigningKey) -> Value {
    json!({
        "device_id": device_id,
        "device_label": label,
        "root_public_key": BASE64_STANDARD.encode([11; 32]),
        "root_fingerprint": BASE64_STANDARD.encode([12; 32]),
        "credential": BASE64_STANDARD.encode(vec![marker; 128]),
        "credential_fingerprint": BASE64_STANDARD.encode([marker; 32]),
        "approval_public_key": BASE64_STANDARD.encode(key.verifying_key().to_bytes()),
        "protocol_version": 1,
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

async fn create_room(app: &TestApp, owner: &TestUser, member: &TestUser) -> Uuid {
    create_room_with_members(app, owner, &[member]).await
}

async fn create_room_with_members(
    app: &TestApp,
    owner: &TestUser,
    members: &[&TestUser],
) -> Uuid {
    let (status, response) = app
        .post_json_authed(
            "/rooms",
            &owner.token,
            &json!({
                "name": "MLS API integration",
                "description": "test",
                "room_type": "group",
                "member_ids": members.iter().map(|member| member.id).collect::<Vec<_>>(),
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

fn control_message_body(
    id: Uuid,
    epoch: i64,
    membership_revision: i64,
    sender_device_id: Uuid,
    content_type: &str,
    payload: &[u8],
) -> String {
    let mut envelope = b"RCML".to_vec();
    envelope.extend_from_slice(&1u16.to_be_bytes());
    envelope.push(if content_type == "welcome" { 3 } else { 2 });
    envelope.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    envelope.extend_from_slice(payload);
    json!({
        "id": id,
        "epoch": epoch,
        "membership_revision": membership_revision,
        "sender_device_id": sender_device_id,
        "recipient_device_id": null,
        "content_type": content_type,
        "envelope": BASE64_STANDARD.encode(envelope),
        "idempotency_key": Uuid::new_v4(),
    })
    .to_string()
}

fn welcome_message_body(
    id: Uuid,
    epoch: i64,
    membership_revision: i64,
    sender_device_id: Uuid,
    recipient_device_id: Uuid,
    payload: &[u8],
) -> String {
    let mut envelope = b"RCML".to_vec();
    envelope.extend_from_slice(&1u16.to_be_bytes());
    envelope.push(3);
    envelope.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    envelope.extend_from_slice(payload);
    json!({
        "id": id,
        "epoch": epoch,
        "membership_revision": membership_revision,
        "sender_device_id": sender_device_id,
        "recipient_device_id": recipient_device_id,
        "content_type": "welcome",
        "envelope": BASE64_STANDARD.encode(envelope),
        "idempotency_key": Uuid::new_v4(),
    })
    .to_string()
}

#[tokio::test]
async fn mls_device_approval_and_key_package_api_are_fail_closed() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "mls-api-alice").await;
    let bob = register_user(&app, "mls-api-bob").await;
    let identity_uri = format!("/e2ee/mls/identities/{}", bob.id);
    let peer_devices_uri = format!("/e2ee/mls/identities/{}/devices", bob.id);
    // 无好友、无共同房间时身份材料不可枚举。
    let (status, _) = app.get_authed(&identity_uri, &alice.token).await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    let alice_first_id = Uuid::new_v4();
    let alice_second_id = Uuid::new_v4();
    let bob_device_id = Uuid::new_v4();
    let alice_first_key = SigningKey::from_bytes(&[21; 32]);
    let alice_second_key = SigningKey::from_bytes(&[22; 32]);
    let bob_key = SigningKey::from_bytes(&[31; 32]);

    let first = register_device(
        &app,
        &alice,
        &device_request(alice_first_id, "Alice iPhone", 41, &alice_first_key),
    )
    .await;
    assert_eq!(first["status"], "active");
    let second_request = device_request(alice_second_id, "Alice Web", 42, &alice_second_key);
    let second = register_device(&app, &alice, &second_request).await;
    assert_eq!(second["status"], "pending_approval");
    let bob_device = register_device(
        &app,
        &bob,
        &device_request(bob_device_id, "Bob Android", 51, &bob_key),
    )
    .await;
    assert_eq!(bob_device["status"], "active");
    let room_id = create_room(&app, &alice, &bob).await;
    // 同房间成员（即使不是好友）可查询根身份；对端设备列表仍限好友。
    let (status, response) = app.get_authed(&identity_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));
    let (status, _) = app.get_authed(&peer_devices_uri, &alice.token).await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let (first_user, second_user) = if alice.id < bob.id {
        (alice.id, bob.id)
    } else {
        (bob.id, alice.id)
    };
    sqlx::query("INSERT INTO friendships (id, user_a_id, user_b_id) VALUES ($1, $2, $3)")
        .bind(Uuid::new_v4())
        .bind(first_user)
        .bind(second_user)
        .execute(&app.pool)
        .await
        .expect("create friendship");
    let (status, response) = app.get_authed(&identity_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    let identity = body_json(&response);
    assert_eq!(identity["user_id"], bob.id.to_string());
    assert_eq!(
        identity["root_public_key"],
        BASE64_STANDARD.encode([11; 32])
    );
    assert_eq!(
        identity["root_fingerprint"],
        BASE64_STANDARD.encode([12; 32])
    );
    assert_eq!(identity["protocol_version"], 1);

    let (status, response) = app.get_authed(&peer_devices_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    let devices = body_json(&response);
    let devices = devices.as_array().expect("peer device list");
    assert_eq!(devices.len(), 1);
    assert_eq!(devices[0]["id"], bob_device_id.to_string());
    assert_eq!(devices[0]["protocol_version"], 1);
    assert!(devices[0].get("device_label").is_none());
    assert!(devices[0].get("status").is_none());

    let self_identity_uri = format!("/e2ee/mls/identities/{}", alice.id);
    let (status, _) = app.get_authed(&self_identity_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    let self_devices_uri = format!("/e2ee/mls/identities/{}/devices", alice.id);
    let (status, response) = app.get_authed(&self_devices_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    let devices = body_json(&response);
    let devices = devices.as_array().expect("self active device list");
    assert_eq!(devices.len(), 1);
    assert_eq!(devices[0]["id"], alice_first_id.to_string());

    let package_id = Uuid::new_v4();
    let package_ref = [61; 32];
    let package_body = json!({
        "packages": [{
            "id": package_id,
            "package_ref": BASE64_STANDARD.encode(package_ref),
            "key_package": BASE64_STANDARD.encode(vec![62; 256]),
            "protocol_version": 1,
            "expires_at": Utc::now() + Duration::hours(1),
        }]
    });
    let (status, _) = app
        .post_json_authed(
            &format!("/e2ee/mls/devices/{alice_second_id}/key-packages"),
            &alice.token,
            &package_body.to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    let approval_payload =
        device_approval_payload(alice.id, alice_first_id, alice_second_id, 1, &[42; 32]);
    let forged_signature = bob_key.sign(&approval_payload);
    let (status, _) = app
        .post_json_authed(
            &format!("/e2ee/mls/devices/{alice_second_id}/approve"),
            &alice.token,
            &json!({
                "approver_device_id": alice_first_id,
                "signature": BASE64_STANDARD.encode(forged_signature.to_bytes()),
            })
            .to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    let signature = alice_first_key.sign(&approval_payload);
    let (status, response) = app
        .post_json_authed(
            &format!("/e2ee/mls/devices/{alice_second_id}/approve"),
            &alice.token,
            &json!({
                "approver_device_id": alice_first_id,
                "signature": BASE64_STANDARD.encode(signature.to_bytes()),
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
    assert_eq!(body_json(&response)["status"], "active");

    let (status, response) = app
        .post_json_authed(
            &format!("/e2ee/mls/devices/{alice_second_id}/key-packages"),
            &alice.token,
            &package_body.to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert_eq!(body_json(&response)["inserted"], 1);

    let claim_uri = format!("/e2ee/mls/devices/{alice_second_id}/key-packages/claim");
    let (status, _) = app
        .post_json_authed(
            &claim_uri,
            &alice.token,
            &json!({"room_id": room_id, "consumer_device_id": bob_device_id}).to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let (status, response) = app
        .post_json_authed(
            &claim_uri,
            &bob.token,
            &json!({"room_id": room_id, "consumer_device_id": bob_device_id}).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert_eq!(body_json(&response)["id"], package_id.to_string());
    let (status, _) = app
        .post_json_authed(
            &claim_uri,
            &bob.token,
            &json!({"room_id": room_id, "consumer_device_id": bob_device_id}).to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let (status, response) = app
        .send(
            "DELETE",
            &format!("/e2ee/mls/devices/{alice_second_id}"),
            Some(&alice.token),
            Body::empty(),
            false,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert_eq!(body_json(&response)["status"], "revoked");

    let (status, response) = app.get_authed("/e2ee/mls/devices", &alice.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let devices = body_json(&response);
    assert_eq!(devices.as_array().expect("device list").len(), 2);
    assert!(!response
        .windows("approval_public_key".len())
        .any(|window| window == b"approval_public_key"));

    let bob_package_body = json!({
        "packages": [{
            "id": Uuid::new_v4(),
            "package_ref": BASE64_STANDARD.encode([81; 32]),
            "key_package": BASE64_STANDARD.encode(vec![82; 128]),
            "protocol_version": 1,
            "expires_at": Utc::now() + Duration::hours(1),
        }]
    })
    .to_string();
    let bob_publish_uri = format!("/e2ee/mls/devices/{bob_device_id}/key-packages");
    for attempt in 1..=60 {
        let (status, response) = app
            .post_json_authed(&bob_publish_uri, &bob.token, &bob_package_body)
            .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "publish attempt {attempt}: {}",
            String::from_utf8_lossy(&response)
        );
    }
    let (status, _) = app
        .post_json_authed(&bob_publish_uri, &bob.token, &bob_package_body)
        .await;
    assert_eq!(status, StatusCode::TOO_MANY_REQUESTS);

    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(alice.id)
        .execute(&app.pool)
        .await
        .expect("delete Alice account");
    let bob_device_survives: bool = sqlx::query_scalar(
        "SELECT EXISTS (SELECT 1 FROM e2ee_devices WHERE id = $1 AND user_id = $2)",
    )
    .bind(bob_device_id)
    .bind(bob.id)
    .fetch_one(&app.pool)
    .await
    .expect("query Bob device");
    assert!(bob_device_survives);
}

#[tokio::test]
async fn device_approval_marks_active_rooms_rekey_required_and_is_idempotent() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "mls-approve-rekey-alice").await;
    let bob = register_user(&app, "mls-approve-rekey-bob").await;
    let room_id = create_room(&app, &alice, &bob).await;
    let alice_first_id = Uuid::new_v4();
    let alice_second_id = Uuid::new_v4();
    let bob_device_id = Uuid::new_v4();
    let alice_first_key = SigningKey::from_bytes(&[101; 32]);
    let alice_second_key = SigningKey::from_bytes(&[102; 32]);
    let bob_key = SigningKey::from_bytes(&[103; 32]);

    register_device(
        &app,
        &alice,
        &device_request(alice_first_id, "Alice primary", 101, &alice_first_key),
    )
    .await;
    register_device(
        &app,
        &bob,
        &device_request(bob_device_id, "Bob primary", 103, &bob_key),
    )
    .await;

    let epoch_uri = format!("/rooms/{room_id}/e2ee/epoch");
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    let revision = body_json(&response)["membership_revision"]
        .as_i64()
        .expect("membership revision");
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &control_message_body(
                Uuid::new_v4(),
                1,
                revision,
                alice_first_id,
                "commit",
                b"initial-commit",
            ),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );

    let second = register_device(
        &app,
        &alice,
        &device_request(alice_second_id, "Alice secondary", 102, &alice_second_key),
    )
    .await;
    assert_eq!(second["status"], "pending_approval");
    let approval_payload =
        device_approval_payload(alice.id, alice_first_id, alice_second_id, 1, &[102; 32]);
    let approval_body = json!({
        "approver_device_id": alice_first_id,
        "signature": BASE64_STANDARD.encode(alice_first_key.sign(&approval_payload).to_bytes()),
    })
    .to_string();
    let approve_uri = format!("/e2ee/mls/devices/{alice_second_id}/approve");
    for _ in 0..2 {
        let (status, response) = app
            .post_json_authed(&approve_uri, &alice.token, &approval_body)
            .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&response)
        );
        assert_eq!(body_json(&response)["status"], "active");
    }

    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    let epoch = body_json(&response);
    assert_eq!(epoch["membership_revision"], revision);
    assert_eq!(epoch["active_epoch"], 1);
    assert_eq!(epoch["status"], "rekey_required");
}

#[tokio::test]
async fn device_revocation_marks_rooms_rekey_required_and_is_idempotent() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "mls-rekey-alice").await;
    let bob = register_user(&app, "mls-rekey-bob").await;
    let room_id = create_room(&app, &alice, &bob).await;
    let alice_first_id = Uuid::new_v4();
    let alice_second_id = Uuid::new_v4();
    let bob_device_id = Uuid::new_v4();
    let alice_first_key = SigningKey::from_bytes(&[121; 32]);
    let alice_second_key = SigningKey::from_bytes(&[122; 32]);
    let bob_key = SigningKey::from_bytes(&[131; 32]);

    let first = register_device(
        &app,
        &alice,
        &device_request(alice_first_id, "Alice iPhone", 141, &alice_first_key),
    )
    .await;
    assert_eq!(first["status"], "active");
    let second = register_device(
        &app,
        &alice,
        &device_request(alice_second_id, "Alice Web", 142, &alice_second_key),
    )
    .await;
    assert_eq!(second["status"], "pending_approval");
    register_device(
        &app,
        &bob,
        &device_request(bob_device_id, "Bob Android", 151, &bob_key),
    )
    .await;

    // 批准第二设备，重复批准幂等。
    let approval_payload =
        device_approval_payload(alice.id, alice_first_id, alice_second_id, 1, &[142; 32]);
    let signature = alice_first_key.sign(&approval_payload);
    let approve_uri = format!("/e2ee/mls/devices/{alice_second_id}/approve");
    let approve_body = json!({
        "approver_device_id": alice_first_id,
        "signature": BASE64_STANDARD.encode(signature.to_bytes()),
    })
    .to_string();
    for _ in 0..2 {
        let (status, response) = app
            .post_json_authed(&approve_uri, &alice.token, &approve_body)
            .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&response)
        );
        assert_eq!(body_json(&response)["status"], "active");
    }

    // 房间激活：A1 提交首个 commit（epoch 1），revision 以服务端为准。
    let epoch_uri = format!("/rooms/{room_id}/e2ee/epoch");
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    let initial_revision = body_json(&response)["membership_revision"]
        .as_i64()
        .expect("membership revision");
    let initial_commit_id = Uuid::new_v4();
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &control_message_body(
                initial_commit_id,
                1,
                initial_revision,
                alice_first_id,
                "commit",
                b"initial-commit",
            ),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let (status, response) = app.get_authed(&epoch_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["active_epoch"], 1);
    assert_eq!(body_json(&response)["status"], "active");

    // 撤销 A2 后房间进入 rekey_required，active epoch 保持不变。
    let revoke_uri = format!("/e2ee/mls/devices/{alice_second_id}");
    for _ in 0..2 {
        let (status, response) = app
            .send(
                "DELETE",
                &revoke_uri,
                Some(&alice.token),
                Body::empty(),
                false,
            )
            .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&response)
        );
        assert_eq!(body_json(&response)["status"], "revoked");
    }
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    let epoch = body_json(&response);
    assert_eq!(epoch["active_epoch"], 1);
    assert_eq!(epoch["status"], "rekey_required");

    // 已撤销设备不能拉取或提交控制消息。
    let (status, _) = app
        .get_authed(
            &format!(
                "/rooms/{room_id}/e2ee/control-messages?device_id={alice_second_id}&after_sequence=0&limit=50"
            ),
            &alice.token,
        )
        .await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    let (status, _) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &control_message_body(
                Uuid::new_v4(),
                2,
                initial_revision,
                alice_second_id,
                "commit",
                b"forbidden-commit",
            ),
        )
        .await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    // 可信设备提交 rekey commit（epoch 2）后房间恢复 active。
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &control_message_body(
                Uuid::new_v4(),
                2,
                initial_revision,
                alice_first_id,
                "commit",
                b"rekey-commit",
            ),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    let epoch = body_json(&response);
    assert_eq!(epoch["active_epoch"], 2);
    assert_eq!(epoch["status"], "active");

    // 待批准设备撤销返回明确冲突，而不是静默进入 revoked。
    let pending_id = Uuid::new_v4();
    register_device(
        &app,
        &alice,
        &device_request(pending_id, "Alice Pending", 143, &alice_second_key),
    )
    .await;
    let (status, _) = app
        .send(
            "DELETE",
            &format!("/e2ee/mls/devices/{pending_id}"),
            Some(&alice.token),
            Body::empty(),
            false,
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
}

#[tokio::test]
async fn group_chat_member_changes_advance_revision_and_gate_epochs() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "mls-group-alice").await;
    let bob = register_user(&app, "mls-group-bob").await;
    let carol = register_user(&app, "mls-group-carol").await;
    let dave = register_user(&app, "mls-group-dave").await;
    let alice_device = Uuid::new_v4();
    let bob_device = Uuid::new_v4();
    let carol_device = Uuid::new_v4();
    let dave_device = Uuid::new_v4();
    let alice_key = SigningKey::from_bytes(&[201; 32]);
    let bob_key = SigningKey::from_bytes(&[202; 32]);
    let carol_key = SigningKey::from_bytes(&[203; 32]);
    let dave_key = SigningKey::from_bytes(&[204; 32]);
    register_device(
        &app,
        &alice,
        &device_request(alice_device, "Alice Group", 241, &alice_key),
    )
    .await;
    register_device(
        &app,
        &bob,
        &device_request(bob_device, "Bob Group", 242, &bob_key),
    )
    .await;
    register_device(
        &app,
        &carol,
        &device_request(carol_device, "Carol Group", 243, &carol_key),
    )
    .await;
    register_device(
        &app,
        &dave,
        &device_request(dave_device, "Dave Group", 244, &dave_key),
    )
    .await;

    let room_id = create_room_with_members(&app, &alice, &[&bob, &carol]).await;
    let epoch_uri = format!("/rooms/{room_id}/e2ee/epoch");
    let members_uri = format!("/rooms/{room_id}/e2ee/members");

    // 仅房间成员可查看成员设备集合；非成员统一 403。
    let (status, response) = app.get_authed(&members_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));
    let members = body_json(&response);
    assert_eq!(members.as_array().expect("member list").len(), 3);
    for entry in members.as_array().expect("member list") {
        assert_eq!(
            entry["devices"].as_array().expect("devices").len(),
            1,
            "每个成员应返回一个 active 设备"
        );
    }
    let (status, _) = app.get_authed(&members_uri, &dave.token).await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    // 同房间成员（即使不是好友）可查询根身份做信任校验；非成员不可枚举。
    let alice_identity_uri = format!("/e2ee/mls/identities/{}", alice.id);
    let (status, _) = app
        .get_authed(&alice_identity_uri, &bob.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    let (status, _) = app
        .get_authed(&alice_identity_uri, &dave.token)
        .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    // A1 提交初始 commit 后房间 active。
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    let initial_revision = body_json(&response)["membership_revision"]
        .as_i64()
        .expect("initial membership revision");
    assert!(initial_revision >= 1, "初始 revision 应大于 0");
    let (status, _) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &control_message_body(
                Uuid::new_v4(),
                1,
                initial_revision,
                alice_device,
                "commit",
                b"group-initial-commit",
            ),
        )
        .await;
    assert_eq!(status, StatusCode::OK);
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    assert_eq!(body_json(&response)["active_epoch"], 1);
    assert_eq!(body_json(&response)["status"], "active");

    // 邀请 D 后 revision 推进并进入 rekey_required。
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/members"),
            &alice.token,
            &json!({ "user_ids": [dave.id] }).to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    let epoch = body_json(&response);
    let invited_revision = epoch["membership_revision"].as_i64().expect("revision");
    assert_eq!(invited_revision, initial_revision + 1);
    assert_eq!(epoch["active_epoch"], 1);
    assert_eq!(epoch["status"], "rekey_required");

    // 旧 revision 的 Commit 必须冲突；新 revision 的 Commit 原子推进 epoch。
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &control_message_body(
                Uuid::new_v4(),
                2,
                initial_revision,
                alice_device,
                "commit",
                b"stale-revision-commit",
            ),
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &control_message_body(
                Uuid::new_v4(),
                2,
                invited_revision,
                alice_device,
                "commit",
                b"add-dave-commit",
            ),
        )
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));

    // 新成员 Welcome 的 epoch 必须等于已激活的 commit epoch。
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &welcome_message_body(
                Uuid::new_v4(),
                2,
                invited_revision,
                alice_device,
                dave_device,
                b"dave-welcome",
            ),
        )
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    assert_eq!(body_json(&response)["active_epoch"], 2);
    assert_eq!(body_json(&response)["status"], "active");

    // D 加入后可拉取自己的控制消息（commit + welcome 的 receipt）。
    let (status, response) = app
        .get_authed(
            &format!(
                "/rooms/{room_id}/e2ee/control-messages?device_id={dave_device}&after_sequence=0&limit=50"
            ),
            &dave.token,
        )
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));
    let controls = body_json(&response);
    assert_eq!(controls.as_array().expect("controls").len(), 2);

    // D 加入后成员设备集合包含四名成员。
    let (_, response) = app.get_authed(&members_uri, &alice.token).await;
    assert_eq!(
        body_json(&response).as_array().expect("member list").len(),
        4
    );

    // C 退出后 revision 再次推进；移除 Commit 后房间恢复 active。
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/leave"),
            &carol.token,
            "{}",
        )
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    let epoch = body_json(&response);
    let removed_revision = epoch["membership_revision"].as_i64().expect("revision");
    assert_eq!(removed_revision, invited_revision + 1);
    assert_eq!(epoch["status"], "rekey_required");
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &alice.token,
            &control_message_body(
                Uuid::new_v4(),
                3,
                removed_revision,
                alice_device,
                "commit",
                b"remove-carol-commit",
            ),
        )
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));
    let (_, response) = app.get_authed(&epoch_uri, &alice.token).await;
    assert_eq!(body_json(&response)["active_epoch"], 3);
    assert_eq!(body_json(&response)["status"], "active");

    // 被移除成员立即失去控制消息与成员设备视图权限。
    let (status, _) = app
        .get_authed(
            &format!(
                "/rooms/{room_id}/e2ee/control-messages?device_id={carol_device}&after_sequence=0&limit=50"
            ),
            &carol.token,
        )
        .await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    let (status, _) = app.get_authed(&members_uri, &carol.token).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
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

#[tokio::test]
async fn key_package_inventory_supports_low_watermark_replenishment() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "mls-inventory-alice").await;
    let bob = register_user(&app, "mls-inventory-bob").await;
    let room_id = create_room(&app, &alice, &bob).await;
    let alice_first_id = Uuid::new_v4();
    let alice_second_id = Uuid::new_v4();
    let bob_device_id = Uuid::new_v4();
    let alice_first_key = SigningKey::from_bytes(&[61; 32]);
    let alice_second_key = SigningKey::from_bytes(&[62; 32]);
    let bob_key = SigningKey::from_bytes(&[71; 32]);

    register_device(
        &app,
        &alice,
        &device_request(alice_first_id, "Alice main", 41, &alice_first_key),
    )
    .await;
    register_device(
        &app,
        &alice,
        &device_request(alice_second_id, "Alice web", 42, &alice_second_key),
    )
    .await;
    register_device(
        &app,
        &bob,
        &device_request(bob_device_id, "Bob android", 51, &bob_key),
    )
    .await;

    // 批准 alice 第二台设备，使其可发布 KeyPackage
    let approval_payload =
        device_approval_payload(alice.id, alice_first_id, alice_second_id, 1, &[42; 32]);
    let signature = alice_first_key.sign(&approval_payload);
    let (status, _) = app
        .post_json_authed(
            &format!("/e2ee/mls/devices/{alice_second_id}/approve"),
            &alice.token,
            &json!({
                "approver_device_id": alice_first_id,
                "signature": BASE64_STANDARD.encode(signature.to_bytes()),
            })
            .to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::OK);

    let inventory_uri = format!("/e2ee/mls/devices/{alice_second_id}/key-packages");

    // 未发布时库存为零；未批准/他人设备查询被拒绝
    let (status, response) = app.get_authed(&inventory_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["available"], 0);
    assert_eq!(body_json(&response)["max_available"], 500);

    // 发布 3 个 KeyPackage 后库存可见
    let publish_uri = format!("/e2ee/mls/devices/{alice_second_id}/key-packages");
    let package_ids = [Uuid::new_v4(), Uuid::new_v4(), Uuid::new_v4()];
    let (status, response) = app
        .post_json_authed(
            &publish_uri,
            &alice.token,
            &package_body(&package_ids.iter().map(|id| (*id, vec![62; 256])).collect::<Vec<_>>()),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert_eq!(body_json(&response)["inserted"], 3);

    let (status, response) = app.get_authed(&inventory_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["available"], 3);

    // Bob 不能查询 Alice 设备的库存
    let (status, _) = app.get_authed(&inventory_uri, &bob.token).await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    // 领取一枚后库存减一；重复领取返回 404
    let claim_uri = format!("/e2ee/mls/devices/{alice_second_id}/key-packages/claim");
    let (status, response) = app
        .post_json_authed(
            &claim_uri,
            &bob.token,
            &json!({"room_id": room_id, "consumer_device_id": bob_device_id}).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let claimed_id = body_json(&response)["id"].as_str().unwrap().to_string();
    assert!(package_ids.iter().any(|id| id.to_string() == claimed_id));
    let (status, response) = app.get_authed(&inventory_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["available"], 2);
}

#[tokio::test]
async fn concurrent_claims_consume_each_key_package_once() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "mls-concurrent-alice").await;
    let bob = register_user(&app, "mls-concurrent-bob").await;
    let room_id = create_room(&app, &alice, &bob).await;
    let alice_first_id = Uuid::new_v4();
    let alice_second_id = Uuid::new_v4();
    let bob_device_id = Uuid::new_v4();
    let alice_first_key = SigningKey::from_bytes(&[81; 32]);
    let alice_second_key = SigningKey::from_bytes(&[82; 32]);
    let bob_key = SigningKey::from_bytes(&[91; 32]);

    register_device(
        &app,
        &alice,
        &device_request(alice_first_id, "Alice main", 41, &alice_first_key),
    )
    .await;
    register_device(
        &app,
        &alice,
        &device_request(alice_second_id, "Alice web", 42, &alice_second_key),
    )
    .await;
    register_device(
        &app,
        &bob,
        &device_request(bob_device_id, "Bob android", 51, &bob_key),
    )
    .await;

    let approval_payload =
        device_approval_payload(alice.id, alice_first_id, alice_second_id, 1, &[42; 32]);
    let signature = alice_first_key.sign(&approval_payload);
    let (status, _) = app
        .post_json_authed(
            &format!("/e2ee/mls/devices/{alice_second_id}/approve"),
            &alice.token,
            &json!({
                "approver_device_id": alice_first_id,
                "signature": BASE64_STANDARD.encode(signature.to_bytes()),
            })
            .to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::OK);

    // Bob 发布两个 KeyPackage，Alice 两台设备并发领取，各自只能消费一枚
    let package_ids = [Uuid::new_v4(), Uuid::new_v4()];
    let (status, response) = app
        .post_json_authed(
            &format!("/e2ee/mls/devices/{bob_device_id}/key-packages"),
            &bob.token,
            &package_body(&package_ids.iter().map(|id| (*id, vec![72; 256])).collect::<Vec<_>>()),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert_eq!(body_json(&response)["inserted"], 2);

    let claim_uri = format!("/e2ee/mls/devices/{bob_device_id}/key-packages/claim");
    let first_body = json!({"room_id": room_id, "consumer_device_id": alice_first_id}).to_string();
    let second_body = json!({"room_id": room_id, "consumer_device_id": alice_second_id}).to_string();
    let first_claim = app.post_json_authed(
        &claim_uri,
        &alice.token,
        &first_body,
    );
    let second_claim = app.post_json_authed(
        &claim_uri,
        &alice.token,
        &second_body,
    );
    let ((first_status, first_response), (second_status, second_response)) =
        tokio::join!(first_claim, second_claim);
    assert_eq!(first_status, StatusCode::OK);
    assert_eq!(second_status, StatusCode::OK);
    let first_body = body_json(&first_response);
    let second_body = body_json(&second_response);
    let first_claimed = first_body["id"].as_str().unwrap();
    let second_claimed = second_body["id"].as_str().unwrap();
    assert_ne!(first_claimed, second_claimed);

    // 第三台并发领取者拿不到任何 KeyPackage
    let (status, _) = app
        .post_json_authed(
            &claim_uri,
            &alice.token,
            &json!({"room_id": room_id, "consumer_device_id": alice_first_id}).to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let (status, response) = app
        .get_authed(&format!("/e2ee/mls/devices/{bob_device_id}/key-packages"), &bob.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["available"], 0);
}

#[tokio::test]
async fn concurrent_replenishment_respects_per_device_cap() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "mls-cap-alice").await;
    let alice_device_id = Uuid::new_v4();
    let alice_key = SigningKey::from_bytes(&[101; 32]);
    register_device(
        &app,
        &alice,
        &device_request(alice_device_id, "Alice main", 41, &alice_key),
    )
    .await;

    // 两批并发补充各 100 个，服务端必须都接受且不重复计数
    let publish_uri = format!("/e2ee/mls/devices/{alice_device_id}/key-packages");
    let first_body = package_body(
        &(0..100)
            .map(|index| (Uuid::new_v4(), vec![110 + (index % 10) as u8; 256]))
            .collect::<Vec<_>>(),
    );
    let second_body = package_body(
        &(0..100)
            .map(|index| (Uuid::new_v4(), vec![120 + (index % 10) as u8; 256]))
            .collect::<Vec<_>>(),
    );
    let (first_status, first_response) = app
        .post_json_authed(&publish_uri, &alice.token, &first_body)
        .await;
    let (second_status, second_response) = app
        .post_json_authed(&publish_uri, &alice.token, &second_body)
        .await;
    assert_eq!(first_status, StatusCode::OK);
    assert_eq!(second_status, StatusCode::OK);
    assert_eq!(body_json(&first_response)["inserted"], 100);
    assert_eq!(body_json(&second_response)["inserted"], 100);

    let (status, response) = app
        .get_authed(&publish_uri, &alice.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["available"], 200);

    // 补充到每设备上限 500 后，继续发布必须被服务端拒绝
    for _ in 0..3 {
        let body = package_body(
            &(0..100)
                .map(|index| (Uuid::new_v4(), vec![130 + (index % 10) as u8; 256]))
                .collect::<Vec<_>>(),
        );
        let (status, response) = app
            .post_json_authed(&publish_uri, &alice.token, &body)
            .await;
        assert_eq!(
            status,
            StatusCode::OK,
            "{}",
            String::from_utf8_lossy(&response)
        );
    }
    let over_limit_body = package_body(
        &(0..100)
            .map(|index| (Uuid::new_v4(), vec![140 + (index % 10) as u8; 256]))
            .collect::<Vec<_>>(),
    );
    let (status, _) = app
        .post_json_authed(&publish_uri, &alice.token, &over_limit_body)
        .await;
    assert_eq!(status, StatusCode::TOO_MANY_REQUESTS);

    let (status, response) = app.get_authed(&publish_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["available"], 500);
}
