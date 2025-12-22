//! 安全中间件
//!
//! 提供安全相关的中间件功能，包括：
//! - 安全头设置
//! - 速率限制
//! - CORS 配置
//! - 请求验证

use axum::{
    extract::ConnectInfo,
    http::{HeaderValue, Method, StatusCode},
    middleware::Next,
    response::Response,
};
use std::{
    net::SocketAddr,
    time::{Duration, SystemTime, UNIX_EPOCH},
};
use tokio::sync::RwLock;
use std::collections::HashMap;
use tracing::warn;

/// IP 速率限制存储
pub struct RateLimitStore {
    /// 存储每个 IP 的请求记录
    requests: RwLock<HashMap<String, Vec<u64>>>,
    /// 时间窗口（秒）
    window_size: u64,
    /// 最大请求数
    max_requests: u64,
}

impl RateLimitStore {
    /// 创建新的速率限制存储
    pub fn new(window_size: u64, max_requests: u64) -> Self {
        Self {
            requests: RwLock::new(HashMap::new()),
            window_size,
            max_requests,
        }
    }

    /// 检查 IP 是否超过速率限制
    pub async fn is_rate_limited(&self, ip: &str) -> bool {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let mut requests = self.requests.write().await;

        // 清理过期记录
        let window_start = now.saturating_sub(self.window_size);
        if let Some(ips) = requests.get_mut(ip) {
            ips.retain(|&ts| ts >= window_start);
        }

        // 检查是否超过限制
        if let Some(ips) = requests.get(ip) {
            if ips.len() >= self.max_requests as usize {
                return true;
            }
        }

        // 记录当前请求
        requests.entry(ip.to_string()).or_insert_with(Vec::new).push(now);
        false
    }

    /// 清理所有过期记录
    pub async fn cleanup(&self) {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let window_start = now.saturating_sub(self.window_size);

        let mut requests = self.requests.write().await;
        for ips in requests.values_mut() {
            ips.retain(|&ts| ts >= window_start);
        }
    }
}

/// 安全头中间件
pub async fn security_headers(
    request: axum::extract::Request,
    next: Next,
) -> Response {
    let mut response = next.run(request).await;

    // 添加安全头
    let headers = response.headers_mut();

    // 防止 MIME 类型嗅探
    headers.insert(
        "X-Content-Type-Options",
        HeaderValue::from_static("nosniff"),
    );

    // XSS 保护
    headers.insert(
        "X-XSS-Protection",
        HeaderValue::from_static("1; mode=block"),
    );

    // 防止页面被嵌入 iframe
    headers.insert(
        "X-Frame-Options",
        HeaderValue::from_static("DENY"),
    );

    // 严格的传输安全（仅 HTTPS）
    headers.insert(
        "Strict-Transport-Security",
        HeaderValue::from_static("max-age=31536000; includeSubDomains; preload"),
    );

    // 内容安全策略
    headers.insert(
        "Content-Security-Policy",
        HeaderValue::from_static(
            "default-src 'self'; \
             script-src 'self' 'unsafe-inline' 'unsafe-eval'; \
             style-src 'self' 'unsafe-inline'; \
             img-src 'self' data: https:; \
             font-src 'self' data:; \
             connect-src 'self' wss: https:; \
             media-src 'self'; \
             object-src 'none'; \
             frame-ancestors 'none';",
        ),
    );

    // 引用者策略
    headers.insert(
        "Referrer-Policy",
        HeaderValue::from_static("strict-origin-when-cross-origin"),
    );

    // 权限策略
    headers.insert(
        "Permissions-Policy",
        HeaderValue::from_static(
            "camera=(), \
             microphone=(), \
             geolocation=(), \
             interest-cohort=()",
        ),
    );

    response
}

/// 速率限制中间件
pub async fn rate_limit_middleware(
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    rate_limit_store: axum::extract::State<RateLimitStore>,
    request: axum::extract::Request,
    next: Next,
) -> Result<Response, (StatusCode, String)> {
    let ip = addr.ip().to_string();
    let uri = request.uri().clone();

    // 跳过健康检查和静态资源的速率限制
    let skip_paths = ["/healthz", "/metrics", "/favicon.ico"];
    if skip_paths.iter().any(|path| uri.path().starts_with(path)) {
        return Ok(next.run(request).await);
    }

    // 检查速率限制
    if rate_limit_store.is_rate_limited(&ip).await {
        warn!("Rate limit exceeded for IP: {}", ip);
        return Err((
            StatusCode::TOO_MANY_REQUESTS,
            format!(
                "Too many requests from {}. Please try again later.",
                ip
            ),
        ));
    }

    Ok(next.run(request).await)
}

