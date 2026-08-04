mod support;

use axum::http::StatusCode;
use serde_json::json;
use support::{body_json, spawn_test_app, unique_username, TestApp};

struct TestUser {
    id: String,
    token: String,
}

async fn register_and_login(app: &TestApp, prefix: &str) -> TestUser {
    let username = unique_username(prefix);
    let registration = json!({
        "username": username,
        "password": "pass123456",
        "nickname": username,
    });
    let (status, body) = app
        .post_json("/auth/register", &registration.to_string())
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&body));

    let login = json!({ "username": username, "password": "pass123456" });
    let (status, body) = app.post_json("/auth/login", &login.to_string()).await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&body));
    let response = body_json(&body);
    TestUser {
        id: response["user"]["id"]
            .as_str()
            .expect("user id")
            .to_string(),
        token: response["token"].as_str().expect("token").to_string(),
    }
}

async fn accept_friend_request(
    app: &TestApp,
    requester: &TestUser,
    target: &TestUser,
    marker: &str,
) {
    let request = json!({ "target_user_id": target.id, "message": marker });
    let (status, body) = app
        .post_json_authed("/friends/requests", &requester.token, &request.to_string())
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&body));
    let request_id = body_json(&body)["id"]
        .as_str()
        .expect("friend request id")
        .to_string();

    let (status, body) = app
        .post_json_authed(
            &format!("/friends/requests/{request_id}/respond"),
            &target.token,
            r#"{"action":"accept"}"#,
        )
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&body));
}

#[tokio::test]
async fn plaintext_friend_acceptance_keeps_request_message_in_history() {
    let app = spawn_test_app().await;
    let alice = register_and_login(&app, "friend-plain-a").await;
    let bob = register_and_login(&app, "friend-plain-b").await;
    let marker = format!("plaintext-friend-{}", uuid::Uuid::new_v4());

    accept_friend_request(&app, &alice, &bob, &marker).await;

    let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM messages WHERE content = $1")
        .bind(&marker)
        .fetch_one(&app.pool)
        .await
        .expect("count plaintext friend message");
    assert_eq!(count, 1);
}

#[tokio::test]
async fn e2ee_friend_acceptance_never_writes_request_message_to_history() {
    let app = spawn_test_app().await;
    sqlx::query(
        r#"
        INSERT INTO general_settings (key, value, description)
        VALUES ('message_content_audit_mode', 'e2ee', 'test')
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
        "#,
    )
    .execute(&app.pool)
    .await
    .expect("enable e2ee runtime");
    let alice = register_and_login(&app, "friend-e2ee-a").await;
    let bob = register_and_login(&app, "friend-e2ee-b").await;
    let marker = format!("e2ee-friend-{}", uuid::Uuid::new_v4());

    accept_friend_request(&app, &alice, &bob, &marker).await;

    let message_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM messages WHERE content = $1")
        .bind(&marker)
        .fetch_one(&app.pool)
        .await
        .expect("count leaked friend message");
    let friendship_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*) FROM friendships
        WHERE (user_a_id = $1::uuid AND user_b_id = $2::uuid)
           OR (user_a_id = $2::uuid AND user_b_id = $1::uuid)
        "#,
    )
    .bind(&alice.id)
    .bind(&bob.id)
    .fetch_one(&app.pool)
    .await
    .expect("count friendship");
    let private_room_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM rooms r
        JOIN room_members a ON a.room_id = r.id AND a.user_id = $1::uuid
        JOIN room_members b ON b.room_id = r.id AND b.user_id = $2::uuid
        WHERE r.room_type = 0 AND r.deleted_at IS NULL
        "#,
    )
    .bind(&alice.id)
    .bind(&bob.id)
    .fetch_one(&app.pool)
    .await
    .expect("count private room");

    assert_eq!(message_count, 0);
    assert_eq!(friendship_count, 1);
    assert_eq!(private_room_count, 1);
}
