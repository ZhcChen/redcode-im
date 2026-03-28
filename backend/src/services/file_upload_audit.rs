use crate::database::file_upload_audit_store::FileUploadAuditStore;
use crate::database::file_upload_store::FileUploadStore;
use crate::database::models::{FileUploadAuditTask, StorageProviderType};
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::Database;
use crate::error::AppError;
use crate::storage;
use chrono::{DateTime, Duration, Utc};
use quick_xml::de::from_str as from_xml_str;
use serde::Deserialize;
use serde_json::json;
use std::collections::BTreeMap;
use tracing::{info, warn};
use uuid::Uuid;

const STATUS_RETRY: i16 = 3;

/// 审核任务配置（全部 env 可选）
#[derive(Debug, Clone)]
pub struct FileUploadAuditConfig {
    pub enabled: bool,
    pub batch_size: i64,
    pub lease_seconds: i64,
    pub max_attempts: i32,
    pub poll_interval_seconds: i64,
    pub retry_base_seconds: i64,
    pub retry_max_seconds: i64,
    /// 腾讯云 CI BizType（可选；建议在控制台配置“全场景审核策略”并填入）
    pub tencent_ci_biz_type: Option<String>,
    /// 是否使用异步接口（图片/文本支持同步；默认统一用异步，减少单次请求耗时）
    pub tencent_ci_use_async: bool,
    /// 视频审核：是否开启音频/文本轨道审核（DetectContent=1）
    pub tencent_ci_video_detect_content: bool,
    /// 视频审核：截图间隔（秒）
    pub tencent_ci_video_snapshot_interval_seconds: i64,
    /// 视频审核：最大截图张数
    pub tencent_ci_video_snapshot_count: i32,
    /// 文本审核：DetectType（默认全量）
    pub tencent_ci_text_detect_type: String,
}

impl FileUploadAuditConfig {
    pub fn from_env() -> Self {
        fn read_i64(key: &str, default: i64) -> i64 {
            std::env::var(key)
                .ok()
                .and_then(|v| v.trim().parse::<i64>().ok())
                .unwrap_or(default)
        }

        fn read_i32(key: &str, default: i32) -> i32 {
            std::env::var(key)
                .ok()
                .and_then(|v| v.trim().parse::<i32>().ok())
                .unwrap_or(default)
        }

        fn read_bool(key: &str, default: bool) -> bool {
            std::env::var(key)
                .ok()
                .map(|v| v.trim().eq_ignore_ascii_case("true") || v.trim() == "1")
                .unwrap_or(default)
        }

        let enabled = std::env::var("FILE_UPLOAD_AUDIT_ENABLED")
            .ok()
            .map(|v| v.trim().eq_ignore_ascii_case("true") || v.trim() == "1")
            .unwrap_or(true);

        let tencent_ci_biz_type = std::env::var("FILE_UPLOAD_AUDIT_TENCENT_CI_BIZ_TYPE")
            .ok()
            .map(|v| v.trim().to_string())
            .filter(|v| !v.is_empty());

        Self {
            enabled,
            batch_size: read_i64("FILE_UPLOAD_AUDIT_BATCH_SIZE", 50),
            lease_seconds: read_i64("FILE_UPLOAD_AUDIT_LEASE_SECONDS", 120),
            max_attempts: read_i32("FILE_UPLOAD_AUDIT_MAX_ATTEMPTS", 12),
            poll_interval_seconds: read_i64("FILE_UPLOAD_AUDIT_POLL_INTERVAL_SECONDS", 15),
            retry_base_seconds: read_i64("FILE_UPLOAD_AUDIT_RETRY_BASE_SECONDS", 30),
            retry_max_seconds: read_i64("FILE_UPLOAD_AUDIT_RETRY_MAX_SECONDS", 3600),
            tencent_ci_biz_type,
            tencent_ci_use_async: read_bool("FILE_UPLOAD_AUDIT_TENCENT_CI_USE_ASYNC", true),
            tencent_ci_video_detect_content: read_bool(
                "FILE_UPLOAD_AUDIT_TENCENT_CI_VIDEO_DETECT_CONTENT",
                true,
            ),
            tencent_ci_video_snapshot_interval_seconds: read_i64(
                "FILE_UPLOAD_AUDIT_TENCENT_CI_VIDEO_SNAPSHOT_INTERVAL_SECONDS",
                50,
            ),
            tencent_ci_video_snapshot_count: read_i32(
                "FILE_UPLOAD_AUDIT_TENCENT_CI_VIDEO_SNAPSHOT_COUNT",
                100,
            ),
            tencent_ci_text_detect_type: std::env::var(
                "FILE_UPLOAD_AUDIT_TENCENT_CI_TEXT_DETECT_TYPE",
            )
            .ok()
            .map(|v| v.trim().to_string())
            .filter(|v| !v.is_empty())
            .unwrap_or_else(|| "Porn,Terrorism,Politics,Ads,Illegal,Abuse".to_string()),
        }
    }
}

