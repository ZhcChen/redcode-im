use crate::http::error::HttpError;
use crate::http::types::{
    BatchRequestPayload, BatchResponsePayload, HttpClientConfig, HttpClientStats,
    HttpRequestOptions, HttpRequestOutcome,
};
use crate::logger;
use base64::{engine::general_purpose, Engine as _};
use bytes::Bytes;
use futures_util::stream;
use reqwest::header::{HeaderMap, HeaderName, HeaderValue};
use reqwest::{Client, Method};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::fs;
use tokio::io::AsyncWriteExt;
use tokio::sync::RwLock;
use tokio::time::sleep;

pub fn create_http_client(config: HttpClientConfig) -> Result<HttpClientState, HttpError> {
    HttpClientState::new(config)
}

pub struct HttpClientState {
    inner: Arc<RwLock<HttpClientInner>>,
}

struct HttpClientInner {
    client: Client,
    config: HttpClientConfig,
    token: Option<String>,
    initialized: bool,
    stats: HttpClientStats,
}

impl HttpClientState {
    pub fn new(config: HttpClientConfig) -> Result<Self, HttpError> {
        let client = Self::build_client(&config)?;
        let inner = HttpClientInner {
            client,
            config,
            token: None,
            initialized: false,
            stats: HttpClientStats::default(),
        };

        Ok(Self {
            inner: Arc::new(RwLock::new(inner)),
        })
    }

    fn build_client(config: &HttpClientConfig) -> Result<Client, HttpError> {
        let mut builder = Client::builder()
            .http1_only() // 强制使用 HTTP/1.1，避免 HTTP/2 协商问题
            .gzip(true) // 明确启用 gzip
            .brotli(true) // 明确启用 brotli
            .deflate(true) // 明确启用 deflate
            .timeout(Duration::from_millis(config.timeout_ms))
            .pool_max_idle_per_host(config.connection_pool.max_idle_per_host)
            .user_agent(config.user_agent.clone());

        if config.connection_pool.idle_timeout_secs > 0 {
            builder = builder.pool_idle_timeout(Some(Duration::from_secs(
                config.connection_pool.idle_timeout_secs,
            )));
        }

        if !config.verify_ssl {
            builder = builder.danger_accept_invalid_certs(true);
        }

        builder
            .build()
            .map_err(|err| HttpError::InvalidConfig(format!("构建 HTTP 客户端失败: {err}")))
    }

    pub async fn initialize(
        &self,
        base_url: Option<String>,
        token: Option<String>,
        timeout_ms: Option<u64>,
        max_retries: Option<u32>,
        retry_delay_ms: Option<u64>,
        verify_ssl: Option<bool>,
    ) -> Result<HttpClientStats, HttpError> {
        let mut inner = self.inner.write().await;

        if let Some(url) = base_url {
            let trimmed = url.trim();
            if trimmed.is_empty() {
                return Err(HttpError::InvalidConfig("baseUrl 不能为空".into()));
            }
            inner.config.base_url = trimmed.to_string();
        }

        if let Some(timeout) = timeout_ms {
            inner.config.timeout_ms = timeout;
        }

        if let Some(retries) = max_retries {
            inner.config.max_retries = retries.max(1);
        }

        if let Some(delay) = retry_delay_ms {
            inner.config.retry_delay_ms = delay.max(100);
        }

        if let Some(verify) = verify_ssl {
            inner.config.verify_ssl = verify;
        }

        inner.client = Self::build_client(&inner.config)?;

        if let Some(token_value) = token {
            if token_value.is_empty() {
                inner.token = None;
            } else {
                inner.token = Some(token_value);
            }
        }

        inner.initialized = true;
        inner.stats.initialized = true;
        Ok(inner.stats.clone())
    }

    pub async fn set_token(&self, token: Option<String>) {
        let mut inner = self.inner.write().await;
        inner.token = token.filter(|v| !v.is_empty());
    }

