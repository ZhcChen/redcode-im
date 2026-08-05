use axum::{
    extract::{Extension, Path, Query, State},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use serde_json;
use uuid::Uuid;

use crate::auth::hash_password;
use crate::database::admin_rbac_store::AdminRbacStore;
use crate::database::models::{
    AdminUser, AdminUserStatus, CaptchaSettingRecord, Permission, Role, StorageProvider,
    StorageProviderType, UserStatus as DbUserStatus,
};
use crate::database::settings_store::SettingsStore;
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::logging::LogQueryParams;
use crate::models::Claims;
use crate::redis::cache::CacheManager;
use crate::redis::models::CacheKeys;
use crate::services::geolocation;
use crate::services::multipart_upload;
use crate::storage;
use crate::AppState;
use chrono::{DateTime, NaiveDate, Utc};
use ipnetwork::IpNetwork;
use sqlx::{FromRow, Postgres, QueryBuilder, Row};
use tracing::{error, info};

/// 管理员用户信息（API响应）
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AdminUserInfo {
    pub id: String,
    pub username: String,
    pub email: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub status: String,
    pub last_login_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// 管理员创建请求
#[derive(Debug, Deserialize)]
pub struct CreateAdminUserRequest {
    pub username: String,
    pub email: String,
    pub password: String,
    pub nickname: Option<String>,
}

/// 管理员用户列表参数
#[derive(Debug, Deserialize)]
pub struct AdminUserListParams {
    #[serde(default)]
    pub page: Option<usize>,
    #[serde(default)]
    pub page_size: Option<usize>,
    pub status: Option<String>,
    pub username: Option<String>,
}

/// 管理员用户列表响应
#[derive(Debug, Serialize)]
pub struct AdminUserListResponse {
    pub users: Vec<AdminUserInfo>,
    pub total: usize,
    pub page: usize,
    pub page_size: usize,
}

/// 更新管理员用户状态请求
#[derive(Debug, Deserialize)]
pub struct UpdateAdminUserStatusRequest {
    pub status: String,
}

/// 管理员操作响应
#[derive(Debug, Serialize)]
pub struct AdminOperationResponse {
    pub success: bool,
    pub message: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
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
#[serde(rename_all = "camelCase")]
pub struct DashboardStorageStats {
    pub total_files: i64,
    /// 统一按字节返回（前端自行格式化）
    pub total_size: i64,
    pub today_uploads: i64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DashboardEmojiStats {
    /// emoji_items 总数
    pub total_emojis: i64,
    /// 今日使用次数（按 message_parts 统计）
    pub today_usage: i64,
    /// 近 7 天内被使用过的表情数量（去重）
    pub popular_count: i64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NodeMonitorInfo {
    pub node_id: String,
    pub address: String,
    pub connected_users: usize,
    pub active_rooms: usize,
    pub cpu_usage: f64,
    pub memory_usage: f64,
    pub disk_usage: f64,
    pub cpu_count: u32,
    pub total_memory: u64,
    pub last_heartbeat: String,
    pub started_at: String,
}

#[derive(Debug, Serialize)]
pub struct DataStatistics {
    pub daily_active_users: Vec<DailyStat>,
    pub daily_messages: Vec<DailyStat>,
    pub storage_usage_by_type: Vec<StorageTypeStat>,
    pub user_growth_rate: f64,
    pub message_growth_rate: f64,
    pub peak_active_time: String,
}

#[derive(Debug, Deserialize)]
pub struct ApiMetricsParams {
    pub page: Option<usize>,
    pub page_size: Option<usize>,
    pub sort_field: Option<String>,
    pub sort_order: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ApiMetricsResponse {
    pub metrics: Vec<serde_json::Value>,
    pub top_avg: Vec<serde_json::Value>,
    pub top_count: Vec<serde_json::Value>,
    pub total: usize,
    pub page: usize,
    pub page_size: usize,
}

#[derive(Debug, Serialize)]
pub struct DailyStat {
    pub date: String,
    pub count: i64,
}

#[derive(Debug, Serialize)]
pub struct StorageTypeStat {
    pub file_type: String,
    pub count: i64,
    pub size_bytes: i64,
    pub percentage: f64,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
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
pub struct AdminUserResponse {
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
    pub users: Vec<AdminUserResponse>,
    pub total: usize,
    pub page: usize,
    pub page_size: usize,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserStatusRequest {
    pub status: String,
}

#[derive(Debug, Deserialize)]
pub struct FeedbackListParams {
    #[serde(default = "default_page")]
    pub page: usize,
    #[serde(default = "default_page_size", alias = "pageSize")]
    pub page_size: usize,
    #[serde(alias = "userId")]
    pub user_id: Option<String>,
    pub keyword: Option<String>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct FeedbackItem {
    pub id: String,
    pub user_id: String,
    pub username: Option<String>,
    pub nickname: Option<String>,
    pub contact: Option<String>,
    pub content: String,
    pub created_at: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FeedbackListResponse {
    pub feedbacks: Vec<FeedbackItem>,
    pub total: i64,
    pub page: usize,
    pub page_size: usize,
}

#[derive(Debug, Serialize)]
pub struct UserDetail {
    pub id: String,
    pub username: String,
    pub email: String,
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    pub status: String,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
    pub last_login_at: Option<String>,
    pub message_count: i64,
    pub room_count: i64,
    pub storage_usage: i64,
}

#[derive(Debug, FromRow)]
struct UserBasicInfoRow {
    id: Uuid,
    username: String,
    email: String,
    nickname: Option<String>,
    avatar_url: Option<String>,
    status: i16,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    deleted_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct CreateUserRequest {
    pub username: String,
    pub email: String,
    pub password: String,
    pub nickname: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub email: Option<String>,
    pub nickname: Option<String>,
    pub status: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ResetPasswordRequest {
    pub new_password: String,
}

#[derive(Debug, Serialize)]
pub struct UserOperationResponse {
    pub success: bool,
    pub message: String,
}

// ========== 权限管理相关数据结构 ==========

#[derive(Debug, Serialize)]
pub struct PermissionListResponse {
    pub permissions: Vec<PermissionResponse>,
}

#[derive(Debug, Serialize)]
pub struct PermissionResponse {
    pub id: String,
    pub name: String,
    pub code: String,
    pub description: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

impl From<Permission> for PermissionResponse {
    fn from(permission: Permission) -> Self {
        Self {
            id: permission.id.to_string(),
            name: permission.name,
            code: permission.code,
            description: permission.description,
            created_at: permission.created_at.to_rfc3339(),
            updated_at: permission.updated_at.to_rfc3339(),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct RoleListResponse {
    pub roles: Vec<RoleResponse>,
}

#[derive(Debug, Serialize)]
pub struct RoleResponse {
    pub id: String,
    pub name: String,
    pub code: String,
    pub description: Option<String>,
    pub is_system: bool,
    pub created_at: String,
    pub updated_at: String,
    pub permissions: Vec<PermissionResponse>,
}

impl From<Role> for RoleResponse {
    fn from(role: Role) -> Self {
        Self {
            id: role.id.to_string(),
            name: role.name,
            code: role.code,
            description: role.description,
            is_system: role.is_system,
            created_at: role.created_at.to_rfc3339(),
            updated_at: role.updated_at.to_rfc3339(),
            permissions: Vec::new(), // 需要单独查询
        }
    }
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct CreateRoleRequest {
    pub name: String,
    pub code: String,
    pub description: Option<String>,
    pub permission_ids: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct UpdateRoleRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub permission_ids: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct CheckPermissionRequest {
    pub user_id: String,
    pub permission_code: String,
}

#[derive(Debug, Serialize)]
pub struct CheckPermissionResponse {
    pub has_permission: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RolePermissionAssignmentResponse {
    pub role_id: String,
    pub permission_ids: Vec<String>,
    pub permission_codes: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateRolePermissionsRequest {
    pub permission_ids: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AdminUserRoleAssignmentResponse {
    pub admin_user_id: String,
    pub role_ids: Vec<String>,
    pub role_codes: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateAdminUserRolesRequest {
    pub role_ids: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CaptchaSetting {
    pub enabled: bool,
    pub captcha_code: String,
    pub description: String,
    pub require_captcha_for_login: bool,
    pub updated_at: String,
}

impl From<CaptchaSettingRecord> for CaptchaSetting {
    fn from(record: CaptchaSettingRecord) -> Self {
        Self {
            enabled: record.enabled,
            captcha_code: record.captcha_code,
            description: record.description,
            require_captcha_for_login: record.require_captcha_for_login,
            updated_at: record.updated_at.to_rfc3339(),
        }
    }
}

pub async fn get_dashboard_stats(
    State(state): State<AppState>,
) -> Result<Json<SystemStats>, AppError> {
    let pool = &state.database.pool;

    // 获取用户统计
    let total_users: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE deleted_at IS NULL")
            .fetch_one(pool)
            .await
            .map_err(|e| {
                tracing::error!("获取总用户数失败: {}", e);
                AppError::DatabaseError(e)
            })?;

    let online_users = get_online_users_count(&state).await.unwrap_or(0);

    // 获取房间统计
    let total_rooms: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM rooms WHERE deleted_at IS NULL")
            .fetch_one(pool)
            .await
            .map_err(|e| {
                tracing::error!("获取总房间数失败: {}", e);
                AppError::DatabaseError(e)
            })?;

    let active_rooms = get_active_rooms_count(pool).await.unwrap_or(0);

    // 获取消息统计
    let total_messages: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM messages WHERE deleted_at IS NULL")
            .fetch_one(pool)
            .await
            .map_err(|e| {
                tracing::error!("获取总消息数失败: {}", e);
                AppError::DatabaseError(e)
            })?;

    let today_messages = get_today_messages_count(pool).await.unwrap_or(0);

    // 获取系统资源使用情况
    let system_load = get_system_load().await.unwrap_or(0.0);
    let memory_usage = get_memory_usage().await.unwrap_or(0.0);
    let storage_usage = get_storage_usage(&state).await.unwrap_or(0.0);

    let stats = SystemStats {
        total_users,
        online_users,
        total_rooms,
        active_rooms,
        total_messages,
        today_messages,
        system_load,
        memory_usage,
        storage_usage,
    };

    Ok(Json(stats))
}

pub async fn get_dashboard_storage_stats(
    State(state): State<AppState>,
) -> Result<Json<DashboardStorageStats>, AppError> {
    let pool = &state.database.pool;

    // 以 file_upload_records 为准：覆盖头像/消息附件/贴纸/版本包等直传文件，并天然去重
    let total_files: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM file_upload_records WHERE status = 1")
            .fetch_one(pool)
            .await?;

    // Postgres 中 SUM(bigint) 返回 NUMERIC，这里显式 cast 回 BIGINT，确保可解码为 i64。
    let total_size: i64 = sqlx::query_scalar(
        "SELECT COALESCE(SUM(file_size)::BIGINT, 0::BIGINT)
         FROM file_upload_records
         WHERE status = 1",
    )
    .fetch_one(pool)
    .await?;

    let today_uploads: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)
         FROM file_upload_records
         WHERE status = 1
           AND COALESCE(uploaded_at, created_at) >= date_trunc('day', NOW())",
    )
    .fetch_one(pool)
    .await?;

    Ok(Json(DashboardStorageStats {
        total_files,
        total_size,
        today_uploads,
    }))
}

pub async fn get_dashboard_emoji_stats(
    State(state): State<AppState>,
) -> Result<Json<DashboardEmojiStats>, AppError> {
    let pool = &state.database.pool;

    let total_emojis: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM emoji_items")
        .fetch_one(pool)
        .await
        .map_err(AppError::DatabaseError)?;

    // 统计“emoji 被使用次数”：以 message_parts 里的图片分片为准，
    // 通过 attachment_key / image_url 与 emoji_items 关联。
    let today_usage: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM message_parts mp
        JOIN messages m ON m.id = mp.message_id AND m.deleted_at IS NULL
        JOIN emoji_items ei
          ON (ei.image_object_key IS NOT NULL AND mp.attachment_key = ei.image_object_key)
          OR (mp.attachment_key = ei.image_url)
        WHERE mp.part_type = 1
          AND mp.created_at >= date_trunc('day', NOW())
        "#,
    )
    .fetch_one(pool)
    .await
    .map_err(AppError::DatabaseError)?;

    let popular_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(DISTINCT ei.id)
        FROM message_parts mp
        JOIN messages m ON m.id = mp.message_id AND m.deleted_at IS NULL
        JOIN emoji_items ei
          ON (ei.image_object_key IS NOT NULL AND mp.attachment_key = ei.image_object_key)
          OR (mp.attachment_key = ei.image_url)
        WHERE mp.part_type = 1
          AND mp.created_at > NOW() - INTERVAL '7 days'
        "#,
    )
    .fetch_one(pool)
    .await
    .map_err(AppError::DatabaseError)?;

    Ok(Json(DashboardEmojiStats {
        total_emojis,
        today_usage,
        popular_count,
    }))
}

async fn get_online_users_count(state: &AppState) -> Result<i64, AppError> {
    // 优先使用 WebSocket 连接管理器统计实时在线用户
    let ws_count = state.connection_manager.get_online_user_count().await;

    // 如果 WebSocket 统计为 0，尝试通过最后活动时间估算（30分钟内有更新的用户）
    if ws_count == 0 {
        let pool = &state.database.pool;
        let estimated_count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM users
             WHERE deleted_at IS NULL
             AND status = 0  -- active users
             AND updated_at > NOW() - INTERVAL '30 minutes'",
        )
        .fetch_one(pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(estimated_count)
    } else {
        Ok(ws_count as i64)
    }
}

async fn get_active_rooms_count(pool: &sqlx::PgPool) -> Result<i64, sqlx::Error> {
    // 统计最近24小时内有消息的房间（更准确反映活跃状态）
    let count: i64 = sqlx::query_scalar(
        "SELECT COUNT(DISTINCT room_id) FROM messages
         WHERE deleted_at IS NULL
         AND created_at > NOW() - INTERVAL '24 hours'",
    )
    .fetch_one(pool)
    .await?;
    Ok(count)
}

async fn get_today_messages_count(pool: &sqlx::PgPool) -> Result<i64, sqlx::Error> {
    // 使用 UTC 时间，统计今天的消息（简化逻辑，避免时区转换问题）
    let count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM messages
         WHERE deleted_at IS NULL
         AND DATE(created_at) = CURRENT_DATE",
    )
    .fetch_one(pool)
    .await?;
    Ok(count)
}

use crate::utils::system::{get_memory_usage, get_system_load};

async fn get_storage_usage(_state: &AppState) -> Result<f64, AppError> {
    // 这里应该调用存储服务获取实际使用量
    // 暂时返回模拟数据
    Ok(0.28)
}

pub async fn list_active_nodes_monitor(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
) -> Result<Json<Vec<NodeMonitorInfo>>, AppError> {
    let session_manager = crate::redis::session::SessionManager::new(
        state.redis.get_session_connection(),
        state.node_id.clone(),
    );

    let nodes = session_manager.get_active_nodes().await.map_err(|e| {
        error!("获取活跃节点失败: {}", e);
        AppError::InternalError("获取节点信息失败".to_string())
    })?;

    let node_monitors = nodes
        .into_iter()
        .map(|node| NodeMonitorInfo {
            node_id: node.node_id,
            address: node.address,
            connected_users: node.connected_users,
            active_rooms: node.active_rooms,
            cpu_usage: node.cpu_usage,
            memory_usage: node.memory_usage,
            disk_usage: node.disk_usage,
            cpu_count: node.cpu_count,
            total_memory: node.total_memory,
            last_heartbeat: node.last_heartbeat.to_rfc3339(),
            started_at: node.started_at.to_rfc3339(),
        })
        .collect();

    Ok(Json(node_monitors))
}

pub async fn get_api_performance_stats(
    State(state): State<AppState>,
    Query(params): Query<ApiMetricsParams>,
    Extension(_claims): Extension<Claims>,
) -> Result<Json<ApiMetricsResponse>, AppError> {
    let session_manager = state.redis.get_session_manager(state.node_id.clone());

    let page = params.page.unwrap_or(1);
    let page_size = params.page_size.unwrap_or(10);

    let (metrics_all, total) = session_manager
        .get_api_performance_stats_paginated(1, 1000) // 先拿 Top 1000 做全局排序
        .await
        .map_err(|e| {
            error!("获取 API 性能统计失败: {}", e);
            AppError::InternalError("获取性能统计失败".to_string())
        })?;

    // 计算 Top 耗时
    let mut top_avg = metrics_all.clone();
    top_avg.sort_by(|a, b| {
        let a_val = a["avg_duration"].as_u64().unwrap_or(0);
        let b_val = b["avg_duration"].as_u64().unwrap_or(0);
        b_val.cmp(&a_val)
    });
    let top_avg = top_avg.into_iter().take(10).collect::<Vec<_>>();

    // 计算 Top 频次
    let mut top_count = metrics_all.clone();
    top_count.sort_by(|a, b| {
        let a_val = a["count"].as_u64().unwrap_or(0);
        let b_val = b["count"].as_u64().unwrap_or(0);
        b_val.cmp(&a_val)
    });
    let top_count = top_count.into_iter().take(10).collect::<Vec<_>>();

    // 执行自定义排序
    let mut metrics_to_sort = metrics_all;
    if let Some(field) = params.sort_field {
        let order = params.sort_order.unwrap_or_else(|| "descend".to_string());
        metrics_to_sort.sort_by(|a, b| {
            let (v_a, v_b) = match field.as_str() {
                "count" => (
                    a["count"].as_u64().unwrap_or(0),
                    b["count"].as_u64().unwrap_or(0),
                ),
                "avg_duration" => (
                    a["avg_duration"].as_u64().unwrap_or(0),
                    b["avg_duration"].as_u64().unwrap_or(0),
                ),
                "max_duration" => (
                    a["max_duration"].as_u64().unwrap_or(0),
                    b["max_duration"].as_u64().unwrap_or(0),
                ),
                _ => (
                    a["count"].as_u64().unwrap_or(0),
                    b["count"].as_u64().unwrap_or(0),
                ),
            };
            if order == "ascend" {
                v_a.cmp(&v_b)
            } else {
                v_b.cmp(&v_a)
            }
        });
    } else {
        // 默认按次数降序
        metrics_to_sort.sort_by(|a, b| b["count"].as_u64().cmp(&a["count"].as_u64()));
    }

    // 执行分页
    let start = (page - 1) * page_size;
    let end = (start + page_size).min(total);
    let metrics = if start < total {
        metrics_to_sort[start..end].to_vec()
    } else {
        Vec::new()
    };

    Ok(Json(ApiMetricsResponse {
        metrics,
        top_avg,
        top_count,
        total,
        page,
        page_size,
    }))
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
        Some("active") => Some(DbUserStatus::Active),
        Some("inactive") => Some(DbUserStatus::Inactive),
        Some("banned") => Some(DbUserStatus::Banned),
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
        .map(|user| AdminUserResponse {
            id: user.id.to_string(),
            username: user.username,
            email: user.email,
            nickname: user.nickname,
            avatar_url: user.avatar_url,
            status: match user.status {
                DbUserStatus::Active => "active".to_string(),
                DbUserStatus::Inactive => "inactive".to_string(),
                DbUserStatus::Banned => "banned".to_string(),
            },
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

/// 获取管理员用户列表
pub async fn get_admin_user_list(
    State(state): State<AppState>,
    Query(params): Query<AdminUserListParams>,
) -> Result<Json<AdminUserListResponse>, AppError> {
    let store = AdminUserStore::new(state.database.clone());

    let page = params.page.unwrap_or(1).max(1);
    let page_size = params.page_size.unwrap_or(20).max(1).min(100);

    let status_param = params
        .status
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let status = match status_param {
        Some("active") => Some(AdminUserStatus::Active),
        Some("inactive") => Some(AdminUserStatus::Inactive),
        Some("banned") => Some(AdminUserStatus::Banned),
        Some("locked") => Some(AdminUserStatus::Locked),
        None => None,
        Some(_) => return Err(AppError::ValidationError("无效的状态参数".to_string())),
    };

    let username = params
        .username
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());

    let (admin_users, total) = store
        .list_admin_users(page, page_size, status, username.map(|s| s.to_string()))
        .await?;

    let admin_user_infos = admin_users
        .into_iter()
        .map(|user| db_admin_user_to_api_user_info(&user))
        .collect();

    Ok(Json(AdminUserListResponse {
        users: admin_user_infos,
        total: total as usize,
        page,
        page_size,
    }))
}

pub async fn list_feedbacks(
    State(state): State<AppState>,
    Query(params): Query<FeedbackListParams>,
) -> Result<Json<FeedbackListResponse>, AppError> {
    let page = params.page.max(1);
    let page_size = params.page_size.max(1).min(100);
    let offset = (page - 1) * page_size;

    let user_id = if let Some(user_id) = params
        .user_id
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        Some(
            Uuid::parse_str(user_id)
                .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?,
        )
    } else {
        None
    };

    let keyword = params
        .keyword
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| s.to_lowercase());

    let mut list_query = QueryBuilder::<Postgres>::new(
        "SELECT f.id, f.user_id, u.username, u.nickname, f.contact, f.content, f.created_at \
         FROM feedbacks f \
         LEFT JOIN users u ON u.id = f.user_id",
    );
    apply_feedback_filters(&mut list_query, user_id, keyword.as_deref());
    list_query.push(" ORDER BY f.created_at DESC LIMIT ");
    list_query.push_bind(page_size as i64);
    list_query.push(" OFFSET ");
    list_query.push_bind(offset as i64);

    let feedback_rows = list_query
        .build_query_as::<FeedbackRow>()
        .fetch_all(&state.database.pool)
        .await
        .map_err(AppError::DatabaseError)?;

    let mut count_query = QueryBuilder::<Postgres>::new(
        "SELECT COUNT(*) AS total FROM feedbacks f LEFT JOIN users u ON u.id = f.user_id",
    );
    apply_feedback_filters(&mut count_query, user_id, keyword.as_deref());

    let total: i64 = count_query
        .build_query_scalar()
        .fetch_one(&state.database.pool)
        .await
        .map_err(AppError::DatabaseError)?;

    let feedbacks = feedback_rows
        .into_iter()
        .map(|row| FeedbackItem {
            id: row.id.to_string(),
            user_id: row.user_id.to_string(),
            username: row.username,
            nickname: row.nickname,
            contact: row.contact,
            content: row.content,
            created_at: row.created_at.to_rfc3339(),
        })
        .collect();

    Ok(Json(FeedbackListResponse {
        feedbacks,
        total,
        page,
        page_size,
    }))
}

fn apply_feedback_filters(
    builder: &mut QueryBuilder<Postgres>,
    user_id: Option<Uuid>,
    keyword: Option<&str>,
) {
    let mut has_where = false;

    if let Some(user_id) = user_id {
        builder.push(" WHERE f.user_id = ");
        builder.push_bind(user_id);
        has_where = true;
    }

    if let Some(keyword) = keyword {
        let like = format!("%{}%", keyword);
        builder.push(if has_where { " AND (" } else { " WHERE (" });
        builder.push("LOWER(f.content) LIKE ");
        builder.push_bind(like.clone());
        builder.push(" OR LOWER(COALESCE(f.contact, '')) LIKE ");
        builder.push_bind(like.clone());
        builder.push(" OR LOWER(COALESCE(u.username, '')) LIKE ");
        builder.push_bind(like.clone());
        builder.push(" OR LOWER(COALESCE(u.nickname, '')) LIKE ");
        builder.push_bind(like);
        builder.push(")");
    }
}

#[derive(Debug, FromRow)]
struct FeedbackRow {
    id: Uuid,
    user_id: Uuid,
    username: Option<String>,
    nickname: Option<String>,
    contact: Option<String>,
    content: String,
    created_at: DateTime<Utc>,
}

/// 创建管理员用户
pub async fn create_admin_user(
    State(state): State<AppState>,
    Json(request): Json<CreateAdminUserRequest>,
) -> Result<Json<AdminUserInfo>, AppError> {
    // 基础验证
    if request.username.trim().is_empty()
        || request.email.trim().is_empty()
        || request.password.trim().is_empty()
    {
        return Err(AppError::ValidationError(
            "用户名、邮箱和密码不能为空".to_string(),
        ));
    }

    if request.username.len() < 3 {
        return Err(AppError::ValidationError(
            "用户名长度至少为3个字符".to_string(),
        ));
    }

    if request.password.len() < 6 {
        return Err(AppError::ValidationError(
            "密码长度至少为6个字符".to_string(),
        ));
    }

    let store = AdminUserStore::new(state.database.clone());

    // 检查用户名是否已存在
    if store.find_by_username(&request.username).await?.is_some() {
        return Err(AppError::ValidationError("用户名已存在".to_string()));
    }

    let admin_user = store.create_admin_user(request).await?;

    // 记录操作日志
    record_admin_operation(
        &state.database,
        None, // 由系统创建，没有操作者
        "create_admin_user",
        Some("admin_user"),
        Some(admin_user.id),
        Some(serde_json::json!({
            "username": admin_user.username,
            "email": admin_user.email
        })),
        None,
        None,
    )
    .await
    .ok(); // 忽略记录失败的错误

    Ok(Json(db_admin_user_to_api_user_info(&admin_user)))
}

/// 更新管理员用户状态
pub async fn update_admin_user_status(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(admin_user_id): Path<String>,
    Json(request): Json<UpdateAdminUserStatusRequest>,
) -> Result<Json<AdminOperationResponse>, AppError> {
    let admin_user_uuid = Uuid::parse_str(&admin_user_id)
        .map_err(|_| AppError::ValidationError("无效的管理员用户ID".to_string()))?;

    let status = match request.status.as_str() {
        "active" => AdminUserStatus::Active,
        "inactive" => AdminUserStatus::Inactive,
        "banned" => AdminUserStatus::Banned,
        "locked" => AdminUserStatus::Locked,
        _ => return Err(AppError::ValidationError("无效的状态值".to_string())),
    };

    let store = AdminUserStore::new(state.database.clone());

    // 检查用户是否存在
    let admin_user = store
        .find_by_id(&admin_user_uuid)
        .await?
        .ok_or_else(|| AppError::NotFound("管理员用户不存在".to_string()))?;

    // 更新状态
    sqlx::query!(
        "UPDATE admin_users SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2",
        status as AdminUserStatus,
        admin_user_uuid
    )
    .execute(&state.database.pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    // 记录操作日志（从 JWT Claims 中解析当前管理员用户 ID）
    let operator_id = crate::models::convert::string_to_uuid(&claims.sub).ok();

    if let Err(e) = record_admin_operation(
        &state.database,
        operator_id,
        "update_admin_user_status",
        Some("admin_user"),
        Some(admin_user_uuid),
        Some(serde_json::json!({
            "old_status": admin_user.status,
            "new_status": status,
            "username": admin_user.username
        })),
        None,
        None,
    )
    .await
    {
        tracing::warn!("记录管理员操作日志失败: {:?}", e);
    }

    Ok(Json(AdminOperationResponse {
        success: true,
        message: "管理员用户状态更新成功".to_string(),
    }))
}

pub async fn get_data_statistics(
    State(state): State<AppState>,
) -> Result<Json<DataStatistics>, AppError> {
    let pool = &state.database.pool;

    // 获取最近30天的日活跃用户
    let daily_active_users = get_daily_active_users(pool, 30).await.unwrap_or_default();

    // 获取最近30天的日消息量
    let daily_messages = get_daily_messages(pool, 30).await.unwrap_or_default();

    // 获取按文件类型分类的存储使用情况（简化版本）
    let storage_usage_by_type = vec![
        StorageTypeStat {
            file_type: "图片".to_string(),
            count: 50,
            size_bytes: 512 * 1024,
            percentage: 50.0,
        },
        StorageTypeStat {
            file_type: "其他".to_string(),
            count: 50,
            size_bytes: 512 * 1024,
            percentage: 50.0,
        },
    ];

    // 计算增长率
    let user_growth_rate = calculate_user_growth_rate(pool).await.unwrap_or(0.0);
    let message_growth_rate = calculate_message_growth_rate(pool).await.unwrap_or(0.0);

    // 获取活跃峰值时间
    let peak_active_time = get_peak_active_time(pool)
        .await
        .unwrap_or("14:00".to_string());

    let stats = DataStatistics {
        daily_active_users,
        daily_messages,
        storage_usage_by_type,
        user_growth_rate,
        message_growth_rate,
        peak_active_time,
    };

    Ok(Json(stats))
}

async fn get_daily_active_users(
    pool: &sqlx::PgPool,
    _days: i64,
) -> Result<Vec<DailyStat>, sqlx::Error> {
    let rows = sqlx::query(
        r#"
        SELECT
            DATE(created_at) as date,
            COUNT(*) as count
        FROM users
        WHERE deleted_at IS NULL
        AND created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY DATE(created_at)
        ORDER BY date DESC
        "#,
    )
    .fetch_all(pool)
    .await?;

    let stats: Vec<DailyStat> = rows
        .into_iter()
        .map(|row| DailyStat {
            date: match row.try_get::<Option<NaiveDate>, _>("date") {
                Ok(Some(value)) => value.to_string(),
                _ => String::new(),
            },
            count: row.try_get::<i64, _>("count").unwrap_or(0),
        })
        .collect();

    Ok(stats)
}

async fn get_daily_messages(
    pool: &sqlx::PgPool,
    _days: i64,
) -> Result<Vec<DailyStat>, sqlx::Error> {
    let rows = sqlx::query(
        r#"
        SELECT
            DATE(created_at) as date,
            COUNT(*) as count
        FROM messages
        WHERE deleted_at IS NULL
        AND created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY DATE(created_at)
        ORDER BY date DESC
        "#,
    )
    .fetch_all(pool)
    .await?;

    let stats: Vec<DailyStat> = rows
        .into_iter()
        .map(|row| DailyStat {
            date: match row.try_get::<Option<NaiveDate>, _>("date") {
                Ok(Some(value)) => value.to_string(),
                _ => String::new(),
            },
            count: row.try_get::<i64, _>("count").unwrap_or(0),
        })
        .collect();

    Ok(stats)
}

#[allow(dead_code)]
async fn get_storage_usage_by_type(_pool: &sqlx::PgPool) -> Result<Vec<StorageTypeStat>, AppError> {
    // 这里需要根据实际的文件存储表来查询
    // 假设我们有文件记录表
    let _query = r#"
    SELECT
        CASE
            WHEN content_type LIKE 'image/%' THEN '图片'
            WHEN content_type LIKE 'audio/%' THEN '音频'
            WHEN content_type LIKE 'video/%' THEN '视频'
            WHEN content_type = 'application/pdf' THEN 'PDF文档'
            ELSE '其他'
        END as file_type,
        COUNT(*) as count,
        COALESCE(SUM(file_size), 0) as size_bytes
    FROM message_parts
    WHERE object_key IS NOT NULL
    AND deleted_at IS NULL
    GROUP BY
        CASE
            WHEN content_type LIKE 'image/%' THEN '图片'
            WHEN content_type LIKE 'audio/%' THEN '音频'
            WHEN content_type LIKE 'video/%' THEN '视频'
            WHEN content_type = 'application/pdf' THEN 'PDF文档'
            ELSE '其他'
        END
    ORDER BY size_bytes DESC
    "#;

    // 简化版本，返回模拟统计数据
    let _total_size = 1024 * 1024; // 1MB

    let stats = vec![
        StorageTypeStat {
            file_type: "图片".to_string(),
            count: 100,
            size_bytes: 500 * 1024,
            percentage: 50.0,
        },
        StorageTypeStat {
            file_type: "文档".to_string(),
            count: 50,
            size_bytes: 300 * 1024,
            percentage: 30.0,
        },
        StorageTypeStat {
            file_type: "其他".to_string(),
            count: 30,
            size_bytes: 224 * 1024,
            percentage: 20.0,
        },
    ];

    Ok(stats)
}

async fn calculate_user_growth_rate(pool: &sqlx::PgPool) -> Result<f64, sqlx::Error> {
    // 计算最近30天相对于之前30天的用户增长率
    let recent_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM users
         WHERE deleted_at IS NULL
         AND created_at >= CURRENT_DATE - INTERVAL '30 days'",
    )
    .fetch_one(pool)
    .await?;

    let previous_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM users
         WHERE deleted_at IS NULL
         AND created_at BETWEEN CURRENT_DATE - INTERVAL '60 days' AND CURRENT_DATE - INTERVAL '30 days'"
    )
    .fetch_one(pool)
    .await?;

    if previous_count == 0 {
        Ok(0.0)
    } else {
        Ok(((recent_count - previous_count) as f64) / (previous_count as f64) * 100.0)
    }
}

async fn calculate_message_growth_rate(pool: &sqlx::PgPool) -> Result<f64, sqlx::Error> {
    // 计算最近7天相对于之前7天的消息增长率
    let recent_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM messages
         WHERE deleted_at IS NULL
         AND created_at >= CURRENT_DATE - INTERVAL '7 days'",
    )
    .fetch_one(pool)
    .await?;

    let previous_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM messages
         WHERE deleted_at IS NULL
         AND created_at BETWEEN CURRENT_DATE - INTERVAL '14 days' AND CURRENT_DATE - INTERVAL '7 days'"
    )
    .fetch_one(pool)
    .await?;

    if previous_count == 0 {
        Ok(0.0)
    } else {
        Ok(((recent_count - previous_count) as f64) / (previous_count as f64) * 100.0)
    }
}

async fn get_peak_active_time(pool: &sqlx::PgPool) -> Result<String, sqlx::Error> {
    // 找出一天中活跃用户最多的时间段
    let row = sqlx::query(
        r#"
        SELECT
            EXTRACT(HOUR FROM created_at) as hour,
            COUNT(*) as count
        FROM users
        WHERE deleted_at IS NULL
        AND created_at >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY EXTRACT(HOUR FROM created_at)
        ORDER BY count DESC
        LIMIT 1
        "#,
    )
    .fetch_optional(pool)
    .await?;

    if let Some(row) = row {
        let hour_value = row.try_get::<Option<f64>, _>("hour").unwrap_or(None);
        let hour: i32 = hour_value
            .map(|value| value.round() as i32)
            .unwrap_or(14)
            .rem_euclid(24);
        return Ok(format!("{:02}:00", hour));
    }

    Ok("14:00".to_string())
}

/// 获取用户详细信息
pub async fn get_user_detail(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
) -> Result<Json<UserDetail>, AppError> {
    let user_id = Uuid::parse_str(&user_id)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;

    let pool = &state.database.pool;

    // 获取用户基本信息
    let user = sqlx::query_as::<_, UserBasicInfoRow>(
        r#"
        SELECT
            id, username, email, nickname, avatar_url, status,
            created_at, updated_at, deleted_at
        FROM users
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?
    .ok_or_else(|| AppError::NotFound("用户不存在".to_string()))?;

    // 获取用户统计信息
    let message_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM messages WHERE sender_id = $1 AND deleted_at IS NULL",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    let room_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM room_members WHERE user_id = $1 AND deleted_at IS NULL",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    // 统计用户发送消息所产生的附件存储占用（近似：按 message_parts.attachment_size 汇总）
    let storage_usage: i64 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(SUM(mp.attachment_size), 0)::bigint
        FROM message_parts mp
        INNER JOIN messages m ON mp.message_id = m.id
        WHERE m.sender_id = $1
          AND m.deleted_at IS NULL
          AND mp.attachment_key IS NOT NULL
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    let user_detail = UserDetail {
        id: user.id.to_string(),
        username: user.username,
        email: user.email,
        nickname: user.nickname,
        avatar_url: user.avatar_url,
        status: user.status.to_string(),
        created_at: user.created_at.to_rfc3339(),
        updated_at: user.updated_at.to_rfc3339(),
        deleted_at: user.deleted_at.map(|dt| dt.to_rfc3339()),
        last_login_at: Some(user.updated_at.to_rfc3339()), // 简化处理，使用更新时间
        message_count,
        room_count,
        storage_usage,
    };

    Ok(Json(user_detail))
}

/// 创建用户
pub async fn create_user(
    State(state): State<AppState>,
    Json(req): Json<CreateUserRequest>,
) -> Result<Json<UserOperationResponse>, AppError> {
    // 验证用户名
    if req.username.len() < 3 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "用户名长度至少3位".to_string(),
        }));
    }

    // 验证密码
    if req.password.len() < 6 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "密码长度至少6位".to_string(),
        }));
    }

    // 验证邮箱格式
    if !req.email.contains('@') {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "邮箱格式不正确".to_string(),
        }));
    }

    let pool = &state.database.pool;

    // 检查用户名是否已存在
    let existing_username: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE username = $1 AND deleted_at IS NULL")
            .bind(&req.username)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

    if existing_username > 0 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "用户名已存在".to_string(),
        }));
    }

    // 检查邮箱是否已存在
    let existing_email: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE email = $1 AND deleted_at IS NULL")
            .bind(&req.email)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

    if existing_email > 0 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "邮箱已被注册".to_string(),
        }));
    }

    // 密码加密
    let password_hash = hash_password(&req.password)
        .map_err(|_| AppError::InternalError("密码加密失败".to_string()))?;

    // 创建用户
    let user_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO users (id, username, email, password_hash, nickname, status, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, 0, NOW(), NOW())
        "#,
    )
    .bind(user_id)
    .bind(&req.username)
    .bind(&req.email)
    .bind(&password_hash)
    .bind(&req.nickname)
    .execute(pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    info!("Admin created user: {} ({})", req.username, user_id);

    Ok(Json(UserOperationResponse {
        success: true,
        message: format!("用户创建成功，ID: {}", user_id),
    }))
}

