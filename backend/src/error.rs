use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde::{Deserialize, Serialize};
use std::fmt;
use tracing::Level;

use crate::i18n::{localizer::default_localizer, message::MessageParams};
use crate::middleware::current_request_locale;

/// 统一的错误响应格式
#[derive(Debug, Serialize, Deserialize)]
pub struct ErrorResponse {
    /// 错误码
    pub code: u32,
    /// 稳定错误键
    pub message_key: String,
    /// 错误消息
    pub message: String,
    /// 错误参数（可选）
    pub message_params: Option<MessageParams>,
    /// 详细信息（可选）
    pub details: Option<String>,
}

/// 应用错误类型
#[derive(Debug)]
#[allow(dead_code)]
pub enum AppError {
    // 数据库错误
    DatabaseError(sqlx::Error),

    // 认证相关错误
    Unauthorized(String),
    InvalidToken(String),
    TokenExpired,
    InvalidCredentials,

    // 资源相关错误
    NotFound(String),
    AlreadyExists(String),

    // 验证错误
    ValidationError(String),
    InvalidInput(String),

    // 权限错误
    Forbidden(String),
    InsufficientPermission,

    // 业务逻辑错误
    BusinessError(String),

    // 限流错误
    RateLimitExceeded(String),
    TooManyRequests,

    // Redis 错误
    CacheError(String),

    // 系统错误
    InternalError(String),
    ServiceUnavailable(String),
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AppError::DatabaseError(_) => write!(f, "数据库错误"),
            AppError::Unauthorized(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "未授权，请先登录")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::InvalidToken(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "无效的令牌")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::TokenExpired => write!(f, "令牌已过期，请重新登录"),
            AppError::InvalidCredentials => write!(f, "用户名或密码错误"),
            AppError::NotFound(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "资源不存在")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::AlreadyExists(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "资源已存在")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::ValidationError(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "验证失败")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::InvalidInput(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "输入无效")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::Forbidden(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "禁止访问")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::InsufficientPermission => write!(f, "权限不足"),
            AppError::BusinessError(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "业务逻辑错误")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::RateLimitExceeded(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "请求过于频繁，请稍后再试")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::TooManyRequests => write!(f, "请求过于频繁，请稍后再试"),
            AppError::CacheError(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "缓存错误")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::InternalError(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "服务器内部错误")
                } else {
                    write!(f, "{}", msg)
                }
            }
            AppError::ServiceUnavailable(msg) => {
                if msg.trim().is_empty() {
                    write!(f, "服务不可用")
                } else {
                    write!(f, "{}", msg)
                }
            }
        }
    }
}

impl std::error::Error for AppError {}

impl AppError {
    /// 获取错误码
    pub fn error_code(&self) -> u32 {
        match self {
            // 认证相关 (40001-40099)
            AppError::Unauthorized(_) => 40001,
            AppError::InvalidToken(_) => 40002,
            AppError::TokenExpired => 40003,
            AppError::InvalidCredentials => 40004,

            // 权限相关 (40301-40399)
            AppError::Forbidden(_) => 40301,
            AppError::InsufficientPermission => 40302,

            // 资源相关 (40401-40499)
            AppError::NotFound(_) => 40401,

            // 验证相关 (42201-42299)
            AppError::ValidationError(_) => 42201,
            AppError::InvalidInput(_) => 42202,

            // 冲突相关 (40901-40999)
            AppError::AlreadyExists(_) => 40901,

            // 限流相关 (42901-42999)
            AppError::RateLimitExceeded(_) => 42901,
            AppError::TooManyRequests => 42902,

            // 业务逻辑错误 (50001-50099)
            AppError::BusinessError(_) => 50001,

            // 数据库错误 (50101-50199)
            AppError::DatabaseError(_) => 50101,

            // 缓存错误 (50201-50299)
            AppError::CacheError(_) => 50201,

            // 系统错误 (50301-50399)
            AppError::InternalError(_) => 50301,
            AppError::ServiceUnavailable(_) => 50302,
        }
    }

