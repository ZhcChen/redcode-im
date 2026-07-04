use axum::{
    extract::{Extension, Path, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::collections::HashMap;

use crate::crypto::SecretCrypto;
use crate::database::push_provider_config_store::PushProviderConfigStore;
use crate::database::settings_store::SettingsStore;
use crate::error::AppError;
use crate::models::convert::string_to_uuid;
use crate::models::Claims;
use crate::AppState;

const SETTING_PUSH_ENABLED: &str = "push_enabled";
const SETTING_PUSH_SKIP_IF_ONLINE: &str = "push_skip_if_online";

fn parse_bool(value: Option<&str>, default: bool) -> bool {
    match value {
        Some(v) => match v.trim().to_lowercase().as_str() {
            "1" | "true" | "yes" | "y" | "on" => true,
            "0" | "false" | "no" | "n" | "off" => false,
            _ => default,
        },
        None => default,
    }
}

#[derive(Debug, Serialize)]
pub struct PushProviderConfigView {
    pub id: String,
    pub provider: String,
    pub platform: String,
    pub enabled: bool,
    pub config_public: serde_json::Value,
    pub has_secret: bool,
    pub secret_fingerprint: Option<String>,
    pub updated_at: String,
    pub updated_by: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct GetPushSettingsResponse {
    pub enabled: bool,
    pub skip_if_online: bool,
    pub providers: Vec<PushProviderConfigView>,
}

pub async fn get_push_settings_admin(
    State(state): State<AppState>,
) -> Result<Json<GetPushSettingsResponse>, AppError> {
    let settings = SettingsStore::new(state.database.clone());
    let enabled_record = settings.get_general_setting(SETTING_PUSH_ENABLED).await?;
    let skip_record = settings
        .get_general_setting(SETTING_PUSH_SKIP_IF_ONLINE)
        .await?;

    let enabled = parse_bool(enabled_record.as_ref().map(|r| r.value.as_str()), true);
    let skip_if_online = parse_bool(skip_record.as_ref().map(|r| r.value.as_str()), true);

    let provider_store = PushProviderConfigStore::new(state.database.pool());
    let configs = provider_store.list_configs().await?;
    let providers = configs
        .into_iter()
        .map(|c| PushProviderConfigView {
            id: c.id.to_string(),
            provider: c.provider,
            platform: c.platform,
            enabled: c.enabled,
            config_public: c.config_public,
            has_secret: c
                .secret_ciphertext
                .as_ref()
                .map(|v| !v.trim().is_empty())
                .unwrap_or(false),
            secret_fingerprint: c.secret_fingerprint,
            updated_at: c.updated_at.to_rfc3339(),
            updated_by: c.updated_by.map(|id| id.to_string()),
        })
        .collect();

    Ok(Json(GetPushSettingsResponse {
        enabled,
        skip_if_online,
        providers,
    }))
}

#[derive(Debug, Deserialize)]
pub struct UpdatePushSettingsRequest {
    pub enabled: bool,
    pub skip_if_online: bool,
}

pub async fn update_push_settings_admin(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdatePushSettingsRequest>,
) -> Result<Json<GetPushSettingsResponse>, AppError> {
    let editor_id = string_to_uuid(&claims.sub)?;
    let settings = SettingsStore::new(state.database.clone());
    let _ = settings
        .upsert_general_setting(
            SETTING_PUSH_ENABLED,
            if payload.enabled { "true" } else { "false" },
            "是否启用离线推送（系统通知）",
            Some(editor_id),
        )
        .await?;
    let _ = settings
        .upsert_general_setting(
            SETTING_PUSH_SKIP_IF_ONLINE,
            if payload.skip_if_online {
                "true"
            } else {
                "false"
            },
            "用户在线时是否跳过离线推送（系统通知）",
            Some(editor_id),
        )
        .await?;

    crate::services::push::invalidate_push_runtime_cache().await;

    get_push_settings_admin(State(state)).await
}

#[derive(Debug, Deserialize)]
pub struct UpsertPushProviderConfigRequest {
    pub enabled: bool,
    /// FCM service account JSON（明文）；服务端会加密落库
    pub service_account_json: Option<String>,
    /// APNs Team ID
    pub team_id: Option<String>,
    /// APNs Auth Key ID
    pub key_id: Option<String>,
    /// iOS App Bundle ID
    pub bundle_id: Option<String>,
    /// APNs environment: sandbox / production
    pub environment: Option<String>,
    /// APNs .p8 私钥（明文）；服务端会加密落库
    pub private_key_p8: Option<String>,
}

#[derive(Debug, Deserialize)]
struct GoogleServiceAccountPayload {
    project_id: String,
    client_email: String,
    private_key: String,
    #[serde(default)]
    token_uri: Option<String>,
}

pub async fn upsert_push_provider_admin(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(provider): Path<String>,
    Json(payload): Json<UpsertPushProviderConfigRequest>,
) -> Result<Json<PushProviderConfigView>, AppError> {
    let provider = provider.trim().to_lowercase();
    if provider != "fcm" && provider != "apns" {
        return Err(AppError::ValidationError(format!(
            "暂不支持的 provider: {}",
            provider
        )));
    }

    let editor_id = string_to_uuid(&claims.sub)?;
    let store = PushProviderConfigStore::new(state.database.pool());
    let platform = if provider == "apns" { "ios" } else { "all" };

    let existing = store.get_config(&provider, platform).await?;
    let mut config_public = existing
        .as_ref()
        .map(|v| v.config_public.clone())
        .unwrap_or_else(|| json!({}));

    let mut secret_ciphertext: Option<String> = None;
    let mut secret_fingerprint: Option<String> = None;

    if provider == "fcm"
        && payload.enabled
        && existing
            .as_ref()
            .and_then(|v| v.secret_ciphertext.as_ref())
            .is_none()
    {
        let has_new_secret = payload
            .service_account_json
            .as_ref()
            .map(|v| !v.trim().is_empty())
            .unwrap_or(false);
        if !has_new_secret {
            return Err(AppError::ValidationError(
                "启用 FCM 需要 service_account_json".to_string(),
            ));
        }
    }

    if provider == "fcm" && payload.service_account_json.is_some() {
        let raw = payload.service_account_json.as_ref().unwrap();
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return Err(AppError::ValidationError(
                "service_account_json 不能为空".to_string(),
            ));
        }

        let parsed: GoogleServiceAccountPayload = serde_json::from_str(trimmed).map_err(|e| {
            AppError::ValidationError(format!("service_account_json 不是合法 JSON: {}", e))
        })?;
        if parsed.project_id.trim().is_empty()
            || parsed.client_email.trim().is_empty()
            || parsed.private_key.trim().is_empty()
        {
            return Err(AppError::ValidationError(
                "service_account_json 缺少必要字段".to_string(),
            ));
        }

        config_public = json!({
            "project_id": parsed.project_id,
            "client_email": parsed.client_email,
            "token_uri": parsed.token_uri,
        });

        let crypto = SecretCrypto::new()
            .map_err(|e| AppError::InternalError(format!("加密器初始化失败: {}", e)))?;
        secret_ciphertext = Some(
            crypto
                .encrypt_to_base64(trimmed)
                .map_err(|e| AppError::InternalError(format!("加密失败: {}", e)))?,
        );
        secret_fingerprint = Some(SecretCrypto::sha256_hex(trimmed));
    }

    if provider == "apns" {
        let mut team_id = config_public
            .get("team_id")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .trim()
            .to_string();
        let mut key_id = config_public
            .get("key_id")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .trim()
            .to_string();
        let mut bundle_id = config_public
            .get("bundle_id")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .trim()
            .to_string();
        let mut environment = config_public
            .get("environment")
            .and_then(|v| v.as_str())
            .unwrap_or("production")
            .trim()
            .to_lowercase();

        if let Some(v) = payload
            .team_id
            .as_ref()
            .map(|v| v.trim())
            .filter(|v| !v.is_empty())
        {
            team_id = v.to_string();
        }
        if let Some(v) = payload
            .key_id
            .as_ref()
            .map(|v| v.trim())
            .filter(|v| !v.is_empty())
        {
            key_id = v.to_string();
        }
        if let Some(v) = payload
            .bundle_id
            .as_ref()
            .map(|v| v.trim())
            .filter(|v| !v.is_empty())
        {
            bundle_id = v.to_string();
        }
        if let Some(v) = payload
            .environment
            .as_ref()
            .map(|v| v.trim().to_lowercase())
            .filter(|v| !v.is_empty())
        {
            environment = match v.as_str() {
                "production" | "prod" => "production".to_string(),
                "sandbox" | "development" | "dev" => "sandbox".to_string(),
                _ => {
                    return Err(AppError::ValidationError(
                        "environment 仅支持 sandbox 或 production".to_string(),
                    ))
                }
            };
        }

        if payload.enabled && (team_id.is_empty() || key_id.is_empty() || bundle_id.is_empty()) {
            return Err(AppError::ValidationError(
                "启用 APNs 需要 team_id、key_id 和 bundle_id".to_string(),
            ));
        }

        let has_existing_secret = existing
            .as_ref()
            .and_then(|v| v.secret_ciphertext.as_ref())
            .map(|v| !v.trim().is_empty())
            .unwrap_or(false);
        let has_new_secret = payload
            .private_key_p8
            .as_ref()
            .map(|v| !v.trim().is_empty())
            .unwrap_or(false);
        if payload.enabled && !has_existing_secret && !has_new_secret {
            return Err(AppError::ValidationError(
                "启用 APNs 需要 private_key_p8".to_string(),
            ));
        }

        if let Some(raw) = payload.private_key_p8.as_ref() {
            let trimmed = raw.trim();
            if trimmed.is_empty() {
                return Err(AppError::ValidationError(
                    "private_key_p8 不能为空".to_string(),
                ));
            }
            if !trimmed.contains("BEGIN PRIVATE KEY") {
                return Err(AppError::ValidationError(
                    "private_key_p8 必须是 APNs .p8 PEM 私钥".to_string(),
                ));
            }
            let crypto = SecretCrypto::new()
                .map_err(|e| AppError::InternalError(format!("加密器初始化失败: {}", e)))?;
            secret_ciphertext = Some(
                crypto
                    .encrypt_to_base64(trimmed)
                    .map_err(|e| AppError::InternalError(format!("加密失败: {}", e)))?,
            );
            secret_fingerprint = Some(SecretCrypto::sha256_hex(trimmed));
        }

        config_public = json!({
            "team_id": team_id,
            "key_id": key_id,
            "bundle_id": bundle_id,
            "environment": environment,
        });
    }

    let saved = store
        .upsert_config(
            &provider,
            platform,
            payload.enabled,
            config_public,
            secret_ciphertext,
            secret_fingerprint,
            Some(editor_id),
        )
        .await?;

    crate::services::push::invalidate_push_runtime_cache().await;

    Ok(Json(PushProviderConfigView {
        id: saved.id.to_string(),
        provider: saved.provider,
        platform: saved.platform,
        enabled: saved.enabled,
        config_public: saved.config_public,
        has_secret: saved
            .secret_ciphertext
            .as_ref()
            .map(|v| !v.trim().is_empty())
            .unwrap_or(false),
        secret_fingerprint: saved.secret_fingerprint,
        updated_at: saved.updated_at.to_rfc3339(),
        updated_by: saved.updated_by.map(|id| id.to_string()),
    }))
}

#[derive(Debug, Deserialize)]
pub struct TestPushRequest {
    pub provider: String,
    pub user_id: Option<String>,
    pub device_token: Option<String>,
    pub title: String,
    pub body: String,
}

#[derive(Debug, Serialize)]
pub struct TestPushResponse {
    pub success: bool,
    pub message: String,
}

pub async fn test_push_admin(
    State(state): State<AppState>,
    Json(payload): Json<TestPushRequest>,
) -> Result<Json<TestPushResponse>, AppError> {
    let provider = payload.provider.trim().to_lowercase();
    if provider != "fcm" && provider != "apns" {
        return Err(AppError::ValidationError(format!(
            "暂不支持的 provider: {}",
            provider
        )));
    }

    let mut token: Option<String> = payload
        .device_token
        .as_ref()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty());

    if token.is_none() {
        if let Some(user_id) = payload
            .user_id
            .as_ref()
            .map(|v| v.trim())
            .filter(|v| !v.is_empty())
        {
            let user_uuid = string_to_uuid(user_id)?;
            let device_store =
                crate::database::push_device_store::PushDeviceStore::new(state.database.pool());
            let devices = device_store
                .list_active_devices_for_users(&[user_uuid])
                .await?;
            token = devices
                .into_iter()
                .find(|d| d.channel == provider.as_str())
                .map(|d| d.device_token);
        }
    }

    let token = token
        .ok_or_else(|| AppError::ValidationError("缺少 device_token 或 user_id".to_string()))?;

    if payload.title.trim().is_empty() {
        return Err(AppError::ValidationError("title 不能为空".to_string()));
    }
    if payload.body.trim().is_empty() {
        return Err(AppError::ValidationError("body 不能为空".to_string()));
    }

    let mut data = HashMap::new();
    data.insert("type".to_string(), "test".to_string());

    match provider.as_str() {
        "fcm" => {
            crate::services::push::send_fcm_test(
                &state,
                &token,
                &payload.title,
                &payload.body,
                &data,
            )
            .await
        }
        "apns" => {
            crate::services::push::send_apns_test(
                &state,
                &token,
                &payload.title,
                &payload.body,
                &data,
            )
            .await
        }
        _ => unreachable!(),
    }
    .map_err(AppError::InternalError)?;

    Ok(Json(TestPushResponse {
        success: true,
        message: "发送成功".to_string(),
    }))
}