/// 更新用户信息
pub async fn update_user(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
    Json(req): Json<UpdateUserRequest>,
) -> Result<Json<UserOperationResponse>, AppError> {
    let user_id = Uuid::parse_str(&user_id)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;

    let pool = &state.database.pool;

    // 检查用户是否存在
    let existing_user: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE id = $1 AND deleted_at IS NULL")
            .bind(user_id)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

    if existing_user == 0 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "用户不存在".to_string(),
        }));
    }

    // 如果更新邮箱，检查邮箱是否已存在
    if let Some(ref email) = req.email {
        if !email.trim().is_empty() {
            let existing_email: i64 = sqlx::query_scalar(
                "SELECT COUNT(*) FROM users WHERE email = $1 AND id != $2 AND deleted_at IS NULL",
            )
            .bind(email.trim())
            .bind(user_id)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

            if existing_email > 0 {
                return Ok(Json(UserOperationResponse {
                    success: false,
                    message: "邮箱已被其他用户使用".to_string(),
                }));
            }
        }
    }

    // 构建更新SQL（按类型 bind，避免 smallint/timestamptz 被错误按 String 绑定）
    let mut query_builder = QueryBuilder::<Postgres>::new("UPDATE users SET ");
    let mut has_updates = false;

    if let Some(email) = &req.email {
        let trimmed = email.trim();
        if !trimmed.is_empty() {
            if has_updates {
                query_builder.push(", ");
            }
            query_builder.push("email = ").push_bind(trimmed);
            has_updates = true;
        }
    }

    if let Some(nickname) = &req.nickname {
        let trimmed = nickname.trim();
        if !trimmed.is_empty() {
            if has_updates {
                query_builder.push(", ");
            }
            query_builder.push("nickname = ").push_bind(trimmed);
            has_updates = true;
        }
    }

    if let Some(status) = &req.status {
        let status_value: i16 = match status.as_str() {
            "active" => DbUserStatus::Active as i16,
            "inactive" => DbUserStatus::Inactive as i16,
            "banned" => DbUserStatus::Banned as i16,
            _ => {
                return Ok(Json(UserOperationResponse {
                    success: false,
                    message: "无效的用户状态".to_string(),
                }));
            }
        };

        if has_updates {
            query_builder.push(", ");
        }
        query_builder.push("status = ").push_bind(status_value);
        has_updates = true;
    }

    if !has_updates {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "没有提供要更新的字段".to_string(),
        }));
    }

    query_builder.push(", updated_at = NOW()");
    query_builder.push(" WHERE id = ").push_bind(user_id);

    query_builder
        .build()
        .execute(pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

    Ok(Json(UserOperationResponse {
        success: true,
        message: "用户信息更新成功".to_string(),
    }))
}