/// 运行一次审核队列（抓取一批 due tasks 并处理）
pub async fn run_file_upload_audit_once(
    database: Database,
    cfg: &FileUploadAuditConfig,
) -> Result<(), AppError> {
    if !cfg.enabled {
        return Ok(());
    }

    let store = FileUploadAuditStore::new(database.clone());
    let tasks = store
        .claim_due_tasks(cfg.batch_size, cfg.lease_seconds)
        .await
        .map_err(|e| AppError::InternalError(format!("认领审核任务失败: {}", e)))?;

    if tasks.is_empty() {
        return Ok(());
    }

    info!("本轮认领到 {} 个审核任务", tasks.len());

    for task in tasks {
        if let Err(e) = process_task(database.clone(), cfg, &task).await {
            warn!(
                "处理审核任务失败: task_id={}, key={}, err={}",
                task.id, task.object_key, e
            );
        }
    }

    Ok(())
}

/// 触发单个任务“尽快执行”（不保证立即执行；用于业务入口侧切加速）
pub async fn trigger_task_now(
    database: Database,
    task_id: Uuid,
    cfg: &FileUploadAuditConfig,
) -> Result<(), AppError> {
    if !cfg.enabled {
        return Ok(());
    }

    let store = FileUploadAuditStore::new(database.clone());
    let claimed = store
        .claim_task_by_id(&task_id, cfg.lease_seconds)
        .await
        .map_err(|e| AppError::InternalError(format!("认领审核任务失败: {}", e)))?;

    let Some(task) = claimed else {
        return Ok(());
    };

    if let Err(e) = process_task(database, cfg, &task).await {
        warn!(
            "触发执行审核任务失败: task_id={}, key={}, err={}",
            task.id, task.object_key, e
        );
    }

    Ok(())
}

