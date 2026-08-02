mod support;

use axum::{body::Body, http::StatusCode};
use serde_json::json;
use support::{body_json, spawn_test_app, unique_username, TestApp};

struct TestUser {
    id: String,
    token: String,
}

async fn register_and_login(app: &TestApp, prefix: &str) -> TestUser {
    let username = unique_username(prefix);
    let registration = json!({
        "username": &username,
        "password": "pass123456",
        "nickname": &username,
    })
    .to_string();
    let (status, body) = app.post_json("/auth/register", &registration).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "register: {}",
        String::from_utf8_lossy(&body)
    );

    let login = json!({"username": &username, "password": "pass123456"}).to_string();
    let (status, body) = app.post_json("/auth/login", &login).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "login: {}",
        String::from_utf8_lossy(&body)
    );
    let payload = body_json(&body);
    TestUser {
        id: payload["user"]["id"].as_str().expect("user.id").to_string(),
        token: payload["token"].as_str().expect("token").to_string(),
    }
}

async fn create_group(app: &TestApp, owner: &TestUser, member: &TestUser) -> String {
    let body = json!({
        "name": "Invitation integration group",
        "description": "group invitation contract",
        "room_type": "group",
        "member_ids": [member.id],
    })
    .to_string();
    let (status, response) = app.post_json_authed("/rooms", &owner.token, &body).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "create group: {}",
        String::from_utf8_lossy(&response)
    );
    body_json(&response)["room"]["id"]
        .as_str()
        .expect("room.id")
        .to_string()
}

#[tokio::test]
async fn received_group_invitations_are_scoped_and_filterable() {
    let app = spawn_test_app().await;
    let owner = register_and_login(&app, "invite_owner").await;
    let member = register_and_login(&app, "invite_member").await;
    let invitee = register_and_login(&app, "invite_target").await;
    let outsider = register_and_login(&app, "invite_outsider").await;
    let room_id = create_group(&app, &owner, &member).await;

    let request = json!({"user_ids": [invitee.id], "message": "欢迎加入测试群"}).to_string();
    let (status, body) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/invitations"),
            &owner.token,
            &request,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "create invitation: {}",
        String::from_utf8_lossy(&body)
    );
    let invitation_id = body_json(&body)["invitations"][0]["id"]
        .as_str()
        .expect("invitation.id")
        .to_string();

    let (status, body) = app
        .get_authed("/group-invitations?status=pending", &invitee.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    let invitation = &body_json(&body)["invitations"][0];
    assert_eq!(invitation["id"].as_str(), Some(invitation_id.as_str()));
    assert_eq!(invitation["room_id"].as_str(), Some(room_id.as_str()));
    assert_eq!(
        invitation["room_name"].as_str(),
        Some("Invitation integration group")
    );
    assert_eq!(invitation["inviter_id"].as_str(), Some(owner.id.as_str()));
    assert_eq!(invitation["message"].as_str(), Some("欢迎加入测试群"));
    assert_eq!(invitation["status"].as_i64(), Some(0));

    let (status, body) = app
        .get_authed("/group-invitations?status=all", &outsider.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        body_json(&body)["invitations"].as_array().map(Vec::len),
        Some(0)
    );

    let response = json!({"status": "declined"}).to_string();
    let (status, body) = app
        .send(
            "PATCH",
            &format!("/rooms/{room_id}/invitations/{invitation_id}/respond"),
            Some(&invitee.token),
            Body::from(response),
            true,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::NO_CONTENT,
        "decline: {}",
        String::from_utf8_lossy(&body)
    );

    let (status, body) = app
        .get_authed("/group-invitations?status=pending", &invitee.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        body_json(&body)["invitations"].as_array().map(Vec::len),
        Some(0)
    );

    let (status, body) = app
        .get_authed("/group-invitations?status=declined", &invitee.token)
        .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(
        body_json(&body)["invitations"][0]["status"].as_i64(),
        Some(2)
    );

    let (status, _) = app
        .get_authed("/group-invitations?status=unknown", &invitee.token)
        .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
}