    /// 获取 HTTP 状态码
    pub fn status_code(&self) -> StatusCode {
        match self {
            AppError::Unauthorized(_)
            | AppError::InvalidToken(_)
            | AppError::TokenExpired
            | AppError::InvalidCredentials => StatusCode::UNAUTHORIZED,

            AppError::Forbidden(_) | AppError::InsufficientPermission => StatusCode::FORBIDDEN,

            AppError::NotFound(_) => StatusCode::NOT_FOUND,

            AppError::ValidationError(_) | AppError::InvalidInput(_) => StatusCode::BAD_REQUEST,

            AppError::AlreadyExists(_) => StatusCode::CONFLICT,

            AppError::RateLimitExceeded(_) | AppError::TooManyRequests => {
                StatusCode::TOO_MANY_REQUESTS
            }

            AppError::BusinessError(_) => StatusCode::UNPROCESSABLE_ENTITY,

            AppError::ServiceUnavailable(_) => StatusCode::SERVICE_UNAVAILABLE,

            AppError::DatabaseError(_) | AppError::CacheError(_) | AppError::InternalError(_) => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
        }
    }

    /// 获取稳定消息 key
    pub fn message_key(&self) -> &'static str {
        match self {
            AppError::DatabaseError(_) => "common.database_error",
            AppError::Unauthorized(_) => "auth.unauthorized",
            AppError::InvalidToken(_) => "auth.invalid_token",
            AppError::TokenExpired => "auth.token_expired",
            AppError::InvalidCredentials => "auth.invalid_credentials",
            AppError::NotFound(_) => "common.not_found",
            AppError::AlreadyExists(_) => "common.already_exists",
            AppError::ValidationError(_) => "common.validation_error",
            AppError::InvalidInput(_) => "common.invalid_input",
            AppError::Forbidden(_) => "auth.forbidden",
            AppError::InsufficientPermission => "auth.insufficient_permission",
            AppError::BusinessError(_) => "common.business_error",
            AppError::RateLimitExceeded(_) | AppError::TooManyRequests => {
                "common.too_many_requests"
            }
            AppError::CacheError(_) => "common.cache_error",
            AppError::InternalError(_) => "common.internal_error",
            AppError::ServiceUnavailable(_) => "common.service_unavailable",
        }
    }

    /// 获取消息参数（Task 1 仅打通协议字段）
    pub fn message_params(&self) -> Option<MessageParams> {
        None
    }

    /// 获取用于响应的最终 message：
    /// - 敏感错误（InternalError/ServiceUnavailable）不透传 payload
    /// - 非敏感错误有 payload 且非空时保留 payload
    /// - 其他情况使用默认 locale (zh-CN) 本地化
    /// - 若 key 缺失则回退为 message_key
    pub fn localized_message(&self) -> String {
        if !self.should_mask_payload_for_client_message() {
            if let Some(payload) = self.payload_message() {
                return payload.to_string();
            }
        }

        let localizer = default_localizer();
        let params = self.message_params();
        let locale =
            current_request_locale().unwrap_or_else(|| localizer.fallback_locale().to_string());
        localizer.localize(&locale, self.message_key(), params.as_ref())
    }

    fn should_mask_payload_for_client_message(&self) -> bool {
        matches!(
            self,
            AppError::InternalError(_) | AppError::ServiceUnavailable(_)
        )
    }

    fn payload_message(&self) -> Option<&str> {
        let message = match self {
            AppError::Unauthorized(msg)
            | AppError::InvalidToken(msg)
            | AppError::NotFound(msg)
            | AppError::AlreadyExists(msg)
            | AppError::ValidationError(msg)
            | AppError::InvalidInput(msg)
            | AppError::Forbidden(msg)
            | AppError::BusinessError(msg)
            | AppError::RateLimitExceeded(msg)
            | AppError::CacheError(msg)
            | AppError::InternalError(msg)
            | AppError::ServiceUnavailable(msg) => msg.as_str(),
            AppError::DatabaseError(_)
            | AppError::TokenExpired
            | AppError::InvalidCredentials
            | AppError::InsufficientPermission
            | AppError::TooManyRequests => "",
        };

        if message.trim().is_empty() {
            None
        } else {
            Some(message)
        }
    }

    /// 获取详细信息（敏感信息不会暴露给客户端）
    pub fn details(&self) -> Option<String> {
        match self {
            // 数据库错误不暴露细节
            AppError::DatabaseError(_) => None,
            // 内部错误不暴露细节
            AppError::InternalError(_) => None,
            // 服务不可用不暴露底层上下文
            AppError::ServiceUnavailable(_) => None,
            // 其他错误仅在 payload 非空时暴露细节
            _ => self.payload_message().map(str::to_string),
        }
    }

    fn response_log_level(&self) -> Level {
        match self {
            AppError::Unauthorized(_)
            | AppError::InvalidToken(_)
            | AppError::TokenExpired
            | AppError::InvalidCredentials
            | AppError::Forbidden(_)
            | AppError::InsufficientPermission => Level::INFO,
            _ => Level::WARN,
        }
    }
}

