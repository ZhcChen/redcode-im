use chrono::{Duration, Utc};
use futures_util::StreamExt;
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use once_cell::sync::OnceCell;
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, HashSet},
    env,
    sync::Arc,
    time::Duration as StdDuration,
};
use tokio::sync::{mpsc, RwLock, Semaphore};
use tokio_stream::wrappers::ReceiverStream;
use tracing::{info, warn};
use uuid::Uuid;

use crate::crypto::SecretCrypto;
use crate::database::member_with_user_info::RoomMemberWithUserInfo;
use crate::database::message_store::MessageStore;
use crate::database::models::{
    MessagePart, MessagePartType, MessageWithSender, NotificationSetting, PushDevice, RoomType,
};
use crate::database::push_device_store::PushDeviceStore;
use crate::database::push_job_store::PushJobStore;
use crate::database::push_log_store::PushLogStore;
use crate::database::push_provider_config_store::PushProviderConfigStore;
use crate::database::room_store::RoomStore;
use crate::database::settings_store::SettingsStore;
use crate::redis::models::CacheKeys;
use crate::AppState;

const SETTING_PUSH_ENABLED: &str = "push_enabled";
const SETTING_PUSH_SKIP_IF_ONLINE: &str = "push_skip_if_online";

const PUSH_RUNTIME_TTL_SECONDS: i64 = 10;
const PUSH_SEND_MAX_ATTEMPTS: i32 = 3;
const PUSH_SEND_RETRY_BASE_MS: u64 = 300;
const PUSH_SEND_HTTP_TIMEOUT_SECONDS: u64 = 10;
const PUSH_SEND_CONCURRENCY: usize = 50;
const PUSH_DEVICE_SEND_CONCURRENCY: usize = 20;
const PUSH_JOB_QUEUE_CAPACITY: usize = 10_000;
const PUSH_JOB_CONCURRENCY: usize = 20;
const PUSH_DB_QUEUE_BATCH_SIZE: i64 = 200;
const PUSH_DB_QUEUE_LEASE_SECONDS: i64 = 120;
const PUSH_DB_QUEUE_POLL_INTERVAL_SECONDS: u64 = 2;
const PUSH_DB_QUEUE_MAX_ATTEMPTS: i32 = 12;
const PUSH_DB_QUEUE_RETRY_BASE_SECONDS: i64 = 2;
const PUSH_DB_QUEUE_RETRY_MAX_SECONDS: i64 = 300;

static PUSH_RUNTIME: OnceCell<RwLock<PushRuntime>> = OnceCell::new();
static PUSH_DISPATCHER: OnceCell<PushDispatcher> = OnceCell::new();
static PUSH_SEND_SEMAPHORE: OnceCell<Arc<Semaphore>> = OnceCell::new();

#[derive(Debug)]
enum PushJob {
    NewMessage {
        message: MessageWithSender,
        parts: Vec<MessagePart>,
    },
    NewMessageById {
        message_id: Uuid,
    },
    FriendRequest {
        request_id: Uuid,
        requester_id: Uuid,
        requester_name: String,
        target_user_id: Uuid,
        message: Option<String>,
    },
    GroupEvent {
        targets: Vec<Uuid>,
        room_id: Uuid,
        room_name: String,
        event: String,
        title: String,
        body: String,
    },
}

#[derive(Debug)]
struct PushDispatcher {
    tx: mpsc::Sender<PushJob>,
}

#[derive(Debug, Clone, Deserialize)]
struct GoogleServiceAccount {
    project_id: String,
    client_email: String,
    private_key: String,
    #[serde(default)]
    token_uri: Option<String>,
}

#[derive(Debug, Clone)]
struct CachedAccessToken {
    access_token: String,
    expires_at: chrono::DateTime<Utc>,
}

#[derive(Debug)]
struct FcmClient {
    http: reqwest::Client,
    sa: GoogleServiceAccount,
    cached_token: RwLock<Option<CachedAccessToken>>,
}

#[derive(Debug, Clone)]
struct PushRuntimeSnapshot {
    enabled: bool,
    skip_if_online: bool,
    fcm: Option<Arc<FcmClient>>,
}

#[derive(Debug)]
struct PushRuntime {
    loaded_at: chrono::DateTime<Utc>,
    enabled: bool,
    skip_if_online: bool,
    fcm_fingerprint: Option<String>,
    fcm: Option<Arc<FcmClient>>,
}

impl Default for PushRuntime {
    fn default() -> Self {
        Self {
            loaded_at: Utc::now() - Duration::seconds(PUSH_RUNTIME_TTL_SECONDS * 10),
            enabled: true,
            skip_if_online: true,
            fcm_fingerprint: None,
            fcm: None,
        }
    }
}

#[derive(Debug, Deserialize)]
struct OAuthTokenResponse {
    access_token: String,
    expires_in: i64,
    #[allow(dead_code)]
    token_type: Option<String>,
}

#[derive(Debug, Deserialize)]
struct FcmSendResponse {
    #[allow(dead_code)]
    name: Option<String>,
}

#[derive(Debug, Deserialize)]
struct FcmErrorEnvelope {
    error: Option<FcmErrorDetail>,
}

#[derive(Debug, Deserialize)]
struct FcmErrorDetail {
    message: Option<String>,
    #[allow(dead_code)]
    status: Option<String>,
    details: Option<Vec<FcmErrorExtraDetail>>,
}

#[derive(Debug, Deserialize)]
struct FcmErrorExtraDetail {
    #[serde(rename = "@type")]
    #[allow(dead_code)]
    type_url: Option<String>,
    #[serde(rename = "errorCode")]
    error_code: Option<String>,
}

#[derive(Debug, Clone)]
enum FcmSendErrorKind {
    Transport,
    Config,
    Http {
        status: reqwest::StatusCode,
        error_code: Option<String>,
    },
}

#[derive(Debug, Clone)]
struct FcmSendError {
    kind: FcmSendErrorKind,
    message: String,
}

impl FcmSendError {
    fn is_unregistered(&self) -> bool {
        matches!(
            &self.kind,
            FcmSendErrorKind::Http {
                error_code: Some(code),
                ..
            } if code.eq_ignore_ascii_case("UNREGISTERED")
        )
    }

    fn is_invalid_token(&self) -> bool {
        match &self.kind {
            FcmSendErrorKind::Transport => false,
            FcmSendErrorKind::Config => false,
            FcmSendErrorKind::Http { status, .. } => {
                if *status != reqwest::StatusCode::BAD_REQUEST {
                    return false;
                }

                let message = self.message.to_lowercase();
                message.contains("not a valid fcm registration token")
                    || message.contains("registration token is not a valid")
                    || message.contains("invalid registration token")
            }
        }
    }

