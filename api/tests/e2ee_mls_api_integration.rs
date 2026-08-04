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
    let (status, response) = app
        .post_json_authed(
            "/rooms",
            &owner.token,
            &json!({
                "name": "MLS API integration",
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

#[tokio::test]
async fn mls_device_approval_and_key_package_api_are_fail_closed() {
    let app = spawn_test_app().await;
    let alice = register_user(&app, "mls-api-alice").await;
    let bob = register_user(&app, "mls-api-bob").await;
    let room_id = create_room(&app, &alice, &bob).await;
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

    let identity_uri = format!("/e2ee/mls/identities/{}", bob.id);
    let (status, _) = app.get_authed(&identity_uri, &alice.token).await;
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

    let self_identity_uri = format!("/e2ee/mls/identities/{}", alice.id);
    let (status, _) = app.get_authed(&self_identity_uri, &alice.token).await;
    assert_eq!(status, StatusCode::OK);

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
