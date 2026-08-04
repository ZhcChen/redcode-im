mod support;

use axum::body::Body;
use axum::http::StatusCode;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use ed25519_dalek::SigningKey;
use serde_json::{json, Value};
use support::{body_json, spawn_test_app, unique_username, TestApp};
use uuid::Uuid;

struct TestUser {
    id: Uuid,
    token: String,
}

async fn register_user(app: &TestApp, prefix: &str) -> TestUser {
    let username = unique_username(prefix);
    let registration = json!({
        "username": username.clone(),
        "password": "pass123456",
        "nickname": username.clone(),
    });
    let (status, response) = app
        .post_json("/auth/register", &registration.to_string())
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let (status, response) = app
        .post_json(
            "/auth/login",
            &json!({"username": username, "password": "pass123456"}).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let body = body_json(&response);
    TestUser {
        id: Uuid::parse_str(body["user"]["id"].as_str().expect("user id")).expect("user UUID"),
        token: body["token"].as_str().expect("token").to_string(),
    }
}

async fn create_room(app: &TestApp, owner: &TestUser, member: &TestUser) -> Uuid {
    let (status, response) = app
        .post_json_authed(
            "/rooms",
            &owner.token,
            &json!({
                "name": "MLS control integration",
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

async fn register_device(app: &TestApp, user: &TestUser, marker: u8) -> Uuid {
    let device_id = Uuid::new_v4();
    let key = SigningKey::from_bytes(&[marker; 32]);
    let request = json!({
        "device_id": device_id,
        "device_label": format!("device-{marker}"),
        "root_public_key": BASE64_STANDARD.encode([marker; 32]),
        "root_fingerprint": BASE64_STANDARD.encode([marker.wrapping_add(1); 32]),
        "credential": BASE64_STANDARD.encode(vec![marker; 128]),
        "credential_fingerprint": BASE64_STANDARD.encode([marker.wrapping_add(2); 32]),
        "approval_public_key": BASE64_STANDARD.encode(key.verifying_key().to_bytes()),
        "protocol_version": 1,
    });
    let (status, response) = app
        .post_json_authed("/e2ee/mls/devices", &user.token, &request.to_string())
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert_eq!(body_json(&response)["status"], "active");
    device_id
}

fn envelope(kind: u8, marker: u8) -> String {
    let payload = vec![marker; 48];
    let mut bytes = b"RCML".to_vec();
    bytes.extend_from_slice(&1_u16.to_be_bytes());
    bytes.push(kind);
    bytes.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    bytes.extend_from_slice(&payload);
    BASE64_STANDARD.encode(bytes)
}

fn control_request(
    id: Uuid,
    idempotency_key: Uuid,
    sender_device_id: Uuid,
    recipient_device_id: Option<Uuid>,
    content_type: &str,
    epoch: i64,
    revision: i64,
    marker: u8,
) -> Value {
    json!({
        "id": id,
        "epoch": epoch,
        "membership_revision": revision,
        "sender_device_id": sender_device_id,
        "recipient_device_id": recipient_device_id,
        "content_type": content_type,
        "envelope": envelope(if content_type == "commit" { 2 } else { 3 }, marker),
        "idempotency_key": idempotency_key,
    })
}

#[tokio::test]
async fn room_revision_and_control_queue_are_ordered_and_device_scoped() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "control-alice").await;
    let bob = register_user(&app, "control-bob").await;
    let room_id = create_room(&app, &alice, &bob).await;
    let alice_device = register_device(&app, &alice, 21).await;
    let bob_device = register_device(&app, &bob, 31).await;
    let epoch_uri = format!("/rooms/{room_id}/e2ee/epoch");

    let (status, response) = app.get_authed(&epoch_uri, &alice.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let initial = body_json(&response);
    assert_eq!(initial["membership_revision"], 2);
    assert_eq!(initial["active_epoch"], 0);
    assert_eq!(initial["status"], "preparing");

    let control_uri = format!("/rooms/{room_id}/e2ee/control-messages");
    let commit_id = Uuid::new_v4();
    let commit_key = Uuid::new_v4();
    let commit = control_request(
        commit_id,
        commit_key,
        alice_device,
        None,
        "commit",
        1,
        2,
        41,
    );
    let (status, response) = app
        .post_json_authed(&control_uri, &alice.token, &commit.to_string())
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let first_sequence = body_json(&response)["sequence_no"]
        .as_i64()
        .expect("commit sequence");

    let (status, response) = app
        .post_json_authed(&control_uri, &alice.token, &commit.to_string())
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert_eq!(body_json(&response)["sequence_no"], first_sequence);

    let mut conflicting = commit.clone();
    conflicting["envelope"] = json!(envelope(2, 99));
    let (status, _) = app
        .post_json_authed(&control_uri, &alice.token, &conflicting.to_string())
        .await;
    assert_eq!(status, StatusCode::CONFLICT);

    let (status, response) = app.get_authed(&epoch_uri, &bob.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let active = body_json(&response);
    assert_eq!(active["active_epoch"], 1);
    assert_eq!(active["status"], "active");

    let bob_queue = format!("{control_uri}?device_id={bob_device}&after_sequence=0&limit=10");
    let (status, response) = app.get_authed(&bob_queue, &bob.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let messages = body_json(&response);
    assert_eq!(messages.as_array().expect("messages").len(), 1);
    assert_eq!(messages[0]["id"], commit_id.to_string());

    let consume_uri = format!("/rooms/{room_id}/e2ee/control-messages/{commit_id}/consume");
    let (status, response) = app
        .post_json_authed(
            &consume_uri,
            &bob.token,
            &json!({"device_id": bob_device}).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );

    let welcome_id = Uuid::new_v4();
    let welcome = control_request(
        welcome_id,
        Uuid::new_v4(),
        alice_device,
        Some(bob_device),
        "welcome",
        1,
        2,
        42,
    );
    let (status, response) = app
        .post_json_authed(&control_uri, &alice.token, &welcome.to_string())
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let welcome_queue =
        format!("{control_uri}?device_id={bob_device}&after_sequence={first_sequence}&limit=10");
    let (status, response) = app.get_authed(&welcome_queue, &bob.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    assert_eq!(body_json(&response)[0]["id"], welcome_id.to_string());

    let stale_commit = control_request(
        Uuid::new_v4(),
        Uuid::new_v4(),
        alice_device,
        None,
        "commit",
        2,
        1,
        43,
    );
    let (status, _) = app
        .post_json_authed(&control_uri, &alice.token, &stale_commit.to_string())
        .await;
    assert_eq!(status, StatusCode::CONFLICT);

    let (status, response) = app
        .send(
            "POST",
            &format!("/rooms/{room_id}/leave"),
            Some(&bob.token),
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

    let (status, response) = app.get_authed(&epoch_uri, &alice.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let rekey = body_json(&response);
    assert_eq!(rekey["membership_revision"], 3);
    assert_eq!(rekey["status"], "rekey_required");

    let (status, _) = app.get_authed(&bob_queue, &bob.token).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    let (status, _) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages/{welcome_id}/consume"),
            &bob.token,
            &json!({"device_id": bob_device}).to_string(),
        )
        .await;
    assert_eq!(status, StatusCode::NOT_FOUND);

    let rekey_commit = control_request(
        Uuid::new_v4(),
        Uuid::new_v4(),
        alice_device,
        None,
        "commit",
        2,
        3,
        44,
    );
    let (status, response) = app
        .post_json_authed(&control_uri, &alice.token, &rekey_commit.to_string())
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
}
