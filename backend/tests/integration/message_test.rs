use axum::http::StatusCode;
use axum_test::{TestServer, TestServerConfig};
use redcode_im_backend::*;
use serde_json::json;
use uuid::Uuid;

// 辅助函数：创建测试token
async fn create_test_user_and_token(server: &TestServer) -> (String, String) {
    // 注册用户
    let register_data = json!({
        "username": format!("testuser_{}", Uuid::new_v4()),
        "password": "password123",
        "email": "test@example.com"
    });

    let register_response = server.post("/api/v1/auth/register")
        .json(&register_data)
        .await;

    assert_eq!(register_response.status_code(), StatusCode::OK);

    // 登录获取token
    let login_data = json!({
        "username": register_data["username"],
        "password": "password123"
    });

    let login_response = server.post("/api/v1/auth/login")
        .json(&login_data)
        .await;

    assert_eq!(login_response.status_code(), StatusCode::OK);
    let login_body = login_response.json::<serde_json::Value>().await;
    let token = login_body["data"]["token"].as_str().unwrap().to_string();

    (register_data["username"].as_str().unwrap().to_string(), token)
}

#[tokio::test]
async fn test_send_message() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (username, token) = create_test_user_and_token(&server).await;

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

    // 发送消息
    let message_data = json!({
        "content": "Hello, world!"
    });

    let message_response = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&message_data)
        .await;

    assert_eq!(message_response.status_code(), StatusCode::OK);
    let message_body = message_response.json::<serde_json::Value>().await;
    assert!(message_body["data"].get("content").is_some());
}

#[tokio::test]
async fn test_get_messages() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (username, token) = create_test_user_and_token(&server).await;

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

    // 发送几条消息
    for i in 1..=5 {
        let message_data = json!({
            "content": format!("Message {}", i)
        });

        let _ = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
            .add_header("Authorization", format!("Bearer {}", token))
            .json(&message_data)
            .await;
    }

    // 获取消息列表
    let response = server.get(&format!("/api/v1/rooms/{}/messages", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>().await;
    let messages = body["data"].as_array().unwrap();
    assert_eq!(messages.len(), 5);
}

#[tokio::test]
async fn test_delete_message() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (username, token) = create_test_user_and_token(&server).await;

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

    // 发送消息
    let message_data = json!({
        "content": "Message to delete"
    });

    let message_response = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&message_data)
        .await;

    assert_eq!(message_response.status_code(), StatusCode::OK);
    let message_body = message_response.json::<serde_json::Value>().await;
    let message_id = message_body["data"]["id"].as_str().unwrap();

    // 删除消息
    let delete_response = server.delete(&format!("/api/v1/rooms/{}/messages/{}", room_id, message_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(delete_response.status_code(), StatusCode::NO_CONTENT);
}

#[tokio::test]
async fn test_mark_message_as_read() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (username, token) = create_test_user_and_token(&server).await;

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

    // 发送消息
    let message_data = json!({
        "content": "Test message"
    });

    let message_response = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&message_data)
        .await;

    assert_eq!(message_response.status_code(), StatusCode::OK);
    let message_body = message_response.json::<serde_json::Value>().await;
    let message_id = message_body["data"]["id"].as_str().unwrap();

    // 标记为已读
    let read_response = server.post(&format!("/api/v1/rooms/{}/messages/{}/read", room_id, message_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(read_response.status_code(), StatusCode::OK);
}

#[tokio::test]
async fn test_pin_unpin_message() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (username, token) = create_test_user_and_token(&server).await;

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

    // 发送消息
    let message_data = json!({
        "content": "Message to pin"
    });

    let message_response = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&message_data)
        .await;

    assert_eq!(message_response.status_code(), StatusCode::OK);
    let message_body = message_response.json::<serde_json::Value>().await;
    let message_id = message_body["data"]["id"].as_str().unwrap();

    // 置顶消息
    let pin_response = server.post(&format!("/api/v1/rooms/{}/messages/{}/pin", room_id, message_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(pin_response.status_code(), StatusCode::OK);
    let pin_body = pin_response.json::<serde_json::Value>().await;
    assert!(pin_body["data"]["is_pinned"].as_bool().unwrap());

    // 取消置顶
    let unpin_response = server.delete(&format!("/api/v1/rooms/{}/messages/{}/pin", room_id, message_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(unpin_response.status_code(), StatusCode::OK);
}