    fn is_permanent(&self) -> bool {
        match &self.kind {
            FcmSendErrorKind::Transport => false,
            FcmSendErrorKind::Config => true,
            FcmSendErrorKind::Http { status, .. } => {
                if *status == reqwest::StatusCode::TOO_MANY_REQUESTS {
                    return false;
                }
                status.is_client_error()
            }
        }
    }

    fn to_log_string(&self) -> String {
        match &self.kind {
            FcmSendErrorKind::Transport => self.message.clone(),
            FcmSendErrorKind::Config => self.message.clone(),
            FcmSendErrorKind::Http { status, error_code } => {
                if let Some(code) = error_code.as_deref().filter(|v| !v.trim().is_empty()) {
                    format!("status={} code={} {}", status, code, self.message)
                } else {
                    format!("status={} {}", status, self.message)
                }
            }
        }
    }
}

#[derive(Debug, Serialize)]
struct ServiceAccountClaims {
    iss: String,
    scope: String,
    aud: String,
    iat: usize,
    exp: usize,
}

impl FcmClient {
    fn from_service_account_json(raw: &str) -> Result<Self, String> {
        let sa: GoogleServiceAccount = serde_json::from_str(raw)
            .map_err(|e| format!("解析 FCM service account JSON 失败: {}", e))?;

        let timeout_seconds =
            env_u64("PUSH_HTTP_TIMEOUT_SECONDS", PUSH_SEND_HTTP_TIMEOUT_SECONDS).clamp(1, 120);

        let http = reqwest::Client::builder()
            .timeout(StdDuration::from_secs(timeout_seconds))
            .connect_timeout(StdDuration::from_secs(5))
            .build()
            .map_err(|e| format!("构建 HTTP client 失败: {}", e))?;

        Ok(Self {
            http,
            sa,
            cached_token: RwLock::new(None),
        })
    }

    async fn access_token(&self) -> Result<String, FcmSendError> {
        {
            let guard = self.cached_token.read().await;
            if let Some(token) = guard.as_ref() {
                // 提前 60s 刷新，避免临界点失败
                if token.expires_at > Utc::now() + Duration::seconds(60) {
                    return Ok(token.access_token.clone());
                }
            }
        }

        let token_uri = self
            .sa
            .token_uri
            .clone()
            .unwrap_or_else(|| "https://oauth2.googleapis.com/token".to_string());

        let now = Utc::now();
        let iat = now.timestamp() as usize;
        let exp = (now + Duration::minutes(55)).timestamp() as usize;

        let claims = ServiceAccountClaims {
            iss: self.sa.client_email.clone(),
            scope: "https://www.googleapis.com/auth/firebase.messaging".to_string(),
            aud: token_uri.clone(),
            iat,
            exp,
        };

        let header = Header::new(Algorithm::RS256);
        let key = EncodingKey::from_rsa_pem(self.sa.private_key.as_bytes()).map_err(|e| {
            FcmSendError {
                kind: FcmSendErrorKind::Config,
                message: format!("解析 private_key 失败: {}", e),
            }
        })?;
        let jwt = encode(&header, &claims, &key).map_err(|e| FcmSendError {
            kind: FcmSendErrorKind::Config,
            message: format!("签名 JWT 失败: {}", e),
        })?;

        let mut form = HashMap::new();
        form.insert("grant_type", "urn:ietf:params:oauth:grant-type:jwt-bearer");
        form.insert("assertion", jwt.as_str());

        let resp = self
            .http
            .post(&token_uri)
            .header(CONTENT_TYPE, "application/x-www-form-urlencoded")
            .form(&form)
            .send()
            .await
            .map_err(|e| FcmSendError {
                kind: FcmSendErrorKind::Transport,
                message: format!("请求 Google OAuth2 token 失败: {}", e),
            })?;

        let status = resp.status();
        let text = resp.text().await.map_err(|e| FcmSendError {
            kind: FcmSendErrorKind::Transport,
            message: format!("读取 token 响应失败: {}", e),
        })?;

        if !status.is_success() {
            return Err(FcmSendError {
                kind: if status.is_client_error() {
                    FcmSendErrorKind::Config
                } else {
                    FcmSendErrorKind::Transport
                },
                message: format!("获取 access_token 失败: status={}, body={}", status, text),
            });
        }

        let parsed: OAuthTokenResponse = serde_json::from_str(&text).map_err(|e| FcmSendError {
            kind: FcmSendErrorKind::Transport,
            message: format!("解析 token 响应失败: {}", e),
        })?;

        let expires_at = Utc::now() + Duration::seconds(parsed.expires_in);
        {
            let mut guard = self.cached_token.write().await;
            *guard = Some(CachedAccessToken {
                access_token: parsed.access_token.clone(),
                expires_at,
            });
        }

        Ok(parsed.access_token)
    }

    async fn send_to_token(
        &self,
        device_token: &str,
        title: &str,
        body: &str,
        data: &HashMap<String, String>,
    ) -> Result<(), FcmSendError> {
        let access_token = self.access_token().await?;

        let url = format!(
            "https://fcm.googleapis.com/v1/projects/{}/messages:send",
            self.sa.project_id
        );

        let mut headers = HeaderMap::new();
        headers.insert(
            AUTHORIZATION,
            HeaderValue::from_str(&format!("Bearer {}", access_token)).map_err(|e| {
                FcmSendError {
                    kind: FcmSendErrorKind::Config,
                    message: format!("构造 Authorization header 失败: {}", e),
                }
            })?,
        );
        headers.insert(
            CONTENT_TYPE,
            HeaderValue::from_static("application/json; charset=utf-8"),
        );

        let payload = serde_json::json!({
            "message": {
                "token": device_token,
                "notification": {
                    "title": title,
                    "body": body,
                },
                "data": data,
            }
        });

        let _permit = push_send_semaphore()
            .clone()
            .acquire_owned()
            .await
            .map_err(|_| FcmSendError {
                kind: FcmSendErrorKind::Transport,
                message: "获取 push send semaphore 失败".to_string(),
            })?;

        let resp = self
            .http
            .post(&url)
            .headers(headers)
            .json(&payload)
            .send()
            .await
            .map_err(|e| FcmSendError {
                kind: FcmSendErrorKind::Transport,
                message: format!("请求 FCM 失败: {}", e),
            })?;

        let status = resp.status();
        let text = resp.text().await.map_err(|e| FcmSendError {
            kind: FcmSendErrorKind::Transport,
            message: format!("读取 FCM 响应失败: {}", e),
        })?;

        if status.is_success() {
            let _ = serde_json::from_str::<FcmSendResponse>(&text).ok();
            return Ok(());
        }

        let parsed = serde_json::from_str::<FcmErrorEnvelope>(&text)
            .ok()
            .and_then(|e| e.error);
        let message = parsed
            .as_ref()
            .and_then(|d| d.message.clone())
            .unwrap_or_else(|| text.clone());
        let error_code = parsed
            .and_then(|d| {
                d.details
                    .unwrap_or_default()
                    .into_iter()
                    .find_map(|detail| detail.error_code)
            })
            .filter(|v| !v.trim().is_empty());

        Err(FcmSendError {
            kind: FcmSendErrorKind::Http { status, error_code },
            message,
        })
    }
}

