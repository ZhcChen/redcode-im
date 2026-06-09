//! 集成测试共享支撑（harness）
//!
//! 提供：临时数据库生命周期 + 测试态 `AppState` 构造 + `axum` `oneshot` 辅助。
//!
//! 用法：在集成测试文件顶部 `mod support;`，然后 `let app = support::spawn_test_app().await;`，
//! 通过 `app.oneshot_get("/healthz").await` 等辅助发起进程内请求。
//!
//! 约束：`Database::new()` / `RedisManager::new()` 读取**全局**环境变量，
//! 因此集成测试需以 `--test-threads=1` 串行运行（见 Makefile `api.test.integration`）。
//! 本模块用 `ENV_LOCK` 在构造期串行化环境写入，作为额外保护。

#![allow(dead_code)]

use std::sync::Arc;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::Router;
use http_body_util::BodyExt;
use redcode_im_api::logging::{LogStore, PostgresLogStore};
use redcode_im_api::{create_routes, websocket, AppState, Database, RedisManager};
use sqlx::PgPool;
use tower::ServiceExt;
use uuid::Uuid;

/// 串行化构造期的全局 env 写入（配合 `--test-threads=1`）。
static ENV_LOCK: once_cell::sync::Lazy<tokio::sync::Mutex<()>> =
    once_cell::sync::Lazy::new(|| tokio::sync::Mutex::new(()));

/// 每个测试一个临时数据库：基于 `DATABASE_URL` 派生 admin 连接，建 / 删独立库。
/// 复用 `api/tests/database_migration_smoke.rs` 已验证的模式。
pub struct TempDatabase {
    admin_url: String,
    pub url: String,
    name: String,
}

impl TempDatabase {
    pub async fn create() -> Result<Self, Box<dyn std::error::Error>> {
        let base_url = std::env::var("DATABASE_URL")?;
        let (prefix, _) = base_url
            .rsplit_once('/')
            .ok_or("DATABASE_URL 缺少数据库名")?;
        let admin_url = format!("{prefix}/postgres");
        let name = format!("api_it_{}", Uuid::new_v4().simple());
        let url = format!("{prefix}/{name}");

        let admin_pool = PgPool::connect(&admin_url).await?;
        sqlx::query(&format!(r#"CREATE DATABASE "{}""#, name))
            .execute(&admin_pool)
            .await?;
        admin_pool.close().await;

        Ok(Self {
            admin_url,
            url,
            name,
        })
    }

    pub async fn drop_db(&self) {
        if let Ok(admin_pool) = PgPool::connect(&self.admin_url).await {
            let _ = sqlx::query(&format!(
                r#"DROP DATABASE IF EXISTS "{}" WITH (FORCE)"#,
                self.name
            ))
            .execute(&admin_pool)
            .await;
            admin_pool.close().await;
        }
    }
}

/// 测试应用：持有可 `oneshot` 的 Router、底层 pool 与临时库句柄。
pub struct TestApp {
    pub router: Router,
    pub pool: PgPool,
    temp: TempDatabase,
}

impl TestApp {
    /// 通用进程内请求：可选 bearer token、可选 JSON content-type。返回 (状态码, 响应体字节)。
    pub async fn send(
        &self,
        method: &str,
        uri: &str,
        token: Option<&str>,
        body: Body,
        json: bool,
    ) -> (StatusCode, Vec<u8>) {
        let mut builder = Request::builder().method(method).uri(uri);
        if json {
            builder = builder.header("content-type", "application/json");
        }
        if let Some(t) = token {
            builder = builder.header("authorization", format!("Bearer {t}"));
        }
        let req = builder.body(body).expect("构造请求失败");
        let resp = self
            .router
            .clone()
            .oneshot(req)
            .await
            .expect("oneshot 失败");
        let status = resp.status();
        let bytes = resp
            .into_body()
            .collect()
            .await
            .expect("读取响应体失败")
            .to_bytes()
            .to_vec();
        (status, bytes)
    }

    pub async fn get(&self, uri: &str) -> (StatusCode, Vec<u8>) {
        self.send("GET", uri, None, Body::empty(), false).await
    }

    pub async fn get_authed(&self, uri: &str, token: &str) -> (StatusCode, Vec<u8>) {
        self.send("GET", uri, Some(token), Body::empty(), false)
            .await
    }

    pub async fn post_json(&self, uri: &str, json: &str) -> (StatusCode, Vec<u8>) {
        self.send("POST", uri, None, Body::from(json.to_owned()), true)
            .await
    }

    pub async fn post_json_authed(
        &self,
        uri: &str,
        token: &str,
        json: &str,
    ) -> (StatusCode, Vec<u8>) {
        self.send("POST", uri, Some(token), Body::from(json.to_owned()), true)
            .await
    }
}

/// 把响应体字节解析为 JSON Value（测试断言用）。
pub fn body_json(bytes: &[u8]) -> serde_json::Value {
    serde_json::from_slice(bytes).expect("响应体不是合法 JSON")
}

/// 生成唯一测试邮箱，避免持久库跨轮次冲突。
pub fn unique_email(prefix: &str) -> String {
    format!("{prefix}_{}@example.test", Uuid::new_v4().simple())
}

impl Drop for TestApp {
    fn drop(&mut self) {
        // 同步上下文中触发异步清理：临时库用 DROP ... WITH (FORCE) 兜底。
        let temp = TempDatabase {
            admin_url: self.temp.admin_url.clone(),
            url: self.temp.url.clone(),
            name: self.temp.name.clone(),
        };
        // 已有 tokio runtime 时 spawn 一个 blocking 任务执行清理。
        if let Ok(handle) = tokio::runtime::Handle::try_current() {
            handle.spawn(async move {
                temp.drop_db().await;
            });
        }
    }
}

/// 构造测试态应用：建临时库 → 注入测试环境变量 → migrate → 组装 AppState → with_state。
///
/// 依赖前置：`DATABASE_URL`（admin 可建库）、`REDIS_*_URL`、对象存储指向 external-mock 的环境变量，
/// 由瘦身测试 compose 提供（见 docs/reference/testing）。
pub async fn spawn_test_app() -> TestApp {
    let _guard = ENV_LOCK.lock().await;

    let temp = TempDatabase::create().await.expect("创建临时库失败");

    // 让 Database::new() 连到本测试的临时库。
    std::env::set_var("DATABASE_URL", &temp.url);
    // 测试态：迁移基线安全策略保持默认（空库 → 建基线）。
    std::env::remove_var("ALLOW_INSECURE_MIGRATION_BASELINE_ADOPT");

    let database = Database::new().await.expect("Database::new 失败");
    database.migrate().await.expect("迁移失败");

    let redis = RedisManager::new().await.expect("RedisManager::new 失败");

    let log_store: Arc<dyn LogStore> = Arc::new(PostgresLogStore::new(database.pool().clone()));
    let connection_manager = Arc::new(websocket::ConnectionManager::new());

    let pool = database.pool().clone();

    let state = AppState {
        database,
        redis,
        node_id: "test-node".to_string(),
        log_store,
        connection_manager,
    };

    let router = create_routes().with_state(state);

    TestApp { router, pool, temp }
}
