use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::models::{CaptchaSettingRecord, UserStatus};
use crate::database::settings_store::SettingsStore;
use crate::database::user_store::UserStore;
use crate::AppState;
use tracing::error;

#[derive(Debug, Serialize)]
pub struct SystemStats {
    pub total_users: i64,
    pub online_users: i64,
    pub total_rooms: i64,
    pub active_rooms: i64,
    pub total_messages: i64,
    pub today_messages: i64,
    pub system_load: f64,
    pub memory_usage: f64,
    pub storage_usage: f64,
}

#[derive(Debug, Serialize)]
pub struct SystemMonitor {
    pub cpu: f64,
    pub memory: f64,
    pub disk: f64,
    pub network_in: f64,
    pub network_out: f64,
    pub connections: i64,
}

#[derive(Debug, Deserialize)]
pub struct PaginationParams {
    #[serde(default = "default_page")]
    pub page: usize,
    #[serde(default = "default_page_size", alias = "pageSize")]
    pub page_size: usize,
}

fn default_page() -> usize {
    1
}

fn default_page_size() -> usize {
    20
}

#[derive(Debug, Deserialize)]
pub struct UserListParams {
    #[serde(default = "default_page")]
    pub page: usize,
    #[serde(default = "default_page_size", alias = "pageSize")]
    pub page_size: usize,
    pub status: Option<String>,
    pub username: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct AdminUser {
    pub id: String,
    pub username: String,
    pub email: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub status: String,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct UserListResponse {
    pub users: Vec<AdminUser>,
    pub total: usize,
    pub page: usize,
    pub page_size: usize,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserStatusRequest {
    pub status: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CaptchaSetting {
    pub enabled: bool,
    pub captcha_code: String,
    pub description: String,
    pub updated_at: String,
}

impl From<CaptchaSettingRecord> for CaptchaSetting {
    fn from(record: CaptchaSettingRecord) -> Self {
        Self {
            enabled: record.enabled,
            captcha_code: record.captcha_code,
            description: record.description,
            updated_at: record.updated_at.to_rfc3339(),
        }
    }
}

pub async fn get_dashboard_stats(
    State(_state): State<AppState>,
) -> Result<Json<SystemStats>, StatusCode> {
    // TODO: 实现真实的统计数据计算
    let stats = SystemStats {
        total_users: 1250,
        online_users: 324,
        total_rooms: 156,
        active_rooms: 42,
        total_messages: 54280,
        today_messages: 1280,
        system_load: 0.45,
        memory_usage: 0.62,
        storage_usage: 0.28,
    };

    Ok(Json(stats))
}

pub async fn get_system_monitor(
    State(_state): State<AppState>,
) -> Result<Json<SystemMonitor>, StatusCode> {
    // TODO: 实现真实的系统监控数据
    let monitor = SystemMonitor {
        cpu: 0.35,
        memory: 0.62,
        disk: 0.28,
        network_in: 512000.0,
        network_out: 256000.0,
        connections: 68,
    };

    Ok(Json(monitor))
}

pub async fn get_user_list(
    State(state): State<AppState>,
    Query(params): Query<UserListParams>,
) -> Result<Json<UserListResponse>, StatusCode> {
    let store = UserStore::new(state.database.clone());

    let page = params.page.max(1);
    let page_size = params.page_size.max(1).min(100);

    let status_param = params
        .status
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let status = match status_param {
        Some("active") => Some(UserStatus::Active),
        Some("inactive") => Some(UserStatus::Inactive),
        Some("banned") => Some(UserStatus::Banned),
        None => None,
        Some(_) => return Err(StatusCode::BAD_REQUEST),
    };

    let username = params
        .username
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let (users, total) = store
        .list_users(page, page_size, status, username)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let admins = users
        .into_iter()
        .map(|user| AdminUser {
            id: user.id.to_string(),
            username: user.username,
            email: user.email,
            nickname: user.nickname,
            avatar_url: user.avatar_url,
            status: user.status.to_string(),
            created_at: user.created_at.to_rfc3339(),
            updated_at: user.updated_at.to_rfc3339(),
            deleted_at: user.deleted_at.map(|dt| dt.to_rfc3339()),
        })
        .collect();

    Ok(Json(UserListResponse {
        users: admins,
        total: total as usize,
        page,
        page_size,
    }))
}

pub async fn update_user_status(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
    Json(req): Json<UpdateUserStatusRequest>,
) -> Result<(), StatusCode> {
    let user_id = Uuid::parse_str(&user_id).map_err(|_| StatusCode::BAD_REQUEST)?;

    let status = match req.status.as_str() {
        "active" => UserStatus::Active,
        "inactive" => UserStatus::Inactive,
        "banned" => UserStatus::Banned,
        _ => return Err(StatusCode::BAD_REQUEST),
    };

    let store = UserStore::new(state.database.clone());

    let updated = store
        .update_user_status(&user_id, status)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if !updated {
        return Err(StatusCode::NOT_FOUND);
    }

    Ok(())
}

pub async fn get_captcha_setting(
    State(state): State<AppState>,
) -> Result<Json<CaptchaSetting>, StatusCode> {
    let store = SettingsStore::new(state.database.clone());
    let setting = store
        .get_captcha_setting()
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(setting.into()))
}

#[derive(Debug, Deserialize)]
pub struct UpdateCaptchaSettingRequest {
    pub enabled: Option<bool>,
    pub captcha_code: Option<String>,
    pub description: Option<String>,
}

pub async fn update_captcha_setting(
    State(state): State<AppState>,
    Json(req): Json<UpdateCaptchaSettingRequest>,
) -> Result<Json<CaptchaSetting>, StatusCode> {
    let store = SettingsStore::new(state.database.clone());

    let enabled = req.enabled.unwrap_or(false);
    let captcha_code = req.captcha_code.unwrap_or_default().trim().to_string();
    let description = req.description.unwrap_or_default();

    let setting = store
        .upsert_captcha_setting(enabled, &captcha_code, &description, None)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(setting.into()))
}

pub async fn is_universal_captcha_code(state: &AppState, input: &str) -> bool {
    if input.trim().is_empty() {
        return false;
    }

    let store = SettingsStore::new(state.database.clone());
    match store.is_universal_captcha_code(input).await {
        Ok(result) => result,
        Err(err) => {
            error!(?err, "读取通用验证码配置失败");
            false
        }
    }
}