fn env_flag(name: &str, default: bool) -> bool {
    match env::var(name) {
        Ok(v) => match v.trim().to_lowercase().as_str() {
            "1" | "true" | "yes" | "y" | "on" => true,
            "0" | "false" | "no" | "n" | "off" => false,
            _ => default,
        },
        Err(_) => default,
    }
}

fn env_usize(name: &str, default: usize) -> usize {
    env::var(name)
        .ok()
        .and_then(|v| v.trim().parse::<usize>().ok())
        .unwrap_or(default)
}

fn env_u64(name: &str, default: u64) -> u64 {
    env::var(name)
        .ok()
        .and_then(|v| v.trim().parse::<u64>().ok())
        .unwrap_or(default)
}

fn env_i64(name: &str, default: i64) -> i64 {
    env::var(name)
        .ok()
        .and_then(|v| v.trim().parse::<i64>().ok())
        .unwrap_or(default)
}

fn env_i32(name: &str, default: i32) -> i32 {
    env::var(name)
        .ok()
        .and_then(|v| v.trim().parse::<i32>().ok())
        .unwrap_or(default)
}

fn parse_bool_value(value: &str, default: bool) -> bool {
    match value.trim().to_lowercase().as_str() {
        "1" | "true" | "yes" | "y" | "on" => true,
        "0" | "false" | "no" | "n" | "off" => false,
        _ => default,
    }
}

fn push_runtime_lock() -> &'static RwLock<PushRuntime> {
    PUSH_RUNTIME.get_or_init(|| RwLock::new(PushRuntime::default()))
}

fn push_send_semaphore() -> &'static Arc<Semaphore> {
    PUSH_SEND_SEMAPHORE.get_or_init(|| {
        let value = env_usize("PUSH_SEND_CONCURRENCY", PUSH_SEND_CONCURRENCY);
        Arc::new(Semaphore::new(value.clamp(1, 500)))
    })
}

fn push_dispatcher() -> Option<&'static PushDispatcher> {
    PUSH_DISPATCHER.get()
}

fn enqueue_push_job_to_db(state: AppState, job_type: &'static str, payload: serde_json::Value) {
    tokio::spawn(async move {
        let store = PushJobStore::new(state.database.pool());
        if let Err(e) = store.enqueue(job_type, &payload, Utc::now()).await {
            warn!(
                "Push: 写入 push_job_queue 失败 job_type={}, err={}",
                job_type, e
            );
        }
    });
}

#[derive(Debug, Deserialize)]
struct DbMessageJobPayload {
    message_id: Uuid,
}

#[derive(Debug, Deserialize)]
struct DbFriendRequestJobPayload {
    request_id: Uuid,
    requester_id: Uuid,
    requester_name: String,
    target_user_id: Uuid,
    message: Option<String>,
}

#[derive(Debug, Deserialize)]
struct DbGroupEventJobPayload {
    targets: Vec<Uuid>,
    room_id: Uuid,
    room_name: String,
    event: String,
    title: String,
    body: String,
}

#[derive(Debug, Clone)]
struct PushDbQueueConfig {
    enabled: bool,
    batch_size: i64,
    lease_seconds: i64,
    poll_interval_seconds: u64,
    max_attempts: i32,
    retry_base_seconds: i64,
    retry_max_seconds: i64,
}

impl PushDbQueueConfig {
    fn from_env() -> Self {
        Self {
            enabled: env_flag("PUSH_DB_QUEUE_ENABLED", true),
            batch_size: env_i64("PUSH_DB_QUEUE_BATCH_SIZE", PUSH_DB_QUEUE_BATCH_SIZE).clamp(1, 2000),
            lease_seconds: env_i64("PUSH_DB_QUEUE_LEASE_SECONDS", PUSH_DB_QUEUE_LEASE_SECONDS)
                .clamp(5, 3600),
            poll_interval_seconds: env_u64(
                "PUSH_DB_QUEUE_POLL_INTERVAL_SECONDS",
                PUSH_DB_QUEUE_POLL_INTERVAL_SECONDS,
            )
            .clamp(1, 60),
            max_attempts: env_i32("PUSH_DB_QUEUE_MAX_ATTEMPTS", PUSH_DB_QUEUE_MAX_ATTEMPTS)
                .clamp(1, 100),
            retry_base_seconds: env_i64(
                "PUSH_DB_QUEUE_RETRY_BASE_SECONDS",
                PUSH_DB_QUEUE_RETRY_BASE_SECONDS,
            )
            .clamp(1, 3600),
            retry_max_seconds: env_i64(
                "PUSH_DB_QUEUE_RETRY_MAX_SECONDS",
                PUSH_DB_QUEUE_RETRY_MAX_SECONDS,
            )
            .clamp(1, 24 * 3600),
        }
    }
}

fn push_db_next_retry_at(cfg: &PushDbQueueConfig, attempts: i32) -> chrono::DateTime<Utc> {
    let exp = attempts.clamp(0, 16) as u32;
    let base = cfg.retry_base_seconds as u64;
    let max = cfg.retry_max_seconds as u64;
    let delay = base.saturating_mul(2u64.saturating_pow(exp)).min(max) as i64;
    Utc::now() + Duration::seconds(delay)
}

