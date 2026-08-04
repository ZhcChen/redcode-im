mod support;

use axum::http::StatusCode;
use chrono::{Duration, Utc};
use redcode_im_api::database::e2ee_mls_store::{E2eeMlsStore, NewKeyPackage, RegisterDeviceInput};
use redcode_im_api::error::AppError;
use serde_json::json;
use support::{body_json, spawn_test_app, unique_username, TestApp};
use uuid::Uuid;

async fn register_user(app: &TestApp, prefix: &str) -> Uuid {
    let username = unique_username(prefix);
    let body = json!({
        "username": username.clone(),
        "password": "pass123456",
        "nickname": username.clone(),
    })
    .to_string();
    let (status, _response) = app.post_json("/auth/register", &body).await;
    assert_eq!(status, StatusCode::OK);
    let login = json!({
        "username": username,
        "password": "pass123456",
    })
    .to_string();
    let (status, response) = app.post_json("/auth/login", &login).await;
    assert_eq!(status, StatusCode::OK);
    Uuid::parse_str(
        body_json(&response)["user"]["id"]
            .as_str()
            .expect("registered user id"),
    )
    .expect("registered user UUID")
}

fn device_input(device_id: Uuid, label: &str, marker: u8) -> RegisterDeviceInput {
    RegisterDeviceInput {
        device_id,
        device_label: label.to_string(),
        root_public_key: vec![11; 32],
        root_fingerprint: vec![12; 32],
        credential: vec![marker; 128],
        credential_fingerprint: vec![marker; 32],
        approval_public_key: vec![marker; 32],
        protocol_version: 1,
    }
}

#[tokio::test]
async fn device_trust_and_key_package_consumption_are_fail_closed() {
    let app = spawn_test_app().await;
    let user_id = register_user(&app, "mls-device").await;
    let store = E2eeMlsStore::new(&app.pool);
    let first_id = Uuid::new_v4();
    let second_id = Uuid::new_v4();
    let third_id = Uuid::new_v4();

    let first = store
        .register_device(user_id, device_input(first_id, "first", 21))
        .await
        .expect("register first device");
    assert_eq!(first.status, "active");
    assert!(first.approved_at.is_some());

    let second = store
        .register_device(user_id, device_input(second_id, "second", 22))
        .await
        .expect("register second device");
    assert_eq!(second.status, "pending_approval");
    let package = NewKeyPackage {
        id: Uuid::new_v4(),
        package_ref: vec![31; 32],
        key_package: vec![32; 256],
        protocol_version: 1,
        expires_at: Utc::now() + Duration::hours(1),
    };
    assert!(matches!(
        store
            .publish_key_packages(user_id, second_id, std::slice::from_ref(&package))
            .await,
        Err(AppError::Forbidden(_))
    ));

    let second = store
        .approve_device(user_id, first_id, second_id)
        .await
        .expect("approve second device");
    assert_eq!(second.status, "active");
    assert_eq!(second.approved_by_device_id, Some(first_id));

    store
        .register_device(user_id, device_input(third_id, "third", 23))
        .await
        .expect("register third device");
    store
        .approve_device(user_id, first_id, third_id)
        .await
        .expect("approve third device");
    assert_eq!(
        store
            .publish_key_packages(user_id, second_id, &[package])
            .await
            .expect("publish key package"),
        1
    );

    let first_pool = app.pool.clone();
    let third_pool = app.pool.clone();
    let first_claim = async move {
        E2eeMlsStore::new(&first_pool)
            .take_key_package(user_id, second_id, first_id)
            .await
            .expect("first consumer claim")
    };
    let third_claim = async move {
        E2eeMlsStore::new(&third_pool)
            .take_key_package(user_id, second_id, third_id)
            .await
            .expect("third consumer claim")
    };
    let (first_claim, third_claim) = tokio::join!(first_claim, third_claim);
    assert_eq!(first_claim.is_some() as u8 + third_claim.is_some() as u8, 1);
    assert!(store
        .take_key_package(user_id, second_id, first_id)
        .await
        .expect("repeat claim")
        .is_none());

    let revoked = store
        .revoke_device(user_id, second_id)
        .await
        .expect("revoke second device");
    assert_eq!(revoked.status, "revoked");
    assert!(revoked.revoked_at.is_some());
    let blocked_package = NewKeyPackage {
        id: Uuid::new_v4(),
        package_ref: vec![41; 32],
        key_package: vec![42; 256],
        protocol_version: 1,
        expires_at: Utc::now() + Duration::hours(1),
    };
    assert!(matches!(
        store
            .publish_key_packages(user_id, second_id, &[blocked_package])
            .await,
        Err(AppError::Forbidden(_))
    ));

    let mut mismatched_root = device_input(Uuid::new_v4(), "forged-root", 24);
    mismatched_root.root_public_key = vec![99; 32];
    assert!(matches!(
        store.register_device(user_id, mismatched_root).await,
        Err(AppError::MessageRuntimeConflict(_))
    ));

    let mut mismatched_device = device_input(first_id, "first", 21);
    mismatched_device.credential = vec![88; 128];
    assert!(matches!(
        store.register_device(user_id, mismatched_device).await,
        Err(AppError::MessageRuntimeConflict(_))
    ));
}
