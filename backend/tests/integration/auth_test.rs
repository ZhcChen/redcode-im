use axum::http::{HeaderValue, Method, StatusCode};
use axum_test::TestServer;
use redcode_im_backend::*;
use serde_json::json;

#[tokio::test]
async fn test_register_user() {
    // 设置测试服务器
    let app = create_routes();
    let server = TestServer::new(app).unwrap();

    // 测试注册数据
    let register_data = json!({
        "username": "testuser",
        "password": "password123",
        "email": "test@example.com"
    });

    // 发送注册请求
    let response = server.post("/api/v1/auth/register")
        .json(&register_data)
        .await;

    // 验证响应
    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>();
    assert!(body.get("success").is_some());
}

#[tokio::test]
async fn test_login_success() {
    let app = create_routes();
    let server = TestServer::new(app).unwrap();

    // 首先注册用户
    let register_data = json!({
        "username": "testuser",
        "password": "password123",
        "email": "test@example.com"
    });
    let _ = server.post("/api/v1/auth/register")
        .json(&register_data)
        .await;

    // 尝试登录
    let login_data = json!({
        "username": "testuser",
        "password": "password123"
    });

    let response = server.post("/api/v1/auth/login")
        .json(&login_data)
        .await;

    assert_eq!(response.status_code(), StatusCode::OK);
    let body = response.json::<serde_json::Value>();
    assert!(body.get("success").is_some());
    assert!(body.get("data").get("token").is_some());
}

#[tokio::test]
async fn test_login_invalid_credentials() {
    let app = create_routes();
    let server = TestServer::new(app).unwrap();

    // 尝试使用错误的凭证登录
    let login_data = json!({
        "username": "nonexistent",
        "password": "wrongpassword"
    });

    let response = server.post("/api/v1/auth/login")
        .json(&login_data)
        .await;

    assert_eq!(response.status_code(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn test_auth_middleware_protects_route() {
    let app = create_routes();
    let server = TestServer::new(app).unwrap();

    // 在没有token的情况下尝试访问受保护的路由
    let response = server.get("/api/v1/user/profile")
        .await;

    assert_eq!(response.status_code(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn test_invalid_token() {
    let app = create_routes();
    let server = TestServer::new(app).unwrap();

    // 尝试使用无效token访问受保护的路由
    let response = server.get("/api/v1/user/profile")
        .add_header("Authorization", "Bearer invalid.token.here")
        .await;

    assert_eq!(response.status_code(), StatusCode::UNAUTHORIZED);
}
#![cfg(feature = "with_axum_test")]