async fn run_push_db_queue_once(state: &AppState, cfg: &PushDbQueueConfig) {
    if !cfg.enabled {
        return;
    }

    let Some(dispatcher) = push_dispatcher() else {
        return;
    };

    let store = PushJobStore::new(state.database.pool());
    let jobs = match store.claim_due_jobs(cfg.batch_size, cfg.lease_seconds).await {
        Ok(v) => v,
        Err(e) => {
            warn!("Push: claim push_job_queue 失败: {}", e);
            return;
        }
    };

    if jobs.is_empty() {
        return;
    }

    for job in jobs {
        if job.attempts >= cfg.max_attempts {
            let _ = store
                .mark_failed(&job.id, "超过最大重试次数，已停止入队")
                .await;
            continue;
        }

        let enqueue_result = match job.job_type.as_str() {
            "message" => {
                let payload: DbMessageJobPayload = match serde_json::from_value(job.payload.clone())
                {
                    Ok(v) => v,
                    Err(e) => {
                        let _ = store
                            .mark_failed(&job.id, &format!("解析 payload 失败: {}", e))
                            .await;
                        continue;
                    }
                };
                dispatcher
                    .tx
                    .try_send(PushJob::NewMessageById {
                        message_id: payload.message_id,
                    })
            }
            "friend_request" => {
                let payload: DbFriendRequestJobPayload =
                    match serde_json::from_value(job.payload.clone()) {
                        Ok(v) => v,
                        Err(e) => {
                            let _ = store
                                .mark_failed(&job.id, &format!("解析 payload 失败: {}", e))
                                .await;
                            continue;
                        }
                    };

                dispatcher.tx.try_send(PushJob::FriendRequest {
                    request_id: payload.request_id,
                    requester_id: payload.requester_id,
                    requester_name: payload.requester_name,
                    target_user_id: payload.target_user_id,
                    message: payload.message,
                })
            }
            "group_event" => {
                let payload: DbGroupEventJobPayload =
                    match serde_json::from_value(job.payload.clone()) {
                        Ok(v) => v,
                        Err(e) => {
                            let _ = store
                                .mark_failed(&job.id, &format!("解析 payload 失败: {}", e))
                                .await;
                            continue;
                        }
                    };

                dispatcher.tx.try_send(PushJob::GroupEvent {
                    targets: payload.targets,
                    room_id: payload.room_id,
                    room_name: payload.room_name,
                    event: payload.event,
                    title: payload.title,
                    body: payload.body,
                })
            }
            other => {
                let _ = store
                    .mark_failed(&job.id, &format!("不支持的 job_type: {}", other))
                    .await;
                continue;
            }
        };

        match enqueue_result {
            Ok(_) => {
                let _ = store.mark_done(&job.id).await;
            }
            Err(e) => {
                let reason = match e {
                    tokio::sync::mpsc::error::TrySendError::Full(_) => "内存队列满",
                    tokio::sync::mpsc::error::TrySendError::Closed(_) => "内存队列已关闭",
                };
                let next_run_at = push_db_next_retry_at(cfg, job.attempts);
                let _ = store
                    .mark_retry(
                        &job.id,
                        &format!("{}，稍后重试入队", reason),
                        next_run_at,
                    )
                    .await;
            }
        }
    }
}

fn start_push_db_queue_worker(state: AppState) {
    let cfg = PushDbQueueConfig::from_env();
    if !cfg.enabled {
        return;
    }

    tokio::spawn(async move {
        loop {
            run_push_db_queue_once(&state, &cfg).await;
            tokio::time::sleep(tokio::time::Duration::from_secs(cfg.poll_interval_seconds)).await;
        }
    });
}

pub fn init_push_dispatcher(state: AppState) {
    if push_dispatcher().is_some() {
        return;
    }

    let capacity = env_usize("PUSH_JOB_QUEUE_CAPACITY", PUSH_JOB_QUEUE_CAPACITY).clamp(1, 200_000);
    let concurrency = env_usize("PUSH_JOB_CONCURRENCY", PUSH_JOB_CONCURRENCY).clamp(1, 200);
    let (tx, rx) = mpsc::channel::<PushJob>(capacity);

    if PUSH_DISPATCHER.set(PushDispatcher { tx }).is_err() {
        return;
    }

    let worker_state = state.clone();
    tokio::spawn(async move {
        ReceiverStream::new(rx)
            .for_each_concurrent(concurrency, |job| {
                let state = worker_state.clone();
                async move {
                    match job {
                        PushJob::NewMessage { message, parts } => {
                            notify_new_message(state, message, parts).await;
                        }
                        PushJob::NewMessageById { message_id } => {
                            let store = MessageStore::new(state.database.pool());
                            let message = match store.get_message_with_sender(message_id).await {
                                Ok(Some(m)) => m,
                                Ok(None) => {
                                    warn!(
                                        "Push: message 不存在，跳过离线推送 message_id={}",
                                        message_id
                                    );
                                    return;
                                }
                                Err(e) => {
                                    warn!(
                                        "Push: 读取 message 失败，跳过离线推送 message_id={}, err={}",
                                        message_id, e
                                    );
                                    return;
                                }
                            };

                            let mut parts_map = match store.get_message_parts_map(&[message_id]).await
                            {
                                Ok(m) => m,
                                Err(e) => {
                                    warn!(
                                        "Push: 读取 message_parts 失败，跳过离线推送 message_id={}, err={}",
                                        message_id, e
                                    );
                                    return;
                                }
                            };
                            let parts = parts_map.remove(&message_id).unwrap_or_default();

                            notify_new_message(state, message, parts).await;
                        }
                        PushJob::FriendRequest {
                            request_id,
                            requester_id,
                            requester_name,
                            target_user_id,
                            message,
                        } => {
                            notify_friend_request(
                                state,
                                request_id,
                                requester_id,
                                requester_name,
                                target_user_id,
                                message,
                            )
                            .await;
                        }
                        PushJob::GroupEvent {
                            targets,
                            room_id,
                            room_name,
                            event,
                            title,
                            body,
                        } => {
                            notify_group_event(
                                state, targets, room_id, room_name, &event, title, body,
                            )
                            .await;
                        }
                    }
                }
            })
            .await;
    });

    // 兜底 DB 队列：当内存队列满时落库，后台轮询重试入队
    start_push_db_queue_worker(state);
}

pub fn enqueue_new_message(state: &AppState, message: MessageWithSender, parts: Vec<MessagePart>) {
    if let Some(dispatcher) = push_dispatcher() {
        let job = PushJob::NewMessage { message, parts };
        match dispatcher.tx.try_send(job) {
            Ok(_) => return,
            Err(e) => {
                let job = match e {
                    tokio::sync::mpsc::error::TrySendError::Full(job) => job,
                    tokio::sync::mpsc::error::TrySendError::Closed(job) => job,
                };
                let PushJob::NewMessage { message, .. } = job else {
                    return;
                };

                let message_id = message.id;
                warn!(
                    "Push: job queue 发送失败，已落库等待重试 job_type=message message_id={}",
                    message_id
                );
                enqueue_push_job_to_db(
                    state.clone(),
                    "message",
                    serde_json::json!({
                        "message_id": message_id,
                    }),
                );
                return;
            }
        }
    }

    let state = state.clone();
    tokio::spawn(async move { notify_new_message(state, message, parts).await });
}