    pub async fn stats(&self) -> HttpClientStats {
        let inner = self.inner.read().await;
        inner.stats.clone()
    }

    pub async fn health_summary(&self) -> HttpClientStats {
        let inner = self.inner.read().await;
        inner.stats.clone()
    }

    pub async fn execute_request(
        &self,
        options: HttpRequestOptions,
    ) -> Result<HttpRequestOutcome, HttpError> {
        self.ensure_initialized().await?;
        let (client, config, token) = self.snapshot().await;
        let url = Self::build_url(&config.base_url, &options.path, options.query.as_ref())?;
        let retries = options.retry_count.unwrap_or(config.max_retries).max(1);
        let timeout = options.timeout_ms.unwrap_or(config.timeout_ms);
        let delay = Duration::from_millis(config.retry_delay_ms);
        let headers = options.headers.clone();
        let body = options.body.clone();
        let method = options.method.clone();

        let mut attempt = 0;
        loop {
            attempt += 1;
            let mut builder = client.request(method.clone(), &url);
            builder = builder.timeout(Duration::from_millis(timeout));

            if options.inject_token {
                if let Some(token_value) = &token {
                    builder = builder.header("Authorization", format!("Bearer {}", token_value));
                }
            }

            if let Some(header_map) = &headers {
                builder = Self::apply_headers(builder, header_map)?;
            }

            if let Some(bytes) = &options.body_bytes {
                if options.force_streaming_body {
                    if !Self::has_content_length(&headers) {
                        builder = builder.header("Content-Length", bytes.len().to_string());
                    }
                    let chunk = bytes.clone();
                    let stream_body =
                        stream::once(
                            async move { Ok::<Bytes, std::io::Error>(Bytes::from(chunk)) },
                        );
                    builder = builder.body(reqwest::Body::wrap_stream(stream_body));
                } else {
                    builder = builder.body(bytes.clone());
                }
            } else if let Some(body_str) = &body {
                if !Self::has_content_type(&headers) {
                    builder = builder.header("Content-Type", "application/json");
                }
                builder = builder.body(body_str.clone());
            }

            let header_keys: Vec<String> = headers
                .as_ref()
                .map(|map| map.keys().cloned().collect())
                .unwrap_or_default();

            logger::log_event(
                "HTTP_REQUEST",
                json!({
                    "method": method.to_string(),
                    "url": url,
                    "attempt": attempt,
                    "injectToken": options.inject_token,
                    "expectBinary": options.expect_binary,
                    "forceStreaming": options.force_streaming_body,
                    "contentLength": options.body_bytes.as_ref().map(|b| b.len()),
                    "headers": header_keys
                }),
            );

            // 拦截关键接口请求 - 输出详细的请求信息（用于对比）
            let should_log = options.path.contains("/friends") && !options.path.contains("/friends/requests")
                || options.path.contains("/auth/login");

            if should_log {
                println!("\n========================================");
                println!("📤 拦截到接口请求: {}", options.path);
                println!("========================================");
                println!("请求 URL: {}", url);
                println!("请求方法: {}", method);
                println!("User-Agent: {}", config.user_agent);
                println!("注入 Token: {}", options.inject_token);

                // 打印完整的 token 值用于调试
                if let Some(t) = &token {
                    println!("Token 完整值: {}", t);
                    println!("Token 长度: {} 字符", t.len());
                    println!("Token 包含特殊字符检查:");
                    println!("  包含换行符: {}", t.contains('\n') || t.contains('\r'));
                    println!("  包含空格: {}", t.contains(' '));
                    println!("  包含制表符: {}", t.contains('\t'));
                } else {
                    println!("Token 值: 无");
                }

                if let Some(header_map) = &headers {
                    println!("请求头:");
                    for (key, value) in header_map {
                        // 对于 Authorization 头，打印完整值用于调试
                        if key.eq_ignore_ascii_case("authorization") {
                            println!("  {}: {} (完整值)", key, value);
                            println!("  Authorization 长度: {} 字符", value.len());
                        } else {
                            println!("  {}: {}", key, value);
                        }
                    }
                } else {
                    println!("请求头: 无");
                }
                println!("请求体: {}", body.as_ref().unwrap_or(&"无".to_string()));
                println!("========================================\n");
            }

            let send_started = Instant::now();
            match self.send(builder, options.expect_binary).await {
                Ok(outcome) => {
                    logger::log_event(
                        "HTTP_RESPONSE",
                        json!({
                            "method": method.to_string(),
                            "url": url,
                            "attempt": attempt,
                            "success": outcome.success,
                            "message": outcome.message,
                            "elapsedMs": send_started.elapsed().as_millis()
                        }),
                    );

                    // 拦截关键接口响应 - 输出到运行控制台（用于对比）
                    let should_log = options.path.contains("/friends") && !options.path.contains("/friends/requests")
                        || options.path.contains("/auth/login");

                    if should_log {
                        println!("\n========================================");
                        println!("🔍 拦截到接口响应: {}", options.path);
                        println!("========================================");
                        println!("请求 URL: {}", url);
                        println!("请求方法: {}", method);
                        println!("响应状态: {}", if outcome.success { "成功" } else { "失败" });
                        println!("响应消息: {}", outcome.message);
                        println!("响应数据: {}", serde_json::to_string_pretty(&outcome.payload).unwrap_or_else(|_| "无法序列化".to_string()));
                        println!("========================================\n");
                    }

                    return Ok(outcome);
                }
                Err(err) => {
                    logger::log_event(
                        "HTTP_RESPONSE_ERROR",
                        json!({
                            "method": method.to_string(),
                            "url": url,
                            "attempt": attempt,
                            "error": err.to_string(),
                            "elapsedMs": send_started.elapsed().as_millis()
                        }),
                    );
                    if attempt >= retries || !err.is_retryable() {
                        return Err(err);
                    }
                    sleep(delay).await;
                }
            }
        }
    }

