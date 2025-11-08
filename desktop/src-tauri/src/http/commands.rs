use super::client::HttpClientState;
use super::error::HttpError;
use super::types::{ApiResponse, BatchRequestPayload, HttpClientStats, HttpRequestOptions};
use base64::{engine::general_purpose, Engine as _};
use reqwest::Method;
use serde_json::Value;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use tauri::{AppHandle, Manager, State};

fn serialize_value(value: Value) -> Result<String, String> {
    serde_json::to_string(&value).map_err(|err| err.to_string())
}

fn serialize_stats(stats: HttpClientStats) -> Result<String, String> {
    let response = ApiResponse::ok(200, "OK", stats);
    serde_json::to_string(&response).map_err(|err| err.to_string())
}

fn serialize_error(err: HttpError) -> Result<String, String> {
    let response = ApiResponse::fail(err.code(), err.to_string(), Value::Null);
    serde_json::to_string(&response).map_err(|ser| ser.to_string())
}

fn resolve_path(app: &AppHandle, input: &str) -> Result<PathBuf, HttpError> {
    let candidate = Path::new(input);
    if candidate.is_absolute() {
        return Ok(candidate.to_path_buf());
    }

    let mut base = app
        .path()
        .app_data_dir()
        .map_err(|err| HttpError::Path(err.to_string()))?;
    base.push(candidate);
    Ok(base)
}

fn build_options(
    method: Method,
    path: String,
    body: Option<String>,
    binary_body: Option<String>,
    expect_binary: Option<bool>,
    inject_token: Option<bool>,
) -> Result<HttpRequestOptions, HttpError> {
    let mut opts = HttpRequestOptions::new(method, path);
    opts.body = body;
    if let Some(encoded) = binary_body {
        let bytes = general_purpose::STANDARD
            .decode(encoded)
            .map_err(|err| HttpError::InvalidConfig(format!("二进制 body 解码失败: {err}")))?;
        opts.body_bytes = Some(bytes);
    }
    opts.expect_binary = expect_binary.unwrap_or(false);
    opts.inject_token = inject_token.unwrap_or(true);
    Ok(opts)
}