pub fn enqueue_friend_request(
    state: &AppState,
    request_id: Uuid,
    requester_id: Uuid,
    requester_name: String,
    target_user_id: Uuid,
    message: Option<String>,
) {
    if let Some(dispatcher) = push_dispatcher() {
        let job = PushJob::FriendRequest {
            request_id,
            requester_id,
            requester_name,
            target_user_id,
            message,
        };

        match dispatcher.tx.try_send(job) {
            Ok(_) => return,
            Err(e) => {
                let job = match e {
                    tokio::sync::mpsc::error::TrySendError::Full(job) => job,
                    tokio::sync::mpsc::error::TrySendError::Closed(job) => job,
                };
                let PushJob::FriendRequest {
                    request_id,
                    requester_id,
                    requester_name,
                    target_user_id,
                    message,
                } = job
                else {
                    return;
                };

                warn!(
                    "Push: job queue 发送失败，已落库等待重试 job_type=friend_request request_id={}",
                    request_id
                );
                enqueue_push_job_to_db(
                    state.clone(),
                    "friend_request",
                    serde_json::json!({
                        "request_id": request_id,
                        "requester_id": requester_id,
                        "requester_name": requester_name,
                        "target_user_id": target_user_id,
                        "message": message,
                    }),
                );
                return;
            }
        }
    }

    let state = state.clone();
    tokio::spawn(async move {
        notify_friend_request(
            state,
            request_id,
            requester_id,
            requester_name,
            target_user_id,
            message,
        )
        .await;
    });
}

pub fn enqueue_group_event(
    state: &AppState,
    targets: Vec<Uuid>,
    room_id: Uuid,
    room_name: String,
    event: &str,
    title: String,
    body: String,
) {
    if let Some(dispatcher) = push_dispatcher() {
        let job = PushJob::GroupEvent {
            targets,
            room_id,
            room_name,
            event: event.to_string(),
            title,
            body,
        };

        match dispatcher.tx.try_send(job) {
            Ok(_) => return,
            Err(e) => {
                let job = match e {
                    tokio::sync::mpsc::error::TrySendError::Full(job) => job,
                    tokio::sync::mpsc::error::TrySendError::Closed(job) => job,
                };
                let PushJob::GroupEvent {
                    targets,
                    room_id,
                    room_name,
                    event,
                    title,
                    body,
                } = job
                else {
                    return;
                };

                warn!(
                    "Push: job queue 发送失败，已落库等待重试 job_type=group_event room_id={}",
                    room_id
                );
                enqueue_push_job_to_db(
                    state.clone(),
                    "group_event",
                    serde_json::json!({
                        "targets": targets,
                        "room_id": room_id,
                        "room_name": room_name,
                        "event": event,
                        "title": title,
                        "body": body,
                    }),
                );
                return;
            }
        }
    }

    let state = state.clone();
    let event = event.to_string();
    tokio::spawn(async move {
        notify_group_event(state, targets, room_id, room_name, &event, title, body).await
    });
}

async fn push_runtime_snapshot(state: &AppState) -> PushRuntimeSnapshot {
    let now = Utc::now();
    {
        let guard = push_runtime_lock().read().await;
        if guard.loaded_at > now - Duration::seconds(PUSH_RUNTIME_TTL_SECONDS) {
            return PushRuntimeSnapshot {
                enabled: guard.enabled,
                skip_if_online: guard.skip_if_online,
                fcm: guard.fcm.clone(),
            };
        }
    }

    let mut guard = push_runtime_lock().write().await;
    if guard.loaded_at > now - Duration::seconds(PUSH_RUNTIME_TTL_SECONDS) {
        return PushRuntimeSnapshot {
            enabled: guard.enabled,
            skip_if_online: guard.skip_if_online,
            fcm: guard.fcm.clone(),
        };
    }

    // 1) 全局开关（优先 DB，缺省回退 env）
    let mut enabled = env_flag("PUSH_ENABLED", true);
    let mut skip_if_online = env_flag("PUSH_SKIP_IF_ONLINE", true);

    let settings_store = SettingsStore::new(state.database.clone());
    if let Ok(Some(record)) = settings_store
        .get_general_setting(SETTING_PUSH_ENABLED)
        .await
    {
        enabled = parse_bool_value(&record.value, enabled);
    }
    if let Ok(Some(record)) = settings_store
        .get_general_setting(SETTING_PUSH_SKIP_IF_ONLINE)
        .await
    {
        skip_if_online = parse_bool_value(&record.value, skip_if_online);
    }

    // 2) 平台配置：优先 DB（管理后台），缺省回退 env 文件路径（兼容开发环境）
    let provider_store = PushProviderConfigStore::new(state.database.pool());
    let cfg = provider_store.get_config("fcm", "all").await.ok().flatten();

    let mut next_fcm: Option<Arc<FcmClient>> = None;
    let mut next_fingerprint: Option<String> = None;

    if let Some(cfg) = cfg {
        if cfg.enabled {
            if let Some(ciphertext) = cfg
                .secret_ciphertext
                .as_ref()
                .map(|v| v.trim())
                .filter(|v| !v.is_empty())
            {
                let crypto = match SecretCrypto::new() {
                    Ok(c) => c,
                    Err(e) => {
                        warn!("Push: SecretCrypto 初始化失败，跳过 FCM（{}）", e);
                        guard.loaded_at = Utc::now();
                        guard.enabled = enabled;
                        guard.skip_if_online = skip_if_online;
                        return PushRuntimeSnapshot {
                            enabled: guard.enabled,
                            skip_if_online: guard.skip_if_online,
                            fcm: guard.fcm.clone(),
                        };
                    }
                };

                match crypto.decrypt_from_base64(ciphertext) {
                    Ok(raw) => {
                        let fp = cfg
                            .secret_fingerprint
                            .clone()
                            .filter(|v| !v.trim().is_empty())
                            .unwrap_or_else(|| SecretCrypto::sha256_hex(&raw));

                        next_fingerprint = Some(fp.clone());
                        if guard.fcm_fingerprint.as_deref() == Some(fp.as_str()) {
                            next_fcm = guard.fcm.clone();
                        } else {
                            match FcmClient::from_service_account_json(&raw) {
                                Ok(client) => next_fcm = Some(Arc::new(client)),
                                Err(e) => warn!("Push: FCM 配置解析失败（{}）", e),
                            }
                        }
                    }
                    Err(e) => warn!("Push: FCM 配置解密失败（{}）", e),
                }
            }
        }
    }

    guard.enabled = enabled;
    guard.skip_if_online = skip_if_online;
    guard.fcm_fingerprint = next_fingerprint;
    guard.fcm = next_fcm;
    guard.loaded_at = Utc::now();

    PushRuntimeSnapshot {
        enabled: guard.enabled,
        skip_if_online: guard.skip_if_online,
        fcm: guard.fcm.clone(),
    }
}

