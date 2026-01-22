//! 健康检查 API 测试
//!
//! 覆盖 `handlers/health.rs` 中的 readyz 端点。

use super::common::{empty_request, read_json, test_router, test_state};
use axum::http::{Method, StatusCode};
use tower::ServiceExt;

#[tokio::test]
async fn readyz_returns_ok_with_checks() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/readyz", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(json.get("status").and_then(|v| v.as_str()), Some("ok"));
    assert!(json.get("checks").is_some(), "响应应包含 checks 字段");
}

#[tokio::test]
async fn readyz_checks_database_status() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/readyz", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);

    let checks = json.get("checks").expect("响应缺少 checks 字段");
    let database = checks.get("database").expect("checks 缺少 database 字段");
    assert_eq!(
        database.get("status").and_then(|v| v.as_str()),
        Some("ok"),
        "数据库状态应为 ok"
    );
    assert!(
        database.get("latencyMs").is_some(),
        "数据库检查应包含 latencyMs"
    );
}

#[tokio::test]
async fn readyz_checks_redis_session_status() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/readyz", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);

    let checks = json.get("checks").expect("响应缺少 checks 字段");
    let redis_session = checks
        .get("redisSession")
        .expect("checks 缺少 redisSession 字段");
    assert_eq!(
        redis_session.get("status").and_then(|v| v.as_str()),
        Some("ok"),
        "Redis Session 状态应为 ok"
    );
}

#[tokio::test]
async fn readyz_checks_redis_cache_status() {
    let state = test_state().await;
    let app = test_router(state);

    let response = app
        .oneshot(empty_request(Method::GET, "/readyz", None))
        .await
        .expect("请求失败");

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);

    let checks = json.get("checks").expect("响应缺少 checks 字段");
    let redis_cache = checks
        .get("redisCache")
        .expect("checks 缺少 redisCache 字段");
    assert_eq!(
        redis_cache.get("status").and_then(|v| v.as_str()),
        Some("ok"),
        "Redis Cache 状态应为 ok"
    );
}
