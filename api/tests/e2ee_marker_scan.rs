mod support;

use axum::http::StatusCode;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use chrono::{Duration, Utc};
use ed25519_dalek::SigningKey;
use futures_util::StreamExt;
use redis::AsyncCommands;
use serde_json::{json, Value};
use support::{body_json, bootstrap_admin_token, spawn_test_app, unique_username, TestApp};
use uuid::Uuid;

const ENCRYPTED_PLACEHOLDER: &str = "[加密消息]";
const TEST_APNS_PRIVATE_KEY: &str = r#"-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg1gsW8p7m26JzSzqh
Xj7a8qzlgQr96B0XOgTxmPLQZ3mhRANCAASLhkavy/UiriTIjBnLK1B0ngJttikw
mN/fOb81W2J8TNvVe4bOgzZAGGWjZYIv/IdHh3Fya9fOEo7CRaKSZs0N
-----END PRIVATE KEY-----"#;

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
                "name": "Marker scan integration",
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

fn device_request(device_id: Uuid, label: &str, marker: u8, key: &SigningKey, platform: &str) -> Value {
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
        "client_version": "0.1.0",
        "client_build": "marker-scan-test",
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

/// 模拟独立安全审查已批准（U7 门禁语义：审查通过前生产 E2EE 保持 No-Go）。
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

/// 启用 APNs Push 配置，使消息发送后真正进入 push_job_queue（R14 扫描对象）。
async fn enable_apns_push(app: &TestApp, admin_token: &str) {
    let payload = json!({
        "enabled": true,
        "team_id": "TEAMID1234",
        "key_id": "KEYID1234",
        "bundle_id": "com.redcode.im.iosapp",
        "environment": "sandbox",
        "private_key_p8": TEST_APNS_PRIVATE_KEY
    })
    .to_string();
    let (status, body) = app
        .put_json_authed(
            "/api/admin/settings/push/providers/apns",
            admin_token,
            &payload,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "启用 APNs Push: {}",
        String::from_utf8_lossy(&body)
    );
}

fn envelope_bytes(payload: &[u8], kind: u8) -> Vec<u8> {
    let mut bytes = b"RCML".to_vec();
    bytes.extend_from_slice(&1_u16.to_be_bytes());
    bytes.push(kind);
    bytes.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    bytes.extend_from_slice(payload);
    bytes
}

async fn submit_commit(
    app: &TestApp,
    user: &TestUser,
    room_id: Uuid,
    device_id: Uuid,
    epoch: i64,
    revision: i64,
) -> Uuid {
    let control_id = Uuid::new_v4();
    let body = json!({
        "id": control_id,
        "epoch": epoch,
        "membership_revision": revision,
        "sender_device_id": device_id,
        "recipient_device_id": null,
        "content_type": "commit",
        "envelope": BASE64_STANDARD.encode(envelope_bytes(&[0x44; 48], 2)),
        "idempotency_key": Uuid::new_v4(),
    });
    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/e2ee/control-messages"),
            &user.token,
            &body.to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    control_id
}

async fn redis_url() -> String {
    std::env::var("REDIS_CACHE_URL")
        .or_else(|_| std::env::var("REDIS_SESSION_URL"))
        .expect("REDIS_CACHE_URL or REDIS_SESSION_URL should be set")
}

fn contains_marker(data: &[u8], marker: &str) -> bool {
    data.windows(marker.len()).any(|window| window == marker.as_bytes())
}

const SENSITIVE_FIELD_NAMES: &[&str] = &[
    "\"dek\"",
    "\"nonce\"",
    "\"rcst\"",
    "\"private_key\"",
    "\"root_private\"",
    "\"credential\"",
];

fn contains_sensitive_field_names(data: &str) -> Option<String> {
    SENSITIVE_FIELD_NAMES
        .iter()
        .find(|name| data.contains(**name))
        .map(|name| name.to_string())
}

/// R14 全链 marker 扫描：注册设备 → 门禁 active → 发送 E2EE 密文并触发
/// Redis 广播与 Push 队列 → 断言 DB/Redis/Push 无明文 marker、无密钥材料。
#[tokio::test]
async fn e2ee_chain_has_no_plaintext_marker_or_secret_material() {
    let app = spawn_test_app().await;
    let admin_token = bootstrap_admin_token(&app).await;
    let alice = register_user(&app, "marker-alice").await;
    let bob = register_user(&app, "marker-bob").await;
    let room_id = create_room(&app, &alice, &bob).await;

    // 两台达标 active 设备 + 库存满足低水位 + 安全审查通过 → gate active。
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
        ),
    )
    .await;
    publish_inventory(&app, &alice, alice_device, 12).await;
    publish_inventory(&app, &bob, bob_device, 12).await;
    approve_security_review(&app).await;
    gate_uri(&app, &admin_token, "prepare").await;
    let active = gate_uri(&app, &admin_token, "active").await;
    assert_eq!(active["state"], "active");
    assert_eq!(active["content_audit_mode"], "e2ee");
    enable_apns_push(&app, &admin_token).await;

    // 建立房间 epoch 与 commit，供 application 密文消息引用。
    let (status, response) = app
        .get_authed(&format!("/rooms/{room_id}/e2ee/epoch"), &alice.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    let epoch_info = body_json(&response);
    let revision = epoch_info["membership_revision"]
        .as_i64()
        .expect("membership revision");
    let commit_id = submit_commit(&app, &alice, room_id, alice_device, 1, revision).await;

    // 明文 marker 只存在于“加密前内容”语义中；密文 payload 用非 ASCII 固定字节，
    // 任何链路若把明文写入 content/日志/Push/Redis 都会命中 marker 扫描。
    let marker = format!("U7-PLAIN-MARKER-{}", Uuid::new_v4());
    let cipher_payload = vec![0xA5; 48];
    let encrypted_body = json!({
        "encrypted_content": BASE64_STANDARD.encode(envelope_bytes(&cipher_payload, 1)),
        "encryption_metadata": {
            "protocol": "mls",
            "version": 1,
            "epoch": 1,
            "sender_device_id": alice_device,
            "content_type": "application",
            "control_message_id": commit_id,
        },
        "idempotency_key": Uuid::new_v4(),
    })
    .to_string();

    // 先订阅房间 Redis Pub/Sub，发送后抓取广播 payload 做扫描。
    let fallback_url = redis_url().await;
    let pubsub_url = std::env::var("REDIS_PUBSUB_URL").unwrap_or(fallback_url);
    let pubsub_client = redis::Client::open(pubsub_url).expect("open redis pubsub client");
    let mut pubsub = pubsub_client
        .get_async_pubsub()
        .await
        .expect("connect redis pubsub");
    let channel = format!("room:{room_id}");
    pubsub.subscribe(&channel).await.expect("subscribe room channel");

    let (status, response) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages/encrypted"),
            &alice.token,
            &encrypted_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "e2ee 模式应接受加密消息: {}",
        String::from_utf8_lossy(&response)
    );
    let sent = body_json(&response);
    assert_eq!(sent["message"]["content"].as_str(), Some(ENCRYPTED_PLACEHOLDER));
    let message_id = Uuid::parse_str(sent["message"]["id"].as_str().expect("message id"))
        .expect("message UUID");

    // Redis 广播（protobuf wire bytes）不得含明文 marker。
    let mut broadcasts = pubsub.on_message();
    let broadcast = loop {
        let message = broadcasts
            .next()
            .await
            .expect("pubsub broadcast message");
        let payload: String = message.get_payload().unwrap_or_default();
        if !matches!(payload.as_str(), "subscribe" | "psubscribe" | "unsubscribe") {
            break message;
        }
    };
    let broadcast_bytes: Vec<u8> = broadcast.get_payload().expect("broadcast payload");
    assert!(
        !contains_marker(&broadcast_bytes, &marker),
        "Redis 广播不得包含明文 marker"
    );

    // 数据库 messages：正文占位符、密文为 RCML envelope、元数据白名单字段且无 marker。
    let persisted: (String, Vec<u8>, String) = sqlx::query_as(
        "SELECT content, encrypted_content, encryption_metadata::text FROM messages WHERE id = $1",
    )
    .bind(message_id)
    .fetch_one(&app.pool)
    .await
    .expect("load persisted encrypted message");
    assert_eq!(persisted.0, ENCRYPTED_PLACEHOLDER);
    assert!(
        !persisted.2.contains(&marker),
        "encryption_metadata 不得包含明文 marker"
    );
    assert!(
        !persisted.2.contains("encrypted_content"),
        "encryption_metadata 不得包含密文正文"
    );
    if let Some(field) = contains_sensitive_field_names(&persisted.2) {
        panic!("encryption_metadata 出现敏感字段 {field}");
    }
    let metadata: Value = serde_json::from_str(&persisted.2).expect("metadata JSON");
    let allowed_keys = [
        "protocol",
        "version",
        "epoch",
        "sender_device_id",
        "content_type",
        "control_message_id",
    ];
    let metadata_keys = metadata
        .as_object()
        .expect("metadata object")
        .keys()
        .cloned()
        .collect::<Vec<_>>();
    assert!(
        metadata_keys.iter().all(|key| allowed_keys.contains(&key.as_str())),
        "encryption_metadata 出现非白名单字段: {:?}",
        metadata_keys
    );
    assert_eq!(
        &persisted.1[..4],
        b"RCML",
        "messages 只保存密文 envelope"
    );
    assert_eq!(
        persisted.1,
        envelope_bytes(&cipher_payload, 1),
        "密文 payload 必须与发送内容一致"
    );

    // message_parts：文本 part 只能是指定占位符。
    let part_text: String = sqlx::query_scalar(
        "SELECT text_content FROM message_parts WHERE message_id = $1 ORDER BY position LIMIT 1",
    )
    .bind(message_id)
    .fetch_one(&app.pool)
    .await
    .expect("load message part");
    assert_eq!(part_text, ENCRYPTED_PLACEHOLDER);

    // Push 队列：存在 message job，snapshot 为占位符且无 marker/敏感字段。
    let push_payloads: Vec<(String, String)> = sqlx::query_as(
        "SELECT job_type, payload::text FROM push_job_queue WHERE job_type = 'message' ORDER BY created_at DESC LIMIT 10",
    )
    .fetch_all(&app.pool)
    .await
    .expect("load push jobs");
    let message_job = push_payloads
        .iter()
        .find(|(_, payload)| payload.contains(&message_id.to_string()))
        .unwrap_or_else(|| panic!("Push 队列应有该消息 job: {:?}", push_payloads));
    assert!(
        !message_job.1.contains(&marker),
        "Push payload 不得包含明文 marker"
    );
    if let Some(field) = contains_sensitive_field_names(&message_job.1) {
        panic!("Push payload 出现敏感字段 {field}");
    }
    let snapshot = serde_json::from_str::<Value>(&message_job.1)
        .expect("push payload JSON")["snapshot"]
        .clone();
    assert_eq!(snapshot["content"], "【加密消息】");
    assert_eq!(snapshot["preview"], "你收到一条加密消息");

    // Redis 全部 string 键值扫描：不得出现明文 marker。
    let scan_client = redis::Client::open(redis_url().await).expect("open redis scan client");
    let mut conn = scan_client
        .get_multiplexed_async_connection()
        .await
        .expect("connect redis");
    let keys = {
        let mut iter = conn.scan::<String>().await.expect("start redis scan");
        let mut keys = Vec::new();
        while let Some(key) = iter.next_item().await {
            keys.push(key);
        }
        keys
    };
    assert!(!keys.is_empty(), "Redis 扫描应至少命中一个键");
    let mut scanned = 0usize;
    for key in keys {
        let value: Result<String, _> = conn.get(&key).await;
        if let Ok(value) = value {
            scanned += 1;
            assert!(
                !value.contains(&marker),
                "Redis 键 {key} 的值包含明文 marker"
            );
        }
    }
    assert!(scanned > 0, "Redis 扫描应至少命中一个 string 键");
}