pub async fn send_fcm_test(
    state: &AppState,
    device_token: &str,
    title: &str,
    body: &str,
    data: &HashMap<String, String>,
) -> Result<(), String> {
    let runtime = push_runtime_snapshot(state).await;
    if !runtime.enabled {
        return Err("Push 已关闭（push_enabled=false）".to_string());
    }
    let fcm = runtime
        .fcm
        .ok_or_else(|| "FCM 未配置或未启用".to_string())?;
    fcm.send_to_token(device_token, title, body, data)
        .await
        .map_err(|e| e.to_log_string())
}

fn preview_text(message: &MessageWithSender, parts: &[MessagePart]) -> String {
    let trimmed = message.content.trim();
    if !trimmed.is_empty() {
        return truncate_with_ellipsis(trimmed, 80);
    }

    for part in parts {
        match part.part_type {
            MessagePartType::Text => {
                if let Some(text) = part.text_content.as_deref() {
                    let t = text.trim();
                    if !t.is_empty() {
                        return truncate_with_ellipsis(t, 80);
                    }
                }
            }
            MessagePartType::Image => return "[图片]".to_string(),
            MessagePartType::Video => return "[视频]".to_string(),
            MessagePartType::Audio => return "[语音]".to_string(),
            MessagePartType::File => return "[文件]".to_string(),
        }
    }

    "[新消息]".to_string()
}

fn truncate_with_ellipsis(text: &str, max_len: usize) -> String {
    if text.chars().count() <= max_len {
        return text.to_string();
    }
    let mut out = String::with_capacity(max_len + 1);
    for (idx, ch) in text.chars().enumerate() {
        if idx >= max_len {
            break;
        }
        out.push(ch);
    }
    out.push('…');
    out
}

#[derive(Debug, Default)]
struct MentionDecision {
    mention_all: bool,
    mentioned_user_ids: HashSet<Uuid>,
}

fn is_mention_char(ch: char) -> bool {
    ch.is_ascii_alphanumeric()
        || matches!(ch, '_' | '-')
        || (!ch.is_ascii() && ch.is_alphanumeric())
}

fn normalize_mention_token(raw: &str) -> String {
    raw.trim().trim_matches('@').to_lowercase()
}

fn is_mention_all_token(token: &str) -> bool {
    matches!(
        token,
        "all" | "everyone" | "here" | "全体" | "全员" | "所有人" | "全体成员" | "全体人员"
    )
}

fn parse_mentions_from_content(
    content: &str,
    members: &[RoomMemberWithUserInfo],
) -> MentionDecision {
    let mut decision = MentionDecision::default();
    let content = content.trim();
    if content.is_empty() {
        return decision;
    }

    let mut mention_key_to_user_ids: HashMap<String, Vec<Uuid>> = HashMap::new();
    for member in members {
        let username_key = normalize_mention_token(&member.username);
        if !username_key.is_empty() {
            mention_key_to_user_ids
                .entry(username_key)
                .or_default()
                .push(member.user_id);
        }
        if let Some(nickname) = member.nickname.as_ref() {
            let nick_key = normalize_mention_token(nickname);
            if !nick_key.is_empty() {
                mention_key_to_user_ids
                    .entry(nick_key)
                    .or_default()
                    .push(member.user_id);
            }
        }
    }

    let chars: Vec<char> = content.chars().collect();
    let mut idx = 0;
    while idx < chars.len() {
        if chars[idx] != '@' {
            idx += 1;
            continue;
        }

        // 避免把 email/handle 当作 @ 提及：前一个字符为 ASCII 字母数字或常见 email 字符时跳过
        if idx > 0 {
            let prev = chars[idx - 1];
            if prev.is_ascii_alphanumeric() || matches!(prev, '_' | '.' | '+' | '-') {
                idx += 1;
                continue;
            }
        }

        let mut j = idx + 1;
        let mut token = String::new();
        while j < chars.len() {
            let ch = chars[j];
            if is_mention_char(ch) {
                token.push(ch);
                j += 1;
                continue;
            }
            break;
        }

        idx = j;

        let token = normalize_mention_token(&token);
        if token.is_empty() {
            continue;
        }
        if is_mention_all_token(&token) {
            decision.mention_all = true;
            continue;
        }

        if let Some(ids) = mention_key_to_user_ids.get(&token) {
            for id in ids {
                decision.mentioned_user_ids.insert(*id);
            }
        }
    }

    decision
}

fn should_send_for_setting(
    setting: NotificationSetting,
    room_type: RoomType,
    target_user_id: &Uuid,
    mentions: &MentionDecision,
) -> bool {
    match setting {
        NotificationSetting::All => true,
        NotificationSetting::Muted => false,
        NotificationSetting::MentionsOnly => {
            if room_type != RoomType::Group {
                return true;
            }
            if mentions.mention_all {
                return true;
            }
            mentions.mentioned_user_ids.contains(target_user_id)
        }
    }
}

async fn filter_targets_skip_online(state: &AppState, targets: Vec<Uuid>) -> Vec<Uuid> {
    if targets.is_empty() {
        return targets;
    }

    let mut candidates: Vec<Uuid> = Vec::with_capacity(targets.len());
    for user_id in targets {
        if state
            .connection_manager
            .is_user_online(&user_id.to_string())
            .await
        {
            continue;
        }
        candidates.push(user_id);
    }

    if candidates.is_empty() {
        return Vec::new();
    }

    let Ok(mut conn) = state
        .redis
        .get_session_client()
        .get_multiplexed_async_connection()
        .await
    else {
        // Redis 不可用时，保持原行为：不做跨节点在线跳过（认为离线）
        return candidates;
    };

    let keys: Vec<String> = candidates
        .iter()
        .map(|user_id| CacheKeys::user_online_status(user_id))
        .collect();

    let mut pipe = redis::pipe();
    for key in &keys {
        pipe.cmd("EXISTS").arg(key);
    }

    let exists_list: Vec<i32> = match pipe.query_async(&mut conn).await {
        Ok(v) => v,
        Err(_) => {
            // Redis 查询失败时，保持原行为：不跳过
            return candidates;
        }
    };

    let mut offline: Vec<Uuid> = Vec::new();
    for (idx, user_id) in candidates.into_iter().enumerate() {
        let exists = exists_list.get(idx).copied().unwrap_or(0);
        if exists == 0 {
            offline.push(user_id);
        }
    }

    offline
}

