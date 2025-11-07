use thiserror::Error;

#[derive(Debug, Error)]
pub enum HttpError {
    #[error("HTTP 客户端尚未初始化")]
    NotInitialized,
    #[error("配置无效: {0}")]
    InvalidConfig(String),
    #[error("网络错误: {0}")]
    Reqwest(#[from] reqwest::Error),
    #[error("IO 错误: {0}")]
    Io(#[from] std::io::Error),
    #[error("序列化失败: {0}")]
    Serde(#[from] serde_json::Error),
    #[error("Header 无效: {0}")]
    InvalidHeader(String),
    #[error("路径解析失败: {0}")]
    Path(String),
}

impl HttpError {
    pub fn code(&self) -> u16 {
        match self {
            HttpError::NotInitialized => 400,
            HttpError::InvalidConfig(_) => 422,
            HttpError::Reqwest(err) => err.status().map(|s| s.as_u16()).unwrap_or(502),
            HttpError::Io(_) => 500,
            HttpError::Serde(_) => 500,
            HttpError::InvalidHeader(_) => 400,
            HttpError::Path(_) => 400,
        }
    }

    pub fn is_retryable(&self) -> bool {
        match self {
            HttpError::Reqwest(err) => {
                err.is_connect()
                    || err.is_timeout()
                    || err.status().map(|s| s.is_server_error()).unwrap_or(true)
            }
            HttpError::Io(_) => true,
            _ => false,
        }
    }
}