async fn process_task(
    database: Database,
    cfg: &FileUploadAuditConfig,
    task: &FileUploadAuditTask,
) -> Result<(), AppError> {
    // 超过重试次数：直接置为 failed，避免队列抖动
    if task.attempts >= cfg.max_attempts && task.status == STATUS_RETRY {
        let store = FileUploadAuditStore::new(database.clone());
        let _ = store
            .mark_failed(&task.id, "超过最大重试次数，已停止处理")
            .await;
        return Ok(());
    }

    let provider_store = StorageProviderStore::new(database.clone());
    let provider = provider_store
        .get_provider_by_id(&task.storage_provider_id)
        .await?
        .ok_or_else(|| AppError::NotFound("存储提供商不存在".to_string()))?;

    if !provider.is_active {
        let store = FileUploadAuditStore::new(database.clone());
        let _ = store
            .mark_retry(
                &task.id,
                "存储提供商未启用，稍后重试",
                next_retry_at(cfg, task.attempts),
            )
            .await;
        return Ok(());
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        let store = FileUploadAuditStore::new(database.clone());
        let _ = store
            .mark_failed(&task.id, "仅支持腾讯云 COS（TencentCos）审核")
            .await;
        return Ok(());
    }

    let bucket = provider
        .bucket_name
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
        .ok_or_else(|| AppError::ValidationError("存储提供商未配置 bucket_name".to_string()))?;

    let media_kind = normalize_media_kind(&task.media_kind);
    let ci_kind = map_media_kind_to_ci_kind(media_kind);
    let Some(ci_kind) = ci_kind else {
        let store = FileUploadAuditStore::new(database.clone());
        let _ = store
            .mark_failed(
                &task.id,
                format!("不支持的 media_kind: {}", media_kind).as_str(),
            )
            .await;
        return Ok(());
    };

    let ci = TencentCiClient::new(
        provider.secret_id.clone(),
        provider.secret_key.clone(),
        provider.region.clone(),
        provider.endpoint.clone(),
        bucket.to_string(),
    )?;

    let audit_store = FileUploadAuditStore::new(database.clone());

    // 1) 未提交：提交任务（拿到 JobId）
    if task
        .vendor_job_id
        .as_deref()
        .unwrap_or("")
        .trim()
        .is_empty()
    {
        let submit = ci.submit_auditing_job(ci_kind, &task.object_key, cfg).await;
        match submit {
            Ok(submitted) => {
                let next_run_at =
                    Utc::now() + Duration::seconds(ci_kind.default_poll_delay_seconds().max(1));
                let _ = audit_store
                    .mark_submitted(
                        &task.id,
                        &submitted.job_id,
                        next_run_at,
                        json!({
                            "vendor": "tencent_ci",
                            "kind": ci_kind.as_str(),
                            "submit": submitted.result_json,
                        }),
                    )
                    .await;
                return Ok(());
            }
            Err(e) => {
                let _ = audit_store
                    .mark_retry(
                        &task.id,
                        &format!("{}", e),
                        next_retry_at(cfg, task.attempts),
                    )
                    .await;
                return Ok(());
            }
        }
    }

    // 2) 已提交：查询结果
    let job_id = task.vendor_job_id.as_deref().unwrap_or("").trim();
    if job_id.is_empty() {
        let _ = audit_store
            .mark_retry(
                &task.id,
                "vendor_job_id 为空，稍后重试",
                next_retry_at(cfg, task.attempts),
            )
            .await;
        return Ok(());
    }

    match ci.query_auditing_job(ci_kind, job_id).await {
        Ok(query) => {
            // 未完成：延后再查
            if !query.is_finished() {
                let next_run_at = Utc::now() + Duration::seconds(cfg.poll_interval_seconds.max(1));
                let _ = audit_store.set_next_run_at(&task.id, next_run_at).await;
                return Ok(());
            }

            // 任务失败：按异常处理（入队重试）
            if query.state.eq_ignore_ascii_case("Failed") {
                let _ = audit_store
                    .mark_retry(
                        &task.id,
                        query.error_message.as_deref().unwrap_or("CI 审核任务失败"),
                        next_retry_at(cfg, task.attempts),
                    )
                    .await;
                return Ok(());
            }

            let audited_at = Utc::now();
            let merged_result = json!({
                "vendor": "tencent_ci",
                "kind": ci_kind.as_str(),
                "job": query.result_json,
            });

            if query.is_violation() {
                let rejected_reason = query
                    .rejected_reason
                    .clone()
                    .unwrap_or_else(|| "内容审核未通过".to_string());

                // 违规：先尝试删除对象，删除成功则置为 rejected；失败则置为 retry 并保留违规原因
                let storage_service = storage::create_storage_service(&provider)?;
                let delete_result = storage_service.delete_file(&task.object_key).await;

                match delete_result {
                    Ok(_) => {
                        let _ = audit_store
                            .mark_rejected(&task.id, &rejected_reason, audited_at, merged_result)
                            .await;

                        // 同步标记 file_upload_records 为 deleted（不存在则忽略）
                        let upload_store = FileUploadStore::new(database);
                        let _ = upload_store
                            .mark_deleted_by_key(
                                &provider.id,
                                &task.object_key,
                                Some(&format!("内容审核拒绝: {}", rejected_reason)),
                            )
                            .await;
                    }
                    Err(err) => {
                        let _ = sqlx::query(
                            r#"
                            UPDATE file_upload_audit_tasks
                            SET status = $2,
                                result = COALESCE(result, '{}'::jsonb) || $3::jsonb,
                                rejected_reason = $4,
                                last_error = $5,
                                attempts = attempts + 1,
                                next_run_at = $6,
                                audited_at = $7,
                                updated_at = NOW()
                            WHERE id = $1
                            "#,
                        )
                        .bind(&task.id)
                        .bind(STATUS_RETRY)
                        .bind(merged_result)
                        .bind(&rejected_reason)
                        .bind(format!("删除违规对象失败: {}", err))
                        .bind(next_retry_at(cfg, task.attempts))
                        .bind(audited_at)
                        .execute(audit_store.pool())
                        .await;
                    }
                }
            } else {
                let _ = audit_store
                    .mark_approved(&task.id, audited_at, merged_result)
                    .await;
            }
        }
        Err(e) => {
            let _ = audit_store
                .mark_retry(
                    &task.id,
                    &format!("{}", e),
                    next_retry_at(cfg, task.attempts),
                )
                .await;
        }
    }

    Ok(())
}

