//! 用户 API 测试
//!
//! 覆盖 `handlers/user.rs` 中的用户相关接口。

use super::common::{
    empty_request, json_request, login_user, read_json, register_user, test_router, test_state,
    unique_phone_username,
};
use axum::http::{Method, StatusCode};
use serde_json::json;
use tower::ServiceExt;

#[tokio::test]
async fn update_me_changes_nickname() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册并登录
    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 更新昵称
    let new_nickname = format!("测试昵称_{}", uuid::Uuid::new_v4().simple());
    let update_body = json!({
        "nickname": new_nickname
    });

    let response = app
        .clone()
        .oneshot(json_request(Method::PATCH, "/users/me", Some(&token), update_body))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "更新昵称应成功: {json}");
    assert_eq!(
        json.get("nickname").and_then(|v| v.as_str()),
        Some(new_nickname.as_str()),
        "昵称应已更新"
    );
}

#[tokio::test]
async fn change_password_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let old_password = "Test123456";
    let new_password = "NewPass789";

    // 注册并登录
    let _ = register_user(app.clone(), &username, old_password).await;
    let token = login_user(app.clone(), &username, old_password).await;

    // 修改密码
    let change_body = json!({
        "old_password": old_password,
        "new_password": new_password
    });

    let response = app
        .clone()
        .oneshot(json_request(
            Method::POST,
            "/users/me/password",
            Some(&token),
            change_body,
        ))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "修改密码应成功: {json}");
    assert_eq!(
        json.get("success").and_then(|v| v.as_bool()),
        Some(true),
        "success 应为 true"
    );

    // 验证新密码可以登录
    let new_token = login_user(app.clone(), &username, new_password).await;
    assert!(!new_token.is_empty(), "应能使用新密码登录");
}

#[tokio::test]
async fn change_password_wrong_old_password_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册并登录
    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 使用错误的旧密码
    let change_body = json!({
        "old_password": "WrongOldPassword",
        "new_password": "NewPass789"
    });

    let response = app
        .oneshot(json_request(
            Method::POST,
            "/users/me/password",
            Some(&token),
            change_body,
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "错误的旧密码应返回 400"
    );
}

#[tokio::test]
async fn change_password_short_new_password_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册并登录
    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 新密码太短
    let change_body = json!({
        "old_password": password,
        "new_password": "12345"
    });

    let response = app
        .oneshot(json_request(
            Method::POST,
            "/users/me/password",
            Some(&token),
            change_body,
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "太短的新密码应返回 400"
    );
}

#[tokio::test]
async fn search_users_returns_results() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册并登录
    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 搜索用户（搜索自己的用户名）
    let search_keyword = &username[..5]; // 取前 5 位
    let uri = format!("/users/search?keyword={}", search_keyword);

    let response = app
        .oneshot(empty_request(Method::GET, &uri, Some(&token)))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "搜索应成功: {json}");
    assert!(json.is_array(), "响应应为数组");
}

#[tokio::test]
async fn search_users_empty_keyword_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册并登录
    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 空关键字搜索
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/users/search?keyword=",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "空关键字应返回 400"
    );
}

#[tokio::test]
async fn search_users_whitespace_keyword_fails() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册并登录
    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 空白关键字搜索
    let response = app
        .oneshot(empty_request(
            Method::GET,
            "/users/search?keyword=%20%20%20",
            Some(&token),
        ))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::BAD_REQUEST,
        "空白关键字应返回 400"
    );
}

#[tokio::test]
async fn get_user_by_id_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册
    let user_id = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 获取用户信息
    let uri = format!("/users/{}", user_id);
    let response = app
        .oneshot(empty_request(Method::GET, &uri, Some(&token)))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取用户信息应成功: {json}");
    assert_eq!(
        json.get("id").and_then(|v| v.as_str()),
        Some(user_id.as_str()),
        "返回的用户 ID 应匹配"
    );
}

#[tokio::test]
async fn get_user_by_id_not_found() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册并登录
    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 查询不存在的用户
    let fake_id = uuid::Uuid::new_v4().to_string();
    let uri = format!("/users/{}", fake_id);
    let response = app
        .oneshot(empty_request(Method::GET, &uri, Some(&token)))
        .await
        .expect("请求失败");

    assert_eq!(
        response.status(),
        StatusCode::NOT_FOUND,
        "不存在的用户应返回 404"
    );
}

#[tokio::test]
async fn deactivate_me_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    // 注册并登录
    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    // 注销账号
    let response = app
        .clone()
        .oneshot(empty_request(Method::DELETE, "/users/me", Some(&token)))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "注销应成功: {json}");
    assert_eq!(
        json.get("success").and_then(|v| v.as_bool()),
        Some(true),
        "success 应为 true"
    );

    // 验证无法再登录
    let login_body = json!({
        "username": username,
        "password": password
    });
    let login_response = app
        .oneshot(json_request(Method::POST, "/auth/login", None, login_body))
        .await
        .expect("请求失败");

    assert_eq!(
        login_response.status(),
        StatusCode::UNAUTHORIZED,
        "注销后应无法登录"
    );
}

// ============================================================================
// Phase 8: 全局未读数测试
// ============================================================================

#[tokio::test]
async fn get_global_unread_counts_success() {
    let state = test_state().await;
    let app = test_router(state);

    let username = unique_phone_username();
    let password = "Test123456";

    let _ = register_user(app.clone(), &username, password).await;
    let token = login_user(app.clone(), &username, password).await;

    let response = app
        .oneshot(empty_request(Method::GET, "/unread_counts", Some(&token)))
        .await
        .expect("请求失败");

    let (status, resp) = read_json(response).await;
    assert_eq!(status, StatusCode::OK, "获取全局未读数失败: {resp}");
}

#[tokio::test]
async fn get_global_unread_counts_requires_auth() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/unread_counts", None))
        .await
        .expect("请求失败");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}
