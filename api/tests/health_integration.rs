mod support;

use axum::http::StatusCode;

/// 健康检查（liveness）：harness 装配的 Router 能进程内响应 /healthz。
#[tokio::test]
async fn healthz_returns_ok() {
    let app = support::spawn_test_app().await;
    let (status, _body) = app.get("/healthz").await;
    assert_eq!(status, StatusCode::OK);
}

/// 就绪检查（readiness）：DB / Redis 就绪时 /readyz 返回 200，证明 state 真连到依赖。
#[tokio::test]
async fn readyz_returns_ok() {
    let app = support::spawn_test_app().await;
    let (status, _body) = app.get("/readyz").await;
    assert_eq!(status, StatusCode::OK);
}