fn next_retry_at(cfg: &FileUploadAuditConfig, attempts: i32) -> DateTime<Utc> {
    let capped_attempts = attempts.max(0).min(30) as u32;
    let base = cfg.retry_base_seconds.max(1);
    let multiplier = 1_i64.checked_shl(capped_attempts).unwrap_or(i64::MAX);
    let mut delay = base.saturating_mul(multiplier);
    if delay > cfg.retry_max_seconds {
        delay = cfg.retry_max_seconds;
    }
    Utc::now() + Duration::seconds(delay.max(1))
}

fn normalize_media_kind(value: &str) -> &str {
    match value.trim().to_ascii_lowercase().as_str() {
        "image" => "image",
        "video" => "video",
        "audio" => "audio",
        "text" => "text",
        "document" => "document",
        _ => "unknown",
    }
}

#[derive(Debug, Clone, Copy)]
enum CiKind {
    Image,
    Video,
    Audio,
    Text,
    Document,
}

impl CiKind {
    fn as_str(&self) -> &'static str {
        match self {
            CiKind::Image => "image",
            CiKind::Video => "video",
            CiKind::Audio => "audio",
            CiKind::Text => "text",
            CiKind::Document => "document",
        }
    }

    fn auditing_path(&self) -> &'static str {
        match self {
            CiKind::Image => "/image/auditing",
            CiKind::Video => "/video/auditing",
            CiKind::Audio => "/audio/auditing",
            CiKind::Text => "/text/auditing",
            CiKind::Document => "/document/auditing",
        }
    }

    fn default_poll_delay_seconds(&self) -> i64 {
        match self {
            CiKind::Image => 5,
            CiKind::Text => 5,
            CiKind::Audio => 15,
            CiKind::Video => 20,
            CiKind::Document => 15,
        }
    }
}

fn map_media_kind_to_ci_kind(kind: &str) -> Option<CiKind> {
    match kind {
        "image" => Some(CiKind::Image),
        "video" => Some(CiKind::Video),
        "audio" => Some(CiKind::Audio),
        "text" => Some(CiKind::Text),
        "document" => Some(CiKind::Document),
        _ => None,
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename = "Response")]
struct CiResponse {
    #[serde(rename = "JobsDetail", default)]
    jobs_detail: Vec<CiJobsDetail>,
}

#[derive(Debug, Deserialize)]
struct CiJobsDetail {
    #[serde(rename = "Code")]
    code: Option<String>,
    #[serde(rename = "Message")]
    message: Option<String>,
    #[serde(rename = "JobId")]
    job_id: Option<String>,
    #[serde(rename = "State")]
    state: Option<String>,
    #[serde(rename = "Result")]
    result: Option<i32>,
    #[serde(rename = "Label")]
    label: Option<String>,
}

struct TencentCiClient {
    signer: crate::storage::cos::TencentCosService,
    bucket_name: String,
    region: String,
    http: reqwest::Client,
    ci_base_url: Option<String>,
    ci_base_host: Option<String>,
    ci_base_path_prefix: String,
}

