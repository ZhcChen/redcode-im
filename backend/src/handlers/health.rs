//! 健康检查端点
//!
//! 提供服务就绪状态检查，用于 Kubernetes readinessProbe 和负载均衡器健康检查。

use axum::{extract::State, http::StatusCode, Json};
use serde::Serialize;
use std::time::Instant;

use crate::AppState;

/// 单个组件的健康检查结果
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ComponentCheck {
    pub status: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub latency_ms: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl ComponentCheck {
    fn ok(latency_ms: u64) -> Self {
        Self {
            status: "ok",
            latency_ms: Some(latency_ms),
            error: None,
        }
    }

    fn error(err: String) -> Self {
        Self {
            status: "error",
            latency_ms: None,
            error: Some(err),
        }
    }
}

/// 健康检查详情
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HealthChecks {
    pub database: ComponentCheck,
    pub redis_session: ComponentCheck,
    pub redis_cache: ComponentCheck,
}

/// 健康检查响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ReadyzResponse {
    pub status: &'static str,
    pub checks: HealthChecks,
}

/// 就绪检查端点
///
/// 检查所有依赖服务（PostgreSQL、Redis）的连接状态。
/// - 成功：返回 200 OK
/// - 失败：返回 503 Service Unavailable
pub async fn readyz(State(state): State<AppState>) -> (StatusCode, Json<ReadyzResponse>) {
    // 并行检查所有组件
    let (db_check, redis_session_check, redis_cache_check) = tokio::join!(
        check_database(&state),
        check_redis_session(&state),
        check_redis_cache(&state),
    );

    // 判断整体状态
    let all_ok = db_check.status == "ok"
        && redis_session_check.status == "ok"
        && redis_cache_check.status == "ok";

    let response = ReadyzResponse {
        status: if all_ok { "ok" } else { "unhealthy" },
        checks: HealthChecks {
            database: db_check,
            redis_session: redis_session_check,
            redis_cache: redis_cache_check,
        },
    };

    let status_code = if all_ok {
        StatusCode::OK
    } else {
        StatusCode::SERVICE_UNAVAILABLE
    };

    (status_code, Json(response))
}

/// 检查 PostgreSQL 连接
async fn check_database(state: &AppState) -> ComponentCheck {
    let start = Instant::now();

    match tokio::time::timeout(
        std::time::Duration::from_secs(3),
        sqlx::query_scalar::<_, i32>("SELECT 1").fetch_one(&state.database.pool),
    )
    .await
    {
        Ok(Ok(_)) => ComponentCheck::ok(start.elapsed().as_millis() as u64),
        Ok(Err(e)) => ComponentCheck::error(format!("query failed: {}", e)),
        Err(_) => ComponentCheck::error("timeout".to_string()),
    }
}

/// 检查 Redis Session 连接
async fn check_redis_session(state: &AppState) -> ComponentCheck {
    let start = Instant::now();

    match tokio::time::timeout(std::time::Duration::from_secs(3), async {
        let mut conn = state
            .redis
            .get_session_client()
            .get_multiplexed_async_connection()
            .await?;
        redis::cmd("PING").query_async::<String>(&mut conn).await
    })
    .await
    {
        Ok(Ok(pong)) if pong == "PONG" => ComponentCheck::ok(start.elapsed().as_millis() as u64),
        Ok(Ok(unexpected)) => ComponentCheck::error(format!("unexpected response: {}", unexpected)),
        Ok(Err(e)) => ComponentCheck::error(format!("redis error: {}", e)),
        Err(_) => ComponentCheck::error("timeout".to_string()),
    }
}

/// 检查 Redis Cache 连接
async fn check_redis_cache(state: &AppState) -> ComponentCheck {
    let start = Instant::now();

    match tokio::time::timeout(std::time::Duration::from_secs(3), async {
        let mut conn = state
            .redis
            .get_cache_client()
            .get_multiplexed_async_connection()
            .await?;
        redis::cmd("PING").query_async::<String>(&mut conn).await
    })
    .await
    {
        Ok(Ok(pong)) if pong == "PONG" => ComponentCheck::ok(start.elapsed().as_millis() as u64),
        Ok(Ok(unexpected)) => ComponentCheck::error(format!("unexpected response: {}", unexpected)),
        Ok(Err(e)) => ComponentCheck::error(format!("redis error: {}", e)),
        Err(_) => ComponentCheck::error("timeout".to_string()),
    }
}