/// 重置用户密码
pub async fn reset_user_password(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
    Json(req): Json<ResetPasswordRequest>,
) -> Result<Json<UserOperationResponse>, AppError> {
    let user_id = Uuid::parse_str(&user_id)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;

    if req.new_password.len() < 6 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "密码长度至少6位".to_string(),
        }));
    }

    let pool = &state.database.pool;

    // 检查用户是否存在
    let existing_user: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE id = $1 AND deleted_at IS NULL")
            .bind(user_id)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

    if existing_user == 0 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "用户不存在".to_string(),
        }));
    }

    // 密码加密
    let password_hash = hash_password(&req.new_password)
        .map_err(|_| AppError::InternalError("密码加密失败".to_string()))?;

    // 更新密码
    let result = sqlx::query(
        "UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL",
    )
    .bind(&password_hash)
    .bind(user_id)
    .execute(pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    if result.rows_affected() == 0 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "密码更新失败".to_string(),
        }));
    }

    info!("Admin reset password for user: {}", user_id);

    Ok(Json(UserOperationResponse {
        success: true,
        message: "密码重置成功".to_string(),
    }))
}

/// 删除用户
pub async fn delete_user(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
) -> Result<Json<UserOperationResponse>, AppError> {
    let user_id = Uuid::parse_str(&user_id)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;

    let pool = &state.database.pool;

    // 软删除用户
    let result =
        sqlx::query("UPDATE users SET deleted_at = $1 WHERE id = $2 AND deleted_at IS NULL")
            .bind(chrono::Utc::now())
            .bind(user_id)
            .execute(pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

    if result.rows_affected() == 0 {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "用户不存在或已被删除".to_string(),
        }));
    }

    Ok(Json(UserOperationResponse {
        success: true,
        message: "用户删除成功".to_string(),
    }))
}

// ========== 权限管理 API ==========

/// 获取所有权限列表
pub async fn get_permissions(
    State(state): State<AppState>,
) -> Result<Json<PermissionListResponse>, AppError> {
    let store = AdminRbacStore::new(state.database.clone());
    let permissions = store
        .list_permissions()
        .await?
        .into_iter()
        .map(PermissionResponse::from)
        .collect();

    Ok(Json(PermissionListResponse { permissions }))
}

/// 获取所有角色列表
pub async fn get_roles(State(state): State<AppState>) -> Result<Json<RoleListResponse>, AppError> {
    let store = AdminRbacStore::new(state.database.clone());
    let roles = store
        .list_roles_with_permissions()
        .await?
        .into_iter()
        .map(|(role, permissions)| role_with_permissions_to_response(role, permissions))
        .collect();

    Ok(Json(RoleListResponse { roles }))
}

/// 创建角色
pub async fn create_role(
    State(state): State<AppState>,
    Json(req): Json<CreateRoleRequest>,
) -> Result<Json<RoleResponse>, AppError> {
    if req.name.trim().is_empty() {
        return Err(AppError::ValidationError("角色名称不能为空".to_string()));
    }

    if req.code.trim().is_empty() {
        return Err(AppError::ValidationError("角色代码不能为空".to_string()));
    }

    let permission_ids = parse_uuid_list(&req.permission_ids, "权限ID")?;
    let store = AdminRbacStore::new(state.database.clone());
    let (role, permissions) = store
        .create_role(
            req.name.trim(),
            req.code.trim(),
            req.description
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty()),
            &permission_ids,
        )
        .await?;

    Ok(Json(role_with_permissions_to_response(role, permissions)))
}

/// 更新角色
pub async fn update_role(
    State(state): State<AppState>,
    Path(role_id): Path<String>,
    Json(req): Json<UpdateRoleRequest>,
) -> Result<Json<RoleResponse>, AppError> {
    let role_id = Uuid::parse_str(role_id.trim())
        .map_err(|_| AppError::ValidationError("无效的角色ID".to_string()))?;

    let permission_ids = req
        .permission_ids
        .as_ref()
        .map(|ids| parse_uuid_list(ids, "权限ID"))
        .transpose()?;

    let description = if let Some(description) = req.description.as_ref() {
        let trimmed = description.trim();
        Some(if trimmed.is_empty() {
            None
        } else {
            Some(trimmed)
        })
    } else {
        None
    };

    let store = AdminRbacStore::new(state.database.clone());
    let (role, permissions) = store
        .update_role(
            &role_id,
            req.name
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty()),
            description,
            permission_ids,
        )
        .await?;

    Ok(Json(role_with_permissions_to_response(role, permissions)))
}

/// 获取角色权限分配
pub async fn get_role_permissions(
    State(state): State<AppState>,
    Path(role_id): Path<String>,
) -> Result<Json<RolePermissionAssignmentResponse>, AppError> {
    let role_id = Uuid::parse_str(role_id.trim())
        .map_err(|_| AppError::ValidationError("无效的角色ID".to_string()))?;
    let store = AdminRbacStore::new(state.database.clone());
    let permission_ids = store.get_role_permission_ids(&role_id).await?;
    let permissions = store.list_permissions().await?;
    let permission_codes = permissions
        .into_iter()
        .filter(|permission| permission_ids.iter().any(|id| id == &permission.id))
        .map(|permission| permission.code)
        .collect();

    Ok(Json(RolePermissionAssignmentResponse {
        role_id: role_id.to_string(),
        permission_ids: permission_ids
            .into_iter()
            .map(|id| id.to_string())
            .collect(),
        permission_codes,
    }))
}

/// 更新角色权限分配
pub async fn update_role_permissions(
    State(state): State<AppState>,
    Path(role_id): Path<String>,
    Json(req): Json<UpdateRolePermissionsRequest>,
) -> Result<Json<RolePermissionAssignmentResponse>, AppError> {
    let role_id = Uuid::parse_str(role_id.trim())
        .map_err(|_| AppError::ValidationError("无效的角色ID".to_string()))?;
    let permission_ids = parse_uuid_list(&req.permission_ids, "权限ID")?;
    let store = AdminRbacStore::new(state.database.clone());
    let permissions = store
        .update_role_permissions(&role_id, &permission_ids)
        .await?;

    Ok(Json(RolePermissionAssignmentResponse {
        role_id: role_id.to_string(),
        permission_ids: permission_ids
            .into_iter()
            .map(|id| id.to_string())
            .collect(),
        permission_codes: permissions
            .into_iter()
            .map(|permission| permission.code)
            .collect(),
    }))
}

/// 获取管理员角色分配
pub async fn get_admin_user_roles(
    State(state): State<AppState>,
    Path(admin_user_id): Path<String>,
) -> Result<Json<AdminUserRoleAssignmentResponse>, AppError> {
    let admin_user_id = Uuid::parse_str(admin_user_id.trim())
        .map_err(|_| AppError::ValidationError("无效的管理员用户ID".to_string()))?;
    let store = AdminRbacStore::new(state.database.clone());
    let role_ids = store.get_admin_user_role_ids(&admin_user_id).await?;
    let roles = store.list_roles_with_permissions().await?;
    let role_codes = roles
        .into_iter()
        .filter(|(role, _)| role_ids.iter().any(|id| id == &role.id))
        .map(|(role, _)| role.code)
        .collect();

    Ok(Json(AdminUserRoleAssignmentResponse {
        admin_user_id: admin_user_id.to_string(),
        role_ids: role_ids.into_iter().map(|id| id.to_string()).collect(),
        role_codes,
    }))
}

/// 更新管理员角色分配
pub async fn update_admin_user_roles(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Path(admin_user_id): Path<String>,
    Json(req): Json<UpdateAdminUserRolesRequest>,
) -> Result<Json<AdminUserRoleAssignmentResponse>, AppError> {
    let admin_user_id = Uuid::parse_str(admin_user_id.trim())
        .map_err(|_| AppError::ValidationError("无效的管理员用户ID".to_string()))?;
    let operator_id = crate::models::convert::string_to_uuid(&claims.sub).ok();
    let role_ids = parse_uuid_list(&req.role_ids, "角色ID")?;
    let store = AdminRbacStore::new(state.database.clone());
    let assigned_role_ids = store
        .update_admin_user_roles(&admin_user_id, &role_ids, operator_id.as_ref())
        .await?;
    let roles = store.list_roles_with_permissions().await?;
    let role_codes = roles
        .into_iter()
        .filter(|(role, _)| assigned_role_ids.iter().any(|id| id == &role.id))
        .map(|(role, _)| role.code)
        .collect();

    Ok(Json(AdminUserRoleAssignmentResponse {
        admin_user_id: admin_user_id.to_string(),
        role_ids: assigned_role_ids
            .into_iter()
            .map(|id| id.to_string())
            .collect(),
        role_codes,
    }))
}

