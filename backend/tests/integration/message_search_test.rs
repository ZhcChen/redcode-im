use axum::http::StatusCode;
use axum_test::{TestServer, TestServerConfig};
use redcode_im_backend::*;
use serde_json::json;
use uuid::Uuid;

// 辅助函数：创建测试用户和房间
async fn create_test_user_and_room(server: &TestServer) -> (String, String, String, String) {
    let username = format!("testuser_{}", Uuid::new_v4());
    let email = format!("{}@example.com", username);

    // 注册用户
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

    // 创建聊天室
    let room_data = json!({
        "name": "Test Room",
        "description": "A test room for search",
        "room_type": "group"
    });

    let room_response = server.post("/api/v1/rooms")
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&room_data)
        .await;

    assert_eq!(room_response.status_code(), StatusCode::OK);
    let room_body = room_response.json::<serde_json::Value>().await;
    let room_id = room_body["room"]["id"].as_str().unwrap().to_string();

    (username, email, token, room_id)
}

#[tokio::test]
async fn test_search_messages() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, room_id) = create_test_user_and_room(&server).await;

    // 发送测试消息
    let messages = vec![
        "Hello world",
        "This is a test message",
        "Search for this specific text",
        "Another message with keywords",
        "Testing search functionality"
    ];

    for msg in &messages {
        let message_data = json!({ "content": msg });
        let _ = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
            .add_header("Authorization", format!("Bearer {}", token))
            .json(&message_data)
            .await;
    }

    // 搜索消息
    let search_params = vec![
        ("test", 2),  // 期望2条结果
        ("hello", 1), // 期望1条结果
        ("notfound", 0), // 期望0条结果
        ("message", 4), // 期望4条结果
    ];

    for (query, expected_count) in search_params {
        let response = server.get("/api/v1/messages/search")
            .add_header("Authorization", format!("Bearer {}", token))
            .query(&[("query", query)])
            .await;

        assert_eq!(response.status_code(), StatusCode::OK);
        let body = response.json::<serde_json::Value>().await;
        let results = body["results"].as_array().unwrap();
        assert_eq!(results.len(), expected_count, "Query: {}", query);
    }
}

#[tokio::test]
async fn test_search_messages_with_filters() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, room_id) = create_test_user_and_room(&server).await;

    // 发送测试消息
    let messages = vec![
        "Message in room 1",
        "Message in room 2",
        "Another message"
    ];

    for msg in &messages {
        let message_data = json!({ "content": msg });
        let _ = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
            .add_header("Authorization", format!("Bearer {}", token))
            .json(&message_data)
            .await;
    }

    // 使用房间过滤器搜索
    let response = server.get("/api/v1/messages/search")
        .add_header("Authorization", format!("Bearer {}", token))
        .query(&[
            ("query", "message"),
            ("room_id", &room_id)
        ])
        .await;

    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>().await;
    let results = body["results"].as_array().unwrap();
    assert_eq!(results.len(), 3);

    // 验证返回的结果包含正确的房间信息
    for result in results {
        assert_eq!(result["room_id"], room_id);
    }
}

#[tokio::test]
async fn test_search_messages_date_filter() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, room_id) = create_test_user_and_room(&server).await;

    // 发送测试消息
    let message_data = json!({ "content": "Test message" });
    let _ = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
        .add_header("Authorization", format!("Bearer {}", token))
        .json(&message_data)
        .await;

    // 获取当前时间戳
    let now = chrono::Utc::now();
    let today = now.timestamp();
    let yesterday = (now - chrono::Duration::days(1)).timestamp();

    // 使用日期范围过滤器搜索
    let response = server.get("/api/v1/messages/search")
        .add_header("Authorization", format!("Bearer {}", token))
        .query(&[
            ("query", "test"),
            ("date_from", &yesterday.to_string()),
            ("date_to", &today.to_string())
        ])
        .await;

    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>().await;
    let results = body["results"].as_array().unwrap();
    assert!(results.len() >= 1);
}

