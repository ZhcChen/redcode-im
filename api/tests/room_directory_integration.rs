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

    let login = json!({
        "username": &username,
        "password": "pass123456",
    })
    .to_string();
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
        "name": "Directory integration group",
        "description": "group directory contract",
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

fn find_room<'a>(items: &'a serde_json::Value, room_id: &str) -> Option<&'a serde_json::Value> {
    items.as_array()?.iter().find(|item| {
        item["room_id"].as_str() == Some(room_id) || item["id"].as_str() == Some(room_id)
    })
}

#[tokio::test]
async fn group_directory_favorites_and_chat_archives_are_user_scoped() {
    let app = spawn_test_app().await;
    let owner = register_and_login(&app, "directory_owner").await;
    let member = register_and_login(&app, "directory_member").await;
    let outsider = register_and_login(&app, "directory_outsider").await;
    let room_id = create_group(&app, &owner, &member).await;

    let (status, body) = app.get_authed("/groups/directory", &owner.token).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "directory: {}",
        String::from_utf8_lossy(&body)
    );
    let directory = body_json(&body);
    let entry = find_room(&directory, &room_id).expect("owner group directory entry");
    assert_eq!(entry["member_count"].as_i64(), Some(2));
    assert_eq!(entry["is_favorited"].as_bool(), Some(false));

    let favorite_path = format!("/rooms/{room_id}/directory-favorite");
    let (status, body) = app
        .post_json_authed(&favorite_path, &owner.token, "{}")
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "favorite: {}",
        String::from_utf8_lossy(&body)
    );
    let favorite = body_json(&body);
    assert_eq!(favorite["is_favorited"].as_bool(), Some(true));
    assert!(favorite["favorited_at"].as_str().is_some());

    let (status, body) = app.get_authed("/groups/directory", &owner.token).await;
    assert_eq!(status, StatusCode::OK);
    let owner_directory = body_json(&body);
    let owner_entry = find_room(&owner_directory, &room_id).expect("favorited owner entry");
    assert_eq!(owner_entry["is_favorited"].as_bool(), Some(true));

    let (status, body) = app.get_authed("/groups/directory", &member.token).await;
    assert_eq!(status, StatusCode::OK);
    let member_directory = body_json(&body);
    let member_entry =
        find_room(&member_directory, &room_id).expect("member group directory entry");
    assert_eq!(member_entry["is_favorited"].as_bool(), Some(false));

    let (status, body) = app
        .send(
            "DELETE",
            &format!("/chats/{room_id}"),
            Some(&owner.token),
            Body::empty(),
            false,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "archive: {}",
        String::from_utf8_lossy(&body)
    );
    assert_eq!(body_json(&body)["success"].as_bool(), Some(true));

    let (status, body) = app.get_authed("/chats", &owner.token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(find_room(&body_json(&body), &room_id).is_none());

    let (status, body) = app
        .post_json_authed(
            &format!("/rooms/{room_id}/messages"),
            &member.token,
            r#"{"content":"reactivate archived chat"}"#,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "persisted message: {}",
        String::from_utf8_lossy(&body)
    );

    let (status, body) = app.get_authed("/chats", &owner.token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(find_room(&body_json(&body), &room_id).is_some());

    let (status, body) = app
        .send(
            "DELETE",
            &format!("/chats/{room_id}"),
            Some(&owner.token),
            Body::empty(),
            false,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "archive after new message: {}",
        String::from_utf8_lossy(&body)
    );

    let (status, body) = app.get_authed("/chats", &owner.token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(find_room(&body_json(&body), &room_id).is_none());

    let (status, body) = app.get_authed("/chats", &member.token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(find_room(&body_json(&body), &room_id).is_some());

    let (status, body) = app.get_authed("/groups/directory", &owner.token).await;
    assert_eq!(status, StatusCode::OK);
    let archived_owner_directory = body_json(&body);
    let archived_owner_entry =
        find_room(&archived_owner_directory, &room_id).expect("archived owner entry");
    assert_eq!(archived_owner_entry["is_favorited"].as_bool(), Some(true));

    let (status, body) = app
        .get_authed(&format!("/rooms/{room_id}"), &owner.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "owner room remains: {}",
        String::from_utf8_lossy(&body)
    );
    let (status, body) = app
        .get_authed(&format!("/rooms/{room_id}"), &member.token)
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "member room remains: {}",
        String::from_utf8_lossy(&body)
    );

    let (status, body) = app
        .post_json_authed(&format!("/chats/{room_id}/restore"), &owner.token, "{}")
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "restore: {}",
        String::from_utf8_lossy(&body)
    );
    assert_eq!(body_json(&body)["success"].as_bool(), Some(true));

    let (status, body) = app.get_authed("/chats", &owner.token).await;
    assert_eq!(status, StatusCode::OK);
    assert!(find_room(&body_json(&body), &room_id).is_some());

    let (status, body) = app
        .send(
            "DELETE",
            &favorite_path,
            Some(&owner.token),
            Body::empty(),
            false,
        )
        .await;
    assert_eq!(
        status,
        StatusCode::OK,
        "unfavorite: {}",
        String::from_utf8_lossy(&body)
    );
    assert_eq!(body_json(&body)["is_favorited"].as_bool(), Some(false));

    let (status, body) = app
        .post_json_authed(&favorite_path, &outsider.token, "{}")
        .await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "non-member must not favorite a group: {}",
        String::from_utf8_lossy(&body)
    );
}