fn read_tencent_ci_base_url() -> Option<String> {
    let raw = std::env::var("FILE_UPLOAD_AUDIT_TENCENT_CI_BASE_URL").ok()?;
    let trimmed = raw.trim().trim_end_matches('/').to_string();
    if trimmed.is_empty() {
        return None;
    }
    reqwest::Url::parse(&trimmed).ok()?;
    Some(trimmed)
}

fn read_tencent_ci_base_host() -> Option<String> {
    let raw = std::env::var("FILE_UPLOAD_AUDIT_TENCENT_CI_BASE_URL").ok()?;
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }

    let parsed = reqwest::Url::parse(trimmed).ok()?;
    let host = parsed.host_str()?;
    let with_port = match parsed.port() {
        Some(port) => format!("{}:{}", host, port),
        None => host.to_string(),
    };
    Some(with_port)
}

fn read_tencent_ci_base_path_prefix() -> String {
    let raw = std::env::var("FILE_UPLOAD_AUDIT_TENCENT_CI_BASE_URL").ok();
    let Some(raw) = raw else {
        return String::new();
    };
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    let Ok(parsed) = reqwest::Url::parse(trimmed) else {
        return String::new();
    };
    let path = parsed.path().trim_end_matches('/');
    if path == "/" {
        return String::new();
    }
    path.to_string()
}

impl TencentCiClient {
    fn new(
        secret_id: String,
        secret_key: String,
        region: String,
        endpoint: String,
        bucket_name: String,
    ) -> Result<Self, AppError> {
        let signer = crate::storage::cos::TencentCosService::new(
            secret_id,
            secret_key,
            region.clone(),
            endpoint,
            bucket_name.clone(),
        )?;
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .map_err(|e| AppError::InternalError(format!("创建HTTP客户端失败: {}", e)))?;

        Ok(Self {
            signer,
            bucket_name,
            region,
            http,
            ci_base_url: read_tencent_ci_base_url(),
            ci_base_host: read_tencent_ci_base_host(),
            ci_base_path_prefix: read_tencent_ci_base_path_prefix(),
        })
    }

    fn ci_host(&self) -> String {
        if let Some(host) = &self.ci_base_host {
            return host.clone();
        }
        format!("{}.ci.{}.myqcloud.com", self.bucket_name, self.region)
    }

    fn ci_url_and_signed_path(&self, path: &str) -> (String, String) {
        if let Some(base_url) = &self.ci_base_url {
            let prefix = self.ci_base_path_prefix.trim_end_matches('/');
            let signed_path = if prefix.is_empty() {
                path.to_string()
            } else {
                format!("{}{}", prefix, path)
            };
            let url = format!("{}{}", base_url, path);
            (url, signed_path)
        } else {
            let host = self.ci_host();
            (format!("https://{}{}", host, path), path.to_string())
        }
    }

    async fn submit_auditing_job(
        &self,
        kind: CiKind,
        object_key: &str,
        cfg: &FileUploadAuditConfig,
    ) -> Result<CiSubmitted, AppError> {
        let host = self.ci_host();
        let path = kind.auditing_path();
        let (url, signed_path) = self.ci_url_and_signed_path(path);

        let xml_body = build_ci_auditing_request_xml(object_key, kind, cfg);

        let mut headers = BTreeMap::new();
        headers.insert("Content-Type".to_string(), "application/xml".to_string());

        let timestamp = time::OffsetDateTime::now_utc().unix_timestamp();
        let authorization = self.signer.generate_signature_v1_with_host(
            "POST",
            &signed_path,
            &headers,
            timestamp,
            &host,
            None,
        );

        let response = self
            .http
            .post(&url)
            .header("Authorization", authorization)
            .header("Host", &host)
            .header("Content-Type", "application/xml")
            .body(xml_body)
            .send()
            .await
            .map_err(|e| AppError::InternalError(format!("提交 CI 审核任务失败: {}", e)))?;

        let status = response.status();
        let text = response.text().await.unwrap_or_default();
        if !status.is_success() {
            return Err(AppError::InternalError(format!(
                "提交 CI 审核任务失败: status={}, body={}",
                status, text
            )));
        }

        let parsed: CiResponse = from_xml_str(&text).map_err(|e| {
            AppError::InternalError(format!("解析 CI 提交响应失败: {}, body={}", e, text))
        })?;

        let detail = parsed.jobs_detail.into_iter().next().ok_or_else(|| {
            AppError::InternalError(format!("CI 提交响应缺少 JobsDetail: {}", text))
        })?;

        if let Some(code) = detail.code.as_deref() {
            if !code.eq_ignore_ascii_case("Success") {
                return Err(AppError::InternalError(format!(
                    "CI 提交返回错误: code={}, message={}",
                    code,
                    detail.message.as_deref().unwrap_or("")
                )));
            }
        }

        let job_id = detail
            .job_id
            .ok_or_else(|| AppError::InternalError(format!("CI 提交未返回 JobId: {}", text)))?;

        Ok(CiSubmitted {
            job_id,
            result_json: json!({
                "state": detail.state,
                "code": detail.code,
                "message": detail.message,
                "raw": text,
            }),
        })
    }

