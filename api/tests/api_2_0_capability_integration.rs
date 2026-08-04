mod support;

use axum::http::StatusCode;
use serde_json::json;
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
        id: Uuid::parse_str(body["user"]["id"].as_str().expect("user id"))
            .expect("user UUID"),
        token: body["token"].as_str().expect("login token").to_string(),
    }
}

async fn send_message(app: &TestApp, token: &str, room_id: &str) -> (StatusCode, Vec<u8>) {
    app.post_json_authed(
        &format!("/rooms/{room_id}/messages"),
        token,
        r#"{"content":"hi"}"#,
    )
    .await
}

// ==================== U1: 个性签名 ====================

#[tokio::test]
async fn test_update_signature_and_read_back() {
    let app = spawn_test_app().await;
    let user = register_user(&app, "sig").await;

    let (status, response) = app
        .patch_json_authed("/users/me", &user.token, r#"{"signature":"hello world"}"#)
        .await;
    assert_eq!(status, StatusCode::OK, "{}", String::from_utf8_lossy(&response));
    assert_eq!(body_json(&response)["signature"], "hello world");

    let (status, response) = app.get_authed("/auth/me", &user.token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["signature"], "hello world");

    let (status, response) = app
        .get_authed(&format!("/users/{}", user.id), &user.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["signature"], "hello world");
}

#[tokio::test]
async fn test_signature_defaults_to_null() {
    let app = spawn_test_app().await;
    let user = register_user(&app, "sigd").await;

    let (status, response) = app.get_authed("/auth/me", &user.token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(body_json(&response)["signature"].is_null());
}

// ==================== U2: 黑名单 ====================

#[tokio::test]
async fn test_block_blocks_messages_and_friend_requests() {
    let app = spawn_test_app().await;
    let user_a = register_user(&app, "blocka").await;
    let user_b = register_user(&app, "blockb").await;

    // 先建立正常私聊并成功互发
    let (status, response) = app
        .post_json_authed(
            &format!("/friends/{}/chat", user_b.id),
            &user_a.token,
            "{}",
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let room_id = body_json(&response)["room_id"].as_str().unwrap().to_string();

    let (status, _) = send_message(&app, &user_b.token, &room_id).await;
    assert_eq!(status, StatusCode::OK);

    // A 拉黑 B
    let block_body = json!({"user_id": user_b.id.to_string()}).to_string();
    let (status, response) = app
        .post_json_authed("/users/blocked", &user_a.token, &block_body)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );

    // 重复拉黑幂等
    let (status, _) = app
        .post_json_authed("/users/blocked", &user_a.token, &block_body)
        .await;
    assert_eq!(status, StatusCode::OK);

    // 列表可见
    let (status, response) = app.get_authed("/users/blocked", &user_a.token).await;
    assert_eq!(status, StatusCode::OK);
    let list = body_json(&response);
    assert_eq!(list["total"], 1);
    assert_eq!(list["items"][0]["userId"], user_b.id.to_string());

    // 双向任一方向拉黑后，双方都不能再发消息
    let (status, response) = send_message(&app, &user_b.token, &room_id).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let (status, _) = send_message(&app, &user_a.token, &room_id).await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    // 拉黑期间不能发起好友申请 / 创建私聊
    let req = json!({"target_user_id": user_a.id.to_string(), "message": "hi"}).to_string();
    let (status, response) = app
        .post_json_authed("/friends/requests", &user_b.token, &req)
        .await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let (status, _) = app
        .post_json_authed(&format!("/friends/{}/chat", user_b.id), &user_a.token, "{}")
        .await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    // 取消拉黑后恢复
    let (status, response) = app
        .delete_authed(&format!("/users/blocked/{}", user_b.id), &user_a.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let (status, response) = send_message(&app, &user_b.token, &room_id).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
}

#[tokio::test]
async fn test_block_self_is_rejected() {
    let app = spawn_test_app().await;
    let user = register_user(&app, "blockself").await;

    let block_body = json!({"user_id": user.id.to_string()}).to_string();
    let (status, _) = app
        .post_json_authed("/users/blocked", &user.token, &block_body)
        .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
}

// ==================== U3: 群公告 ====================

async fn create_group(app: &TestApp, owner: &TestUser, member: &TestUser) -> String {
    let (status, response) = app
        .post_json_authed(
            "/rooms",
            &owner.token,
            &json!({
                "name": "announcement group",
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
    body_json(&response)["room"]["id"].as_str().unwrap().to_string()
}

#[tokio::test]
async fn test_group_announcement_owner_manage_member_read() {
    let app = spawn_test_app().await;
    let owner = register_user(&app, "annowner").await;
    let member = register_user(&app, "annmember").await;
    let outsider = register_user(&app, "annoutsider").await;
    let room_id = create_group(&app, &owner, &member).await;

    // 普通成员不能发布
    let (status, response) = app
        .put_json_authed(
            &format!("/rooms/{room_id}/announcement"),
            &member.token,
            r#"{"content":"member try"}"#,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "{}",
        String::from_utf8_lossy(&response)
    );

    // 未发布时读取为 404
    let (status, response) = app
        .get_authed(&format!("/rooms/{room_id}/announcement"), &member.token)
        .await;
    if status != StatusCode::NOT_FOUND {
        eprintln!(
            "announcement read status={status:?} body={:?}",
            String::from_utf8_lossy(&response)
        );
    }
    assert_eq!(status, StatusCode::NOT_FOUND);

    // 群主发布，成员可读
    let (status, response) = app
        .put_json_authed(
            &format!("/rooms/{room_id}/announcement"),
            &owner.token,
            r#"{"content":"welcome to the group"}"#,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "{}",
        String::from_utf8_lossy(&response)
    );
    let body = body_json(&response);
    assert_eq!(body["content"], "welcome to the group");
    assert_eq!(body["roomId"], room_id);

    let (status, response) = app
        .get_authed(&format!("/rooms/{room_id}/announcement"), &member.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["content"], "welcome to the group");

    // 非成员不能读取
    let (status, _) = app
        .get_authed(&format!("/rooms/{room_id}/announcement"), &outsider.token)
        .await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    // 群主删除后 404
    let (status, _) = app
        .delete_authed(&format!("/rooms/{room_id}/announcement"), &owner.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    let (status, _) = app
        .get_authed(&format!("/rooms/{room_id}/announcement"), &member.token)
        .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
}

// ==================== U4: 消息收藏 ====================

#[tokio::test]
async fn test_message_favorite_is_private_and_idempotent() {
    let app = spawn_test_app().await;
    let user_a = register_user(&app, "fava").await;
    let user_b = register_user(&app, "favb").await;
    let outsider = register_user(&app, "favout").await;

    // 建私聊并发消息
    let (status, response) = app
        .post_json_authed(
            &format!("/friends/{}/chat", user_b.id),
            &user_a.token,
            "{}",
        )
        .await;
    assert_eq!(status, StatusCode::OK);
    let room_id = body_json(&response)["room_id"].as_str().unwrap().to_string();

    let (status, response) = send_message(&app, &user_a.token, &room_id).await;
    assert_eq!(status, StatusCode::OK);
    let message_id = body_json(&response)["message"]["id"]
        .as_str()
        .unwrap()
        .to_string();

    // 收藏（幂等）
    let fav_url = format!("/rooms/{room_id}/messages/{message_id}/favorite");
    let (status, _) = app
        .post_json_authed(&fav_url, &user_a.token, "{}")
        .await;
    assert_eq!(status, StatusCode::OK);
    let (status, _) = app
        .post_json_authed(&fav_url, &user_a.token, "{}")
        .await;
    assert_eq!(status, StatusCode::OK);

    // A 列表可见，B 不可见（隔离）
    let (status, response) = app
        .get_authed("/messages/favorites", &user_a.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    let list = body_json(&response);
    assert_eq!(list["total"], 1);
    assert_eq!(list["items"][0]["messageId"], message_id);

    let (status, response) = app
        .get_authed("/messages/favorites", &user_b.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["total"], 0);

    // 非成员收藏被拒
    let (status, _) = app
        .post_json_authed(&fav_url, &outsider.token, "{}")
        .await;
    assert_eq!(status, StatusCode::FORBIDDEN);

    // 取消后列表为空
    let (status, _) = app
        .delete_authed(&fav_url, &user_a.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    let (status, response) = app
        .get_authed("/messages/favorites", &user_a.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(body_json(&response)["total"], 0);
}
