mod support;

use axum::{body::Body, http::StatusCode};
use futures_util::{SinkExt, StreamExt};
use redis::AsyncCommands;
use serde_json::{json, Value};
use support::{body_json, bootstrap_admin_token, spawn_test_app, unique_username, TestApp};
use tokio::net::TcpListener;
use tokio_tungstenite::{connect_async, tungstenite::Message};
use uuid::Uuid;

const TEST_APNS_PRIVATE_KEY: &str = r#"-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg1gsW8p7m26JzSzqh
Xj7a8qzlgQr96B0XOgTxmPLQZ3mhRANCAASLhkavy/UiriTIjBnLK1B0ngJttikw
mN/fOb81W2J8TNvVe4bOgzZAGGWjZYIv/IdHh3Fya9fOEo7CRaKSZs0N
-----END PRIVATE KEY-----"#;

struct TestUser {
    id: String,
    token: String,
}

async fn register_and_login(app: &TestApp, prefix: &str) -> TestUser {
    let username = unique_username(prefix);
    let body =
        format!(r#"{{"username":"{username}","password":"pass123456","nickname":"{username}"}}"#);
    let (status, resp) = app.post_json("/auth/register", &body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "register: {}",
        String::from_utf8_lossy(&resp)
    );

    let login = format!(r#"{{"username":"{username}","password":"pass123456"}}"#);
    let (status, resp) = app.post_json("/auth/login", &login).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "login: {}",
        String::from_utf8_lossy(&resp)
    );

    let parsed = body_json(&resp);
    TestUser {
        id: parsed["user"]["id"].as_str().expect("user.id").to_string(),
        token: parsed["token"].as_str().expect("token").to_string(),
    }
}

async fn create_room(app: &TestApp, owner: &TestUser, members: &[&TestUser]) -> String {
    let member_ids: Vec<&str> = members.iter().map(|user| user.id.as_str()).collect();
    let body = json!({
        "name": "ws integration",
        "description": "test",
        "room_type": "group",
        "member_ids": member_ids,
    })
    .to_string();

    let (status, resp) = app.post_json_authed("/rooms", &owner.token, &body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "create room: {}",
        String::from_utf8_lossy(&resp)
    );
    body_json(&resp)["room"]["id"]
        .as_str()
        .expect("room.id")
        .to_string()
}

async fn set_message_runtime_modes(
    app: &TestApp,
    admin_token: &str,
    server_storage_mode: &str,
    content_audit_mode: &str,
) {
    let payload = json!({
        "server_storage_mode": server_storage_mode,
        "content_audit_mode": content_audit_mode
    })
    .to_string();
    let (status, body) = app
        .put_json_authed("/api/admin/settings/message-runtime", admin_token, &payload)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "切换 {server_storage_mode}/{content_audit_mode} 消息运行模式: {}",
        String::from_utf8_lossy(&body)
    );
}

async fn set_message_runtime(app: &TestApp, admin_token: &str, server_storage_mode: &str) {
    set_message_runtime_modes(app, admin_token, server_storage_mode, "plaintext").await;
}

async fn set_relay_only_runtime(app: &TestApp, admin_token: &str) {
    set_message_runtime(app, admin_token, "relay_only").await;
}

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

async fn assert_message_persistence(app: &TestApp, message_id: &str, expected_rows: i64) {
    let message_uuid = Uuid::parse_str(message_id).expect("message id should be uuid");
    let message_rows: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM messages WHERE id = $1")
        .bind(message_uuid)
        .fetch_one(&app.pool)
        .await
        .expect("count messages by id");
    assert_eq!(
        message_rows, expected_rows,
        "messages 表中 message_id={message_id} 的行数不符合预期"
    );

    let message_part_rows: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM message_parts WHERE message_id = $1")
            .bind(message_uuid)
            .fetch_one(&app.pool)
            .await
            .expect("count message_parts by message id");
    assert_eq!(
        message_part_rows, expected_rows,
        "message_parts 表中 message_id={message_id} 的行数不符合预期"
    );
}

async fn assert_no_message_push_job(app: &TestApp, message_id: &str) {
    let push_job_rows: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM push_job_queue WHERE job_type = 'message' AND payload::text LIKE '%' || $1 || '%'",
    )
    .bind(message_id)
    .fetch_one(&app.pool)
    .await
    .expect("count push message jobs by snapshot id");
    assert_eq!(
        push_job_rows, 0,
        "relay_only 不应把 message_id={message_id} 的消息快照写入 push_job_queue"
    );
}

async fn assert_message_push_job_exists(app: &TestApp, message_id: &str) {
    let push_job_rows: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM push_job_queue WHERE job_type = 'message' AND payload::text LIKE '%' || $1 || '%'",
    )
    .bind(message_id)
    .fetch_one(&app.pool)
    .await
    .expect("count push message jobs by payload");
    assert!(
        push_job_rows > 0,
        "persist 模式应把 message_id={message_id} 写入 push_job_queue"
    );
}

