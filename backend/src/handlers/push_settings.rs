use axum::{
    extract::{Extension, Path, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::collections::{BTreeMap, HashMap};
use uuid::Uuid;

use crate::crypto::SecretCrypto;
use crate::database::push_provider_config_store::PushProviderConfigStore;
use crate::database::settings_store::SettingsStore;
use crate::error::AppError;
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
    let editor_id = Uuid::parse_str(&claims.sub).map_err(|_| {
        AppError::InvalidToken(String::new()).with_message_key("auth.token_subject_invalid")
    })?;
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

    get_push_settings_admin(State(state)).await
}

#[derive(Debug, Deserialize)]
pub struct UpsertFcmConfigRequest {
    pub enabled: bool,
    /// FCM service account JSON（明文）；服务端会加密落库
    pub service_account_json: Option<String>,
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
    Json(payload): Json<UpsertFcmConfigRequest>,
) -> Result<Json<PushProviderConfigView>, AppError> {
    let provider = provider.trim().to_lowercase();
    if provider != "fcm" {
        return Err(
            AppError::ValidationError(String::new()).with_message_key_and_params(
                "push.provider_unsupported",
                Some(BTreeMap::from([("provider".to_string(), provider.clone())])),
            ),
        );
    }

    let editor_id = Uuid::parse_str(&claims.sub).map_err(|_| {
        AppError::InvalidToken(String::new()).with_message_key("auth.token_subject_invalid")
    })?;
    let store = PushProviderConfigStore::new(state.database.pool());

    let existing = store.get_config(&provider, "all").await?;
    let mut config_public = existing
        .as_ref()
        .map(|v| v.config_public.clone())
        .unwrap_or_else(|| json!({}));

    let mut secret_ciphertext: Option<String> = None;
    let mut secret_fingerprint: Option<String> = None;

    if let Some(raw) = payload.service_account_json.as_ref() {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            return Err(AppError::ValidationError(String::new())
                .with_message_key("push.service_account_json_required"));
        }

        let parsed: GoogleServiceAccountPayload = serde_json::from_str(trimmed).map_err(|e| {
            AppError::ValidationError(String::new()).with_message_key_and_params(
                "push.service_account_json_invalid",
                Some(BTreeMap::from([("reason".to_string(), e.to_string())])),
            )
        })?;
        if parsed.project_id.trim().is_empty()
            || parsed.client_email.trim().is_empty()
            || parsed.private_key.trim().is_empty()
        {
            return Err(AppError::ValidationError(String::new())
                .with_message_key("push.service_account_json_missing_fields"));
        }

        config_public = json!({
            "project_id": parsed.project_id,
            "client_email": parsed.client_email,
            "token_uri": parsed.token_uri,
        });

        let crypto = SecretCrypto::new().map_err(|e| {
            AppError::InternalError(String::new()).with_message_key_and_params(
                "push.secret_crypto_init_failed",
                Some(BTreeMap::from([("reason".to_string(), e.to_string())])),
            )
        })?;
        secret_ciphertext = Some(crypto.encrypt_to_base64(trimmed).map_err(|e| {
            AppError::InternalError(String::new()).with_message_key_and_params(
                "push.secret_encrypt_failed",
                Some(BTreeMap::from([("reason".to_string(), e.to_string())])),
            )
        })?);
        secret_fingerprint = Some(SecretCrypto::sha256_hex(trimmed));
    }

    let saved = store
        .upsert_config(
            &provider,
            "all",
            payload.enabled,
            config_public,
            secret_ciphertext,
            secret_fingerprint,
            Some(editor_id),
        )
        .await?;

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
    if provider != "fcm" {
        return Err(
            AppError::ValidationError(String::new()).with_message_key_and_params(
                "push.provider_unsupported",
                Some(BTreeMap::from([("provider".to_string(), provider.clone())])),
            ),
        );
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
            let user_uuid = Uuid::parse_str(user_id).map_err(|_| {
                AppError::ValidationError(String::new()).with_message_key("push.user_id_invalid")
            })?;
            let device_store =
                crate::database::push_device_store::PushDeviceStore::new(state.database.pool());
            let devices = device_store
                .list_active_devices_for_users(&[user_uuid])
                .await?;
            token = devices
                .into_iter()
                .find(|d| d.channel == "fcm")
                .map(|d| d.device_token);
        }
    }

    let token = token.ok_or_else(|| {
        AppError::ValidationError(String::new())
            .with_message_key("push.device_token_or_user_id_required")
    })?;

    if payload.title.trim().is_empty() {
        return Err(
            AppError::ValidationError(String::new()).with_message_key("push.title_required")
        );
    }
    if payload.body.trim().is_empty() {
        return Err(AppError::ValidationError(String::new()).with_message_key("push.body_required"));
    }

    let mut data = HashMap::new();
    data.insert("type".to_string(), "test".to_string());

    crate::services::push::send_fcm_test(&state, &token, &payload.title, &payload.body, &data)
        .await
        .map_err(|e| {
            AppError::InternalError(String::new()).with_message_key_and_params(
                "push.test_send_failed",
                Some(BTreeMap::from([("reason".to_string(), e)])),
            )
        })?;

    Ok(Json(TestPushResponse {
        success: true,
        message: "ok".to_string(),
    }))
}