#[tauri::command]
pub async fn http_initialize(
    state: State<'_, HttpClientState>,
    base_url: Option<String>,
    token: Option<String>,
    timeout: Option<u64>,
    max_retries: Option<u32>,
    retry_delay: Option<u64>,
    verify_ssl: Option<bool>,
) -> Result<String, String> {
    match state
        .initialize(
            base_url,
            token,
            timeout,
            max_retries,
            retry_delay,
            verify_ssl,
        )
        .await
    {
        Ok(stats) => serialize_stats(stats),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_set_token(
    state: State<'_, HttpClientState>,
    token: String,
) -> Result<String, String> {
    state.set_token(Some(token)).await;
    serialize_value(serde_json::json!({
        "success": true,
        "code": 200,
        "message": "Token 已更新",
        "data": Value::Null
    }))
}

#[tauri::command]
pub async fn http_clear_token(state: State<'_, HttpClientState>) -> Result<String, String> {
    state.set_token(None).await;
    serialize_value(serde_json::json!({
        "success": true,
        "code": 200,
        "message": "Token 已清除",
        "data": Value::Null
    }))
}

#[tauri::command]
pub async fn http_get(state: State<'_, HttpClientState>, path: String) -> Result<String, String> {
    match state
        .execute_request(HttpRequestOptions::new(Method::GET, path))
        .await
    {
        Ok(outcome) => serialize_value(outcome.payload),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_delete(
    state: State<'_, HttpClientState>,
    path: String,
) -> Result<String, String> {
    match state
        .execute_request(HttpRequestOptions::new(Method::DELETE, path))
        .await
    {
        Ok(outcome) => serialize_value(outcome.payload),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_post(
    state: State<'_, HttpClientState>,
    path: String,
    body: Option<String>,
    binary_body: Option<String>,
    expect_binary: Option<bool>,
    inject_token: Option<bool>,
) -> Result<String, String> {
    let opts = match build_options(
        Method::POST,
        path,
        body,
        binary_body,
        expect_binary,
        inject_token,
    ) {
        Ok(opts) => opts,
        Err(err) => return serialize_error(err),
    };
    match state.execute_request(opts).await {
        Ok(outcome) => serialize_value(outcome.payload),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_put(
    state: State<'_, HttpClientState>,
    path: String,
    body: Option<String>,
    binary_body: Option<String>,
    expect_binary: Option<bool>,
    inject_token: Option<bool>,
) -> Result<String, String> {
    let opts = match build_options(
        Method::PUT,
        path,
        body,
        binary_body,
        expect_binary,
        inject_token,
    ) {
        Ok(opts) => opts,
        Err(err) => return serialize_error(err),
    };
    match state.execute_request(opts).await {
        Ok(outcome) => serialize_value(outcome.payload),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_patch(
    state: State<'_, HttpClientState>,
    path: String,
    body: Option<String>,
    binary_body: Option<String>,
    expect_binary: Option<bool>,
    inject_token: Option<bool>,
) -> Result<String, String> {
    let opts = match build_options(
        Method::PATCH,
        path,
        body,
        binary_body,
        expect_binary,
        inject_token,
    ) {
        Ok(opts) => opts,
        Err(err) => return serialize_error(err),
    };
    match state.execute_request(opts).await {
        Ok(outcome) => serialize_value(outcome.payload),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_request(
    state: State<'_, HttpClientState>,
    method: String,
    path: String,
    body: Option<String>,
    binary_body: Option<String>,
    headers: Option<HashMap<String, String>>,
    query_params: Option<HashMap<String, String>>,
    timeout: Option<u64>,
    retry_count: Option<u32>,
    expect_binary: Option<bool>,
    inject_token: Option<bool>,
) -> Result<String, String> {
    let parsed_method = method.parse::<Method>().unwrap_or_else(|_| Method::GET);
    let mut opts = match build_options(
        parsed_method,
        path,
        body,
        binary_body,
        expect_binary,
        inject_token,
    ) {
        Ok(opts) => opts,
        Err(err) => return serialize_error(err),
    };
    opts.headers = headers;
    opts.query = query_params;
    opts.timeout_ms = timeout;
    opts.retry_count = retry_count;

    match state.execute_request(opts).await {
        Ok(outcome) => serialize_value(outcome.payload),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_upload(
    app: AppHandle,
    state: State<'_, HttpClientState>,
    path: String,
    file_path: String,
    content_type: Option<String>,
) -> Result<String, String> {
    let resolved = match resolve_path(&app, &file_path) {
        Ok(p) => p,
        Err(err) => return serialize_error(err),
    };
    match state.upload_file(path, resolved, content_type).await {
        Ok(outcome) => serialize_value(outcome.payload),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_download(
    app: AppHandle,
    state: State<'_, HttpClientState>,
    url: String,
    save_path: String,
) -> Result<String, String> {
    let resolved = match resolve_path(&app, &save_path) {
        Ok(p) => p,
        Err(err) => return serialize_error(err),
    };
    match state.download_file(url, resolved).await {
        Ok(outcome) => serialize_value(outcome.payload),
        Err(err) => serialize_error(err),
    }
}

#[tauri::command]
pub async fn http_health(state: State<'_, HttpClientState>) -> Result<String, String> {
    let stats = state.health_summary().await;
    let response = ApiResponse::ok(
        200,
        "OK",
        serde_json::json!({
            "initialized": stats.initialized,
            "totalRequests": stats.total_requests,
            "failedRequests": stats.failed_requests,
        }),
    );
    serde_json::to_string(&response).map_err(|err| err.to_string())
}

#[tauri::command]
pub async fn http_stats(state: State<'_, HttpClientState>) -> Result<String, String> {
    serialize_stats(state.stats().await)
}

#[tauri::command]
pub async fn http_batch(
    state: State<'_, HttpClientState>,
    requests: Vec<BatchRequestPayload>,
) -> Result<String, String> {
    match state.run_batch(requests).await {
        Ok(result) => {
            let response = ApiResponse::ok(200, "OK", result);
            serde_json::to_string(&response).map_err(|err| err.to_string())
        }
        Err(err) => serialize_error(err),
    }
}