async fn seed_default_storage_provider(app: &TestApp) -> Uuid {
    let provider_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO storage_providers (
            id, provider_type, name, secret_id, secret_key, region, endpoint, bucket_name,
            is_active, is_default, description
        )
        VALUES ($1, 5, 'test-b2', 'mock-key-id', 'mock-application-key', 'us-east-005',
                'http://external-mock:19080', 'mock-bucket', TRUE, TRUE, '测试默认存储')
        ON CONFLICT (id) DO NOTHING
        "#,
    )
    .bind(provider_id)
    .execute(&app.pool)
    .await
    .expect("seed default storage provider");
    provider_id
}

async fn seed_completed_message_attachment(
    app: &TestApp,
    provider_id: Uuid,
    object_key: &str,
    content_type: &str,
    file_size: i64,
) {
    sqlx::query(
        r#"
        INSERT INTO file_upload_records (
            storage_provider_id,
            object_key,
            hash_alg,
            hash_value,
            file_size,
            content_type,
            status,
            uploaded_at
        )
        VALUES ($1, $2, 1, $3, $4, $5, 1, NOW())
        ON CONFLICT (storage_provider_id, object_key) DO UPDATE
        SET file_size = EXCLUDED.file_size,
            content_type = EXCLUDED.content_type,
            status = 1,
            uploaded_at = COALESCE(file_upload_records.uploaded_at, NOW()),
            updated_at = NOW()
        "#,
    )
    .bind(provider_id)
    .bind(object_key)
    .bind(format!("test-hash-{}", Uuid::new_v4().simple()))
    .bind(file_size)
    .bind(content_type)
    .execute(&app.pool)
    .await
    .expect("seed completed file upload record");

    sqlx::query(
        r#"
        INSERT INTO file_upload_audit_tasks (
            storage_provider_id,
            object_key,
            scene,
            media_kind,
            content_type,
            file_size,
            status,
            audited_at
        )
        VALUES ($1, $2, 'message_attachment', 'image', $3, $4, 1, NOW())
        ON CONFLICT (storage_provider_id, object_key) DO UPDATE
        SET content_type = EXCLUDED.content_type,
            file_size = EXCLUDED.file_size,
            status = 1,
            audited_at = COALESCE(file_upload_audit_tasks.audited_at, NOW()),
            updated_at = NOW()
        "#,
    )
    .bind(provider_id)
    .bind(object_key)
    .bind(content_type)
    .bind(file_size)
    .execute(&app.pool)
    .await
    .expect("seed passed file upload audit task");
}

async fn delete_relay_only_attachment_grant(room_id: &str, object_key: &str) {
    let redis_url = std::env::var("REDIS_CACHE_URL")
        .or_else(|_| std::env::var("REDIS_SESSION_URL"))
        .expect("REDIS_CACHE_URL or REDIS_SESSION_URL should be set");
    let client = redis::Client::open(redis_url).expect("open redis client");
    let mut conn = client
        .get_multiplexed_async_connection()
        .await
        .expect("connect redis");
    let grant_key = format!(
        "relay_only:attachment_grant:{room_id}:{}",
        object_key.trim()
    );
    let _: usize = conn.del(grant_key).await.expect("delete relay grant");
}

fn download_url_expires_in_seconds(payload: &Value) -> Option<u32> {
    let url = payload["download_url"].as_str()?;
    let query = url.split_once('?')?.1;
    query
        .split('&')
        .filter_map(|part| part.split_once('='))
        .find_map(|(key, value)| {
            if key == "X-Amz-Expires" {
                value.parse::<u32>().ok()
            } else {
                None
            }
        })
}

async fn assert_relay_only_unsupported(
    app: &TestApp,
    method: &str,
    uri: &str,
    token: &str,
    body: Option<Value>,
) {
    let json_body = body.is_some();
    let request_body = body
        .map(|value| Body::from(value.to_string()))
        .unwrap_or_else(Body::empty);
    let (status, resp) = app
        .send(method, uri, Some(token), request_body, json_body)
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "{method} {uri} should be unsupported in relay_only: {}",
        String::from_utf8_lossy(&resp)
    );
    assert!(
        String::from_utf8_lossy(&resp).contains("relay_only"),
        "unsupported error should mention relay_only: {}",
        String::from_utf8_lossy(&resp)
    );
}

