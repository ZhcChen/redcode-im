use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde::{Deserialize, Serialize};
use std::fmt;

/// 统一的错误响应格式
#[derive(Debug, Serialize, Deserialize)]
pub struct ErrorResponse {
    /// 错误码
    pub code: u32,
    /// 错误消息
    pub message: String,
    /// 详细信息（可选）
    #[serde(skip_serializing_if = "Option::is_none")]
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
            AppError::DatabaseError(e) => write!(f, "Database error: {}", e),
            AppError::Unauthorized(msg) => write!(f, "Unauthorized: {}", msg),
            AppError::InvalidToken(msg) => write!(f, "Invalid token: {}", msg),
            AppError::TokenExpired => write!(f, "Token has expired"),
            AppError::InvalidCredentials => write!(f, "Invalid username or password"),
            AppError::NotFound(msg) => write!(f, "Not found: {}", msg),
            AppError::AlreadyExists(msg) => write!(f, "Already exists: {}", msg),
            AppError::ValidationError(msg) => write!(f, "Validation error: {}", msg),
            AppError::InvalidInput(msg) => write!(f, "Invalid input: {}", msg),
            AppError::Forbidden(msg) => write!(f, "Forbidden: {}", msg),
            AppError::InsufficientPermission => write!(f, "Insufficient permission"),
            AppError::BusinessError(msg) => write!(f, "Business error: {}", msg),
            AppError::RateLimitExceeded(msg) => write!(f, "Rate limit exceeded: {}", msg),
            AppError::TooManyRequests => write!(f, "Too many requests"),
            AppError::CacheError(msg) => write!(f, "Cache error: {}", msg),
            AppError::InternalError(msg) => write!(f, "Internal error: {}", msg),
            AppError::ServiceUnavailable(msg) => write!(f, "Service unavailable: {}", msg),
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

    /// 获取详细信息（敏感信息不会暴露给客户端）
    pub fn details(&self) -> Option<String> {
        match self {
            // 数据库错误不暴露细节
            AppError::DatabaseError(_) => None,
            // 内部错误不暴露细节
            AppError::InternalError(_) => None,
            // 其他错误可以暴露细节
            _ => Some(self.to_string()),
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
        let message = self.to_string();
        let details = self.details();

        let error_response = ErrorResponse {
            code: error_code,
            message,
            details,
        };

        tracing::warn!(
            "API error response: status={}, code={}, error={:?}",
            status_code.as_u16(),
            error_code,
            error_response.message
        );

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
}
