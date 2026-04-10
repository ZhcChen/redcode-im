use crate::database::document_store::DocumentStore;
use crate::database::settings_store::SettingsStore;
use crate::error::AppError;
use crate::models::convert::{api_update_document_to_db, db_document_to_api, string_to_uuid};
use crate::models::{Claims, DocumentContent, UpdateDocumentRequest};
use crate::AppState;
use axum::{extract::State, Extension, Json};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

const PRIVACY_POLICY_KEY: &str = "privacy_policy";
const PRIVACY_POLICY_FALLBACK_TITLE: &str = "隐私协议";
const PRIVACY_POLICY_FALLBACK_CONTENT: &str = "<p>隐私协议内容尚未配置。</p>";

const USER_AGREEMENT_KEY: &str = "user_agreement";
const USER_AGREEMENT_FALLBACK_TITLE: &str = "用户协议";
const USER_AGREEMENT_FALLBACK_CONTENT: &str = "<p>用户协议内容尚未配置。</p>";
const MESSAGE_SERVER_STORAGE_MODE_KEY: &str = "message_server_storage_mode";
const MESSAGE_CONTENT_AUDIT_MODE_KEY: &str = "message_content_audit_mode";
const DEFAULT_MESSAGE_SERVER_STORAGE_MODE: &str = "persist";
const DEFAULT_MESSAGE_CONTENT_AUDIT_MODE: &str = "plaintext";

pub async fn get_privacy_policy(
    State(state): State<AppState>,
) -> Result<Json<DocumentContent>, AppError> {
    let store = DocumentStore::new(state.database.clone());
    let doc = match store.get_document(PRIVACY_POLICY_KEY).await? {
        Some(doc) => doc,
        None => {
            let update = crate::database::models::DocumentUpdate {
                title: Some(PRIVACY_POLICY_FALLBACK_TITLE.to_string()),
                content: PRIVACY_POLICY_FALLBACK_CONTENT.to_string(),
                updated_by: None,
            };
            store.upsert_document(PRIVACY_POLICY_KEY, &update).await?
        }
    };

    Ok(Json(db_document_to_api(&doc)))
}

pub async fn get_privacy_policy_admin(
    State(state): State<AppState>,
) -> Result<Json<DocumentContent>, AppError> {
    get_privacy_policy(State(state)).await
}

pub async fn update_privacy_policy(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateDocumentRequest>,
) -> Result<Json<DocumentContent>, AppError> {
    if payload.content.trim().is_empty() {
        return Err(AppError::ValidationError(
            "隐私协议内容不能为空".to_string(),
        ));
    }

    let editor_id = string_to_uuid(&claims.sub)?;
    let store = DocumentStore::new(state.database.clone());
    let update = api_update_document_to_db(&payload, Some(editor_id));

    let doc = store.upsert_document(PRIVACY_POLICY_KEY, &update).await?;

    Ok(Json(db_document_to_api(&doc)))
}

// ===== 用户协议 API =====

/// 获取用户协议（公开 API，无需 token）
pub async fn get_user_agreement(
    State(state): State<AppState>,
) -> Result<Json<DocumentContent>, AppError> {
    let store = DocumentStore::new(state.database.clone());
    let doc = match store.get_document(USER_AGREEMENT_KEY).await? {
        Some(doc) => doc,
        None => {
            let update = crate::database::models::DocumentUpdate {
                title: Some(USER_AGREEMENT_FALLBACK_TITLE.to_string()),
                content: USER_AGREEMENT_FALLBACK_CONTENT.to_string(),
                updated_by: None,
            };
            store.upsert_document(USER_AGREEMENT_KEY, &update).await?
        }
    };

    Ok(Json(db_document_to_api(&doc)))
}

/// 获取用户协议（管理员 API）
pub async fn get_user_agreement_admin(
    State(state): State<AppState>,
) -> Result<Json<DocumentContent>, AppError> {
    get_user_agreement(State(state)).await
}