async fn send_to_token_with_retry(
    fcm: &FcmClient,
    device_token: &str,
    title: &str,
    body: &str,
    data: &HashMap<String, String>,
) -> DeviceSendOutcome {
    let mut attempt: i32 = 1;
    loop {
        match fcm.send_to_token(device_token, title, body, data).await {
            Ok(_) => {
                return DeviceSendOutcome {
                    ok: true,
                    attempt,
                    error: None,
                    deactivate_device: false,
                }
            }
            Err(e) => {
                let deactivate_device = e.is_unregistered() || e.is_invalid_token();
                let error = Some(e.to_log_string());
                if e.is_permanent() || attempt >= PUSH_SEND_MAX_ATTEMPTS {
                    return DeviceSendOutcome {
                        ok: false,
                        attempt,
                        error,
                        deactivate_device,
                    };
                }
                let exp = (attempt - 1).clamp(0, 16) as u32;
                let delay_ms = PUSH_SEND_RETRY_BASE_MS.saturating_mul(2u64.saturating_pow(exp));
                tokio::time::sleep(tokio::time::Duration::from_millis(delay_ms)).await;
                attempt += 1;
            }
        }
    }
}

struct DeviceSendOutcome {
    ok: bool,
    attempt: i32,
    error: Option<String>,
    deactivate_device: bool,
}

fn push_device_send_concurrency() -> usize {
    env_usize("PUSH_DEVICE_SEND_CONCURRENCY", PUSH_DEVICE_SEND_CONCURRENCY).clamp(1, 200)
}

async fn send_fcm_to_devices_and_log(
    state: &AppState,
    fcm: Arc<FcmClient>,
    devices: Vec<PushDevice>,
    title: String,
    body: String,
    data: HashMap<String, String>,
    data_json: serde_json::Value,
    push_id: Uuid,
    event_type: &str,
    room_id: Option<Uuid>,
    message_id: Option<Uuid>,
    request_id: Option<Uuid>,
) {
    let devices: Vec<PushDevice> = devices
        .into_iter()
        .filter(|device| device.channel == "fcm")
        .collect();

    if devices.is_empty() {
        return;
    }

    let title = Arc::new(title);
    let body = Arc::new(body);
    let data = Arc::new(data);

    let concurrency = push_device_send_concurrency();
    let device_store = PushDeviceStore::new(state.database.pool());
    let log_store = PushLogStore::new(state.database.pool());

    let mut success = 0usize;
    let mut failed = 0usize;

    let mut stream = futures_util::stream::iter(devices)
        .map(|device| {
            let fcm = fcm.clone();
            let title = title.clone();
            let body = body.clone();
            let data = data.clone();
            async move {
                let outcome = send_to_token_with_retry(
                    &fcm,
                    &device.device_token,
                    title.as_str(),
                    body.as_str(),
                    data.as_ref(),
                )
                .await;
                (device, outcome)
            }
        })
        .buffer_unordered(concurrency);

    while let Some((device, outcome)) = stream.next().await {
        if outcome.ok {
            success += 1;
        } else {
            failed += 1;
        }

        if outcome.deactivate_device {
            match device_store
                .deactivate_device(device.user_id, &device.device_id)
                .await
            {
                Ok(updated) => {
                    if updated {
                        info!(
                            "Push: 已停用无效 token user_id={}, device_id={}",
                            device.user_id, device.device_id
                        );
                    }
                }
                Err(e) => warn!(
                    "Push: 停用无效 token 失败 user_id={}, device_id={}, err={}",
                    device.user_id, device.device_id, e
                ),
            }
        }

        if let Err(e) = log_store
            .insert_log(
                push_id,
                device.user_id,
                &device.device_id,
                &device.platform,
                &device.channel,
                "fcm",
                event_type,
                room_id,
                message_id,
                request_id,
                Some(title.as_str()),
                Some(body.as_str()),
                &data_json,
                outcome.attempt,
                outcome.ok,
                outcome.error.as_deref(),
            )
            .await
        {
            warn!(
                "Push: 写入 push_logs 失败 user_id={}, device_id={}, err={}",
                device.user_id, device.device_id, e
            );
        }

        if let Some(err) = outcome.error.as_deref() {
            warn!(
                "Push: 发送失败 user_id={}, device_id={}, attempt={}, err={}",
                device.user_id, device.device_id, outcome.attempt, err
            );
        }
    }

    info!(
        "Push: event_type={} push_id={} success={} failed={}",
        event_type, push_id, success, failed
    );
}

async fn send_basic_notification(
    state: &AppState,
    targets: Vec<Uuid>,
    title: String,
    body: String,
    mut data: HashMap<String, String>,
    event_type: &str,
    room_id: Option<Uuid>,
    message_id: Option<Uuid>,
    request_id: Option<Uuid>,
) {
    let push_id = Uuid::new_v4();
    data.insert("push_id".to_string(), push_id.to_string());
    let data_json = serde_json::to_value(&data).unwrap_or_else(|_| serde_json::json!({}));

    let runtime = push_runtime_snapshot(state).await;
    if !runtime.enabled {
        return;
    }

    let fcm = match runtime.fcm {
        Some(c) => c,
        None => return,
    };

    let skip_if_online = runtime.skip_if_online;

    let filtered = if skip_if_online {
        filter_targets_skip_online(state, targets).await
    } else {
        targets
    };

    if filtered.is_empty() {
        return;
    }

    let device_store = PushDeviceStore::new(state.database.pool());
    let devices = match device_store.list_active_devices_for_users(&filtered).await {
        Ok(devices) => devices,
        Err(e) => {
            warn!("Push: 获取 push_devices 失败: {}", e);
            return;
        }
    };

    if devices.is_empty() {
        return;
    }

    send_fcm_to_devices_and_log(
        state, fcm, devices, title, body, data, data_json, push_id, event_type, room_id,
        message_id, request_id,
    )
    .await;
}

pub async fn notify_friend_request(
    state: AppState,
    request_id: Uuid,
    requester_id: Uuid,
    requester_name: String,
    target_user_id: Uuid,
    message: Option<String>,
) {
    let title = "新的好友请求".to_string();
    let body = match message
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
    {
        Some(m) => format!("{}: {}", requester_name, truncate_with_ellipsis(m, 80)),
        None => format!("{} 想添加你为好友", requester_name),
    };

    let mut data: HashMap<String, String> = HashMap::new();
    data.insert("type".to_string(), "friend_request".to_string());
    data.insert("request_id".to_string(), request_id.to_string());
    data.insert("requester_id".to_string(), requester_id.to_string());
    data.insert("requester_name".to_string(), requester_name);

    send_basic_notification(
        &state,
        vec![target_user_id],
        title,
        body,
        data,
        "friend_request",
        None,
        None,
        Some(request_id),
    )
    .await;
}