/// 删除角色
pub async fn delete_role(
    State(state): State<AppState>,
    Path(role_id): Path<String>,
) -> Result<Json<RoleOperationResponse>, AppError> {
    let role_id = Uuid::parse_str(role_id.trim())
        .map_err(|_| AppError::ValidationError("无效的角色ID".to_string()))?;
    let store = AdminRbacStore::new(state.database.clone());
    let deleted = store.delete_role(&role_id).await?;

    if !deleted {
        return Ok(Json(RoleOperationResponse {
            success: false,
            message: "角色删除失败".to_string(),
        }));
    }

    Ok(Json(RoleOperationResponse {
        success: true,
        message: "角色删除成功".to_string(),
    }))
}

/// 检查用户权限
pub async fn check_user_permission(
    State(state): State<AppState>,
    Json(req): Json<CheckPermissionRequest>,
) -> Result<Json<CheckPermissionResponse>, AppError> {
    let user_id = Uuid::parse_str(req.user_id.trim())
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;
    let store = AdminRbacStore::new(state.database.clone());
    let has_permission = store
        .has_admin_permission(&user_id, req.permission_code.trim())
        .await?;

    Ok(Json(CheckPermissionResponse { has_permission }))
}

#[derive(Debug, Serialize)]
pub struct RoleOperationResponse {
    pub success: bool,
    pub message: String,
}

// ========== 文件管理和存储统计相关数据结构 ==========

#[derive(Debug, Serialize)]
pub struct FileManagementStats {
    pub total_files: i64,
    pub total_size_bytes: i64,
    pub total_size_gb: f64,
    pub files_by_type: Vec<FileTypeStats>,
    pub files_by_date: Vec<FileDateStats>,
    pub largest_files: Vec<FileItem>,
    pub recent_files: Vec<FileItem>,
    pub storage_usage_by_user: Vec<UserStorageStats>,
    pub storage_growth_trend: Vec<StorageGrowthData>,
}

#[derive(Debug, Serialize)]
pub struct FileTypeStats {
    pub file_type: String,
    pub count: i64,
    pub size_bytes: i64,
    pub percentage: f64,
}

#[derive(Debug, Serialize)]
pub struct FileDateStats {
    pub date: String,
    pub count: i64,
    pub size_bytes: i64,
}