    async fn query_auditing_job(
        &self,
        kind: CiKind,
        job_id: &str,
    ) -> Result<CiQueryResult, AppError> {
        let host = self.ci_host();
        let base = kind.auditing_path();
        let path = format!("{}/{}", base, job_id);
        let (url, signed_path) = self.ci_url_and_signed_path(&path);

        let headers = BTreeMap::new();
        let timestamp = time::OffsetDateTime::now_utc().unix_timestamp();
        let authorization = self.signer.generate_signature_v1_with_host(
            "GET",
            &signed_path,
            &headers,
            timestamp,
            &host,
            None,
        );

        let response = self
            .http
            .get(&url)
            .header("Authorization", authorization)
            .header("Host", &host)
            .send()
            .await
            .map_err(|e| AppError::InternalError(format!("查询 CI 审核结果失败: {}", e)))?;

        let status = response.status();
        let text = response.text().await.unwrap_or_default();
        if !status.is_success() {
            return Err(AppError::InternalError(format!(
                "查询 CI 审核结果失败: status={}, body={}",
                status, text
            )));
        }

        let parsed: CiResponse = from_xml_str(&text).map_err(|e| {
            AppError::InternalError(format!("解析 CI 查询响应失败: {}, body={}", e, text))
        })?;

        let detail = parsed.jobs_detail.into_iter().next().ok_or_else(|| {
            AppError::InternalError(format!("CI 查询响应缺少 JobsDetail: {}", text))
        })?;

        if let Some(code) = detail.code.as_deref() {
            if !code.eq_ignore_ascii_case("Success") {
                return Err(AppError::InternalError(format!(
                    "CI 查询返回错误: code={}, message={}",
                    code,
                    detail.message.as_deref().unwrap_or("")
                )));
            }
        }

        let state_opt = detail.state.clone();
        let message_opt = detail.message.clone();
        let code_opt = detail.code.clone();
        let label_opt = detail.label.clone();

        let state = state_opt.clone().unwrap_or_else(|| "Unknown".to_string());
        let result = detail.result;
        let label = label_opt.clone().unwrap_or_default();
        let rejected_reason = match result {
            Some(0) | None => None,
            Some(1) => {
                if label.is_empty() {
                    Some("内容违规".to_string())
                } else {
                    Some(format!("内容违规: {}", label))
                }
            }
            Some(2) => {
                if label.is_empty() {
                    Some("疑似违规".to_string())
                } else {
                    Some(format!("疑似违规: {}", label))
                }
            }
            Some(other) => Some(format!("审核未通过: result={}", other)),
        };

        Ok(CiQueryResult {
            state,
            result,
            rejected_reason,
            error_message: message_opt.clone(),
            result_json: json!({
                "state": state_opt,
                "result": result,
                "label": label_opt,
                "code": code_opt,
                "message": message_opt,
                "raw": text,
            }),
        })
    }
}

struct CiSubmitted {
    job_id: String,
    result_json: serde_json::Value,
}

struct CiQueryResult {
    state: String,
    result: Option<i32>,
    rejected_reason: Option<String>,
    error_message: Option<String>,
    result_json: serde_json::Value,
}