async fn spawn_ws_server(app: &TestApp) -> String {
    let listener = TcpListener::bind("127.0.0.1:0")
        .await
        .expect("bind ws test server");
    let addr = listener.local_addr().expect("local addr");
    let router = app
        .router
        .clone()
        .into_make_service_with_connect_info::<std::net::SocketAddr>();
    tokio::spawn(async move {
        let _ = axum::serve(listener, router).await;
    });
    format!("ws://{addr}/ws?format=json")
}

async fn connect_ws(
    base_ws_url: &str,
) -> tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>> {
    let (stream, _resp) = connect_async(base_ws_url).await.expect("connect websocket");
    stream
}

async fn send_json(
    ws: &mut tokio_tungstenite::WebSocketStream<
        tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
    >,
    value: Value,
) {
    ws.send(Message::Text(value.to_string().into()))
        .await
        .expect("send ws json");
}

async fn next_json_of_type(
    ws: &mut tokio_tungstenite::WebSocketStream<
        tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
    >,
    expected_type: &str,
) -> Value {
    let deadline = tokio::time::Instant::now() + std::time::Duration::from_secs(5);
    loop {
        let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
        assert!(
            !remaining.is_zero(),
            "timed out waiting for websocket event {expected_type}"
        );

        let frame = tokio::time::timeout(remaining, ws.next())
            .await
            .expect("wait websocket frame")
            .expect("websocket frame")
            .expect("websocket frame ok");

        let Message::Text(text) = frame else {
            continue;
        };
        let parsed: Value = serde_json::from_str(&text).expect("valid json websocket frame");
        if parsed["type"].as_str() == Some(expected_type) {
            return parsed;
        }
    }
}

async fn authenticate_ws(
    ws: &mut tokio_tungstenite::WebSocketStream<
        tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
    >,
    token: &str,
) -> Value {
    send_json(ws, json!({"type": "auth", "token": token})).await;
    next_json_of_type(ws, "authed").await
}

async fn join_room_ws(
    ws: &mut tokio_tungstenite::WebSocketStream<
        tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>,
    >,
    room_id: &str,
) -> Value {
    send_json(ws, json!({"type": "join", "room_id": room_id})).await;
    next_json_of_type(ws, "joined").await
}

#[tokio::test]
async fn websocket_auth_join_ping_and_message_broadcast_succeeds() {
    let app = spawn_test_app().await;
    let owner = register_and_login(&app, "wso").await;
    let member = register_and_login(&app, "wsm").await;
    let room_id = create_room(&app, &owner, &[&member]).await;
    let ws_url = spawn_ws_server(&app).await;

    let mut ws = connect_ws(&ws_url).await;
    let authed = authenticate_ws(&mut ws, &member.token).await;
    assert_eq!(authed["user_id"].as_str(), Some(member.id.as_str()));

    let joined = join_room_ws(&mut ws, &room_id).await;
    assert_eq!(joined["room_id"].as_str(), Some(room_id.as_str()));

    send_json(&mut ws, json!({"type": "ping"})).await;
    let pong = next_json_of_type(&mut ws, "pong").await;
    assert_eq!(pong["type"].as_str(), Some("pong"));

    let body = json!({"content": "hello websocket"}).to_string();
    let (status, resp) = app
        .post_json_authed(&format!("/rooms/{room_id}/messages"), &owner.token, &body)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "send message: {}",
        String::from_utf8_lossy(&resp)
    );
    let sent = body_json(&resp);
    let message_id = sent["message"]["id"]
        .as_str()
        .expect("persist response message id")
        .to_string();
    assert_message_persistence(&app, &message_id, 1).await;

    let pushed = next_json_of_type(&mut ws, "message").await;
    assert_eq!(pushed["room_id"].as_str(), Some(room_id.as_str()));
    assert_eq!(pushed["message_id"].as_str(), Some(message_id.as_str()));
    assert_eq!(pushed["content"].as_str(), Some("hello websocket"));
}

#[tokio::test]
async fn message_send_endpoints_follow_content_audit_mode() {
    let app = spawn_test_app().await;
    let owner = register_and_login(&app, "mode-owner").await;
    let member = register_and_login(&app, "mode-member").await;
    let room_id = create_room(&app, &owner, &[&member]).await;
    let admin_token = bootstrap_admin_token(&app).await;
    let encrypted_body = json!({
        "content_summary": "[加密消息]",
        "encrypted_content": "aGVsbG8=",
        "encryption_metadata": {"alg": "test"}
    })
    .to_string();

    let (status, body) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages/encrypted"),
            &owner.token,
            &encrypted_body,
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(body_json(&body)["code"].as_u64(), Some(40902));

    set_message_runtime_modes(&app, &admin_token, "persist", "e2ee").await;

    let plaintext_body = json!({"content": "must not leak"}).to_string();
    let (status, body) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &owner.token,
            &plaintext_body,
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(body_json(&body)["code"].as_u64(), Some(40902));

    let (status, body) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages/encrypted"),
            &owner.token,
            &encrypted_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "e2ee 模式应接受加密消息: {}",
        String::from_utf8_lossy(&body)
    );
}