    pub async fn upload_file(
        &self,
        remote_path: String,
        file_path: PathBuf,
        content_type: Option<String>,
    ) -> Result<HttpRequestOutcome, HttpError> {
        self.ensure_initialized().await?;
        let (client, config, token) = self.snapshot().await;
        let url = Self::build_url(&config.base_url, &remote_path, None)?;
        let file_name = file_path
            .file_name()
            .and_then(|n| n.to_str())
            .ok_or_else(|| HttpError::InvalidConfig("无法解析文件名".into()))?
            .to_string();
        let bytes = fs::read(&file_path).await?;

        let retries = config.max_retries.max(1);
        let delay = Duration::from_millis(config.retry_delay_ms);
        let timeout = config.timeout_ms;
        let mut attempt = 0;

        loop {
            attempt += 1;
            let mut part =
                reqwest::multipart::Part::bytes(bytes.clone()).file_name(file_name.clone());
            if let Some(ct) = &content_type {
                if !ct.trim().is_empty() {
                    part = part.mime_str(ct).map_err(|err| {
                        HttpError::InvalidConfig(format!("Content-Type 无效: {err}"))
                    })?;
                }
            }
            let form = reqwest::multipart::Form::new().part("file", part);

            let mut builder = client
                .post(&url)
                .multipart(form)
                .timeout(Duration::from_millis(timeout));
            if let Some(token_value) = &token {
                builder = builder.header("Authorization", format!("Bearer {}", token_value));
            }

            match self.send(builder, false).await {
                Ok(outcome) => return Ok(outcome),
                Err(err) => {
                    if attempt >= retries || !err.is_retryable() {
                        return Err(err);
                    }
                    sleep(delay).await;
                }
            }
        }
    }