impl CiQueryResult {
    fn is_finished(&self) -> bool {
        self.state.eq_ignore_ascii_case("Success") || self.state.eq_ignore_ascii_case("Failed")
    }

    fn is_violation(&self) -> bool {
        matches!(self.result, Some(1) | Some(2))
    }
}

fn build_ci_auditing_request_xml(
    object_key: &str,
    kind: CiKind,
    cfg: &FileUploadAuditConfig,
) -> String {
    let object_key = xml_escape(object_key);
    let biz_type = cfg.tencent_ci_biz_type.as_deref().map(xml_escape);

    match kind {
        CiKind::Image => {
            // 参考：图片审核任务（支持同步/异步；默认统一使用异步）
            // https://cloud.tencent.com/document/product/436/54063
            let async_flag = if cfg.tencent_ci_use_async { "1" } else { "0" };
            let biz_type_xml = biz_type
                .as_deref()
                .map(|v| format!("<BizType>{}</BizType>", v))
                .unwrap_or_default();
            format!(
                r#"<Request><Input><Object>{}</Object></Input><Conf>{}<Async>{}</Async></Conf></Request>"#,
                object_key, biz_type_xml, async_flag
            )
        }
        CiKind::Video => {
            // 参考：视频审核任务（Snapshot 必填）
            // https://cloud.tencent.com/document/product/436/46427
            let biz_type_xml = biz_type
                .as_deref()
                .map(|v| format!("<BizType>{}</BizType>", v))
                .unwrap_or_default();
            let detect_content = if cfg.tencent_ci_video_detect_content {
                1
            } else {
                0
            };
            let interval = cfg.tencent_ci_video_snapshot_interval_seconds.max(1);
            let count = cfg.tencent_ci_video_snapshot_count.max(1);
            format!(
                r#"<Request><Input><Object>{}</Object></Input><Conf>{}<DetectContent>{}</DetectContent><Snapshot><Mode>Interval</Mode><TimeInterval>{}</TimeInterval><Count>{}</Count></Snapshot></Conf></Request>"#,
                object_key, biz_type_xml, detect_content, interval, count
            )
        }
        CiKind::Audio => {
            // 参考：音频审核任务
            // https://cloud.tencent.com/document/product/436/53395
            let biz_type_xml = biz_type
                .as_deref()
                .map(|v| format!("<BizType>{}</BizType>", v))
                .unwrap_or_default();
            if biz_type_xml.is_empty() {
                format!(
                    r#"<Request><Input><Object>{}</Object></Input></Request>"#,
                    object_key
                )
            } else {
                format!(
                    r#"<Request><Input><Object>{}</Object></Input><Conf>{}</Conf></Request>"#,
                    object_key, biz_type_xml
                )
            }
        }
        CiKind::Text => {
            // 参考：文本审核任务
            // https://cloud.tencent.com/document/product/436/53977
            let biz_type_xml = biz_type
                .as_deref()
                .map(|v| format!("<BizType>{}</BizType>", v))
                .unwrap_or_default();
            let detect_type = xml_escape(&cfg.tencent_ci_text_detect_type);
            format!(
                r#"<Request><Input><Object>{}</Object></Input><Conf>{}<DetectType>{}</DetectType></Conf></Request>"#,
                object_key, biz_type_xml, detect_type
            )
        }
        CiKind::Document => {
            // 参考：文档审核任务
            // https://cloud.tencent.com/document/product/436/53394
            let biz_type_xml = biz_type
                .as_deref()
                .map(|v| format!("<BizType>{}</BizType>", v))
                .unwrap_or_default();
            if biz_type_xml.is_empty() {
                format!(
                    r#"<Request><Input><Object>{}</Object></Input></Request>"#,
                    object_key
                )
            } else {
                format!(
                    r#"<Request><Input><Object>{}</Object></Input><Conf>{}</Conf></Request>"#,
                    object_key, biz_type_xml
                )
            }
        }
    }
}

fn xml_escape(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&apos;"),
            _ => out.push(ch),
        }
    }
    out
}
