use reqwest::Method;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

/// HTTP 连接池配置
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ConnectionPoolConfig {
    pub max_idle_per_host: usize,
    pub idle_timeout_secs: u64,
}

impl Default for ConnectionPoolConfig {
    fn default() -> Self {
        Self {
            max_idle_per_host: 20,
            idle_timeout_secs: 300,
        }
    }
}

/// HTTP 客户端配置
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HttpClientConfig {
    pub base_url: String,
    pub timeout_ms: u64,
    pub max_retries: u32,
    pub retry_delay_ms: u64,
    pub verify_ssl: bool,
    pub user_agent: String,
    pub connection_pool: ConnectionPoolConfig,
}

impl Default for HttpClientConfig {
    fn default() -> Self {
        let base_url =
            std::env::var("API_BASE_URL").unwrap_or_else(|_| "http://localhost:8010".to_string());
        Self {
            base_url,
            timeout_ms: 30_000,
            max_retries: 3,
            retry_delay_ms: 1_000,
            verify_ssl: true,
            user_agent: format!("bear-chat-tauri/{}", env!("CARGO_PKG_VERSION")),
            connection_pool: ConnectionPoolConfig::default(),
        }
    }
}

/// HTTP 客户端运行统计
#[derive(Clone, Debug, Serialize)]
pub struct HttpClientStats {
    pub initialized: bool,
    pub total_requests: u64,
    pub success_requests: u64,
    pub failed_requests: u64,
    pub avg_latency_ms: f64,
    pub last_latency_ms: Option<u64>,
    pub last_error: Option<String>,
}

impl Default for HttpClientStats {
    fn default() -> Self {
        Self {
            initialized: false,
            total_requests: 0,
            success_requests: 0,
            failed_requests: 0,
            avg_latency_ms: 0.0,
            last_latency_ms: None,
            last_error: None,
        }
    }
}

/// HTTP 请求选项
#[derive(Clone, Debug)]
pub struct HttpRequestOptions {
    pub method: Method,
    pub path: String,
    pub body: Option<String>,
    pub headers: Option<HashMap<String, String>>,
    pub query: Option<HashMap<String, String>>,
    pub timeout_ms: Option<u64>,
    pub retry_count: Option<u32>,
}

impl HttpRequestOptions {
    pub fn new(method: Method, path: String) -> Self {
        Self {
            method,
            path,
            body: None,
            headers: None,
            query: None,
            timeout_ms: None,
            retry_count: None,
        }
    }
}

/// 批量请求参数
#[derive(Debug, Deserialize)]
pub struct BatchRequestPayload {
    pub method: Option<String>,
    pub path: String,
    pub body: Option<String>,
    #[serde(rename = "headers")]
    pub headers: Option<HashMap<String, String>>,
    #[serde(rename = "queryParams")]
    pub query_params: Option<HashMap<String, String>>,
    #[serde(rename = "timeout")]
    pub timeout_ms: Option<u64>,
    pub retry_count: Option<u32>,
}

/// 批量请求响应
#[derive(Debug, Serialize)]
pub struct BatchResponsePayload {
    pub results: Vec<Value>,
}

/// 通用 API 响应
#[derive(Debug, Serialize)]
pub struct ApiResponse<T>
where
    T: Serialize,
{
    pub success: bool,
    pub code: u16,
    pub message: String,
    pub data: T,
}

impl<T> ApiResponse<T>
where
    T: Serialize,
{
    pub fn ok(code: u16, message: impl Into<String>, data: T) -> Self {
        Self {
            success: true,
            code,
            message: message.into(),
            data,
        }
    }

    pub fn fail(code: u16, message: impl Into<String>, data: T) -> Self {
        Self {
            success: false,
            code,
            message: message.into(),
            data,
        }
    }
}

/// HTTP 请求结果
#[derive(Debug, Clone)]
pub struct HttpRequestOutcome {
    pub success: bool,
    pub message: String,
    pub payload: Value,
}

impl HttpRequestOutcome {
    pub fn from_http(status: u16, body: String) -> Self {
        match serde_json::from_str::<Value>(&body) {
            Ok(value) => {
                if value.get("code").is_some()
                    && value.get("success").is_some()
                    && value.get("message").is_some()
                {
                    let success = value
                        .get("success")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(status < 400);
                    let message = value
                        .get("message")
                        .and_then(|v| v.as_str())
                        .unwrap_or(if success { "OK" } else { "请求失败" })
                        .to_string();

                    Self {
                        success,
                        message,
                        payload: value,
                    }
                } else {
                    let success = status < 400;
                    let wrapper = serde_json::json!({
                        "success": success,
                        "code": status,
                        "message": if success {
                            "OK"
                        } else {
                            value
                                .get("message")
                                .and_then(|m| m.as_str())
                                .unwrap_or("请求失败")
                        },
                        "data": value
                    });
                    let message = wrapper
                        .get("message")
                        .and_then(|v| v.as_str())
                        .unwrap_or("请求失败")
                        .to_string();
                    Self {
                        success,
                        message,
                        payload: wrapper,
                    }
                }
            }
            Err(_) => {
                let success = status < 400;
                let data = if body.is_empty() {
                    Value::Null
                } else {
                    Value::String(body.clone())
                };
                let message = if success {
                    "OK".to_string()
                } else if body.is_empty() {
                    format!("HTTP {} 请求失败", status)
                } else {
                    body.clone()
                };
                let wrapper = serde_json::json!({
                    "success": success,
                    "code": status,
                    "message": message,
                    "data": data
                });
                Self {
                    success,
                    message,
                    payload: wrapper,
                }
            }
        }
    }
}