/// 实现从 sqlx::Error 到 AppError 的转换
impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        tracing::error!("Database error: {:?}", err);
        AppError::DatabaseError(err)
    }
}

/// 实现从 redis::RedisError 到 AppError 的转换
impl From<redis::RedisError> for AppError {
    fn from(err: redis::RedisError) -> Self {
        tracing::error!("Redis error: {:?}", err);
        AppError::CacheError(err.to_string())
    }
}

/// 实现 IntoResponse trait，使 AppError 可以作为 Axum handler 的返回值
impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let status_code = self.status_code();
        let error_code = self.error_code();
        let message_key = self.message_key().to_string();
        let message = self.localized_message();
        let message_params = self.message_params();
        let details = self.details();
        let log_level = self.response_log_level();

        let error_response = ErrorResponse {
            code: error_code,
            message_key,
            message,
            message_params,
            details,
        };

        match log_level {
            Level::INFO => tracing::info!(
                "API error response: status={}, code={}, key={}, error={:?}",
                status_code.as_u16(),
                error_code,
                error_response.message_key,
                error_response.message
            ),
            _ => tracing::warn!(
                "API error response: status={}, code={}, key={}, error={:?}",
                status_code.as_u16(),
                error_code,
                error_response.message_key,
                error_response.message
            ),
        }

        (status_code, Json(error_response)).into_response()
    }
}