    pub async fn download_file(
        &self,
        url_or_path: String,
        save_path: PathBuf,
    ) -> Result<HttpRequestOutcome, HttpError> {
        self.download_file_with_progress(url_or_path, save_path, None).await
    }

    pub async fn download_file_with_progress(
        &self,
        url_or_path: String,
        save_path: PathBuf,
        progress_callback: Option<Box<dyn Fn(f64) + Send + Sync>>,
    ) -> Result<HttpRequestOutcome, HttpError> {
        logger::log_message(&format!("[download_file_with_progress] 开始下载: url={}, save_path={:?}", url_or_path, save_path));
        
        self.ensure_initialized().await?;
        let (client, config, token) = self.snapshot().await;
        let is_external_url = url_or_path.starts_with("http://") || url_or_path.starts_with("https://");
        let url = if is_external_url {
            url_or_path.clone()
        } else {
            Self::build_url(&config.base_url, &url_or_path, None)?
        };

        logger::log_message(&format!("[download_file_with_progress] 最终 URL: {}, is_external: {}", url, is_external_url));

        let mut builder = client.get(&url);
        // 只对内部 API URL 添加 Authorization header，外部 URL（如 COS 签名 URL）不需要
        if !is_external_url {
            if let Some(token_value) = &token {
                builder = builder.header("Authorization", format!("Bearer {}", token_value));
            }
        }

        let start = Instant::now();
        match builder.send().await {
            Ok(mut resp) => {
                let status = resp.status();
                logger::log_message(&format!("[download_file_with_progress] HTTP 状态码: {}", status));
                
                if !status.is_success() {
                    let text = resp.text().await.unwrap_or_default();
                    logger::log_message(&format!("[download_file_with_progress] HTTP 请求失败: status={}, body={}", status, text));
                    let outcome = HttpRequestOutcome::from_http(status.as_u16(), text);
                    self.record_outcome(&outcome, start.elapsed()).await;
                    return Ok(outcome);
                }

                if let Some(parent) = save_path.parent() {
                    logger::log_message(&format!("[download_file_with_progress] 创建目录: {:?}", parent));
                    fs::create_dir_all(parent).await.map_err(|e| {
                        logger::log_message(&format!("[download_file_with_progress] 创建目录失败: {}", e));
                        HttpError::Io(e)
                    })?;
                }

                let total_size = resp.content_length();
                logger::log_message(&format!("[download_file_with_progress] 文件大小: {:?} bytes", total_size));
                
                logger::log_message(&format!("[download_file_with_progress] 创建文件: {:?}", save_path));
                let mut file = fs::File::create(&save_path).await.map_err(|e| {
                    logger::log_message(&format!("[download_file_with_progress] 创建文件失败: {}", e));
                    HttpError::Io(e)
                })?;
                let mut downloaded: u64 = 0;

                logger::log_message(&format!("[download_file_with_progress] 开始下载数据块..."));
                while let Some(chunk) = resp.chunk().await.map_err(|e| {
                    logger::log_message(&format!("[download_file_with_progress] 读取数据块失败: {}", e));
                    HttpError::from(e)
                })? {
                    file.write_all(&chunk).await.map_err(|e| {
                        logger::log_message(&format!("[download_file_with_progress] 写入文件失败: {}", e));
                        HttpError::Io(e)
                    })?;
                    downloaded += chunk.len() as u64;
                    
                    // 调用进度回调
                    if let Some(callback) = &progress_callback {
                        let progress = if let Some(total) = total_size {
                            if total > 0 {
                                (downloaded as f64 / total as f64).min(1.0)
                            } else {
                                0.0
                            }
                        } else {
                            // 如果没有总大小，返回 -1 表示未知进度
                            -1.0
                        };
                        callback(progress);
                    }
                }

                logger::log_message(&format!("[download_file_with_progress] 下载完成: {} bytes", downloaded));

                let payload = serde_json::json!({
                    "success": true,
                    "code": status.as_u16(),
                    "message": "Download finished",
                    "data": {
                        "path": save_path.to_string_lossy()
                    }
                });
                let outcome = HttpRequestOutcome {
                    success: true,
                    message: "Download finished".into(),
                    payload,
                };
                self.record_outcome(&outcome, start.elapsed()).await;
                Ok(outcome)
            }
            Err(err) => {
                logger::log_message(&format!("[download_file_with_progress] 请求发送失败: {}", err));
                let http_error = HttpError::from(err);
                self.record_error(start.elapsed(), &http_error).await;
                Err(http_error)
            }
        }
    }

