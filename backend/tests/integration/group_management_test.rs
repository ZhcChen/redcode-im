use axum::http::StatusCode;
use axum_test::{TestServer, TestServerConfig};
use redcode_im_backend::*;
use serde_json::json;
use uuid::Uuid;

// 辅助函数：创建测试用户
async fn create_test_user(server: &TestServer) -> (String, String, String) {
    let username = format!("testuser_{}", Uuid::new_v4());
    let email = format!("{}@example.com", username);

    let register_data = json!({
        "username": username,
        "password": "password123",
        "email": email
    });

    let register_response = server.post("/api/v1/auth/register")
        .json(&register_data)
        .await;

    assert_eq!(register_response.status_code(), StatusCode::OK);

    // 登录获取token
    let login_data = json!({
        "username": username,
        "password": "password123"
    });

    let login_response = server.post("/api/v1/auth/login")
        .json(&login_data)
        .await;

    assert_eq!(login_response.status_code(), StatusCode::OK);
    let login_body = login_response.json::<serde_json::Value>().await;
    let token = login_body["data"]["token"].as_str().unwrap().to_string();

    (username, email, token)
}

#[tokio::test]
async fn test_create_room() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token) = create_test_user(&server).await;

    let room_data = json!({
        "name": "Test Group",
        "description": "A test group for testing",
        "room_type": "group"
    });

    let response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>().await;
    assert_eq!(body["room"]["name"], "Test Group");
    assert_eq!(body["room"]["description"], "A test group for testing");
}

#[tokio::test]
async fn test_join_and_leave_room() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap;

    let (_, _, token) = create_test_user(&server).await;

    // 创建聊天室
    let room_data = json!({
        "name": "Test Room",
        "description": "A test room",
        "room_type": "group"
    });

    let room_response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(room_response.status_code(), StatusCode::OK);
    let room_body = room_response.json::<serde_json::Value>().await;
    let room_id = room_body["room"]["id"].as_str().unwrap();

    // 离开聊天室
    let leave_response = server.post(&format!("/api/v1/rooms/{}/leave", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(leave_response.status_code(), StatusCode::OK);
}

#[tokio::test]
async fn test_list_room_members() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token) = create_test_user(&server).await;

    // 创建聊天室
    let room_data = json!({
        "name": "Test Room",
        "description": "A test room",
        "room_type": "group"
    });

    let room_response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(room_response.status_code(), StatusCode::OK);
    let room_body = room_response.json::<serde_json::Value>().await;
    let room_id = room_body["room"]["id"].as_str().unwrap();

    // 获取成员列表
    let members_response = server.get(&format!("/api/v1/rooms/{}/members", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(members_response.status_code(), StatusCode::OK);
    let members_body = members_response.json::<serde_json::Value>().await;
    let members = members_body.as_array().unwrap();
    assert_eq!(members.len(), 1); // 只有创建者
}

#[tokio::test]
async fn test_group_settings() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token) = create_test_user(&server).await;

    // 创建聊天室
    let room_data = json!({
        "name": "Test Room",
        "description": "A test room",
        "room_type": "group"
    });

    let room_response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(room_response.status_code(), StatusCode::OK);
    let room_body = room_response.json::<serde_json::Value>().await;
    let room_id = room_body["room"]["id"].as_str().unwrap();

    // 获取群设置
    let settings_response = server.get(&format!("/api/v1/rooms/{}/settings", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(settings_response.status_code(), StatusCode::OK);

    // 更新群设置
    let update_data = json!({
        "join_approval_required": true,
        "max_members": 100
    });

    let update_response = server.patch(&format!("/api/v1/rooms/{}/settings", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&update_data)
        .await;

    assert_eq!(update_response.status_code(), StatusCode::OK);
}

#[tokio::test]
async fn test_group_rules() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token) = create_test_user(&server).await;

    // 创建聊天室
    let room_data = json!({
        "name": "Test Room",
        "description": "A test room",
        "room_type": "group"
    });

    let room_response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(room_response.status_code(), StatusCode::OK);
    let room_body = room_response.json::<serde_json::Value>().await;
    let room_id = room_body["room"]["id"].as_str().unwrap();

    // 创建群规
    let rule_data = json!({
        "title": "Group Rule 1",
        "content": "Please be respectful to all members"
    });

    let create_response = server.post(&format!("/api/v1/rooms/{}/rules", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&rule_data)
        .await;

    assert_eq!(create_response.status_code(), StatusCode::OK);

    // 获取群规列表
    let list_response = server.get(&format!("/api/v1/rooms/{}/rules", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(list_response.status_code(), StatusCode::OK);
    let list_body = list_response.json::<serde_json::Value>().await;
    let rules = list_body["rules"].as_array().unwrap();
    assert_eq!(rules.len(), 1);
}

#[tokio::test]
async fn test_join_request() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token) = create_test_user(&server).await;

    // 创建聊天室
    let room_data = json!({
        "name": "Test Room",
        "description": "A test room",
        "room_type": "group"
    });

    let room_response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(room_response.status_code(), StatusCode::OK);
    let room_body = room_response.json::<serde_json::Value>().await;
    let room_id = room_body["room"]["id"].as_str().unwrap();

    // 创建入群申请
    let request_data = json!({
        "message": "I would like to join this group"
    });

    let request_response = server.post(&format!("/api/v1/rooms/{}/join-requests", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&request_data)
        .await;

    assert_eq!(request_response.status_code(), StatusCode::OK);
}

#[tokio::test]
async fn test_group_admin_management() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token) = create_test_user(&server).await;

    // 创建聊天室
    let room_data = json!({
        "name": "Test Room",
        "description": "A test room",
        "room_type": "group"
    });

    let room_response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(room_response.status_code(), StatusCode::OK);
    let room_body = room_response.json::<serde_json::Value>().await;
    let room_id = room_body["room"]["id"].as_str().unwrap();

    // 获取管理员列表
    let admins_response = server.get(&format!("/api/v1/rooms/{}/admins", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(admins_response.status_code(), StatusCode::OK);
}

#[tokio::test]
async fn test_mute_user() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token) = create_test_user(&server).await;

    // 创建聊天室
    let room_data = json!({
        "name": "Test Room",
        "description": "A test room",
        "room_type": "group"
    });

    let room_response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(room_response.status_code(), StatusCode::OK);
    let room_body = room_response.json::<serde_json::Value>().await;
    let room_id = room_body["room"]["id"].as_str().unwrap();

    // 获取禁言列表
    let mutes_response = server.get(&format!("/api/v1/rooms/{}/mutes", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(mutes_response.status_code(), StatusCode::OK);
}