pub async fn notify_group_event(
    state: AppState,
    targets: Vec<Uuid>,
    room_id: Uuid,
    room_name: String,
    event: &str,
    title: String,
    body: String,
) {
    let mut data: HashMap<String, String> = HashMap::new();
    data.insert("type".to_string(), "group_event".to_string());
    data.insert("event".to_string(), event.to_string());
    data.insert("room_id".to_string(), room_id.to_string());
    data.insert("room_name".to_string(), room_name);

    send_basic_notification(
        &state,
        targets,
        title,
        body,
        data,
        "group_event",
        Some(room_id),
        None,
        None,
    )
    .await;
}

pub async fn notify_new_message(
    state: AppState,
    message: MessageWithSender,
    parts: Vec<MessagePart>,
) {
    let runtime = push_runtime_snapshot(&state).await;
    if !runtime.enabled {
        return;
    }

    let fcm = match runtime.fcm {
        Some(c) => c,
        None => return,
    };

    // 系统消息不做离线推送
    if message.message_type == crate::database::models::MessageType::System {
        return;
    }

    let room_store = RoomStore::new(state.database.pool());
    let room = match room_store.get_room(message.room_id).await {
        Ok(room) => room,
        Err(e) => {
            warn!("Push: 获取房间失败 room_id={}, err={}", message.room_id, e);
            return;
        }
    };

    let sender_name = message
        .sender_nickname
        .as_ref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
        .map(|v| v.to_string())
        .unwrap_or_else(|| message.sender_username.clone());

    let preview = preview_text(&message, &parts);

    let (title, body) = match room.room_type {
        RoomType::Group => (room.name.clone(), format!("{}: {}", sender_name, preview)),
        _ => (sender_name.clone(), preview.clone()),
    };

    let members = match room_store
        .list_member_notification_settings(message.room_id)
        .await
    {
        Ok(members) => members,
        Err(e) => {
            warn!(
                "Push: 获取房间成员通知设置失败 room_id={}, err={}",
                message.room_id, e
            );
            return;
        }
    };

    let skip_if_online = runtime.skip_if_online;

    let mention_decision = if room.room_type == RoomType::Group
        && message.content.contains('@')
        && members
            .iter()
            .any(|(_, setting)| *setting == NotificationSetting::MentionsOnly)
    {
        match room_store
            .list_members_with_user_info(message.room_id)
            .await
        {
            Ok(members) => parse_mentions_from_content(&message.content, &members),
            Err(e) => {
                warn!(
                    "Push: 获取房间成员信息失败 room_id={}, err={}",
                    message.room_id, e
                );
                MentionDecision::default()
            }
        }
    } else {
        MentionDecision::default()
    };

    let mut targets: Vec<Uuid> = Vec::new();
    for (user_id, setting) in members {
        if user_id == message.sender_id {
            continue;
        }
        if !should_send_for_setting(setting, room.room_type, &user_id, &mention_decision) {
            continue;
        }
        targets.push(user_id);
    }

    let targets = if skip_if_online {
        filter_targets_skip_online(&state, targets).await
    } else {
        targets
    };

    if targets.is_empty() {
        return;
    }

    let device_store = PushDeviceStore::new(state.database.pool());
    let devices = match device_store.list_active_devices_for_users(&targets).await {
        Ok(devices) => devices,
        Err(e) => {
            warn!("Push: 获取 push_devices 失败: {}", e);
            return;
        }
    };

    if devices.is_empty() {
        return;
    }

    let mut data: HashMap<String, String> = HashMap::new();
    data.insert("type".to_string(), "message".to_string());
    data.insert("room_id".to_string(), message.room_id.to_string());
    data.insert("message_id".to_string(), message.id.to_string());
    data.insert("room_type".to_string(), room.room_type.to_string());
    data.insert("sender_id".to_string(), message.sender_id.to_string());
    data.insert("sender_name".to_string(), sender_name.clone());
    data.insert("chat_name".to_string(), title.clone());
    let push_id = Uuid::new_v4();
    data.insert("push_id".to_string(), push_id.to_string());
    let data_json = serde_json::to_value(&data).unwrap_or_else(|_| serde_json::json!({}));

    send_fcm_to_devices_and_log(
        &state,
        fcm,
        devices,
        title,
        body,
        data,
        data_json,
        push_id,
        "message",
        Some(message.room_id),
        Some(message.id),
        None,
    )
    .await;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::models::MemberRole;
    use chrono::Utc;

    fn member(user_id: Uuid, username: &str, nickname: Option<&str>) -> RoomMemberWithUserInfo {
        RoomMemberWithUserInfo {
            user_id,
            username: username.to_string(),
            nickname: nickname.map(|v| v.to_string()),
            avatar_url: None,
            avatar_object_key: None,
            role: MemberRole::Member,
            joined_at: Some(Utc::now()),
        }
    }

    #[test]
    fn parse_mentions_should_ignore_email_like_patterns() {
        let alice = Uuid::new_v4();
        let members = vec![member(alice, "example", None)];
        let decision = parse_mentions_from_content("test@example.com", &members);
        assert!(!decision.mention_all);
        assert!(decision.mentioned_user_ids.is_empty());
    }

    #[test]
    fn parse_mentions_should_pick_username_and_nickname() {
        let alice = Uuid::new_v4();
        let bob = Uuid::new_v4();
        let members = vec![
            member(alice, "alice", Some("张三")),
            member(bob, "bob", Some("李四")),
        ];

        let decision = parse_mentions_from_content("你好@张三，ping @bob", &members);
        assert!(!decision.mention_all);
        assert!(decision.mentioned_user_ids.contains(&alice));
        assert!(decision.mentioned_user_ids.contains(&bob));
    }

    #[test]
    fn parse_mentions_should_support_mention_all() {
        let alice = Uuid::new_v4();
        let members = vec![member(alice, "alice", None)];
        let decision = parse_mentions_from_content("@all 请看一下", &members);
        assert!(decision.mention_all);
    }

    #[test]
    fn mentions_only_should_send_only_when_mentioned_in_group() {
        let alice = Uuid::new_v4();
        let mut decision = MentionDecision::default();
        decision.mentioned_user_ids.insert(alice);

        assert!(should_send_for_setting(
            NotificationSetting::MentionsOnly,
            RoomType::Group,
            &alice,
            &decision
        ));

        let bob = Uuid::new_v4();
        assert!(!should_send_for_setting(
            NotificationSetting::MentionsOnly,
            RoomType::Group,
            &bob,
            &decision
        ));
    }
}