#[derive(Debug, Serialize)]
pub struct FileItem {
    pub id: String,
    pub object_key: String,
    pub original_name: Option<String>,
    pub mime_type: Option<String>,
    pub size_bytes: Option<i64>,
    pub created_at: String,
    pub user_id: String,
    pub username: String,
    pub room_id: Option<String>,
    pub room_name: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct UserStorageStats {
    pub user_id: String,
    pub username: String,
    pub nickname: Option<String>,
    pub file_count: i64,
    pub size_bytes: i64,
    pub last_upload_at: String,
}

#[derive(Debug, Serialize)]
pub struct StorageGrowthData {
    pub date: String,
    pub size_bytes: i64,
    pub file_count: i64,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct FileListParams {
    #[serde(default = "default_page")]
    pub page: usize,
    #[serde(default = "default_page_size", alias = "pageSize")]
    pub page_size: usize,
    pub file_type: Option<String>,
    pub user_id: Option<String>,
    pub room_id: Option<String>,
    pub date_from: Option<String>,
    pub date_to: Option<String>,
    pub search: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct FileListResponse {
    pub files: Vec<FileItem>,
    pub total: usize,
    pub page: usize,
    pub page_size: usize,
    pub total_size_bytes: i64,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct DeleteFileRequest {
    pub force: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct FileOperationResponse {
    pub success: bool,
    pub message: String,
    pub deleted_count: Option<usize>,
}

// ========== 文件管理和存储统计 API ==========

/// 获取文件管理和存储统计数据（简化版本）
pub async fn get_file_management_stats(
    State(state): State<AppState>,
) -> Result<Json<FileManagementStats>, AppError> {
    let pool = &state.database.pool;

    // 获取总体统计
    let total_files: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM message_parts WHERE attachment_key IS NOT NULL")
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

    // 注意：SUM(bigint) 在 PostgreSQL 中返回 numeric（避免溢出），需要显式 cast 才能被 sqlx 解码为 i64。
    let total_size_bytes: i64 = sqlx::query_scalar(
        "SELECT COALESCE(SUM(attachment_size), 0)::BIGINT FROM message_parts WHERE attachment_key IS NOT NULL"
    )
    .fetch_one(pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    // 简化版本，返回模拟统计数据
    let stats = FileManagementStats {
        total_files,
        total_size_bytes,
        total_size_gb: (total_size_bytes as f64) / (1024.0 * 1024.0 * 1024.0),
        files_by_type: vec![
            FileTypeStats {
                file_type: "图片".to_string(),
                count: total_files / 2,
                size_bytes: total_size_bytes / 2,
                percentage: 50.0,
            },
            FileTypeStats {
                file_type: "其他".to_string(),
                count: total_files / 2,
                size_bytes: total_size_bytes / 2,
                percentage: 50.0,
            },
        ],
        files_by_date: vec![],
        largest_files: vec![],
        recent_files: vec![],
        storage_usage_by_user: vec![],
        storage_growth_trend: vec![],
    };

    Ok(Json(stats))
}

/// 获取文件列表（简化版本）
pub async fn get_file_list(
    State(state): State<AppState>,
    Query(params): Query<FileListParams>,
) -> Result<Json<FileListResponse>, AppError> {
    let _pool = &state.database.pool;

    let page = params.page.max(1);
    let page_size = params.page_size.max(1).min(100);

    // 简化版本，返回模拟数据
    let files = vec![FileItem {
        id: "1".to_string(),
        object_key: "attachments/test.jpg".to_string(),
        original_name: Some("test.jpg".to_string()),
        mime_type: Some("image/jpeg".to_string()),
        size_bytes: Some(1024),
        created_at: chrono::Utc::now().to_rfc3339(),
        user_id: "1".to_string(),
        username: "admin".to_string(),
        room_id: Some("1".to_string()),
        room_name: Some("测试房间".to_string()),
    }];

    Ok(Json(FileListResponse {
        files,
        total: 1,
        page,
        page_size,
        total_size_bytes: 1024,
    }))
}

/// 删除文件（简化版本）
pub async fn delete_file(
    State(_state): State<AppState>,
    Path(file_id): Path<String>,
    Json(_req): Json<DeleteFileRequest>,
) -> Result<Json<FileOperationResponse>, AppError> {
    // 简化版本，仅返回成功消息
    if file_id.is_empty() {
        return Ok(Json(FileOperationResponse {
            success: false,
            message: "文件ID不能为空".to_string(),
            deleted_count: None,
        }));
    }

    Ok(Json(FileOperationResponse {
        success: true,
        message: "文件删除成功（简化版本）".to_string(),
        deleted_count: Some(1),
    }))
}

/// 批量删除文件（简化版本）
pub async fn delete_files_batch(
    State(_state): State<AppState>,
    Json(file_ids): Json<Vec<String>>,
) -> Result<Json<FileOperationResponse>, AppError> {
    if file_ids.is_empty() {
        return Ok(Json(FileOperationResponse {
            success: false,
            message: "请提供要删除的文件ID列表".to_string(),
            deleted_count: Some(0),
        }));
    }

    Ok(Json(FileOperationResponse {
        success: true,
        message: format!("成功删除 {} 个文件（简化版本）", file_ids.len()),
        deleted_count: Some(file_ids.len()),
    }))
}

/// 更新用户状态
pub async fn update_user_status(
    State(state): State<AppState>,
    Path(user_id): Path<String>,
    Json(req): Json<UpdateUserStatusRequest>,
) -> Result<(), StatusCode> {
    info!(
        "收到更新用户状态请求: user_id={}, status={}",
        user_id, req.status
    );

    let user_id = Uuid::parse_str(&user_id).map_err(|e| {
        error!("无效的用户ID格式: {}, 错误: {}", user_id, e);
        StatusCode::BAD_REQUEST
    })?;

    let status = match req.status.as_str() {
        "active" => {
            info!("设置用户状态为: active");
            DbUserStatus::Active
        }
        "inactive" => {
            info!("设置用户状态为: inactive");
            DbUserStatus::Inactive
        }
        "banned" => {
            info!("设置用户状态为: banned");
            DbUserStatus::Banned
        }
        _ => {
            error!("无效的用户状态: {}", req.status);
            return Err(StatusCode::BAD_REQUEST);
        }
    };

    let store = UserStore::new(state.database.clone());

    // 获取用户当前状态用于日志和推送
    info!("获取用户当前状态...");
    let old_user = store
        .find_by_id_any_status(&user_id)
        .await
        .map_err(|e| {
            error!("查询用户失败: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?
        .ok_or_else(|| {
            error!("用户不存在: {}", user_id);
            StatusCode::NOT_FOUND
        })?;

    info!("用户当前状态: {:?}", old_user.status);

    info!("更新用户状态...");
    let updated = store
        .update_user_status(&user_id, status)
        .await
        .map_err(|e| {
            error!("更新用户状态失败: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    if !updated {
        error!("用户状态更新失败，可能用户不存在: {}", user_id);
        return Err(StatusCode::NOT_FOUND);
    }

    info!("用户状态更新成功: {} -> {:?}", user_id, status);

    // 如果用户被封禁，向其所有客户端发送封禁通知
    if status == DbUserStatus::Banned && old_user.status != DbUserStatus::Banned {
        let ban_push = crate::websocket::ServerPush::UserBanned {
            user_id: user_id.to_string(),
            reason: "管理员封禁".to_string(),
        };

        state
            .connection_manager
            .send_to_user(&user_id.to_string(), ban_push)
            .await;

        tracing::info!("用户 {} 已被封禁，已向其所有客户端发送通知", user_id);
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
    pub require_captcha_for_login: Option<bool>,
}

pub async fn update_captcha_setting(
    State(state): State<AppState>,
    Json(req): Json<UpdateCaptchaSettingRequest>,
) -> Result<Json<CaptchaSetting>, StatusCode> {
    let store = SettingsStore::new(state.database.clone());

    let enabled = req.enabled.unwrap_or(false);
    let captcha_code = req.captcha_code.unwrap_or_default().trim().to_string();
    let description = req.description.unwrap_or_default();

    let require_captcha_for_login = req.require_captcha_for_login.unwrap_or(false);
    let setting = store
        .upsert_captcha_setting(
            enabled,
            &captcha_code,
            &description,
            require_captcha_for_login,
            None,
        )
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

// ========== 文件上传提供商管理 API ==========

#[derive(Debug, Serialize)]
pub struct StorageProviderResponse {
    pub id: String,
    pub provider_type: String,
    pub name: String,
    pub secret_id: String,
    pub secret_key: String,
    pub secret_id_configured: bool,
    pub secret_key_configured: bool,
    pub region: String,
    pub endpoint: String,
    pub bucket_name: Option<String>,
    pub is_active: bool,
    pub is_default: bool,
    pub description: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub updated_by: Option<String>,
}

impl From<StorageProvider> for StorageProviderResponse {
    fn from(provider: StorageProvider) -> Self {
        let secret_id_configured = !provider.secret_id.trim().is_empty();
        let secret_key_configured = !provider.secret_key.trim().is_empty();
        Self {
            id: provider.id.to_string(),
            provider_type: provider.provider_type.to_string(),
            name: provider.name,
            secret_id: String::new(),
            secret_key: String::new(),
            secret_id_configured,
            secret_key_configured,
            region: provider.region,
            endpoint: provider.endpoint,
            bucket_name: provider.bucket_name,
            is_active: provider.is_active,
            is_default: provider.is_default,
            description: provider.description,
            created_at: provider.created_at.to_rfc3339(),
            updated_at: provider.updated_at.to_rfc3339(),
            updated_by: provider.updated_by.map(|u| u.to_string()),
        }
    }
}

#[derive(Debug, Serialize)]
pub struct StorageProviderListResponse {
    pub providers: Vec<StorageProviderResponse>,
}

/// 获取所有文件上传提供商配置
pub async fn list_storage_providers(
    State(state): State<AppState>,
) -> Result<Json<StorageProviderListResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());
    let providers = store.list_providers().await?;

    let responses: Vec<StorageProviderResponse> = providers.into_iter().map(Into::into).collect();

    Ok(Json(StorageProviderListResponse {
        providers: responses,
    }))
}

#[derive(Debug, Deserialize)]
pub struct CreateStorageProviderRequest {
    pub provider_type: String,
    pub name: String,
    pub secret_id: String,
    pub secret_key: String,
    pub region: String,
    pub endpoint: String,
    pub bucket_name: Option<String>,
    pub is_active: Option<bool>,
    pub is_default: Option<bool>,
    pub description: Option<String>,
}

/// 创建文件上传提供商配置
pub async fn create_storage_provider(
    State(state): State<AppState>,
    Extension(claims): Extension<crate::models::Claims>,
    Json(req): Json<CreateStorageProviderRequest>,
) -> Result<Json<StorageProviderResponse>, AppError> {
    // 验证必填字段
    if req.name.trim().is_empty() {
        return Err(AppError::ValidationError("提供商名称不能为空".to_string()));
    }
    if req.secret_id.trim().is_empty() {
        return Err(AppError::ValidationError("密钥ID不能为空".to_string()));
    }
    if req.secret_key.trim().is_empty() {
        return Err(AppError::ValidationError("密钥Key不能为空".to_string()));
    }
    if req.region.trim().is_empty() {
        return Err(AppError::ValidationError("地域不能为空".to_string()));
    }
    if req.endpoint.trim().is_empty() {
        return Err(AppError::ValidationError("端点域名不能为空".to_string()));
    }

    // 解析提供商类型
    let provider_type = match req.provider_type.as_str() {
        "s3_compatible" | "backblaze_b2" => StorageProviderType::S3Compatible,
        _ => {
            return Err(AppError::ValidationError(format!(
                "当前仅支持 S3 兼容对象存储，收到: {}",
                req.provider_type
            )));
        }
    };

    let updated_by = Uuid::parse_str(&claims.sub).ok();

    let store = StorageProviderStore::new(state.database.clone());

    // 统一清理 bucket_name，空字符串视为未提供
    let bucket_name = req
        .bucket_name
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string);

    if provider_type == StorageProviderType::S3Compatible && bucket_name.is_none() {
        return Err(AppError::ValidationError(
            "S3 兼容对象存储需要配置 bucket_name".to_string(),
        ));
    }

    let provider = store
        .create_provider(
            provider_type,
            req.name.trim(),
            req.secret_id.trim(),
            req.secret_key.trim(),
            req.region.trim(),
            req.endpoint.trim(),
            bucket_name.as_deref(),
            req.is_active.unwrap_or(false),
            req.is_default.unwrap_or(false),
            req.description.as_deref(),
            updated_by,
        )
        .await?;

    Ok(Json(provider.into()))
}

#[derive(Debug, Deserialize)]
pub struct UpdateStorageProviderRequest {
    pub provider_type: Option<String>,
    pub name: Option<String>,
    pub secret_id: Option<String>,
    pub secret_key: Option<String>,
    pub region: Option<String>,
    pub endpoint: Option<String>,
    pub bucket_name: Option<Option<String>>,
    pub is_active: Option<bool>,
    pub is_default: Option<bool>,
    pub description: Option<Option<String>>,
}

/// 更新文件上传提供商配置
pub async fn update_storage_provider(
    State(state): State<AppState>,
    Path(provider_id): Path<String>,
    Extension(claims): Extension<crate::models::Claims>,
    Json(req): Json<UpdateStorageProviderRequest>,
) -> Result<Json<StorageProviderResponse>, AppError> {
    let provider_id = Uuid::parse_str(&provider_id)
        .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;

    let updated_by = Uuid::parse_str(&claims.sub).ok();

    // 解析提供商类型（如果提供）
    let provider_type = if let Some(ref pt) = req.provider_type {
        match pt.as_str() {
            "s3_compatible" | "backblaze_b2" => Some(StorageProviderType::S3Compatible),
            _ => {
                return Err(AppError::ValidationError(format!(
                    "当前仅支持 S3 兼容对象存储，收到: {}",
                    pt
                )));
            }
        }
    } else {
        None
    };

    let name = req
        .name
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let secret_id = req
        .secret_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let secret_key = req
        .secret_key
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let region = req
        .region
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let endpoint = req
        .endpoint
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let bucket_name = req.bucket_name.as_ref().map(|value| {
        value
            .as_deref()
            .map(str::trim)
            .filter(|bucket_name| !bucket_name.is_empty())
    });
    let bucket_name_cleared = matches!(req.bucket_name.as_ref(), Some(None))
        || matches!(req.bucket_name.as_ref(), Some(Some(value)) if value.trim().is_empty());
    let description = req.description.as_ref().map(|value| {
        value
            .as_deref()
            .map(str::trim)
            .filter(|description| !description.is_empty())
    });

    let store = StorageProviderStore::new(state.database.clone());
    let existing_provider = store
        .get_provider_by_id(&provider_id)
        .await?
        .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?;
    let effective_provider_type = provider_type.unwrap_or(existing_provider.provider_type);
    let effective_bucket_name = if bucket_name_cleared {
        None
    } else {
        bucket_name
            .as_ref()
            .and_then(|value| value.as_deref())
            .or(existing_provider.bucket_name.as_deref())
    };

    if effective_provider_type == StorageProviderType::S3Compatible
        && effective_bucket_name
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .is_none()
    {
        return Err(AppError::ValidationError(
            "S3 兼容对象存储需要配置 bucket_name".to_string(),
        ));
    }

    let provider = store
        .update_provider(
            &provider_id,
            provider_type,
            name,
            secret_id,
            secret_key,
            region,
            endpoint,
            bucket_name,
            req.is_active,
            req.is_default,
            description,
            updated_by,
        )
        .await?;

    match provider {
        Some(p) => Ok(Json(p.into())),
        None => Err(AppError::NotFound("提供商配置不存在".to_string())),
    }
}

/// 删除文件上传提供商配置
pub async fn delete_storage_provider(
    State(state): State<AppState>,
    Path(provider_id): Path<String>,
) -> Result<StatusCode, AppError> {
    let provider_id = Uuid::parse_str(&provider_id)
        .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;

    let store = StorageProviderStore::new(state.database.clone());
    let deleted = store.delete_provider(&provider_id).await?;

    if deleted {
        Ok(StatusCode::NO_CONTENT)
    } else {
        Err(AppError::NotFound("提供商配置不存在".to_string()))
    }
}

/// 获取默认文件上传提供商配置
pub async fn get_default_storage_provider(
    State(state): State<AppState>,
) -> Result<Json<StorageProviderResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());
    let provider = store.get_default_provider().await?;

    match provider {
        Some(p) => Ok(Json(p.into())),
        None => Err(AppError::NotFound(
            "未找到默认文件上传提供商配置".to_string(),
        )),
    }
}

// ========== 对象存储测试 API ==========

#[derive(Debug, Deserialize)]
pub struct TestStorageUploadRequest {
    pub provider_id: Option<String>,
    pub key: String,
    pub content: Option<String>,
    pub file_base64: Option<String>,
    pub content_type: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TestStorageUploadResponse {
    pub success: bool,
    pub url: Option<String>,
    pub message: String,
}

#[derive(Debug, Deserialize)]
pub struct TestStorageUploadSignatureRequest {
    pub provider_id: Option<String>,
    pub key: String,
    pub content_type: Option<String>,
    /// 文件大小（字节，可选）
    pub file_size: Option<i64>,
    /// 文件哈希值（由前端计算并上报，十六进制字符串）
    pub hash_value: Option<String>,
    /// 哈希算法：1=md5, 2=sha256；缺省视为 1
    pub hash_alg: Option<i16>,
}

#[derive(Debug, Serialize)]
pub struct TestStorageUploadSignatureResponse {
    pub success: bool,
    pub signature: Option<storage::DirectUploadSignature>,
    pub message: String,
}

#[derive(Debug, Deserialize)]
pub struct TestStorageUploadMultipartInitiateRequest {
    pub provider_id: Option<String>,
    pub key: String,
    pub content_type: Option<String>,
    /// 文件大小（字节，必填）
    pub file_size: i64,
    /// 文件哈希值（由前端计算并上报，十六进制字符串）
    pub hash_value: Option<String>,
    /// 哈希算法：1=md5, 2=sha256；缺省视为 1
    pub hash_alg: Option<i16>,
}

#[derive(Debug, Serialize)]
pub struct TestStorageUploadMultipartInitiateResponse {
    pub success: bool,
    pub message: String,
    pub key: Option<String>,
    pub session_id: Option<String>,
    pub part_size: Option<i32>,
    pub total_parts: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct TestStorageDownloadUrlRequest {
    pub provider_id: Option<String>,
    pub key: String,
    pub expires_in_seconds: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct TestStorageDownloadUrlResponse {
    pub success: bool,
    pub url: Option<String>,
    pub message: String,
}

/// 测试对象存储文件上传
pub async fn test_storage_upload(
    State(state): State<AppState>,
    Json(req): Json<TestStorageUploadRequest>,
) -> Result<Json<TestStorageUploadResponse>, AppError> {
    use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
    use base64::Engine;

    let TestStorageUploadRequest {
        provider_id,
        key,
        content,
        file_base64,
        content_type,
    } = req;

    let store = StorageProviderStore::new(state.database.clone());

    let provider = if let Some(provider_id) = provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestStorageUploadResponse {
            success: false,
            url: None,
            message: "提供商未启用".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    let content_bytes = if let Some(file_base64) = file_base64 {
        let data_part = file_base64
            .split_once(',')
            .map(|(_, data)| data)
            .unwrap_or(file_base64.as_str());

        match BASE64_STANDARD.decode(data_part) {
            Ok(bytes_vec) => bytes::Bytes::from(bytes_vec),
            Err(e) => {
                return Ok(Json(TestStorageUploadResponse {
                    success: false,
                    url: None,
                    message: format!("文件内容解码失败: {}", e),
                }))
            }
        }
    } else if let Some(text_content) = content {
        bytes::Bytes::from(text_content)
    } else {
        return Ok(Json(TestStorageUploadResponse {
            success: false,
            url: None,
            message: "请提供文件内容或选择文件上传".to_string(),
        }));
    };

    match storage_service
        .upload_file(&key, content_bytes, content_type.as_deref())
        .await
    {
        Ok(url) => {
            let media_kind = content_type
                .as_deref()
                .map(|v| v.trim().to_ascii_lowercase())
                .map(|v| {
                    if v.starts_with("image/") {
                        "image"
                    } else if v.starts_with("video/") {
                        "video"
                    } else if v.starts_with("audio/") {
                        "audio"
                    } else if v.starts_with("text/") {
                        "text"
                    } else {
                        "document"
                    }
                })
                .unwrap_or("unknown");

            let audit_store = crate::database::file_upload_audit_store::FileUploadAuditStore::new(
                state.database.clone(),
            );
            let _ = audit_store
                .upsert_task(
                    &provider.id,
                    &key,
                    "admin_test_upload",
                    media_kind,
                    content_type.as_deref(),
                    None,
                )
                .await;

            Ok(Json(TestStorageUploadResponse {
                success: true,
                url: Some(url),
                message: "上传成功".to_string(),
            }))
        }
        Err(e) => Ok(Json(TestStorageUploadResponse {
            success: false,
            url: None,
            message: format!("上传失败: {}", e),
        })),
    }
}

/// 生成对象存储前端直传签名
pub async fn test_storage_upload_signature(
    State(state): State<AppState>,
    Json(req): Json<TestStorageUploadSignatureRequest>,
) -> Result<Json<TestStorageUploadSignatureResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    if req.key.trim().is_empty() {
        return Ok(Json(TestStorageUploadSignatureResponse {
            success: false,
            signature: None,
            message: "文件路径不能为空".to_string(),
        }));
    }

    let provider = if let Some(provider_id) = req.provider_id.clone() {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestStorageUploadSignatureResponse {
            success: false,
            signature: None,
            message: "提供商未启用".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    if let (Some(ref hash_value), Some(file_size)) = (&req.hash_value, req.file_size) {
        if file_size > 0 {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store =
                crate::database::file_upload_store::FileUploadStore::new(state.database.clone());
            if let Some(existing) = upload_store
                .find_completed_by_hash(&provider.id, hash_alg, hash_value, file_size, None)
                .await
                .map_err(AppError::from)?
            {
                info!(
                    "[Admin] 复用已上传的测试文件: key={}, hash_alg={}, hash_value={}",
                    existing.object_key, hash_alg, hash_value
                );

                return Ok(Json(TestStorageUploadSignatureResponse {
                    success: true,
                    signature: None,
                    message: "复用已上传的测试文件，未生成新的直传签名".to_string(),
                }));
            }
        }
    }

    if let (Some(ref hash_value), Some(file_size)) = (&req.hash_value, req.file_size) {
        if file_size > 0 {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store =
                crate::database::file_upload_store::FileUploadStore::new(state.database.clone());
            let _ = upload_store
                .create_pending_record(
                    &provider.id,
                    &req.key,
                    hash_alg,
                    hash_value,
                    Some(file_size),
                    req.content_type.as_deref(),
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    match storage_service
        .generate_direct_upload_signature(&req.key, req.content_type.as_deref())
        .await
    {
        Ok(signature) => {
            info!("前端获取直传参数 key: {}", req.key);
            Ok(Json(TestStorageUploadSignatureResponse {
                success: true,
                signature: Some(signature),
                message: "生成直传签名成功".to_string(),
            }))
        }
        Err(e) => Ok(Json(TestStorageUploadSignatureResponse {
            success: false,
            signature: None,
            message: format!("生成直传签名失败: {}", e),
        })),
    }
}

/// 初始化对象存储分片上传（Multipart Upload）并创建后端会话（仅用于测试页面）
pub async fn test_storage_upload_multipart_initiate(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<TestStorageUploadMultipartInitiateRequest>,
) -> Result<Json<TestStorageUploadMultipartInitiateResponse>, AppError> {
    let key = req.key.trim();
    if key.is_empty() {
        return Ok(Json(TestStorageUploadMultipartInitiateResponse {
            success: false,
            message: "文件路径不能为空".to_string(),
            key: None,
            session_id: None,
            part_size: None,
            total_parts: None,
        }));
    }

    if req.file_size <= 0 {
        return Ok(Json(TestStorageUploadMultipartInitiateResponse {
            success: false,
            message: "file_size 必填且必须大于 0".to_string(),
            key: Some(key.to_string()),
            session_id: None,
            part_size: None,
            total_parts: None,
        }));
    }

    let (part_size, total_parts) = match multipart_upload::plan_multipart_upload(req.file_size) {
        Ok(plan) => plan,
        Err(e) => {
            return Ok(Json(TestStorageUploadMultipartInitiateResponse {
                success: false,
                message: format!("{}", e),
                key: Some(key.to_string()),
                session_id: None,
                part_size: None,
                total_parts: None,
            }));
        }
    };

    let store = StorageProviderStore::new(state.database.clone());
    let provider = if let Some(provider_id) = req.provider_id.clone() {
        let provider_uuid = Uuid::parse_str(provider_id.trim())
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestStorageUploadMultipartInitiateResponse {
            success: false,
            message: "提供商未启用".to_string(),
            key: Some(key.to_string()),
            session_id: None,
            part_size: None,
            total_parts: None,
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    if let Some(ref hash_value) = req.hash_value {
        let hash_value_trimmed = hash_value.trim();
        if !hash_value_trimmed.is_empty() {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store =
                crate::database::file_upload_store::FileUploadStore::new(state.database.clone());
            if let Some(existing) = upload_store
                .find_completed_by_hash(
                    &provider.id,
                    hash_alg,
                    hash_value_trimmed,
                    req.file_size,
                    None,
                )
                .await
                .map_err(AppError::from)?
            {
                if !storage_service.file_exists(&existing.object_key).await? {
                    let _ = upload_store
                        .mark_deleted_by_key(
                            &provider.id,
                            &existing.object_key,
                            Some("对象不存在，已标记为删除"),
                        )
                        .await;
                } else {
                    info!(
                        "[Admin] 复用已上传的测试文件（分片直传 initiate）: key={}, hash_alg={}, hash_value={}",
                        existing.object_key, hash_alg, hash_value_trimmed
                    );

                    return Ok(Json(TestStorageUploadMultipartInitiateResponse {
                        success: true,
                        message: "复用已上传的对象，无需重新上传".to_string(),
                        key: Some(existing.object_key),
                        session_id: None,
                        part_size: None,
                        total_parts: None,
                    }));
                }
            }
        }
    }

    if let Some(ref hash_value) = req.hash_value {
        let hash_value_trimmed = hash_value.trim();
        if !hash_value_trimmed.is_empty() {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store =
                crate::database::file_upload_store::FileUploadStore::new(state.database.clone());
            let _ = upload_store
                .create_pending_record(
                    &provider.id,
                    key,
                    hash_alg,
                    hash_value_trimmed,
                    Some(req.file_size),
                    req.content_type.as_deref(),
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    let content_type = req
        .content_type
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty());

    let upload_id = match storage_service
        .initiate_multipart_upload(key, content_type)
        .await
    {
        Ok(upload_id) => upload_id,
        Err(e) => {
            return Ok(Json(TestStorageUploadMultipartInitiateResponse {
                success: false,
                message: format!("初始化分片上传失败: {}", e),
                key: Some(key.to_string()),
                session_id: None,
                part_size: None,
                total_parts: None,
            }));
        }
    };

    let creator_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let session_store = crate::database::file_upload_multipart_store::FileUploadMultipartStore::new(
        state.database.clone(),
    );
    let session = match session_store
        .create_session(
            &provider.id,
            key,
            &upload_id,
            &creator_id,
            claims.is_admin,
            Some(req.file_size),
            content_type,
            part_size,
            total_parts,
        )
        .await
    {
        Ok(session) => session,
        Err(e) => {
            let _ = storage_service
                .abort_multipart_upload(key, &upload_id)
                .await;
            return Ok(Json(TestStorageUploadMultipartInitiateResponse {
                success: false,
                message: format!("创建分片会话失败: {}", e),
                key: Some(key.to_string()),
                session_id: None,
                part_size: None,
                total_parts: None,
            }));
        }
    };

    Ok(Json(TestStorageUploadMultipartInitiateResponse {
        success: true,
        message: "初始化分片上传会话成功".to_string(),
        key: Some(key.to_string()),
        session_id: Some(session.id.to_string()),
        part_size: Some(part_size),
        total_parts: Some(total_parts),
    }))
}

/// 生成可访问的下载链接
pub async fn test_storage_download_url(
    State(state): State<AppState>,
    Json(req): Json<TestStorageDownloadUrlRequest>,
) -> Result<Json<TestStorageDownloadUrlResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    if req.key.trim().is_empty() {
        return Ok(Json(TestStorageDownloadUrlResponse {
            success: false,
            url: None,
            message: "文件路径（key）不能为空".to_string(),
        }));
    }

    let provider = if let Some(provider_id) = req.provider_id.clone() {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestStorageDownloadUrlResponse {
            success: false,
            url: None,
            message: "提供商未启用".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    let cache_key = CacheKeys::download_url_cache(
        req.key.trim(),
        &provider.id.to_string(),
        req.expires_in_seconds.unwrap_or(3600),
    );

    let cache_manager = CacheManager::new(state.redis.get_cache_client().clone());

    if let Ok(Some(cached_url)) = cache_manager.get_cached_download_url(&cache_key).await {
        info!("命中下载URL缓存: {}", req.key.trim());
        return Ok(Json(TestStorageDownloadUrlResponse {
            success: true,
            url: Some(cached_url),
            message: "生成下载链接成功（缓存）".to_string(),
        }));
    }

    match storage_service
        .generate_download_url(req.key.trim(), req.expires_in_seconds)
        .await
    {
        Ok(url) => {
            let url_expires_in = req.expires_in_seconds.unwrap_or(3600);
            let cache_ttl = (url_expires_in as f64 * 0.9) as u64;

            if let Err(e) = cache_manager
                .cache_download_url(&cache_key, &url, cache_ttl)
                .await
            {
                error!("缓存下载URL失败: {:?}", e);
            } else {
                info!("缓存下载URL成功: {} (TTL: {}s)", req.key.trim(), cache_ttl);
            }

            Ok(Json(TestStorageDownloadUrlResponse {
                success: true,
                url: Some(url),
                message: "生成下载链接成功".to_string(),
            }))
        }
        Err(e) => Ok(Json(TestStorageDownloadUrlResponse {
            success: false,
            url: None,
            message: format!("生成下载链接失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestStorageDeleteRequest {
    pub provider_id: Option<String>,
    pub key: String,
}

#[derive(Debug, Serialize)]
pub struct TestStorageDeleteResponse {
    pub success: bool,
    pub message: String,
}

/// 测试对象存储文件删除
pub async fn test_storage_delete(
    State(state): State<AppState>,
    Json(req): Json<TestStorageDeleteRequest>,
) -> Result<Json<TestStorageDeleteResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestStorageDeleteResponse {
            success: false,
            message: "提供商未启用".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service.delete_file(&req.key).await {
        Ok(_) => Ok(Json(TestStorageDeleteResponse {
            success: true,
            message: "删除成功".to_string(),
        })),
        Err(e) => Ok(Json(TestStorageDeleteResponse {
            success: false,
            message: format!("删除失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestStorageExistsRequest {
    pub provider_id: Option<String>,
    pub key: String,
}

#[derive(Debug, Serialize)]
pub struct TestStorageExistsResponse {
    pub success: bool,
    pub exists: bool,
    pub message: String,
}

/// 测试对象存储文件是否存在
pub async fn test_storage_exists(
    State(state): State<AppState>,
    Json(req): Json<TestStorageExistsRequest>,
) -> Result<Json<TestStorageExistsResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestStorageExistsResponse {
            success: false,
            exists: false,
            message: "提供商未启用".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service.file_exists(&req.key).await {
        Ok(exists) => Ok(Json(TestStorageExistsResponse {
            success: true,
            exists,
            message: if exists {
                "文件存在".to_string()
            } else {
                "文件不存在".to_string()
            },
        })),
        Err(e) => Ok(Json(TestStorageExistsResponse {
            success: false,
            exists: false,
            message: format!("检查失败: {}", e),
        })),
    }
}

// ========== Bucket 管理 API ==========

#[derive(Debug, Deserialize)]
pub struct TestStorageListBucketsRequest {
    pub provider_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TestStorageListBucketsResponse {
    pub success: bool,
    pub buckets: Vec<storage::BucketInfo>,
    pub message: String,
}

/// 测试对象存储获取 bucket 列表
pub async fn test_storage_list_buckets(
    State(state): State<AppState>,
    Json(req): Json<TestStorageListBucketsRequest>,
) -> Result<Json<TestStorageListBucketsResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestStorageListBucketsResponse {
            success: false,
            buckets: Vec::new(),
            message: "提供商未启用".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service_without_bucket(&provider)?;

    match storage_service.list_buckets().await {
        Ok(buckets) => Ok(Json(TestStorageListBucketsResponse {
            success: true,
            buckets: buckets.clone(),
            message: format!("成功获取 {} 个 bucket", buckets.len()),
        })),
        Err(e) => Ok(Json(TestStorageListBucketsResponse {
            success: false,
            buckets: Vec::new(),
            message: format!("获取 bucket 列表失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestStorageCreateBucketRequest {
    pub provider_id: Option<String>,
    pub bucket_name: String,
}

#[derive(Debug, Serialize)]
pub struct TestStorageCreateBucketResponse {
    pub success: bool,
    pub message: String,
}

/// 测试对象存储创建 bucket
pub async fn test_storage_create_bucket(
    State(state): State<AppState>,
    Json(req): Json<TestStorageCreateBucketRequest>,
) -> Result<Json<TestStorageCreateBucketResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
    let provider = if let Some(provider_id) = req.provider_id {
        let provider_uuid = Uuid::parse_str(&provider_id)
            .map_err(|_| AppError::ValidationError("无效的提供商ID".to_string()))?;
        store
            .get_provider_by_id(&provider_uuid)
            .await?
            .ok_or_else(|| AppError::NotFound("提供商配置不存在".to_string()))?
    } else {
        store
            .get_default_provider()
            .await?
            .ok_or_else(|| AppError::NotFound("未找到默认文件上传提供商配置".to_string()))?
    };

    if !provider.is_active {
        return Ok(Json(TestStorageCreateBucketResponse {
            success: false,
            message: "提供商未启用".to_string(),
        }));
    }

    if req.bucket_name.trim().is_empty() {
        return Ok(Json(TestStorageCreateBucketResponse {
            success: false,
            message: "bucket 名称不能为空".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service_without_bucket(&provider)?;

    match storage_service.create_bucket(&req.bucket_name.trim()).await {
        Ok(_) => Ok(Json(TestStorageCreateBucketResponse {
            success: true,
            message: format!("成功创建 bucket: {}", req.bucket_name),
        })),
        Err(e) => Ok(Json(TestStorageCreateBucketResponse {
            success: false,
            message: format!("创建 bucket 失败: {}", e),
        })),
    }
}

// ========== 管理员用户管理相关 ==========

/// 管理员用户数据存储
pub struct AdminUserStore {
    pool: sqlx::PgPool,
}

impl AdminUserStore {
    pub fn new(database: crate::database::Database) -> Self {
        Self {
            pool: database.pool,
        }
    }

    /// 根据用户名查找管理员用户
    pub async fn find_by_username(&self, username: &str) -> Result<Option<AdminUser>, AppError> {
        let user = sqlx::query_as!(
            AdminUser,
            r#"SELECT
                id, username, email, password_hash, nickname, avatar_url,
                status as "status: AdminUserStatus",
                last_login_at, login_attempts, locked_until,
                require_password_change, password_changed_at,
                created_at, updated_at, deleted_at
            FROM admin_users
            WHERE username = $1 AND deleted_at IS NULL"#,
            username
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(user)
    }

    /// 根据ID查找管理员用户
    pub async fn find_by_id(&self, id: &Uuid) -> Result<Option<AdminUser>, AppError> {
        let user = sqlx::query_as!(
            AdminUser,
            r#"SELECT
                id, username, email, password_hash, nickname, avatar_url,
                status as "status: AdminUserStatus",
                last_login_at, login_attempts, locked_until,
                require_password_change, password_changed_at,
                created_at, updated_at, deleted_at
            FROM admin_users
            WHERE id = $1 AND deleted_at IS NULL"#,
            id
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(user)
    }

    /// 验证管理员用户登录
    pub async fn authenticate(
        &self,
        request: crate::models::LoginRequest,
    ) -> Result<Option<AdminUser>, AppError> {
        let user = match self.find_by_username(&request.username).await? {
            Some(u) => u,
            None => return Ok(None),
        };

        // 验证密码
        let is_valid = bcrypt::verify(&request.password, &user.password_hash)
            .map_err(|_| AppError::InternalError("密码验证失败".to_string()))?;

        if !is_valid {
            // 记录登录失败
            self.record_login_failure(&user.id, "密码错误").await?;
            return Ok(None);
        }

        Ok(Some(user))
    }

    /// 记录登录历史
    pub async fn record_login_history(
        &self,
        admin_user_id: &Uuid,
        ip_address: Option<IpNetwork>,
        user_agent: Option<String>,
        success: bool,
        failure_reason: Option<String>,
    ) -> Result<(), AppError> {
        sqlx::query!(
            r#"INSERT INTO admin_login_history
                (admin_user_id, ip_address, user_agent, success, failure_reason)
            VALUES ($1, $2, $3, $4, $5)"#,
            admin_user_id,
            ip_address,
            user_agent,
            success,
            failure_reason
        )
        .execute(&self.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(())
    }

    /// 记录登录失败
    pub async fn record_login_failure(
        &self,
        admin_user_id: &Uuid,
        reason: &str,
    ) -> Result<(), AppError> {
        // 增加登录失败次数
        sqlx::query!(
            r#"UPDATE admin_users
            SET login_attempts = login_attempts + 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1"#,
            admin_user_id
        )
        .execute(&self.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        // 记录登录历史
        self.record_login_history(admin_user_id, None, None, false, Some(reason.to_string()))
            .await?;

        Ok(())
    }

    /// 更新登录信息（成功登录后调用）
    pub async fn update_login_info(&self, admin_user_id: &Uuid) -> Result<(), AppError> {
        sqlx::query!(
            r#"UPDATE admin_users
            SET last_login_at = CURRENT_TIMESTAMP,
                login_attempts = 0,
                locked_until = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1"#,
            admin_user_id
        )
        .execute(&self.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(())
    }

    /// 创建管理员用户
    pub async fn create_admin_user(
        &self,
        request: CreateAdminUserRequest,
    ) -> Result<AdminUser, AppError> {
        let password_hash = hash_password(&request.password)
            .map_err(|_| AppError::InternalError("密码哈希失败".to_string()))?;

        let user = sqlx::query_as!(
            AdminUser,
            r#"INSERT INTO admin_users
                (username, email, password_hash, nickname, status, require_password_change, password_changed_at)
            VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
            RETURNING
                id, username, email, password_hash, nickname, avatar_url,
                status as "status: AdminUserStatus",
                last_login_at, login_attempts, locked_until,
                require_password_change, password_changed_at,
                created_at, updated_at, deleted_at"#,
            request.username,
            request.email,
            password_hash,
            request.nickname,
            AdminUserStatus::Active as AdminUserStatus,
            false
        )
        .fetch_one(&self.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(user)
    }

    /// 获取管理员用户列表
    pub async fn list_admin_users(
        &self,
        page: usize,
        page_size: usize,
        status: Option<AdminUserStatus>,
        username: Option<String>,
    ) -> Result<(Vec<AdminUser>, i64), AppError> {
        let offset = (page - 1) * page_size;

        let mut query = sqlx::QueryBuilder::new(
            r#"SELECT
                id, username, email, password_hash, nickname, avatar_url,
                status,
                last_login_at, login_attempts, locked_until,
                require_password_change, password_changed_at,
                created_at, updated_at, deleted_at,
                COUNT(*) OVER() as total_count
            FROM admin_users
            WHERE deleted_at IS NULL"#,
        );

        if let Some(status) = status {
            query.push(" AND status = ");
            query.push_bind(status);
        }

        if let Some(username) = username {
            query.push(" AND username ILIKE ");
            query.push_bind(format!("%{}%", username));
        }

        query.push(" ORDER BY created_at DESC LIMIT ");
        query.push_bind(page_size as i64);
        query.push(" OFFSET ");
        query.push_bind(offset as i64);

        let rows = query
            .build_query_as::<AdminUserWithCount>()
            .fetch_all(&self.pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

        let total = rows.first().map(|r| r.total_count).unwrap_or(0);
        let users = rows.into_iter().map(|r| r.into()).collect();

        Ok((users, total))
    }

    /// 更新管理员用户信息
    pub async fn update_admin_user(
        &self,
        admin_user_id: &Uuid,
        nickname: Option<String>,
        avatar_url: Option<String>,
    ) -> Result<Option<AdminUser>, AppError> {
        sqlx::query_as!(
            AdminUser,
            r#"UPDATE admin_users
            SET nickname = COALESCE($2, nickname),
                avatar_url = COALESCE($3, avatar_url),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING
                id, username, email, password_hash, nickname, avatar_url,
                status as "status: AdminUserStatus",
                last_login_at, login_attempts, locked_until,
                require_password_change, password_changed_at,
                created_at, updated_at, deleted_at"#,
            admin_user_id,
            nickname,
            avatar_url
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))
    }

    /// 更新管理员用户密码
    pub async fn update_password(
        &self,
        admin_user_id: &Uuid,
        new_password_hash: &str,
    ) -> Result<bool, AppError> {
        let result = sqlx::query!(
            r#"UPDATE admin_users
            SET password_hash = $2,
                password_changed_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1 AND deleted_at IS NULL"#,
            admin_user_id,
            new_password_hash
        )
        .execute(&self.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

        Ok(result.rows_affected() > 0)
    }
}

/// 管理员用户查询结果（包含总数）
#[derive(FromRow)]
struct AdminUserWithCount {
    id: Uuid,
    username: String,
    email: String,
    password_hash: String,
    nickname: Option<String>,
    avatar_url: Option<String>,
    status: i16,
    last_login_at: Option<DateTime<Utc>>,
    login_attempts: i16,
    locked_until: Option<DateTime<Utc>>,
    require_password_change: bool,
    password_changed_at: DateTime<Utc>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    deleted_at: Option<DateTime<Utc>>,
    total_count: i64,
}

impl From<AdminUserWithCount> for AdminUser {
    fn from(row: AdminUserWithCount) -> Self {
        AdminUser {
            id: row.id,
            username: row.username,
            email: row.email,
            password_hash: row.password_hash,
            nickname: row.nickname,
            avatar_url: row.avatar_url,
            status: match row.status {
                0 => AdminUserStatus::Active,
                1 => AdminUserStatus::Inactive,
                2 => AdminUserStatus::Banned,
                3 => AdminUserStatus::Locked,
                _ => AdminUserStatus::Active, // 默认值
            },
            last_login_at: row.last_login_at,
            login_attempts: row.login_attempts,
            locked_until: row.locked_until,
            require_password_change: row.require_password_change,
            password_changed_at: row.password_changed_at,
            created_at: row.created_at,
            updated_at: row.updated_at,
            deleted_at: row.deleted_at,
        }
    }
}

fn role_with_permissions_to_response(role: Role, permissions: Vec<Permission>) -> RoleResponse {
    RoleResponse {
        id: role.id.to_string(),
        name: role.name,
        code: role.code,
        description: role.description,
        is_system: role.is_system,
        created_at: role.created_at.to_rfc3339(),
        updated_at: role.updated_at.to_rfc3339(),
        permissions: permissions
            .into_iter()
            .map(PermissionResponse::from)
            .collect(),
    }
}

fn parse_uuid_list(values: &[String], field_name: &str) -> Result<Vec<Uuid>, AppError> {
    values
        .iter()
        .map(|value| {
            Uuid::parse_str(value.trim())
                .map_err(|_| AppError::ValidationError(format!("{}包含无效 UUID", field_name)))
        })
        .collect()
}

/// 数据库管理员用户转换为API响应
pub fn db_admin_user_to_api_user_info(db_user: &AdminUser) -> AdminUserInfo {
    AdminUserInfo {
        id: db_user.id.to_string(),
        username: db_user.username.clone(),
        email: db_user.email.clone(),
        nickname: db_user.nickname.clone(),
        avatar_url: db_user.avatar_url.clone(),
        status: match db_user.status {
            AdminUserStatus::Active => "active".to_string(),
            AdminUserStatus::Inactive => "inactive".to_string(),
            AdminUserStatus::Banned => "banned".to_string(),
            AdminUserStatus::Locked => "locked".to_string(),
        },
        last_login_at: db_user.last_login_at.map(|dt| dt.to_rfc3339()),
        created_at: db_user.created_at.to_rfc3339(),
        updated_at: db_user.updated_at.to_rfc3339(),
    }
}

/// 记录管理员操作日志
async fn record_admin_operation(
    database: &crate::database::Database,
    admin_user_id: Option<Uuid>,
    operation: &str,
    resource_type: Option<&str>,
    resource_id: Option<Uuid>,
    details: Option<serde_json::Value>,
    ip_address: Option<IpNetwork>,
    user_agent: Option<String>,
) -> Result<(), AppError> {
    sqlx::query!(
        r#"INSERT INTO admin_operation_logs
            (admin_user_id, operation, resource_type, resource_id, details, ip_address, user_agent)
        VALUES ($1, $2, $3, $4, $5, $6, $7)"#,
        admin_user_id,
        operation,
        resource_type,
        resource_id,
        details,
        ip_address,
        user_agent
    )
    .execute(&database.pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    Ok(())
}

// ===== ipinfo.io Token 管理 API =====

/// ipinfo Token信息（API响应）
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IpInfoTokenInfo {
    pub id: String,
    pub name: String,
    pub token: String,
    pub monthly_limit: i32,
    pub used_count: i32,
    pub reset_date: String,
    pub status: String,
    pub last_used_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// 创建Token请求
#[derive(Debug, Deserialize)]
pub struct CreateTokenRequest {
    pub name: String,
    pub token: String,
    pub monthly_limit: Option<i32>,
}

/// 更新Token请求
#[derive(Debug, Deserialize)]
pub struct UpdateTokenRequest {
    pub name: Option<String>,
    pub token: Option<String>,
    pub monthly_limit: Option<i32>,
    pub status: Option<String>,
}

/// Token列表响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TokenListResponse {
    pub list: Vec<IpInfoTokenInfo>,
    pub total: i64,
}

/// 获取Token列表
pub async fn get_token_list(
    State(state): State<AppState>,
    Query(params): Query<std::collections::HashMap<String, String>>,
) -> Result<Json<TokenListResponse>, AppError> {
    let page: i32 = params.get("page").and_then(|s| s.parse().ok()).unwrap_or(1);
    let page_size: i32 = params
        .get("page_size")
        .and_then(|s| s.parse().ok())
        .unwrap_or(10);
    let status_filter = params.get("status");

    let offset = (page - 1) * page_size;

    let tokens = if let Some(status) = status_filter {
        sqlx::query(
            r#"
            SELECT id, name, token, monthly_limit, used_count, reset_date, status, last_used_at, created_at, updated_at
            FROM ipinfo_tokens
            WHERE status = $1
            ORDER BY created_at DESC
            LIMIT $2 OFFSET $3
            "#,
        )
        .bind(status)
        .bind(page_size)
        .bind(offset)
        .fetch_all(&state.database.pool)
        .await
    } else {
        sqlx::query(
            r#"
            SELECT id, name, token, monthly_limit, used_count, reset_date, status, last_used_at, created_at, updated_at
            FROM ipinfo_tokens
            ORDER BY created_at DESC
            LIMIT $1 OFFSET $2
            "#,
        )
        .bind(page_size)
        .bind(offset)
        .fetch_all(&state.database.pool)
        .await
    }
    .map_err(|e| AppError::DatabaseError(e))?;

    let list: Vec<IpInfoTokenInfo> = tokens
        .into_iter()
        .map(|row| {
            Ok(IpInfoTokenInfo {
                id: row.try_get::<Uuid, _>("id")?.to_string(),
                name: row.try_get("name")?,
                token: row.try_get("token")?,
                monthly_limit: row.try_get("monthly_limit")?,
                used_count: row.try_get("used_count")?,
                reset_date: row.try_get::<NaiveDate, _>("reset_date")?.to_string(),
                status: row.try_get("status")?,
                last_used_at: row
                    .try_get::<Option<DateTime<Utc>>, _>("last_used_at")?
                    .map(|dt| dt.to_rfc3339()),
                created_at: row.try_get::<DateTime<Utc>, _>("created_at")?.to_rfc3339(),
                updated_at: row.try_get::<DateTime<Utc>, _>("updated_at")?.to_rfc3339(),
            })
        })
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| AppError::DatabaseError(e))?;

    // 获取总数
    let total_query = if status_filter.is_some() {
        "SELECT COUNT(*) as count FROM ipinfo_tokens WHERE status = $1"
    } else {
        "SELECT COUNT(*) as count FROM ipinfo_tokens"
    };

    let total = if let Some(status) = status_filter {
        sqlx::query_scalar::<_, Option<i64>>(total_query)
            .bind(status)
            .fetch_one(&state.database.pool)
            .await
    } else {
        sqlx::query_scalar::<_, Option<i64>>(total_query)
            .fetch_one(&state.database.pool)
            .await
    }
    .map_err(|e| AppError::DatabaseError(e))?
    .unwrap_or(0);

    Ok(Json(TokenListResponse { list, total }))
}

/// 创建Token
pub async fn create_token(
    State(state): State<AppState>,
    Json(request): Json<CreateTokenRequest>,
) -> Result<Json<IpInfoTokenInfo>, AppError> {
    // 验证输入
    if request.name.trim().is_empty() {
        return Err(AppError::ValidationError("Token名称不能为空".to_string()));
    }
    if request.token.trim().is_empty() {
        return Err(AppError::ValidationError("Token值不能为空".to_string()));
    }

    // 检查名称是否已存在
    let existing =
        sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM ipinfo_tokens WHERE name = $1")
            .bind(&request.name)
            .fetch_one(&state.database.pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

    if existing > 0 {
        return Err(AppError::AlreadyExists("Token名称已存在".to_string()));
    }

    let monthly_limit = request.monthly_limit.unwrap_or(50000);

    // 创建Token
    let row = sqlx::query(
        r#"
        INSERT INTO ipinfo_tokens (name, token, monthly_limit)
        VALUES ($1, $2, $3)
        RETURNING id, name, token, monthly_limit, used_count, reset_date, status, last_used_at, created_at, updated_at
        "#,
    )
    .bind(&request.name)
    .bind(&request.token)
    .bind(monthly_limit)
    .fetch_one(&state.database.pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    let token = IpInfoTokenInfo {
        id: row.try_get::<Uuid, _>("id")?.to_string(),
        name: row.try_get("name")?,
        token: row.try_get("token")?,
        monthly_limit: row.try_get("monthly_limit")?,
        used_count: row.try_get("used_count")?,
        reset_date: row.try_get::<NaiveDate, _>("reset_date")?.to_string(),
        status: row.try_get("status")?,
        last_used_at: row
            .try_get::<Option<DateTime<Utc>>, _>("last_used_at")?
            .map(|dt| dt.to_rfc3339()),
        created_at: row.try_get::<DateTime<Utc>, _>("created_at")?.to_rfc3339(),
        updated_at: row.try_get::<DateTime<Utc>, _>("updated_at")?.to_rfc3339(),
    };

    Ok(Json(token))
}

/// 更新Token
pub async fn update_token(
    State(state): State<AppState>,
    Path(token_id): Path<String>,
    Json(request): Json<UpdateTokenRequest>,
) -> Result<Json<IpInfoTokenInfo>, AppError> {
    let token_uuid = Uuid::parse_str(&token_id)
        .map_err(|_| AppError::ValidationError("无效的Token ID".to_string()))?;

    // 检查Token是否存在
    let existing = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM ipinfo_tokens WHERE id = $1")
        .bind(&token_uuid)
        .fetch_one(&state.database.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

    if existing == 0 {
        return Err(AppError::NotFound("Token不存在".to_string()));
    }

    // 检查名称是否与其他Token冲突
    if let Some(ref name) = request.name {
        if !name.trim().is_empty() {
            let name_conflict = sqlx::query_scalar::<_, i64>(
                "SELECT COUNT(*) FROM ipinfo_tokens WHERE name = $1 AND id != $2",
            )
            .bind(name)
            .bind(&token_uuid)
            .fetch_one(&state.database.pool)
            .await
            .map_err(|e| AppError::DatabaseError(e))?;

            if name_conflict > 0 {
                return Err(AppError::AlreadyExists("Token名称已存在".to_string()));
            }
        }
    }

    // 构建更新SQL（注意：sqlx::QueryBuilder::separated 不适合拼接 "field = " + bind 这种多段片段）
    let mut query_builder = QueryBuilder::<Postgres>::new("UPDATE ipinfo_tokens SET ");
    let mut has_updates = false;

    if let Some(ref name) = request.name {
        let trimmed = name.trim();
        if !trimmed.is_empty() {
            if has_updates {
                query_builder.push(", ");
            }
            query_builder.push("name = ").push_bind(trimmed);
            has_updates = true;
        }
    }

    if let Some(ref token) = request.token {
        let trimmed = token.trim();
        if !trimmed.is_empty() {
            if has_updates {
                query_builder.push(", ");
            }
            query_builder.push("token = ").push_bind(trimmed);
            has_updates = true;
        }
    }

    if let Some(monthly_limit) = request.monthly_limit {
        if has_updates {
            query_builder.push(", ");
        }
        query_builder
            .push("monthly_limit = ")
            .push_bind(monthly_limit);
        has_updates = true;
    }

    if let Some(ref status) = request.status {
        let trimmed = status.trim();
        if !trimmed.is_empty() {
            if has_updates {
                query_builder.push(", ");
            }
            query_builder.push("status = ").push_bind(trimmed);
            has_updates = true;
        }
    }

    if !has_updates {
        return Err(AppError::ValidationError("没有需要更新的字段".to_string()));
    }

    query_builder.push(", updated_at = NOW()");
    query_builder.push(" WHERE id = ").push_bind(token_uuid);

    query_builder
        .build()
        .execute(&state.database.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

    // 获取更新后的Token信息
    let row = sqlx::query(
        r#"
        SELECT id, name, token, monthly_limit, used_count, reset_date, status, last_used_at, created_at, updated_at
        FROM ipinfo_tokens WHERE id = $1
        "#,
    )
    .bind(&token_uuid)
    .fetch_one(&state.database.pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    let token = IpInfoTokenInfo {
        id: row.try_get::<Uuid, _>("id")?.to_string(),
        name: row.try_get("name")?,
        token: row.try_get("token")?,
        monthly_limit: row.try_get("monthly_limit")?,
        used_count: row.try_get("used_count")?,
        reset_date: row.try_get::<NaiveDate, _>("reset_date")?.to_string(),
        status: row.try_get("status")?,
        last_used_at: row
            .try_get::<Option<DateTime<Utc>>, _>("last_used_at")?
            .map(|dt| dt.to_rfc3339()),
        created_at: row.try_get::<DateTime<Utc>, _>("created_at")?.to_rfc3339(),
        updated_at: row.try_get::<DateTime<Utc>, _>("updated_at")?.to_rfc3339(),
    };

    Ok(Json(token))
}

/// 删除Token
pub async fn delete_token(
    State(state): State<AppState>,
    Path(token_id): Path<String>,
) -> Result<StatusCode, AppError> {
    let token_uuid = Uuid::parse_str(&token_id)
        .map_err(|_| AppError::ValidationError("无效的Token ID".to_string()))?;

    // 检查Token是否存在
    let existing = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM ipinfo_tokens WHERE id = $1")
        .bind(&token_uuid)
        .fetch_one(&state.database.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

    if existing == 0 {
        return Err(AppError::NotFound("Token不存在".to_string()));
    }

    // 删除Token（级联删除使用记录）
    sqlx::query("DELETE FROM ipinfo_tokens WHERE id = $1")
        .bind(&token_uuid)
        .execute(&state.database.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

    Ok(StatusCode::NO_CONTENT)
}

/// 重置Token使用量
pub async fn reset_token_usage(
    State(state): State<AppState>,
    Path(token_id): Path<String>,
) -> Result<Json<IpInfoTokenInfo>, AppError> {
    let token_uuid = Uuid::parse_str(&token_id)
        .map_err(|_| AppError::ValidationError("无效的Token ID".to_string()))?;

    // 检查Token是否存在
    let existing = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM ipinfo_tokens WHERE id = $1")
        .bind(&token_uuid)
        .fetch_one(&state.database.pool)
        .await
        .map_err(|e| AppError::DatabaseError(e))?;

    if existing == 0 {
        return Err(AppError::NotFound("Token不存在".to_string()));
    }

    // 重置使用量
    sqlx::query(
        r#"
        UPDATE ipinfo_tokens
        SET used_count = 0, status = 'active', reset_date = CURRENT_DATE + INTERVAL '1 month', updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(&token_uuid)
    .execute(&state.database.pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    // 获取更新后的Token信息
    let row = sqlx::query(
        r#"
        SELECT id, name, token, monthly_limit, used_count, reset_date, status, last_used_at, created_at, updated_at
        FROM ipinfo_tokens WHERE id = $1
        "#,
    )
    .bind(&token_uuid)
    .fetch_one(&state.database.pool)
    .await
    .map_err(|e| AppError::DatabaseError(e))?;

    let token = IpInfoTokenInfo {
        id: row.try_get::<Uuid, _>("id")?.to_string(),
        name: row.try_get("name")?,
        token: row.try_get("token")?,
        monthly_limit: row.try_get("monthly_limit")?,
        used_count: row.try_get("used_count")?,
        reset_date: row.try_get::<NaiveDate, _>("reset_date")?.to_string(),
        status: row.try_get("status")?,
        last_used_at: row
            .try_get::<Option<DateTime<Utc>>, _>("last_used_at")?
            .map(|dt| dt.to_rfc3339()),
        created_at: row.try_get::<DateTime<Utc>, _>("created_at")?.to_rfc3339(),
        updated_at: row.try_get::<DateTime<Utc>, _>("updated_at")?.to_rfc3339(),
    };

    Ok(Json(token))
}

/// 地理位置API测试请求
#[derive(Debug, Deserialize)]
pub struct GeolocationApiTestRequest {
    pub ip_address: String,
}

/// 地理位置API测试响应
#[derive(Debug, Serialize)]
pub struct GeolocationApiTestResponse {
    pub ip: String,
    pub hostname: Option<String>,
    pub city: Option<String>,
    pub region: Option<String>,
    pub country: Option<String>,
    pub loc: Option<String>,
    pub org: Option<String>,
    pub postal: Option<String>,
    pub timezone: Option<String>,
}

/// 测试地理位置API
pub async fn test_geolocation_api(
    State(_state): State<AppState>,
    Json(request): Json<GeolocationApiTestRequest>,
) -> Result<Json<GeolocationApiTestResponse>, AppError> {
    info!("收到地理位置API测试请求，IP地址: {}", request.ip_address);

    // 验证IP地址格式
    let ip_address = request.ip_address.trim();
    if ip_address.is_empty() {
        error!("IP地址为空");
        return Err(AppError::ValidationError("IP地址不能为空".to_string()));
    }

    // 简单的IP地址格式验证
    let ip_parts: Vec<&str> = ip_address.split('.').collect();
    if ip_parts.len() != 4 {
        error!("IP地址格式无效，分段数量: {}", ip_parts.len());
        return Err(AppError::ValidationError("IP地址格式无效".to_string()));
    }

    for (i, part) in ip_parts.iter().enumerate() {
        if let Ok(_num) = part.parse::<u8>() {
            info!("IP段 {} 验证通过: {}", i, part);
        } else {
            error!("IP段 {} 验证失败: {}", i, part);
            return Err(AppError::ValidationError("IP地址格式无效".to_string()));
        }
    }

    info!("IP地址格式验证通过: {}", ip_address);

    // 调用地理位置服务进行测试
    info!("正在获取地理位置服务...");
    let geolocation_service = crate::services::geolocation::get_geolocation_service();

    if geolocation_service.is_none() {
        error!("地理位置服务未初始化");
        return Err(AppError::InternalError("地理位置服务未初始化".to_string()));
    }

    let geolocation_service = geolocation_service.unwrap();
    info!("地理位置服务获取成功");

    info!("开始查询IP {} 的地理位置...", ip_address);
    match geolocation_service.query_ip_geolocation(ip_address).await {
        Ok(Some(geo)) => {
            info!(
                "地理位置查询成功: IP={}, 城市={:?}, 国家={:?}",
                geo.ip_address, geo.city, geo.country
            );

            let response = GeolocationApiTestResponse {
                ip: geo.ip_address,
                hostname: geo.hostname,
                city: geo.city,
                region: geo.region,
                country: geo.country,
                loc: if let (Some(lat), Some(lon)) = (geo.latitude, geo.longitude) {
                    Some(format!("{},{}", lat, lon))
                } else {
                    None
                },
                org: geo.isp,
                postal: geo.zip_code,
                timezone: geo.timezone,
            };
            Ok(Json(response))
        }
        Ok(None) => {
            error!("地理位置查询返回None结果");
            Err(AppError::InternalError("无法获取地理位置信息".to_string()))
        }
        Err(e) => {
            error!("地理位置API测试失败: {}", e);
            Err(AppError::InternalError(format!("API测试失败: {}", e)))
        }
    }
}

/// 数据清理响应
#[derive(Debug, Serialize)]
pub struct DataCleanupResponse {
    pub success: bool,
    pub message: String,
    pub cleaned_tables: Vec<String>,
    pub error: Option<String>,
}

/// 清理所有 App 用户相关数据（仅限开发环境）
pub async fn cleanup_all_app_data(
    State(state): State<AppState>,
) -> Result<Json<DataCleanupResponse>, AppError> {
    info!("开始清理所有App用户相关数据");

    let pool = &state.database.pool;

    // 获取需要清理的表列表（仅限用户业务数据，不清理系统配置/管理数据）
    // 注意：必须先清理有外键引用的表，再清理被引用的表
    let tables_to_cleanup = vec![
        // 消息相关表的子表
        "message_parts",
        "message_reads",
        // 群组管理相关表
        "group_operation_logs",
        "group_mutes",
        "group_admins",
        "group_invitations",
        "join_requests",
        "group_rules",
        "group_announcements",
        "group_settings",
        // 房间成员关系（room_members 在 messages 之前清理，因 last_read_message_id 外键）
        "room_members",
        "user_room_pins",
        "room_pins",
        // 消息表（清除自引用字段后删除）
        "messages",
        // E2EE 用户数据（先删引用设备的控制消息，再删 KeyPackage/设备/身份；
        // e2ee_control_messages.sender_device_id 为 RESTRICT，必须先于设备删除）
        "e2ee_control_receipts",
        "e2ee_control_messages",
        "e2ee_key_packages",
        "e2ee_devices",
        "e2ee_account_identities",
        "e2ee_room_epochs",
        // 旧版 X3DH 预密钥表无外键，删除 users 不会级联，必须显式清理
        "e2ee_identity_keys",
        "e2ee_signed_pre_keys",
        "e2ee_one_time_pre_keys",
        // 用户关系相关表
        "user_friend_remarks",
        "friend_requests",
        "friendships",
        "user_roles",
        "user_login_history",
        "feedbacks",
        "rooms",
        "users",
    ];

    // ⚠️  以下表被故意排除在清理列表之外（系统配置/管理数据）：
    // 1. storage_providers - 文件上传提供商配置（保留系统存储配置）
    // 2. emoji_packs, emoji_pack_items, user_emoji_packs - 贴纸相关（系统资源）
    // 3. ipinfo_tokens, user_geolocations - IP地理位置Token管理（系统服务配置）
    // 4. privacy_policies, user_agreements - 隐私协议和用户协议（法律文档）
    // 5. captcha_settings - 验证码设置（系统安全配置）
    // 6. general_settings - 通用设置（系统全局配置）
    // 7. admin_users, admin_login_history, admin_operation_logs - 管理员相关（管理后台数据）
    // 8. app_versions - 应用版本管理（系统版本数据）
    // 9. permissions, roles, role_permissions - 权限管理（系统权限配置）
    // 10. e2ee_runtime_gate - E2EE 门禁单行表（部署配置，含安全审查批准状态，
    //     与 general_settings 同属系统配置，清理用户数据时保留）

    let mut cleaned_tables = Vec::new();
    let mut last_error = None;
    let mut has_error = false;

    // 开始事务
    let mut tx = pool.begin().await.map_err(AppError::DatabaseError)?;

    // 按顺序清理每个表
    for table_name in &tables_to_cleanup {
        info!("正在清理表: {}", table_name);

        // 检查表是否存在
        let table_exists: Option<Option<i64>> = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) as count
            FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = $1
            "#,
            table_name
        )
        .fetch_optional(&mut *tx)
        .await
        .map_err(AppError::DatabaseError)?;

        if table_exists.flatten() != Some(1) {
            info!("表 {} 不存在，跳过", table_name);
            continue;
        }

        // 特殊处理 messages 表：先清除自引用外键字段
        if table_name == &"messages" {
            info!("正在清除 messages 表的自引用字段...");
            if let Err(e) = sqlx::query(
                "UPDATE messages SET quoted_message_id = NULL, forward_from_message_id = NULL",
            )
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)
            {
                error!("清除 messages 表自引用字段失败: {}", e);
                last_error = Some(format!("清除 messages 表自引用字段失败: {:?}", e));
                has_error = true;
                break;
            }
            info!("messages 表自引用字段清除成功");
        }

        // 构建并执行删除SQL
        let delete_sql = format!("DELETE FROM {}", table_name);
        match sqlx::query(&delete_sql)
            .execute(&mut *tx)
            .await
            .map_err(AppError::DatabaseError)
        {
            Ok(_) => {
                info!("表 {} 清理成功", table_name);
                cleaned_tables.push(table_name.to_string());
            }
            Err(e) => {
                error!("清理表 {} 失败: {:?}", table_name, e);
                last_error = Some(format!("清理表 {} 失败: {:?}", table_name, e));
                // 如果出现错误，中断清理并回滚
                has_error = true;
                break;
            }
        }
    }

    // 根据是否有错误决定提交或回滚
    if has_error {
        info!("数据清理过程中发生错误，执行回滚...");
        tx.rollback().await.map_err(AppError::DatabaseError)?;
        info!("事务已回滚");

        // 返回错误响应
        return Ok(Json(DataCleanupResponse {
            success: false,
            message: format!("数据清理失败，已清理 {} 个表", cleaned_tables.len()),
            cleaned_tables,
            error: last_error,
        }));
    } else {
        info!("所有表清理成功，提交事务...");
        tx.commit().await.map_err(AppError::DatabaseError)?;
        info!("数据清理完成，成功清理 {} 个表", cleaned_tables.len());
    }

    Ok(Json(DataCleanupResponse {
        success: true,
        message: format!("成功清理 {} 个表的数据", cleaned_tables.len()),
        cleaned_tables,
        error: last_error,
    }))
}

// ========== IP地理位置解析开关管理 API ==========

/// 获取IP地理位置解析功能开关状态（需要管理员权限）
pub async fn get_ip_geolocation_enabled(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
) -> Result<Json<IpGeolocationStatusResponse>, AppError> {
    let enabled = geolocation::is_ip_geolocation_enabled(&state.database).await;

    info!(
        "查询IP地理位置解析功能开关状态: {}",
        if enabled { "开启" } else { "关闭" }
    );

    Ok(Json(IpGeolocationStatusResponse {
        enabled,
        description: "控制是否启用用户IP地理位置解析功能，用于管理员数据统计".to_string(),
    }))
}

/// 设置IP地理位置解析功能开关
#[derive(Debug, Deserialize)]
pub struct SetIpGeolocationEnabledRequest {
    pub enabled: bool,
}

/// 设置IP地理位置解析功能开关响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IpGeolocationStatusResponse {
    pub enabled: bool,
    pub description: String,
}

/// 设置IP地理位置解析功能开关（需要管理员权限）
pub async fn set_ip_geolocation_enabled(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<SetIpGeolocationEnabledRequest>,
) -> Result<Json<IpGeolocationStatusResponse>, AppError> {
    let admin_user_id = crate::models::convert::string_to_uuid(&claims.sub)?;

    geolocation::set_ip_geolocation_enabled(&state.database, req.enabled, Some(admin_user_id))
        .await
        .map_err(|e| {
            error!("设置IP地理位置解析开关失败: {}", e);
            AppError::InternalError(format!("设置失败: {}", e))
        })?;

    info!(
        "IP地理位置解析功能开关已设置为: {}",
        if req.enabled { "开启" } else { "关闭" }
    );

    Ok(Json(IpGeolocationStatusResponse {
        enabled: req.enabled,
        description: "控制是否启用用户IP地理位置解析功能，用于管理员数据统计".to_string(),
    }))
}

// ========== 系统日志管理 API ==========

/// 系统日志查询参数
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemLogQueryParams {
    /// 日志级别 (DEBUG/INFO/WARN/ERROR)
    pub level: Option<String>,
    /// 模块路径（模糊匹配）
    pub target: Option<String>,
    /// 关键词搜索（消息内容模糊匹配）
    pub keyword: Option<String>,
    /// 开始时间
    pub start_time: Option<DateTime<Utc>>,
    /// 结束时间
    pub end_time: Option<DateTime<Utc>>,
    /// 每页数量（默认 50，最大 500）
    pub limit: Option<i64>,
    /// 偏移量
    pub offset: Option<i64>,
}

/// 系统日志条目响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemLogEntry {
    pub id: String,
    pub level: String,
    pub target: String,
    pub message: String,
    pub fields: Option<serde_json::Value>,
    pub span_id: Option<String>,
    pub node_id: String,
    pub created_at: String,
}

/// 系统日志查询响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemLogsResponse {
    pub logs: Vec<SystemLogEntry>,
    pub total: i64,
    pub limit: i64,
    pub offset: i64,
}

/// 系统日志统计响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SystemLogStatsResponse {
    pub total_count: i64,
    pub debug_count: i64,
    pub info_count: i64,
    pub warn_count: i64,
    pub error_count: i64,
    pub oldest_log: Option<String>,
    pub newest_log: Option<String>,
}

/// 日志清理请求
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LogCleanupRequest {
    /// 保留天数（清理早于此天数的日志）
    pub retention_days: i64,
}

/// 日志清理响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LogCleanupResponse {
    pub success: bool,
    pub deleted_count: u64,
    pub message: String,
}

/// 查询系统日志（需要管理员权限）
pub async fn list_system_logs(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
    Query(params): Query<SystemLogQueryParams>,
) -> Result<Json<SystemLogsResponse>, AppError> {
    let query_params = LogQueryParams {
        level: params.level,
        target: params.target,
        keyword: params.keyword,
        start_time: params.start_time,
        end_time: params.end_time,
        limit: params.limit,
        offset: params.offset,
    };

    let result = state.log_store.query(&query_params).await?;

    let logs = result
        .logs
        .into_iter()
        .map(|entry| SystemLogEntry {
            id: entry.id.map(|id| id.to_string()).unwrap_or_default(),
            level: entry.level,
            target: entry.target,
            message: entry.message,
            fields: entry.fields,
            span_id: entry.span_id,
            node_id: entry.node_id,
            created_at: entry.created_at.to_rfc3339(),
        })
        .collect();

    Ok(Json(SystemLogsResponse {
        logs,
        total: result.total,
        limit: result.limit,
        offset: result.offset,
    }))
}

/// 获取系统日志统计（需要管理员权限）
pub async fn get_system_log_stats(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
) -> Result<Json<SystemLogStatsResponse>, AppError> {
    let stats = state.log_store.stats().await?;

    Ok(Json(SystemLogStatsResponse {
        total_count: stats.total_count,
        debug_count: stats.debug_count,
        info_count: stats.info_count,
        warn_count: stats.warn_count,
        error_count: stats.error_count,
        oldest_log: stats.oldest_log.map(|t| t.to_rfc3339()),
        newest_log: stats.newest_log.map(|t| t.to_rfc3339()),
    }))
}

/// 手动清理系统日志（需要管理员权限）
pub async fn cleanup_system_logs(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<LogCleanupRequest>,
) -> Result<Json<LogCleanupResponse>, AppError> {
    if req.retention_days < 1 {
        return Err(AppError::ValidationError("保留天数必须大于 0".to_string()));
    }

    info!(
        "管理员 {} 请求清理系统日志，保留 {} 天内的日志",
        claims.sub, req.retention_days
    );

    let deleted_count = state.log_store.cleanup(req.retention_days).await?;

    info!(
        "系统日志清理完成: 删除了 {} 条日志，保留 {} 天",
        deleted_count, req.retention_days
    );

    Ok(Json(LogCleanupResponse {
        success: true,
        deleted_count,
        message: format!(
            "成功删除 {} 条日志，保留最近 {} 天的日志",
            deleted_count, req.retention_days
        ),
    }))
}

// ========== 文件内容审核运维 API ==========

/// 文件内容审核任务查询参数
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileUploadAuditTaskQueryParams {
    pub provider_id: Option<String>,
    pub status: Option<i16>,
    pub scene: Option<String>,
    pub media_kind: Option<String>,
    pub keyword: Option<String>,
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 文件内容审核任务（列表项）
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FileUploadAuditTaskListEntry {
    pub id: String,
    pub storage_provider_id: String,
    pub object_key: String,
    pub scene: String,
    pub media_kind: String,
    pub content_type: Option<String>,
    pub file_size: Option<i64>,
    pub status: i16,
    pub vendor_job_id: Option<String>,
    pub rejected_reason: Option<String>,
    pub attempts: i32,
    pub next_run_at: String,
    pub last_error: Option<String>,
    pub audited_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// 文件内容审核任务查询响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FileUploadAuditTaskListResponse {
    pub tasks: Vec<FileUploadAuditTaskListEntry>,
    pub total: i64,
    pub limit: i64,
    pub offset: i64,
}

/// 文件内容审核任务详情响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FileUploadAuditTaskDetailResponse {
    pub task: FileUploadAuditTaskDetailEntry,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FileUploadAuditTaskDetailEntry {
    pub id: String,
    pub storage_provider_id: String,
    pub object_key: String,
    pub scene: String,
    pub media_kind: String,
    pub content_type: Option<String>,
    pub file_size: Option<i64>,
    pub status: i16,
    pub vendor_job_id: Option<String>,
    pub result: serde_json::Value,
    pub rejected_reason: Option<String>,
    pub attempts: i32,
    pub next_run_at: String,
    pub last_error: Option<String>,
    pub audited_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

/// 重新入队响应
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FileUploadAuditTaskRequeueResponse {
    pub success: bool,
    pub message: String,
}

pub async fn list_file_upload_audit_tasks(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
    Query(params): Query<FileUploadAuditTaskQueryParams>,
) -> Result<Json<FileUploadAuditTaskListResponse>, AppError> {
    let provider_uuid = params
        .provider_id
        .as_deref()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
        .map(|v| {
            Uuid::parse_str(v)
                .map_err(|_| AppError::ValidationError("无效的 provider_id".to_string()))
        })
        .transpose()?;

    let limit = params.limit.unwrap_or(50).clamp(1, 500);
    let offset = params.offset.unwrap_or(0).max(0);

    let store =
        crate::database::file_upload_audit_store::FileUploadAuditStore::new(state.database.clone());

    let tasks = store
        .list_tasks(
            provider_uuid,
            params.status,
            params.scene.as_deref(),
            params.media_kind.as_deref(),
            params.keyword.as_deref(),
            params.start_time,
            params.end_time,
            limit,
            offset,
        )
        .await
        .map_err(AppError::from)?;

    let total = store
        .count_tasks(
            provider_uuid,
            params.status,
            params.scene.as_deref(),
            params.media_kind.as_deref(),
            params.keyword.as_deref(),
            params.start_time,
            params.end_time,
        )
        .await
        .map_err(AppError::from)?;

    let items = tasks
        .into_iter()
        .map(|t| FileUploadAuditTaskListEntry {
            id: t.id.to_string(),
            storage_provider_id: t.storage_provider_id.to_string(),
            object_key: t.object_key,
            scene: t.scene,
            media_kind: t.media_kind,
            content_type: t.content_type,
            file_size: t.file_size,
            status: t.status,
            vendor_job_id: t.vendor_job_id,
            rejected_reason: t.rejected_reason,
            attempts: t.attempts,
            next_run_at: t.next_run_at.to_rfc3339(),
            last_error: t.last_error,
            audited_at: t.audited_at.map(|v| v.to_rfc3339()),
            created_at: t.created_at.to_rfc3339(),
            updated_at: t.updated_at.to_rfc3339(),
        })
        .collect();

    Ok(Json(FileUploadAuditTaskListResponse {
        tasks: items,
        total,
        limit,
        offset,
    }))
}

pub async fn get_file_upload_audit_task(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
    Path(task_id): Path<String>,
) -> Result<Json<FileUploadAuditTaskDetailResponse>, AppError> {
    let task_uuid = Uuid::parse_str(task_id.trim())
        .map_err(|_| AppError::ValidationError("无效的 task_id".to_string()))?;

    let store =
        crate::database::file_upload_audit_store::FileUploadAuditStore::new(state.database.clone());

    let task = store
        .get_task_by_id(&task_uuid)
        .await
        .map_err(AppError::from)?
        .ok_or_else(|| AppError::NotFound("审核任务不存在".to_string()))?;

    Ok(Json(FileUploadAuditTaskDetailResponse {
        task: FileUploadAuditTaskDetailEntry {
            id: task.id.to_string(),
            storage_provider_id: task.storage_provider_id.to_string(),
            object_key: task.object_key,
            scene: task.scene,
            media_kind: task.media_kind,
            content_type: task.content_type,
            file_size: task.file_size,
            status: task.status,
            vendor_job_id: task.vendor_job_id,
            result: task.result,
            rejected_reason: task.rejected_reason,
            attempts: task.attempts,
            next_run_at: task.next_run_at.to_rfc3339(),
            last_error: task.last_error,
            audited_at: task.audited_at.map(|v| v.to_rfc3339()),
            created_at: task.created_at.to_rfc3339(),
            updated_at: task.updated_at.to_rfc3339(),
        },
    }))
}

pub async fn requeue_file_upload_audit_task(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
    Path(task_id): Path<String>,
) -> Result<Json<FileUploadAuditTaskRequeueResponse>, AppError> {
    let task_uuid = Uuid::parse_str(task_id.trim())
        .map_err(|_| AppError::ValidationError("无效的 task_id".to_string()))?;

    let store =
        crate::database::file_upload_audit_store::FileUploadAuditStore::new(state.database.clone());

    let updated = store
        .requeue_task(&task_uuid)
        .await
        .map_err(AppError::from)?;

    if !updated {
        return Err(AppError::NotFound("审核任务不存在".to_string()));
    }

    Ok(Json(FileUploadAuditTaskRequeueResponse {
        success: true,
        message: "已重新入队".to_string(),
    }))
}