/// API 密钥验证中间件
pub async fn api_key_validation(
    request: axum::extract::Request,
    next: Next,
) -> Result<Response, (StatusCode, String)> {
    // 获取 API 密钥（如果需要）
    let api_key = request.headers()
        .get("X-API-Key")
        .and_then(|v| v.to_str().ok());

    // 验证 API 密钥（这里应该从数据库或配置中验证）
    // 暂时简化处理
    if let Some(key) = api_key {
        if !is_valid_api_key(key).await {
            return Err((StatusCode::UNAUTHORIZED, "Invalid API key".to_string()));
        }
    }

    Ok(next.run(request).await)
}

/// 验证 API 密钥（示例实现）
async fn is_valid_api_key(key: &str) -> bool {
    // 实际实现中应该从数据库或配置中验证
    // 这里只是示例
    !key.is_empty() && key.len() >= 32
}

/// 创建 CORS 层
pub fn create_cors_layer() -> tower_http::cors::CorsLayer {
    tower_http::cors::CorsLayer::new()
        // 允许的来源
        .allow_origin([
            "https://redcode-im.com".parse().unwrap(),
            "https://www.redcode-im.com".parse().unwrap(),
            "http://localhost:8010".parse().unwrap(),
            "http://localhost:1420".parse().unwrap(),
        ])
        // 允许的方法
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::PATCH,
            Method::DELETE,
            Method::HEAD,
            Method::OPTIONS,
        ])
        // 允许的请求头
        .allow_headers([
            axum::http::header::CONTENT_TYPE,
            axum::http::header::AUTHORIZATION,
            axum::http::header::ACCEPT,
            axum::http::header::HeaderName::from_static("x-requested-with"),
            axum::http::header::HeaderName::from_static("x-api-key"),
        ])
        // 允许凭证
        .allow_credentials(true)
        // 暴露的响应头
        .expose_headers([
            axum::http::header::CONTENT_TYPE,
            axum::http::header::HeaderName::from_static("x-ratelimit-limit"),
            axum::http::header::HeaderName::from_static("x-ratelimit-remaining"),
            axum::http::header::HeaderName::from_static("x-ratelimit-reset"),
        ])
        // 设置预检缓存时间（1小时）
        .max_age(Duration::from_secs(3600))
}

/// JWT 安全增强
pub mod jwt_security {
    use jsonwebtoken::{Validation};
    use serde::{Deserialize, Serialize};

    /// JWT 声明结构
    #[derive(Debug, Serialize, Deserialize)]
    pub struct Claims {
        /// 用户ID
        pub sub: String,
        /// 用户名
        pub username: String,
        /// 发行者
        pub iss: String,
        /// 受众
        pub aud: String,
        /// 过期时间
        pub exp: u64,
        /// 签发时间
        pub iat: u64,
        /// 令牌ID（用于撤销）
        pub jti: String,
    }

    /// 创建更安全的 JWT 声明
    pub fn create_claims(
        user_id: &str,
        username: &str,
        issuer: &str,
        audience: &str,
        ttl_seconds: u64,
    ) -> Claims {
        use std::time::{SystemTime, UNIX_EPOCH};

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        Claims {
            sub: user_id.to_string(),
            username: username.to_string(),
            iss: issuer.to_string(),
            aud: audience.to_string(),
            exp: now + ttl_seconds,
            iat: now,
            jti: uuid::Uuid::new_v4().to_string(),
        }
    }

    /// 验证 JWT 声明
    pub fn validate_claims(
        claims: &Claims,
        issuer: &str,
        audience: &str,
    ) -> Result<(), jsonwebtoken::errors::Error> {
        let mut validation = Validation::default();
        validation.set_issuer(&[issuer]);
        validation.set_audience(&[audience]);

        use std::time::{SystemTime, UNIX_EPOCH};
        // 验证过期时间
        if claims.exp < SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
        {
            return Err(jsonwebtoken::errors::ErrorKind::ExpiredSignature.into());
        }

        Ok(())
    }
}
