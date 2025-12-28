use chrono::{Duration, Utc};
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use once_cell::sync::OnceCell;
use reqwest::header::{HeaderMap, HeaderValue, AUTHORIZATION, CONTENT_TYPE};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, env, fs, sync::Arc};
use tokio::sync::RwLock;
use tracing::{debug, info, warn};
use uuid::Uuid;

use crate::crypto::SecretCrypto;
use crate::database::models::{
    MessagePart, MessagePartType, MessageWithSender, NotificationSetting, RoomType,
};
use crate::database::push_device_store::PushDeviceStore;
use crate::database::push_provider_config_store::PushProviderConfigStore;
use crate::database::room_store::RoomStore;
use crate::database::settings_store::SettingsStore;
use crate::AppState;

const SETTING_PUSH_ENABLED: &str = "push_enabled";
const SETTING_PUSH_SKIP_IF_ONLINE: &str = "push_skip_if_online";

const PUSH_RUNTIME_TTL_SECONDS: i64 = 10;

static PUSH_RUNTIME: OnceCell<RwLock<PushRuntime>> = OnceCell::new();

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

        Ok(Self {
            http: reqwest::Client::new(),
            sa,
            cached_token: RwLock::new(None),
        })
    }

    async fn access_token(&self) -> Result<String, String> {
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
        let key = EncodingKey::from_rsa_pem(self.sa.private_key.as_bytes())
            .map_err(|e| format!("解析 private_key 失败: {}", e))?;
        let jwt = encode(&header, &claims, &key).map_err(|e| format!("签名 JWT 失败: {}", e))?;

        let mut form = HashMap::new();
        form.insert(
            "grant_type",
            "urn:ietf:params:oauth:grant-type:jwt-bearer",
        );
        form.insert("assertion", jwt.as_str());

        let resp = self
            .http
            .post(&token_uri)
            .header(CONTENT_TYPE, "application/x-www-form-urlencoded")
            .form(&form)
            .send()
            .await
            .map_err(|e| format!("请求 Google OAuth2 token 失败: {}", e))?;

        let status = resp.status();
        let text = resp
            .text()
            .await
            .map_err(|e| format!("读取 token 响应失败: {}", e))?;

        if !status.is_success() {
            return Err(format!("获取 access_token 失败: status={}, body={}", status, text));
        }

        let parsed: OAuthTokenResponse =
            serde_json::from_str(&text).map_err(|e| format!("解析 token 响应失败: {}", e))?;

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
    ) -> Result<(), String> {
        let access_token = self.access_token().await?;

        let url = format!(
            "https://fcm.googleapis.com/v1/projects/{}/messages:send",
            self.sa.project_id
        );

        let mut headers = HeaderMap::new();
        headers.insert(
            AUTHORIZATION,
            HeaderValue::from_str(&format!("Bearer {}", access_token))
                .map_err(|e| format!("构造 Authorization header 失败: {}", e))?,
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

        let resp = self
            .http
            .post(&url)
            .headers(headers)
            .json(&payload)
            .send()
            .await
            .map_err(|e| format!("请求 FCM 失败: {}", e))?;

        let status = resp.status();
        let text = resp
            .text()
            .await
            .map_err(|e| format!("读取 FCM 响应失败: {}", e))?;

        if status.is_success() {
            let _ = serde_json::from_str::<FcmSendResponse>(&text).ok();
            return Ok(());
        }

        let message = serde_json::from_str::<FcmErrorEnvelope>(&text)
            .ok()
            .and_then(|e| e.error)
            .and_then(|d| d.message)
            .unwrap_or_else(|| text.clone());

        Err(format!("FCM send 失败: status={}, {}", status, message))
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
    if let Ok(Some(record)) = settings_store.get_general_setting(SETTING_PUSH_ENABLED).await {
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
    let has_db_record = cfg.is_some();

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

    // 仅当 DB 未配置该 provider 时才允许回退 env，避免“后台已禁用但仍发 push”的混乱。
    if next_fcm.is_none() && !has_db_record {
        if let Ok(path) = env::var("FCM_SERVICE_ACCOUNT_PATH") {
            if !path.trim().is_empty() {
                match fs::read_to_string(path.trim()) {
                    Ok(raw) => {
                        let fp = SecretCrypto::sha256_hex(&raw);
                        next_fingerprint = Some(format!("env:{}", fp));
                        if guard.fcm_fingerprint.as_deref() == Some(next_fingerprint.as_ref().unwrap().as_str()) {
                            next_fcm = guard.fcm.clone();
                        } else {
                            match FcmClient::from_service_account_json(&raw) {
                                Ok(client) => next_fcm = Some(Arc::new(client)),
                                Err(e) => warn!("Push: env FCM 配置解析失败（{}）", e),
                            }
                        }
                    }
                    Err(e) => warn!("Push: 读取 env FCM 配置失败（{}）", e),
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
    let fcm = runtime.fcm.ok_or_else(|| "FCM 未配置或未启用".to_string())?;
    fcm.send_to_token(device_token, title, body, data).await
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

fn should_send_for_setting(setting: NotificationSetting, content: &str) -> bool {
    match setting {
        NotificationSetting::All => true,
        NotificationSetting::Muted => false,
        NotificationSetting::MentionsOnly => content.contains('@'),
    }
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

    let mut targets: Vec<Uuid> = Vec::new();
    for (user_id, setting) in members {
        if user_id == message.sender_id {
            continue;
        }
        if !should_send_for_setting(setting, &message.content) {
            continue;
        }
        if skip_if_online && state
            .connection_manager
            .is_user_online(&user_id.to_string())
            .await
        {
            debug!("Push: skip online user {} for room {}", user_id, message.room_id);
            continue;
        }
        targets.push(user_id);
    }

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

    // 逐 token 发送（首版先简单实现，后续可做并发与重试）
    let mut success = 0usize;
    let mut failed = 0usize;
    for device in devices {
        if device.channel != "fcm" {
            continue;
        }

        match fcm.send_to_token(&device.device_token, &title, &body, &data).await {
            Ok(_) => {
                success += 1;
            }
            Err(e) => {
                failed += 1;
                warn!(
                    "Push: 发送失败 user_id={}, device_id={}, err={}",
                    device.user_id, device.device_id, e
                );
            }
        }
    }

    info!(
        "Push: message={} room={} targets={} success={} failed={}",
        message.id,
        message.room_id,
        targets.len(),
        success,
        failed
    );
}