#[tokio::test]
async fn test_search_messages_empty_query() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, _) = create_test_user_and_room(&server).await;

    // 使用空查询搜索（应该返回错误）
    let response = server.get("/api/v1/messages/search")
        .add_header("Authorization", format!("Bearer {}", token))
        .query(&[("query", "")])
        .await;

    assert_eq!(response.status_code(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn test_search_messages_long_query() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, _) = create_test_user_and_room(&server).await;

    // 使用过长的查询字符串（应该返回错误）
    let long_query = "a".repeat(201);
    let response = server.get("/api/v1/messages/search")
        .add_header("Authorization", format!("Bearer {}", token))
        .query(&[("query", &long_query)])
        .await;

    assert_eq!(response.status_code(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn test_search_suggestions() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, room_id) = create_test_user_and_room(&server).await;

    // 发送包含特定关键词的消息
    let messages = vec![
        "project planning",
        "project status",
        "project timeline",
        "meeting agenda"
    ];

    for msg in &messages {
        let message_data = json!({ "content": msg });
        let _ = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
            .add_header("Authorization", format!("Bearer {}", token))
            .json(&message_data)
            .await;
    }

    // 获取搜索建议
    let response = server.get("/api/v1/messages/search/suggestions")
        .add_header("Authorization", format!("Bearer {}", token))
        .query(&[("prefix", "proj")])
        .await;

    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>().await;
    let suggestions = body.as_array().unwrap();
    assert!(suggestions.len() > 0);
}

#[tokio::test]
async fn test_search_suggestions_empty_prefix() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, _) = create_test_user_and_room(&server).await;

    // 使用空前缀获取建议（应该返回空列表）
    let response = server.get("/api/v1/messages/search/suggestions")
        .add_header("Authorization", format!("Bearer {}", token))
        .query(&[("prefix", "")])
        .await;

    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>().await;
    let suggestions = body.as_array().unwrap();
    assert_eq!(suggestions.len(), 0);
}

#[tokio::test]
async fn test_get_trending_keywords() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, room_id) = create_test_user_and_room(&server).await;

    // 发送多条包含相同关键词的消息
    let common_word = "important";
    for i in 1..=10 {
        let message_data = json!({ "content": format!("This is {} message number {}", common_word, i) });
        let _ = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
            .add_header("Authorization", format!("Bearer {}", token))
            .json(&message_data)
            .await;
    }

    // 获取热门关键词
    let response = server.get("/api/v1/messages/search/trending")
        .add_header("Authorization", format!("Bearer {}", token))
        .await;

    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>().await;
    let keywords = body.as_array().unwrap();
    assert!(keywords.len() > 0);

    // 验证返回的关键词包含我们的热门词
    let keyword_found = keywords.iter().any(|k| {
        k["keyword"].as_str() == Some(common_word)
    });
    assert!(keyword_found, "Should find the trending keyword");
}

#[tokio::test]
async fn test_search_results_pagination() {
    let app = create_routes();
    let config = TestServerConfig::builder()
        .expect_failure_handlers()
        .test_config();
    let server = TestServer::new_with_config(app, config).unwrap();

    let (_, _, token, room_id) = create_test_user_and_room(&server).await;

    // 发送多条消息
    for i in 1..=30 {
        let message_data = json!({ "content": format!("Message number {} with test keyword", i) });
        let _ = server.post(&format!("/api/v1/rooms/{}/messages", room_id))
            .add_header("Authorization", format!("Bearer {}", token))
            .json(&message_data)
            .await;
    }

    // 第一页
    let response1 = server.get("/api/v1/messages/search")
        .add_header("Authorization", format!("Bearer {}", token))
        .query(&[
            ("query", "test"),
            ("limit", "10"),
            ("offset", "0")
        ])
        .await;

    assert_eq!(response1.status_code(), StatusCode::OK);
    let body1 = response1.json::<serde_json::Value>().await;
    let results1 = body1["results"].as_array().unwrap();
    assert_eq!(results1.len(), 10);

    // 第二页
    let response2 = server.get("/api/v1/messages/search")
        .add_header("Authorization", format!("Bearer {}", token))
        .query(&[
            ("query", "test"),
            ("limit", "10"),
            ("offset", "10")
        ])
        .await;

    assert_eq!(response2.status_code(), StatusCode::OK);
    let body2 = response2.json::<serde_json::Value>().await;
    let results2 = body2["results"].as_array().unwrap();
    assert_eq!(results2.len(), 10);

    // 验证分页结果不重复
    let ids1: Vec<&str> = results1.iter().map(|r| r["id"].as_str().unwrap()).collect();
    let ids2: Vec<&str> = results2.iter().map(|r| r["id"].as_str().unwrap()).collect();
    assert!(!ids1.iter().any(|id| ids2.contains(id)));
}