#[tokio::test]
async fn persist_mode_rejects_uncommitted_attachment_keys() {
    let app = spawn_test_app().await;
    let owner = register_and_login(&app, "pao").await;
    let member = register_and_login(&app, "pam").await;
    let room_id = create_room(&app, &owner, &[&member]).await;
    let provider_id = seed_default_storage_provider(&app).await;

    let forged_key = format!("messages/{}/images_20260724/forged.png", Uuid::new_v4());
    let forged_body = json!({
        "parts": [
            {
                "type": "image",
                "key": forged_key,
                "name": "forged.png",
                "mime": "image/png",
                "size": 12345
            }
        ]
    })
    .to_string();
    let (status, forged_resp) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &owner.token,
            &forged_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "persist 模式应拒绝未提交附件 key: {}",
        String::from_utf8_lossy(&forged_resp)
    );
    assert!(
        String::from_utf8_lossy(&forged_resp).contains("上传提交"),
        "persist 模式错误信息应提示先完成上传提交: {}",
        String::from_utf8_lossy(&forged_resp)
    );

    let committed_key = format!("messages/{}/images_20260724/committed.png", Uuid::new_v4());
    seed_completed_message_attachment(&app, provider_id, &committed_key, "image/png", 12345).await;
    let committed_body = json!({
        "parts": [
            {
                "type": "image",
                "key": committed_key,
                "name": "committed.png",
                "mime": "image/png",
                "size": 12345
            }
        ]
    })
    .to_string();
    let (status, committed_resp) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &owner.token,
            &committed_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "persist 模式应允许已提交附件 key: {}",
        String::from_utf8_lossy(&committed_resp)
    );
    let committed_sent = body_json(&committed_resp);
    let committed_message_id = committed_sent["message"]["id"]
        .as_str()
        .expect("persist attachment response message id")
        .to_string();
    assert_eq!(
        committed_sent["message"]["parts"][0]["attachment"]["key"].as_str(),
        Some(committed_key.as_str())
    );
    assert_message_persistence(&app, &committed_message_id, 1).await;
}

