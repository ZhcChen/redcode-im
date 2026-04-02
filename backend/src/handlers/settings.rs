use crate::database::document_store::DocumentStore;
use crate::database::settings_store::SettingsStore;
use crate::error::AppError;
use crate::i18n::{localizer::default_localizer, message::MessageParams};
use crate::middleware::current_request_locale;
use crate::models::convert::{api_update_document_to_db, db_document_to_api, string_to_uuid};
use crate::models::{Claims, DocumentContent, UpdateDocumentRequest};
use crate::AppState;
use axum::{extract::State, Extension, Json};
use serde::{Deserialize, Serialize};

const PRIVACY_POLICY_KEY: &str = "privacy_policy";
const PRIVACY_POLICY_FALLBACK_TITLE_KEY: &str = "settings.privacy_policy_fallback_title";
const PRIVACY_POLICY_FALLBACK_CONTENT_KEY: &str = "settings.privacy_policy_fallback_content";

const USER_AGREEMENT_KEY: &str = "user_agreement";
const USER_AGREEMENT_FALLBACK_TITLE_KEY: &str = "settings.user_agreement_fallback_title";
const USER_AGREEMENT_FALLBACK_CONTENT_KEY: &str = "settings.user_agreement_fallback_content";

fn settings_validation_error(message_key: &'static str) -> AppError {
    AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn settings_validation_error_with_params(
    message_key: &'static str,
    params: MessageParams,
) -> AppError {
    AppError::ValidationError(String::new()).with_message_key_and_params(message_key, Some(params))
}

fn settings_localized_message(message_key: &'static str) -> String {
    let localizer = default_localizer();
    let locale =
        current_request_locale().unwrap_or_else(|| localizer.fallback_locale().to_string());
    localizer.localize(&locale, message_key, None)
}

pub async fn get_privacy_policy(
    State(state): State<AppState>,
) -> Result<Json<DocumentContent>, AppError> {
    let store = DocumentStore::new(state.database.clone());
    let doc = match store.get_document(PRIVACY_POLICY_KEY).await? {
        Some(doc) => doc,
        None => {
            let update = crate::database::models::DocumentUpdate {
                title: Some(settings_localized_message(
                    PRIVACY_POLICY_FALLBACK_TITLE_KEY,
                )),
                content: settings_localized_message(PRIVACY_POLICY_FALLBACK_CONTENT_KEY),
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
        return Err(settings_validation_error(
            "settings.privacy_policy_content_required",
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
                title: Some(settings_localized_message(
                    USER_AGREEMENT_FALLBACK_TITLE_KEY,
                )),
                content: settings_localized_message(USER_AGREEMENT_FALLBACK_CONTENT_KEY),
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
        return Err(settings_validation_error(
            "settings.user_agreement_content_required",
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
}

#[derive(Serialize)]
pub struct AppNameResponse {
    pub app_name: String,
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
    Ok(Json(GeneralSettingsResponse { app_name }))
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
        return Err(settings_validation_error("settings.app_name_required"));
    }
    if app_name.len() > 50 {
        return Err(settings_validation_error_with_params(
            "settings.app_name_too_long",
            MessageParams::from([("max_length".to_string(), "50".to_string())]),
        ));
    }

    let editor_id = string_to_uuid(&claims.sub)?;
    let store = SettingsStore::new(state.database.clone());
    store
        .upsert_general_setting(
            "app_name",
            app_name,
            &settings_localized_message("settings.app_name_description"),
            Some(editor_id),
        )
        .await?;

    Ok(Json(AppNameResponse {
        app_name: app_name.to_string(),
    }))
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
        return Err(settings_validation_error(
            "settings.account_validation_rule_required",
        ));
    }

    // 验证长度范围
    if payload.enable_length_validation {
        if payload.min_length < 3 || payload.max_length > 50 {
            return Err(settings_validation_error_with_params(
                "settings.account_length_range_invalid",
                MessageParams::from([
                    ("min_allowed".to_string(), "3".to_string()),
                    ("max_allowed".to_string(), "50".to_string()),
                ]),
            ));
        }
        if payload.min_length > payload.max_length {
            return Err(settings_validation_error(
                "settings.account_min_length_gt_max_length",
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_settings_validation_error_uses_settings_domain_message_key() {
        let error = settings_validation_error("settings.app_name_required");

        assert_eq!(error.message_key(), "common.validation_error");
        assert_eq!(error.response_message_key(), "settings.app_name_required");
    }

    #[test]
    fn test_settings_validation_error_with_params_preserves_message_params() {
        let params = MessageParams::from([("max_length".to_string(), "50".to_string())]);
        let error =
            settings_validation_error_with_params("settings.app_name_too_long", params.clone());

        assert_eq!(error.message_key(), "common.validation_error");
        assert_eq!(error.response_message_key(), "settings.app_name_too_long");
        assert_eq!(error.message_params().as_ref(), Some(&params));
    }

    #[test]
    fn settings_policy_fallbacks_should_use_catalog_messages() {
        let source = include_str!("settings.rs");

        assert!(
            source.contains("settings.privacy_policy_fallback_title"),
            "settings handler should use settings.privacy_policy_fallback_title"
        );
        assert!(
            source.contains("settings.privacy_policy_fallback_content"),
            "settings handler should use settings.privacy_policy_fallback_content"
        );
        assert!(
            source.contains("settings.user_agreement_fallback_title"),
            "settings handler should use settings.user_agreement_fallback_title"
        );
        assert!(
            source.contains("settings.user_agreement_fallback_content"),
            "settings handler should use settings.user_agreement_fallback_content"
        );
    }

    #[test]
    fn settings_policy_fallbacks_should_not_embed_legacy_literals() {
        let source = include_str!("settings.rs");

        for legacy in [
            [
                "const PRIVACY_POLICY_FALLBACK_TITLE: &str = \"",
                "\u{9690}\u{79c1}\u{534f}\u{8bae}",
                "\";",
            ]
            .concat(),
            [
                "const PRIVACY_POLICY_FALLBACK_CONTENT: &str = \"<p>",
                "\u{9690}\u{79c1}\u{534f}\u{8bae}\u{5185}\u{5bb9}\u{5c1a}\u{672a}\u{914d}\u{7f6e}\u{3002}",
                "</p>\";",
            ]
            .concat(),
            [
                "const USER_AGREEMENT_FALLBACK_TITLE: &str = \"",
                "\u{7528}\u{6237}\u{534f}\u{8bae}",
                "\";",
            ]
            .concat(),
            [
                "const USER_AGREEMENT_FALLBACK_CONTENT: &str = \"<p>",
                "\u{7528}\u{6237}\u{534f}\u{8bae}\u{5185}\u{5bb9}\u{5c1a}\u{672a}\u{914d}\u{7f6e}\u{3002}",
                "</p>\";",
            ]
            .concat(),
        ] {
            assert!(
                !source.contains(&legacy),
                "settings handler should not embed legacy fallback literal pattern: {legacy}"
            );
        }
    }

    #[test]
    fn settings_general_setting_descriptions_should_use_i18n_keys() {
        let source = include_str!("settings.rs");

        assert!(
            source.contains("settings.app_name_description"),
            "settings handler should reuse app_name description i18n key"
        );
    }

    #[test]
    fn settings_general_setting_descriptions_should_not_embed_legacy_literals() {
        let source = include_str!("settings.rs");
        let legacy = ["\"", "\u{5e94}\u{7528}\u{540d}\u{79f0}", "\""].concat();

        assert!(
            !source.contains(&legacy),
            "settings handler should not embed legacy general-setting description literal: {legacy}"
        );
    }
}
