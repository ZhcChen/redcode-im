mod support;

use axum::http::StatusCode;
use futures_util::{SinkExt, StreamExt};
use serde_json::{json, Value};
use support::{body_json, spawn_test_app, unique_email, TestApp};
use tokio::net::TcpListener;
use tokio_tungstenite::{connect_async, tungstenite::Message};

struct TestUser {
    id: String,
    token: String,
}

async fn register_and_login(app: &TestApp, prefix: &str) -> TestUser {
    let email = unique_email(prefix);
    let body = format!(r#"{{"email":"{email}","password":"pass123456","nickname":"{email}"}}"#);
    let (status, resp) = app.post_json("/auth/register", &body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "register: {}",
        String::from_utf8_lossy(&resp)
    );

    let login = format!(r#"{{"email":"{email}","password":"pass123456"}}"#);
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

    let pushed = next_json_of_type(&mut ws, "message").await;
    assert_eq!(pushed["room_id"].as_str(), Some(room_id.as_str()));
    assert_eq!(pushed["content"].as_str(), Some("hello websocket"));
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