#[tokio::test]
async fn relay_only_message_broadcasts_without_server_persistence() {
    let app = spawn_test_app().await;
    let owner = register_and_login(&app, "rlo").await;
    let member = register_and_login(&app, "rlm").await;
    let room_id = create_room(&app, &owner, &[&member]).await;
    let admin_token = bootstrap_admin_token(&app).await;
    enable_apns_push(&app, &admin_token).await;
    let provider_id = seed_default_storage_provider(&app).await;

    let persist_body = json!({"content": "persist visible before relay"}).to_string();
    let (status, persist_resp) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &owner.token,
            &persist_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "send persist control message: {}",
        String::from_utf8_lossy(&persist_resp)
    );
    let persist_sent = body_json(&persist_resp);
    let persist_message_id = persist_sent["message"]["id"]
        .as_str()
        .expect("persist control response message id")
        .to_string();
    assert_message_persistence(&app, &persist_message_id, 1).await;
    assert_message_push_job_exists(&app, &persist_message_id).await;

    let (status, persist_history_body) = app
        .get_authed(&format!("/rooms/{room_id}/messages"), &member.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "persist history: {}",
        String::from_utf8_lossy(&persist_history_body)
    );
    assert!(
        body_json(&persist_history_body)
            .as_array()
            .expect("persist history array")
            .iter()
            .any(|item| item["id"].as_str() == Some(persist_message_id.as_str())),
        "persist 模式应能读取切换前历史消息"
    );

    let (status, persist_search_body) = app
        .get_authed(
            "/messages/search?query=persist%20visible%20before%20relay",
            &member.token,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "persist search: {}",
        String::from_utf8_lossy(&persist_search_body)
    );
    assert_eq!(
        body_json(&persist_search_body)["stats"]["total_results"].as_i64(),
        Some(1)
    );

    let (status, persist_chats_body) = app.get_authed("/chats", &member.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "persist chats: {}",
        String::from_utf8_lossy(&persist_chats_body)
    );
    let persist_chats = body_json(&persist_chats_body);
    let persist_chat = persist_chats
        .as_array()
        .and_then(|items| {
            items
                .iter()
                .find(|item| item["room_id"].as_str() == Some(room_id.as_str()))
        })
        .expect("persist chats should include current room");
    assert_eq!(
        persist_chat["last_message"]["id"].as_str(),
        Some(persist_message_id.as_str())
    );
    assert_eq!(persist_chat["unread_count"].as_i64(), Some(1));

    set_relay_only_runtime(&app, &admin_token).await;
    let ws_url = spawn_ws_server(&app).await;

    let mut member_ws = connect_ws(&ws_url).await;
    authenticate_ws(&mut member_ws, &member.token).await;
    join_room_ws(&mut member_ws, &room_id).await;

    let body = json!({"content": "relay only hello"}).to_string();
    let (status, resp) = app
        .post_json_authed(&format!("/rooms/{room_id}/messages"), &owner.token, &body)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "send relay_only message: {}",
        String::from_utf8_lossy(&resp)
    );
    let sent = body_json(&resp);
    let message_id = sent["message"]["id"]
        .as_str()
        .expect("relay_only response message id")
        .to_string();
    assert_eq!(
        sent["message"]["content"].as_str(),
        Some("relay only hello")
    );

    let pushed = next_json_of_type(&mut member_ws, "message").await;
    assert_eq!(pushed["room_id"].as_str(), Some(room_id.as_str()));
    assert_eq!(pushed["message_id"].as_str(), Some(message_id.as_str()));
    assert_eq!(pushed["content"].as_str(), Some("relay only hello"));

    assert_message_persistence(&app, &message_id, 0).await;
    assert_no_message_push_job(&app, &message_id).await;

    set_message_runtime_modes(&app, &admin_token, "relay_only", "e2ee").await;
    let encrypted_body = json!({
        "content_summary": "[加密消息]",
        "encrypted_content": "aGVsbG8=",
        "encryption_metadata": {"alg": "test", "iv": "iv1"}
    })
    .to_string();
    let (status, encrypted_resp) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages/encrypted"),
            &owner.token,
            &encrypted_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "send relay_only encrypted message: {}",
        String::from_utf8_lossy(&encrypted_resp)
    );
    let encrypted_sent = body_json(&encrypted_resp);
    let encrypted_message_id = encrypted_sent["message"]["id"]
        .as_str()
        .expect("relay_only encrypted response message id")
        .to_string();
    assert_eq!(
        encrypted_sent["message"]["encrypted_content"].as_str(),
        Some("aGVsbG8=")
    );
    assert_eq!(
        encrypted_sent["message"]["encryption_metadata"]["alg"].as_str(),
        Some("test")
    );

    let encrypted_pushed = next_json_of_type(&mut member_ws, "message").await;
    assert_eq!(encrypted_pushed["room_id"].as_str(), Some(room_id.as_str()));
    assert_eq!(
        encrypted_pushed["message_id"].as_str(),
        Some(encrypted_message_id.as_str())
    );
    assert_eq!(
        encrypted_pushed["encrypted_content"].as_str(),
        Some("aGVsbG8=")
    );
    assert_eq!(
        encrypted_pushed["encryption_metadata"]["alg"].as_str(),
        Some("test")
    );
    assert_message_persistence(&app, &encrypted_message_id, 0).await;
    assert_no_message_push_job(&app, &encrypted_message_id).await;
    set_message_runtime(&app, &admin_token, "relay_only").await;

    let ungranted_key = format!("messages/{room_id}/images_20260723/ungranted.png");
    let (status, ungranted_download_body) = app
        .get_authed(
            &format!("/rooms/{room_id}/messages/attachments/download?key={ungranted_key}"),
            &member.token,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "relay_only should reject ungranted attachment key: {}",
        String::from_utf8_lossy(&ungranted_download_body)
    );

    let foreign_room_id = Uuid::new_v4();
    let foreign_attachment_key = format!("messages/{foreign_room_id}/images_20260723/stolen.png");
    let foreign_attachment_body = json!({
        "parts": [
            {
                "type": "image",
                "key": foreign_attachment_key,
                "name": "stolen.png",
                "mime": "image/png",
                "size": 12345
            }
        ]
    })
    .to_string();
    let (status, foreign_resp) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &owner.token,
            &foreign_attachment_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "relay_only should reject attachment key outside current room: {}",
        String::from_utf8_lossy(&foreign_resp)
    );
    assert!(
        String::from_utf8_lossy(&foreign_resp).contains("relay_only"),
        "foreign key rejection should mention relay_only: {}",
        String::from_utf8_lossy(&foreign_resp)
    );

    let forged_attachment_key = format!("messages/{room_id}/images_20260723/forged.png");
    let forged_attachment_body = json!({
        "parts": [
            {
                "type": "image",
                "key": forged_attachment_key,
                "name": "forged.png",
                "mime": "image/png",
                "size": 12345
            }
        ]
    })
    .to_string();
    let (status, forged_resp) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &owner.token,
            &forged_attachment_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "relay_only should reject current-room key without committed upload: {}",
        String::from_utf8_lossy(&forged_resp)
    );
    assert!(
        String::from_utf8_lossy(&forged_resp).contains("上传提交"),
        "forged key rejection should require committed upload: {}",
        String::from_utf8_lossy(&forged_resp)
    );

    std::env::set_var("MESSAGE_RELAY_ATTACHMENT_GRANT_TTL_SECONDS", "60");
    let attachment_key = format!("messages/{room_id}/images_20260723/relay01.png");
    let thumbnail_key = format!("messages/{room_id}/images_20260723/relay01_thumb.png");
    seed_completed_message_attachment(&app, provider_id, &attachment_key, "image/png", 12345).await;
    seed_completed_message_attachment(&app, provider_id, &thumbnail_key, "image/png", 12345).await;
    let attachment_body = json!({
        "parts": [
            {
                "type": "image",
                "key": attachment_key,
                "name": "relay01.png",
                "mime": "image/png",
                "size": 12345,
                "width": 800,
                "height": 600,
                "thumbnail_key": thumbnail_key
            }
        ]
    })
    .to_string();
    let (status, attachment_resp) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &owner.token,
            &attachment_body,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "send relay_only attachment message: {}",
        String::from_utf8_lossy(&attachment_resp)
    );
    let attachment_sent = body_json(&attachment_resp);
    let attachment_message_id = attachment_sent["message"]["id"]
        .as_str()
        .expect("relay_only attachment response message id")
        .to_string();
    assert_eq!(
        attachment_sent["message"]["parts"][0]["attachment"]["key"].as_str(),
        Some(attachment_key.as_str())
    );

    let attachment_pushed = next_json_of_type(&mut member_ws, "message").await;
    assert_eq!(
        attachment_pushed["message_id"].as_str(),
        Some(attachment_message_id.as_str())
    );
    assert_eq!(
        attachment_pushed["parts"][0]["attachment"]["key"].as_str(),
        Some(attachment_key.as_str())
    );
    assert_message_persistence(&app, &attachment_message_id, 0).await;
    assert_no_message_push_job(&app, &attachment_message_id).await;

    let (status, download_body) = app
        .get_authed(
            &format!(
                "/rooms/{room_id}/messages/attachments/download?key={attachment_key}&expires_in_seconds=86400"
            ),
            &member.token,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only attachment download: {}",
        String::from_utf8_lossy(&download_body)
    );
    let download = body_json(&download_body);
    assert_eq!(download["success"].as_bool(), Some(true));
    let expires = download_url_expires_in_seconds(&download)
        .expect("download URL should include X-Amz-Expires");
    assert!(
        (1..=60).contains(&expires),
        "relay_only download URL expires should not exceed Redis grant TTL: {download}"
    );
    assert!(
        download["download_url"]
            .as_str()
            .map(|url| url.contains("relay01.png"))
            .unwrap_or(false),
        "download_url should include attachment object key: {download}"
    );

    let (status, thumbnail_download_body) = app
        .get_authed(
            &format!("/rooms/{room_id}/messages/attachments/download?key={thumbnail_key}"),
            &member.token,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only thumbnail download: {}",
        String::from_utf8_lossy(&thumbnail_download_body)
    );
    let thumbnail_download = body_json(&thumbnail_download_body);
    assert!(
        thumbnail_download["download_url"]
            .as_str()
            .map(|url| url.contains("relay01_thumb.png"))
            .unwrap_or(false),
        "thumbnail download_url should include thumbnail object key: {thumbnail_download}"
    );

    let (status, history_body) = app
        .get_authed(&format!("/rooms/{room_id}/messages"), &member.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only history: {}",
        String::from_utf8_lossy(&history_body)
    );
    assert_eq!(
        body_json(&history_body).as_array().map(Vec::len),
        Some(0),
        "relay_only 历史消息应返回空列表"
    );

    let (status, search_body) = app
        .get_authed("/messages/search?query=relay", &member.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only search: {}",
        String::from_utf8_lossy(&search_body)
    );
    let search = body_json(&search_body);
    assert_eq!(search["results"].as_array().map(Vec::len), Some(0));
    assert_eq!(search["stats"]["total_results"].as_i64(), Some(0));

    let (status, suggestions_body) = app
        .get_authed("/messages/search/suggestions?prefix=re", &member.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only suggestions: {}",
        String::from_utf8_lossy(&suggestions_body)
    );
    assert_eq!(
        body_json(&suggestions_body).as_array().map(Vec::len),
        Some(0)
    );

    let (status, trending_body) = app
        .get_authed("/messages/search/trending", &member.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only trending: {}",
        String::from_utf8_lossy(&trending_body)
    );
    assert_eq!(body_json(&trending_body).as_array().map(Vec::len), Some(0));

    let (status, read_body) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages/read"),
            &member.token,
            &json!({"message_id": message_id}).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "relay_only read receipt should be unsupported: {}",
        String::from_utf8_lossy(&read_body)
    );
    assert!(
        String::from_utf8_lossy(&read_body).contains("relay_only"),
        "unsupported error should mention relay_only: {}",
        String::from_utf8_lossy(&read_body)
    );

    let (status, read_until_body) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages/read_until"),
            &member.token,
            &json!({"message_id": message_id}).to_string(),
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "relay_only read_until should be unsupported: {}",
        String::from_utf8_lossy(&read_until_body)
    );
    assert!(
        String::from_utf8_lossy(&read_until_body).contains("relay_only"),
        "unsupported error should mention relay_only: {}",
        String::from_utf8_lossy(&read_until_body)
    );

    let (status, reads_body) = app
        .get_authed(
            &format!("/rooms/{room_id}/messages/{message_id}/reads"),
            &member.token,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "relay_only read list should be unsupported: {}",
        String::from_utf8_lossy(&reads_body)
    );
    assert!(
        String::from_utf8_lossy(&reads_body).contains("relay_only"),
        "unsupported error should mention relay_only: {}",
        String::from_utf8_lossy(&reads_body)
    );

    let (status, unread_body) = app
        .get_authed(&format!("/rooms/{room_id}/unread_count"), &member.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only unread_count: {}",
        String::from_utf8_lossy(&unread_body)
    );
    let unread = body_json(&unread_body);
    assert_eq!(unread["room_id"].as_str(), Some(room_id.as_str()));
    assert_eq!(unread["unread_count"].as_i64(), Some(0));
    assert!(unread["last_read_message_id"].is_null());

    let (status, all_unread_body) = app.get_authed("/unread_counts", &member.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only unread_counts: {}",
        String::from_utf8_lossy(&all_unread_body)
    );
    let all_unread = body_json(&all_unread_body);
    let room_unread = all_unread
        .as_array()
        .and_then(|items| {
            items
                .iter()
                .find(|item| item["room_id"].as_str() == Some(room_id.as_str()))
        })
        .expect("relay_only unread_counts should include current room");
    assert_eq!(room_unread["unread_count"].as_i64(), Some(0));
    assert!(room_unread["last_read_message_id"].is_null());

    let (status, chats_body) = app.get_authed("/chats", &member.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only chats: {}",
        String::from_utf8_lossy(&chats_body)
    );
    let chats = body_json(&chats_body);
    let chat = chats
        .as_array()
        .and_then(|items| {
            items
                .iter()
                .find(|item| item["room_id"].as_str() == Some(room_id.as_str()))
        })
        .expect("relay_only chats should include current room");
    assert_eq!(chat["unread_count"].as_i64(), Some(0));
    assert!(chat["last_message"].is_null());
    assert!(chat["last_read_message_id"].is_null());

    let (status, admin_history_body) = app
        .get_authed("/api/admin/chat-history", &admin_token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only admin chat history: {}",
        String::from_utf8_lossy(&admin_history_body)
    );
    let admin_history = body_json(&admin_history_body);
    assert_eq!(admin_history["messages"].as_array().map(Vec::len), Some(0));
    assert_eq!(admin_history["total"].as_i64(), Some(0));

    let (status, admin_rooms_body) = app
        .get_authed(
            &format!("/api/admin/users/{}/rooms", member.id),
            &admin_token,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only admin user rooms: {}",
        String::from_utf8_lossy(&admin_rooms_body)
    );
    let admin_rooms = body_json(&admin_rooms_body);
    let admin_room = admin_rooms["rooms"]
        .as_array()
        .and_then(|items| {
            items
                .iter()
                .find(|item| item["id"].as_str() == Some(room_id.as_str()))
        })
        .expect("relay_only admin user rooms should include current room");
    assert!(admin_room["last_message"].is_null());

    assert_relay_only_unsupported(
        &app,
        "POST",
        &format!("/rooms/{room_id}/messages/forward"),
        &member.token,
        Some(json!({"original_message_id": message_id})),
    )
    .await;
    assert_relay_only_unsupported(
        &app,
        "POST",
        &format!("/rooms/{room_id}/messages"),
        &owner.token,
        Some(json!({"content": "quoted relay", "quoted_message_id": message_id})),
    )
    .await;
    let encrypted_quote = json!({
        "content_summary": "[加密消息]",
        "encrypted_content": "aGVsbG8=",
        "quoted_message_id": message_id
    })
    .to_string();
    let (status, body) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages/encrypted"),
            &owner.token,
            &encrypted_quote,
        )
        .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(body_json(&body)["code"].as_u64(), Some(40902));
    assert_relay_only_unsupported(
        &app,
        "PATCH",
        &format!("/rooms/{room_id}/messages/{message_id}"),
        &owner.token,
        Some(json!({"content": "edited"})),
    )
    .await;
    assert_relay_only_unsupported(
        &app,
        "DELETE",
        &format!("/rooms/{room_id}/messages/{message_id}"),
        &owner.token,
        None,
    )
    .await;
    assert_relay_only_unsupported(
        &app,
        "POST",
        &format!("/rooms/{room_id}/messages/{message_id}/pin"),
        &member.token,
        None,
    )
    .await;
    assert_relay_only_unsupported(
        &app,
        "DELETE",
        &format!("/rooms/{room_id}/messages/{message_id}/pin"),
        &member.token,
        None,
    )
    .await;
    assert_relay_only_unsupported(
        &app,
        "POST",
        &format!("/rooms/{room_id}/messages/{message_id}/reactions"),
        &member.token,
        Some(json!({"reaction_key": "👍"})),
    )
    .await;
    assert_relay_only_unsupported(
        &app,
        "GET",
        &format!("/rooms/{room_id}/messages/{message_id}/reactions"),
        &member.token,
        None,
    )
    .await;
    assert_relay_only_unsupported(
        &app,
        "DELETE",
        &format!("/rooms/{room_id}/messages/{message_id}/reactions?reaction_key=%F0%9F%91%8D"),
        &member.token,
        None,
    )
    .await;
    assert_relay_only_unsupported(
        &app,
        "DELETE",
        &format!("/rooms/{room_id}/messages"),
        &member.token,
        None,
    )
    .await;

    set_message_runtime(&app, &admin_token, "persist").await;
    let (status, download_after_persist_body) = app
        .get_authed(
            &format!("/rooms/{room_id}/messages/attachments/download?key={attachment_key}"),
            &member.token,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "relay_only attachment grant should survive mode switch while TTL is valid: {}",
        String::from_utf8_lossy(&download_after_persist_body)
    );

    delete_relay_only_attachment_grant(&room_id, &attachment_key).await;
    let (status, download_after_grant_removed_body) = app
        .get_authed(
            &format!("/rooms/{room_id}/messages/attachments/download?key={attachment_key}"),
            &member.token,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "removed relay_only grant should make non-persisted attachment unavailable: {}",
        String::from_utf8_lossy(&download_after_grant_removed_body)
    );
    std::env::remove_var("MESSAGE_RELAY_ATTACHMENT_GRANT_TTL_SECONDS");
}

