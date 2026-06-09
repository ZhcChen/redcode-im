use crate::AppState;
use axum::{
    body::Body,
    extract::State,
    http::{Method, Request},
    middleware::Next,
    response::Response,
};
use std::time::Instant;

/// API 性能监控中间件
pub async fn metrics_middleware(
    State(state): State<AppState>,
    method: Method,
    uri: axum::http::Uri,
    request: Request<Body>,
    next: Next,
) -> Response {
    let start = Instant::now();
    let path = uri.path().to_string();

    // 跳过健康检查等非业务接口，减少 Redis 压力
    let skip_paths = ["/healthz", "/readyz", "/ws"];
    if skip_paths.iter().any(|p| path == *p) {
        return next.run(request).await;
    }

    let response = next.run(request).await;

    let duration = start.elapsed().as_millis() as u64;
    let status = response.status().as_u16();

    // 异步记录指标，避免阻塞请求响应
    let redis = state.redis.get_session_manager(state.node_id.clone());
    tokio::spawn(async move {
        if let Err(e) = redis
            .record_api_metric(method.as_str(), &path, duration, status)
            .await
        {
            tracing::error!("Failed to record API metric: {:?}", e);
        }
    });

    response
}