/// 更新用户协议（需要管理员权限）
pub async fn update_user_agreement(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateDocumentRequest>,
) -> Result<Json<DocumentContent>, AppError> {
    if payload.content.trim().is_empty() {
        return Err(AppError::ValidationError(
            "用户协议内容不能为空".to_string(),
        ));
    }

    let editor_id = string_to_uuid(&claims.sub)?;
    let store = DocumentStore::new(state.database.clone());
    let update = api_update_document_to_db(&payload, Some(editor_id));

    let doc = store.upsert_document(USER_AGREEMENT_KEY, &update).await?;

    Ok(Json(db_document_to_api(&doc)))
}

// ===== 通用设置 API =====

#[derive(Serialize)]
pub struct GeneralSettingsResponse {
    pub app_name: String,
    pub message_runtime: MessageRuntimeSettingsResponse,
}

#[derive(Serialize)]
pub struct AppNameResponse {
    pub app_name: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum MessageServerStorageMode {
    Persist,
    RelayOnly,
}

impl MessageServerStorageMode {
    fn as_str(self) -> &'static str {
        match self {
            Self::Persist => "persist",
            Self::RelayOnly => "relay_only",
        }
    }

    fn parse(raw: &str) -> Result<Self, AppError> {
        match raw.trim().to_ascii_lowercase().as_str() {
            "persist" => Ok(Self::Persist),
            "relay_only" => Ok(Self::RelayOnly),
            _ => Err(AppError::ValidationError(
                "server_storage_mode 仅支持 persist / relay_only".to_string(),
            )),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum MessageContentAuditMode {
    Plaintext,
    E2ee,
}

impl MessageContentAuditMode {
    fn as_str(self) -> &'static str {
        match self {
            Self::Plaintext => "plaintext",
            Self::E2ee => "e2ee",
        }
    }

    fn parse(raw: &str) -> Result<Self, AppError> {
        match raw.trim().to_ascii_lowercase().as_str() {
            "plaintext" => Ok(Self::Plaintext),
            "e2ee" => Ok(Self::E2ee),
            _ => Err(AppError::ValidationError(
                "content_audit_mode 仅支持 plaintext / e2ee".to_string(),
            )),
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct MessageRuntimeSettingsResponse {
    pub server_storage_mode: String,
    pub content_audit_mode: String,
    pub updated_at: Option<String>,
    pub updated_by: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateMessageRuntimeSettingsRequest {
    pub server_storage_mode: String,
    pub content_audit_mode: String,
}

fn merge_message_runtime_metadata(
    left: Option<&crate::database::models::GeneralSettingRecord>,
    right: Option<&crate::database::models::GeneralSettingRecord>,
) -> (Option<DateTime<Utc>>, Option<String>) {
    let chosen = match (left, right) {
        (Some(l), Some(r)) => {
            if l.updated_at >= r.updated_at {
                Some(l)
            } else {
                Some(r)
            }
        }
        (Some(l), None) => Some(l),
        (None, Some(r)) => Some(r),
        (None, None) => None,
    };

    (
        chosen.map(|record| record.updated_at),
        chosen.and_then(|record| record.updated_by.map(|value| value.to_string())),
    )
}

async fn load_message_runtime_settings(
    store: &SettingsStore,
) -> Result<MessageRuntimeSettingsResponse, AppError> {
    let server_storage = store
        .get_general_setting(MESSAGE_SERVER_STORAGE_MODE_KEY)
        .await?;
    let content_audit = store
        .get_general_setting(MESSAGE_CONTENT_AUDIT_MODE_KEY)
        .await?;
    let (updated_at, updated_by) =
        merge_message_runtime_metadata(server_storage.as_ref(), content_audit.as_ref());

    Ok(MessageRuntimeSettingsResponse {
        server_storage_mode: server_storage
            .as_ref()
            .map(|record| record.value.clone())
            .unwrap_or_else(|| DEFAULT_MESSAGE_SERVER_STORAGE_MODE.to_string()),
        content_audit_mode: content_audit
            .as_ref()
            .map(|record| record.value.clone())
            .unwrap_or_else(|| DEFAULT_MESSAGE_CONTENT_AUDIT_MODE.to_string()),
        updated_at: updated_at.map(|value| value.to_rfc3339()),
        updated_by,
    })
}

#[derive(Deserialize)]
pub struct UpdateAppNameRequest {
    pub app_name: String,
}

/// 获取通用设置（公开 API，无需 token）
pub async fn get_general_settings(
    State(state): State<AppState>,
) -> Result<Json<GeneralSettingsResponse>, AppError> {
    let store = SettingsStore::new(state.database.clone());
    let app_name = store.get_app_name().await?;
    let message_runtime = load_message_runtime_settings(&store).await?;
    Ok(Json(GeneralSettingsResponse {
        app_name,
        message_runtime,
    }))
}

/// 获取应用名称（公开 API，无需 token）
pub async fn get_app_name(
    State(state): State<AppState>,
) -> Result<Json<AppNameResponse>, AppError> {
    let store = SettingsStore::new(state.database.clone());
    let app_name = store.get_app_name().await?;
    Ok(Json(AppNameResponse { app_name }))
}

/// 更新应用名称（需要管理员权限）
pub async fn update_app_name(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateAppNameRequest>,
) -> Result<Json<AppNameResponse>, AppError> {
    let app_name = payload.app_name.trim();
    if app_name.is_empty() {
        return Err(AppError::ValidationError("应用名称不能为空".to_string()));
    }
    if app_name.len() > 50 {
        return Err(AppError::ValidationError(
            "应用名称不能超过50个字符".to_string(),
        ));
    }

    let editor_id = string_to_uuid(&claims.sub)?;
    let store = SettingsStore::new(state.database.clone());
    store
        .upsert_general_setting("app_name", app_name, "应用名称", Some(editor_id))
        .await?;

    Ok(Json(AppNameResponse {
        app_name: app_name.to_string(),
    }))
}

pub async fn get_message_runtime_settings_admin(
    State(state): State<AppState>,
) -> Result<Json<MessageRuntimeSettingsResponse>, AppError> {
    let store = SettingsStore::new(state.database.clone());
    Ok(Json(load_message_runtime_settings(&store).await?))
}

pub async fn update_message_runtime_settings_admin(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateMessageRuntimeSettingsRequest>,
) -> Result<Json<MessageRuntimeSettingsResponse>, AppError> {
    let editor_id = string_to_uuid(&claims.sub)?;
    let server_storage_mode = MessageServerStorageMode::parse(&payload.server_storage_mode)?;
    let content_audit_mode = MessageContentAuditMode::parse(&payload.content_audit_mode)?;

    let store = SettingsStore::new(state.database.clone());
    store
        .upsert_general_setting(
            MESSAGE_SERVER_STORAGE_MODE_KEY,
            server_storage_mode.as_str(),
            "消息服务器存储模式（persist=落库，relay_only=仅转发）",
            Some(editor_id),
        )
        .await?;
    store
        .upsert_general_setting(
            MESSAGE_CONTENT_AUDIT_MODE_KEY,
            content_audit_mode.as_str(),
            "消息内容审计模式（plaintext=明文可审计，e2ee=端侧加密）",
            Some(editor_id),
        )
        .await?;

    Ok(Json(load_message_runtime_settings(&store).await?))
}

// ===== 验证码设置 API（公开，无需 token）=====

#[derive(Serialize)]
pub struct CaptchaSettingPublicResponse {
    pub require_captcha_for_login: bool,
}

/// 获取登录/注册是否需要验证码（公开 API，无需 token）
pub async fn get_captcha_setting_public(
    State(state): State<AppState>,
) -> Result<Json<CaptchaSettingPublicResponse>, AppError> {
    let store = SettingsStore::new(state.database.clone());
    let require_captcha = store.require_captcha_for_login().await?;
    Ok(Json(CaptchaSettingPublicResponse {
        require_captcha_for_login: require_captcha,
    }))
}

#[cfg(test)]
mod tests {
    use super::{MessageContentAuditMode, MessageServerStorageMode};

    #[test]
    fn message_server_storage_mode_parse_accepts_supported_values() {
        assert_eq!(
            MessageServerStorageMode::parse("persist")
                .expect("persist should be valid")
                .as_str(),
            "persist"
        );
        assert_eq!(
            MessageServerStorageMode::parse("relay_only")
                .expect("relay_only should be valid")
                .as_str(),
            "relay_only"
        );
    }

    #[test]
    fn message_content_audit_mode_parse_accepts_supported_values() {
        assert_eq!(
            MessageContentAuditMode::parse("plaintext")
                .expect("plaintext should be valid")
                .as_str(),
            "plaintext"
        );
        assert_eq!(
            MessageContentAuditMode::parse("e2ee")
                .expect("e2ee should be valid")
                .as_str(),
            "e2ee"
        );
    }

    #[test]
    fn message_runtime_mode_parse_rejects_invalid_values() {
        assert!(MessageServerStorageMode::parse("other").is_err());
        assert!(MessageContentAuditMode::parse("secret").is_err());
    }
}

// ===== 用户账号限制设置 API =====

#[derive(Serialize)]
pub struct UserAccountLimitResponse {
    pub enable_phone_validation: bool,
    pub enable_email_validation: bool,
    pub enable_length_validation: bool,
    pub min_length: i32,
    pub max_length: i32,
    pub enable_alphanumeric_validation: bool,
}

#[derive(Deserialize)]
pub struct UpdateUserAccountLimitRequest {
    pub enable_phone_validation: bool,
    pub enable_email_validation: bool,
    pub enable_length_validation: bool,
    pub min_length: i32,
    pub max_length: i32,
    pub enable_alphanumeric_validation: bool,
}

/// 获取用户账号限制设置（管理员 API）
pub async fn get_user_account_limit(
    State(state): State<AppState>,
) -> Result<Json<UserAccountLimitResponse>, AppError> {
    let store = SettingsStore::new(state.database.clone());
    let setting = store.get_user_account_limit_setting().await?;
    Ok(Json(UserAccountLimitResponse {
        enable_phone_validation: setting.enable_phone_validation,
        enable_email_validation: setting.enable_email_validation,
        enable_length_validation: setting.enable_length_validation,
        min_length: setting.min_length,
        max_length: setting.max_length,
        enable_alphanumeric_validation: setting.enable_alphanumeric_validation,
    }))
}

/// 更新用户账号限制设置（需要管理员权限）
pub async fn update_user_account_limit(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateUserAccountLimitRequest>,
) -> Result<Json<UserAccountLimitResponse>, AppError> {
    // 验证至少启用一种校验规则
    if !payload.enable_phone_validation
        && !payload.enable_email_validation
        && !payload.enable_length_validation
        && !payload.enable_alphanumeric_validation
    {
        return Err(AppError::ValidationError(
            "至少需要启用一种校验规则".to_string(),
        ));
    }

    // 验证长度范围
    if payload.enable_length_validation {
        if payload.min_length < 3 || payload.max_length > 50 {
            return Err(AppError::ValidationError(
                "长度限制范围必须在 3-50 之间".to_string(),
            ));
        }
        if payload.min_length > payload.max_length {
            return Err(AppError::ValidationError(
                "最小长度不能大于最大长度".to_string(),
            ));
        }
    }

    let editor_id = string_to_uuid(&claims.sub)?;
    let store = SettingsStore::new(state.database.clone());
    let updated_setting = store
        .update_user_account_limit_setting(
            payload.enable_phone_validation,
            payload.enable_email_validation,
            payload.enable_length_validation,
            payload.min_length,
            payload.max_length,
            payload.enable_alphanumeric_validation,
            Some(editor_id),
        )
        .await?;

    Ok(Json(UserAccountLimitResponse {
        enable_phone_validation: updated_setting.enable_phone_validation,
        enable_email_validation: updated_setting.enable_email_validation,
        enable_length_validation: updated_setting.enable_length_validation,
        min_length: updated_setting.min_length,
        max_length: updated_setting.max_length,
        enable_alphanumeric_validation: updated_setting.enable_alphanumeric_validation,
    }))
}