#[tokio::test]
async fn websocket_rejects_join_for_non_member() {
    let app = spawn_test_app().await;
    let owner = register_and_login(&app, "wso").await;
    let member = register_and_login(&app, "wsm").await;
    let outsider = register_and_login(&app, "wsx").await;
    let room_id = create_room(&app, &owner, &[&member]).await;
    let ws_url = spawn_ws_server(&app).await;

    let mut ws = connect_ws(&ws_url).await;
    authenticate_ws(&mut ws, &outsider.token).await;
    send_json(&mut ws, json!({"type": "join", "room_id": room_id})).await;

    let err = next_json_of_type(&mut ws, "error").await;
    assert!(
        err["message"]
            .as_str()
            .unwrap_or_default()
            .contains("forbidden"),
        "unexpected error payload: {err}"
    );
}

#[tokio::test]
async fn websocket_typing_requires_subscription_and_broadcasts_after_join() {
    let app = spawn_test_app().await;
    let owner = register_and_login(&app, "wso").await;
    let member = register_and_login(&app, "wsm").await;
    let room_id = create_room(&app, &owner, &[&member]).await;
    let ws_url = spawn_ws_server(&app).await;

    let mut owner_ws = connect_ws(&ws_url).await;
    authenticate_ws(&mut owner_ws, &owner.token).await;

    send_json(
        &mut owner_ws,
        json!({"type": "typing", "room_id": room_id, "is_typing": true}),
    )
    .await;
    let err = next_json_of_type(&mut owner_ws, "error").await;
    assert!(
        err["message"]
            .as_str()
            .unwrap_or_default()
            .contains("not subscribed"),
        "unexpected error payload: {err}"
    );

    let mut member_ws = connect_ws(&ws_url).await;
    authenticate_ws(&mut member_ws, &member.token).await;
    join_room_ws(&mut member_ws, &room_id).await;
    join_room_ws(&mut owner_ws, &room_id).await;

    send_json(
        &mut owner_ws,
        json!({"type": "typing", "room_id": room_id, "is_typing": true}),
    )
    .await;
    let typing = next_json_of_type(&mut member_ws, "typing_update").await;
    assert_eq!(typing["room_id"].as_str(), Some(room_id.as_str()));
    assert_eq!(typing["user_id"].as_str(), Some(owner.id.as_str()));
    assert_eq!(typing["is_typing"].as_bool(), Some(true));
}