    pub async fn run_batch(
        &self,
        requests: Vec<BatchRequestPayload>,
    ) -> Result<BatchResponsePayload, HttpError> {
        let mut results = Vec::with_capacity(requests.len());
        for req in requests {
            let method = req
                .method
                .as_deref()
                .unwrap_or("GET")
                .parse::<Method>()
                .unwrap_or(Method::GET);
            let mut opts = HttpRequestOptions::new(method, req.path);
            opts.body = req.body;
            opts.headers = req.headers.clone();
            opts.query = req.query_params.clone();
            opts.timeout_ms = req.timeout_ms;
            opts.retry_count = req.retry_count;

            match self.execute_request(opts).await {
                Ok(outcome) => results.push(outcome.payload),
                Err(err) => {
                    let payload = serde_json::json!({
                        "success": false,
                        "code": err.code(),
                        "message": err.to_string(),
                        "data": Value::Null
                    });
                    results.push(payload);
                }
            }
        }

        Ok(BatchResponsePayload { results })
    }

    async fn ensure_initialized(&self) -> Result<(), HttpError> {
        let inner = self.inner.read().await;
        if inner.initialized {
            Ok(())
        } else {
            Err(HttpError::NotInitialized)
        }
    }

    async fn snapshot(&self) -> (Client, HttpClientConfig, Option<String>) {
        let inner = self.inner.read().await;
        (
            inner.client.clone(),
            inner.config.clone(),
            inner.token.clone(),
        )
    }

    fn build_url(
        base: &str,
        path: &str,
        query: Option<&HashMap<String, String>>,
    ) -> Result<String, HttpError> {
        let prefix = path.trim();
        let mut url = if prefix.starts_with("http://") || prefix.starts_with("https://") {
            prefix.to_string()
        } else {
            format!(
                "{}/{}",
                base.trim_end_matches('/'),
                prefix.trim_start_matches('/')
            )
        };

        if let Some(params) = query {
            if !params.is_empty() {
                let qs = serde_urlencoded::to_string(params).map_err(|err| {
                    HttpError::InvalidConfig(format!("query 参数编码失败: {err}"))
                })?;
                if url.contains('?') {
                    url.push('&');
                    url.push_str(&qs);
                } else {
                    url.push('?');
                    url.push_str(&qs);
                }
            }
        }

        Ok(url)
    }

    fn has_content_type(headers: &Option<HashMap<String, String>>) -> bool {
        headers
            .as_ref()
            .map(|map| {
                map.keys()
                    .any(|key| key.eq_ignore_ascii_case("content-type"))
            })
            .unwrap_or(false)
    }

    fn has_content_length(headers: &Option<HashMap<String, String>>) -> bool {
        headers
            .as_ref()
            .map(|map| {
                map.keys()
                    .any(|key| key.eq_ignore_ascii_case("content-length"))
            })
            .unwrap_or(false)
    }

    fn apply_headers(
        mut builder: reqwest::RequestBuilder,
        headers: &HashMap<String, String>,
    ) -> Result<reqwest::RequestBuilder, HttpError> {
        for (key, value) in headers {
            let header_name = HeaderName::from_bytes(key.as_bytes())
                .map_err(|_| HttpError::InvalidHeader(key.clone()))?;
            let header_value =
                HeaderValue::from_str(value).map_err(|_| HttpError::InvalidHeader(key.clone()))?;
            builder = builder.header(header_name, header_value);
        }
        Ok(builder)
    }