/// 辅助宏：快速创建各种错误
#[macro_export]
macro_rules! app_error {
    (unauthorized, $msg:expr) => {
        $crate::error::AppError::Unauthorized($msg.to_string())
    };
    (not_found, $msg:expr) => {
        $crate::error::AppError::NotFound($msg.to_string())
    };
    (validation, $msg:expr) => {
        $crate::error::AppError::ValidationError($msg.to_string())
    };
    (forbidden, $msg:expr) => {
        $crate::error::AppError::Forbidden($msg.to_string())
    };
    (conflict, $msg:expr) => {
        $crate::error::AppError::AlreadyExists($msg.to_string())
    };
    (rate_limit, $msg:expr) => {
        $crate::error::AppError::RateLimitExceeded($msg.to_string())
    };
    (business, $msg:expr) => {
        $crate::error::AppError::BusinessError($msg.to_string())
    };
    (internal, $msg:expr) => {
        $crate::error::AppError::InternalError($msg.to_string())
    };
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::{
        body::Body,
        extract::Extension,
        http::{header::ACCEPT_LANGUAGE, Request},
        routing::get,
        Router,
    };
    use http_body_util::BodyExt;
    use serde_json::Value;
    use std::sync::{Arc, Mutex};
    use tower::ServiceExt;
    use tracing::Level;
    use tracing_subscriber::{layer::SubscriberExt, Layer, Registry};

    #[test]
    fn test_error_codes() {
        assert_eq!(
            AppError::Unauthorized("test".to_string()).error_code(),
            40001
        );
        assert_eq!(AppError::NotFound("test".to_string()).error_code(), 40401);
        assert_eq!(
            AppError::ValidationError("test".to_string()).error_code(),
            42201
        );
    }

    #[test]
    fn test_status_codes() {
        assert_eq!(
            AppError::Unauthorized("test".to_string()).status_code(),
            StatusCode::UNAUTHORIZED
        );
        assert_eq!(
            AppError::NotFound("test".to_string()).status_code(),
            StatusCode::NOT_FOUND
        );
    }

    #[tokio::test]
    async fn test_error_response_uses_request_locale_from_accept_language() {
        let app = Router::new().route("/error", get(locale_error_handler));
        let app = crate::routes::with_request_locale_layer(app);

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/error")
                    .header(ACCEPT_LANGUAGE, "en-US,en;q=0.9")
                    .body(Body::empty())
                    .expect("build request"),
            )
            .await
            .expect("send request");

        let body = read_body_json(response.into_body()).await;
        assert_eq!(body["message_key"], "auth.token_expired");
        assert_eq!(body["message"], "Token expired. Please sign in again.");
    }

    #[tokio::test]
    async fn test_error_response_defaults_to_zh_cn_without_accept_language() {
        let app = Router::new().route("/error", get(locale_error_handler));
        let app = crate::routes::with_request_locale_layer(app);

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/error")
                    .body(Body::empty())
                    .expect("build request"),
            )
            .await
            .expect("send request");

        let body = read_body_json(response.into_body()).await;
        assert_eq!(body["message_key"], "auth.token_expired");
        assert_eq!(body["message"], "令牌已过期，请重新登录");
    }

    #[tokio::test]
    async fn test_error_request_locale_extension_is_injected() {
        let app = Router::new().route("/locale", get(locale_extension_handler));
        let app = crate::routes::with_request_locale_layer(app);

        let response = app
            .oneshot(
                Request::builder()
                    .uri("/locale")
                    .header(ACCEPT_LANGUAGE, "en-GB,en;q=0.9")
                    .body(Body::empty())
                    .expect("build request"),
            )
            .await
            .expect("send request");

        let body = read_body_json(response.into_body()).await;
        assert_eq!(body["locale"], "en-US");
    }

    #[test]
    fn test_error_expected_auth_failures_log_at_info_level() {
        for error in [
            AppError::Unauthorized(String::new()),
            AppError::InvalidToken(String::new()),
            AppError::TokenExpired,
            AppError::InvalidCredentials,
            AppError::Forbidden(String::new()),
            AppError::InsufficientPermission,
        ] {
            let levels = capture_log_levels(|| {
                let _ = error.into_response();
            });

            assert_eq!(levels.as_slice(), &[Level::INFO]);
        }
    }

    #[test]
    fn test_error_internal_failures_still_log_at_warn_level() {
        let levels = capture_log_levels(|| {
            let _ = AppError::InternalError(String::new()).into_response();
        });

        assert_eq!(levels.as_slice(), &[Level::WARN]);
    }

    async fn locale_error_handler() -> Result<(), AppError> {
        Err(AppError::TokenExpired)
    }

    async fn locale_extension_handler(
        Extension(locale): Extension<crate::middleware::RequestLocale>,
    ) -> axum::Json<Value> {
        axum::Json(serde_json::json!({ "locale": locale.as_str() }))
    }

    async fn read_body_json(body: Body) -> Value {
        let bytes = body
            .collect()
            .await
            .expect("collect response body")
            .to_bytes();
        serde_json::from_slice(&bytes).expect("parse json body")
    }

    fn capture_log_levels(action: impl FnOnce()) -> Vec<Level> {
        #[derive(Clone)]
        struct LevelCollector {
            levels: Arc<Mutex<Vec<Level>>>,
        }

        impl<S> Layer<S> for LevelCollector
        where
            S: tracing::Subscriber,
        {
            fn on_event(
                &self,
                event: &tracing::Event<'_>,
                _ctx: tracing_subscriber::layer::Context<'_, S>,
            ) {
                self.levels
                    .lock()
                    .expect("lock levels")
                    .push(*event.metadata().level());
            }
        }

        let levels = Arc::new(Mutex::new(Vec::new()));
        let subscriber = Registry::default().with(LevelCollector {
            levels: levels.clone(),
        });

        tracing::subscriber::with_default(subscriber, action);

        let captured = levels.lock().expect("lock levels").clone();
        captured
    }
}
