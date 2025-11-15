use crate::database::document_store::DocumentStore;
use crate::database::settings_store::SettingsStore;
use crate::error::AppError;
use crate::models::convert::{api_update_document_to_db, db_document_to_api, string_to_uuid};
use crate::models::{Claims, DocumentContent, UpdateDocumentRequest};
use crate::AppState;
use axum::{extract::State, Extension, Json};
use serde::{Deserialize, Serialize};

const PRIVACY_POLICY_KEY: &str = "privacy_policy";
const PRIVACY_POLICY_FALLBACK_TITLE: &str = "隐私协议";
const PRIVACY_POLICY_FALLBACK_CONTENT: &str = "<p>隐私协议内容尚未配置。</p>";

const USER_AGREEMENT_KEY: &str = "user_agreement";
const USER_AGREEMENT_FALLBACK_TITLE: &str = "用户协议";
const USER_AGREEMENT_FALLBACK_CONTENT: &str = "<p>用户协议内容尚未配置。</p>";

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
        return Err(AppError::ValidationError(
            "应用名称不能为空".to_string(),
        ));
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