    async fn send(
        &self,
        builder: reqwest::RequestBuilder,
        expect_binary: bool,
    ) -> Result<HttpRequestOutcome, HttpError> {
        let start = Instant::now();
        match builder.send().await {
            Ok(response) => {
                if expect_binary {
                    let status = response.status();
                    let headers = Self::headers_to_map(response.headers());
                    match response.bytes().await {
                        Ok(bytes) => {
                            let base64_body = general_purpose::STANDARD.encode(&bytes);
                            let success = status.is_success();
                            let message = if success {
                                "OK".to_string()
                            } else {
                                format!("HTTP {} 请求失败", status.as_u16())
                            };
                            let payload = serde_json::json!({
                                "success": success,
                                "code": status.as_u16(),
                                "message": message,
                                "data": {
                                    "base64": base64_body,
                                    "headers": headers
                                }
                            });
                            let outcome = HttpRequestOutcome {
                                success,
                                message,
                                payload,
                            };
                            self.record_outcome(&outcome, start.elapsed()).await;
                            Ok(outcome)
                        }
                        Err(err) => {
                            let http_error = HttpError::from(err);
                            self.record_error(start.elapsed(), &http_error).await;
                            Err(http_error)
                        }
                    }
                } else {
                    let status = response.status().as_u16();
                    let text = response.text().await.unwrap_or_default();
                    let outcome = HttpRequestOutcome::from_http(status, text);
                    self.record_outcome(&outcome, start.elapsed()).await;
                    Ok(outcome)
                }
            }
            Err(err) => {
                let http_error = HttpError::from(err);
                self.record_error(start.elapsed(), &http_error).await;
                Err(http_error)
            }
        }
    }

    fn headers_to_map(headers: &HeaderMap) -> HashMap<String, String> {
        headers
            .iter()
            .filter_map(|(key, value)| {
                value
                    .to_str()
                    .ok()
                    .map(|v| (key.to_string(), v.to_string()))
            })
            .collect()
    }

    async fn record_outcome(&self, outcome: &HttpRequestOutcome, elapsed: Duration) {
        let mut inner = self.inner.write().await;
        inner.stats.initialized = inner.stats.initialized || inner.initialized;
        inner.stats.total_requests += 1;
        inner.stats.last_latency_ms = Some(elapsed.as_millis() as u64);
        let total = inner.stats.total_requests;
        let prev_avg = inner.stats.avg_latency_ms;
        inner.stats.avg_latency_ms = if total == 0 {
            elapsed.as_millis() as f64
        } else {
            ((prev_avg * (total.saturating_sub(1) as f64)) + elapsed.as_millis() as f64)
                / (total as f64)
        };

        if outcome.success {
            inner.stats.success_requests += 1;
            inner.stats.last_error = None;
        } else {
            inner.stats.failed_requests += 1;
            inner.stats.last_error = Some(outcome.message.clone());
        }
    }

    async fn record_error(&self, elapsed: Duration, error: &HttpError) {
        let mut inner = self.inner.write().await;
        inner.stats.initialized = inner.stats.initialized || inner.initialized;
        inner.stats.total_requests += 1;
        inner.stats.failed_requests += 1;
        inner.stats.last_latency_ms = Some(elapsed.as_millis() as u64);
        let total = inner.stats.total_requests;
        let prev_avg = inner.stats.avg_latency_ms;
        inner.stats.avg_latency_ms = if total == 0 {
            elapsed.as_millis() as f64
        } else {
            ((prev_avg * (total.saturating_sub(1) as f64)) + elapsed.as_millis() as f64)
                / (total as f64)
        };
        inner.stats.last_error = Some(error.to_string());
    }
}
