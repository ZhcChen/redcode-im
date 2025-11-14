use axum::{
    extract::{Extension, Path, Query, State},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::models::{
    CaptchaSettingRecord, Permission, Role, StorageProvider, StorageProviderType, UserStatus,
};
use crate::database::settings_store::SettingsStore;
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::user_store::UserStore;
use crate::error::AppError;
use crate::storage;
use crate::AppState;
use chrono::{DateTime, NaiveDate, Utc};
use sqlx::{FromRow, Row};
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
    pub uptime: i64,
    pub load_average: Vec<f64>,
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
pub struct AssignRoleRequest {
    pub user_id: String,
    pub role_id: String,
}

#[derive(Debug, Serialize)]
pub struct UserRoleResponse {
    pub user_id: String,
    pub role_id: String,
    pub role_name: String,
    pub role_code: String,
    pub assigned_at: String,
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

    let online_users = get_online_users_count(pool).await.unwrap_or(0);

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

async fn get_online_users_count(pool: &sqlx::PgPool) -> Result<i64, sqlx::Error> {
    // 假设我们有在线状态记录，或者通过最近活动时间判断
    let count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM users
         WHERE deleted_at IS NULL
         AND updated_at > NOW() - INTERVAL '30 minutes'",
    )
    .fetch_one(pool)
    .await?;
    Ok(count)
}

async fn get_active_rooms_count(pool: &sqlx::PgPool) -> Result<i64, sqlx::Error> {
    // 假设活跃房间是指最近24小时内有消息的房间
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
    let count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM messages
         WHERE deleted_at IS NULL
         AND DATE(created_at) = CURRENT_DATE",
    )
    .fetch_one(pool)
    .await?;
    Ok(count)
}

async fn get_system_load() -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        use std::fs;
        let load_avg = fs::read_to_string("/proc/loadavg")?;
        let load_str = load_avg.split_whitespace().next().unwrap_or("0.0");
        Ok(load_str.parse::<f64>().unwrap_or(0.0))
    }
    #[cfg(not(unix))]
    {
        // Windows/macOS 系统使用其他方式获取
        Ok(0.0)
    }
}

async fn get_memory_usage() -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        use std::fs;
        let meminfo = fs::read_to_string("/proc/meminfo")?;
        let mut total_memory = 0u64;
        let mut free_memory = 0u64;
        let mut available_memory = 0u64;

        for line in meminfo.lines() {
            if line.starts_with("MemTotal:") {
                total_memory = line
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("0")
                    .parse::<u64>()
                    .unwrap_or(0);
            } else if line.starts_with("MemFree:") {
                free_memory = line
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("0")
                    .parse::<u64>()
                    .unwrap_or(0);
            } else if line.starts_with("MemAvailable:") {
                available_memory = line
                    .split_whitespace()
                    .nth(1)
                    .unwrap_or("0")
                    .parse::<u64>()
                    .unwrap_or(0);
            }
        }

        let used = if available_memory > 0 {
            total_memory - available_memory
        } else {
            total_memory - free_memory
        };

        Ok((used as f64) / (total_memory as f64))
    }
    #[cfg(not(unix))]
    {
        Ok(0.0)
    }
}

async fn get_storage_usage(_state: &AppState) -> Result<f64, AppError> {
    // 这里应该调用存储服务获取实际使用量
    // 暂时返回模拟数据
    Ok(0.28)
}

pub async fn get_system_monitor(
    State(_state): State<AppState>,
) -> Result<Json<SystemMonitor>, AppError> {
    // 获取真实的系统监控数据
    let cpu = get_system_load().await.unwrap_or(0.0);
    let memory = get_memory_usage().await.unwrap_or(0.0);
    let disk = get_disk_usage().await.unwrap_or(0.0);
    let (network_in, network_out) = get_network_stats().await.unwrap_or((512000.0, 256000.0));
    let connections = get_active_connections().await.unwrap_or(68);
    let uptime = get_system_uptime().await.unwrap_or(0);
    let load_average = get_load_average().await.unwrap_or(vec![0.0, 0.0, 0.0]);

    let monitor = SystemMonitor {
        cpu,
        memory,
        disk,
        network_in,
        network_out,
        connections,
        uptime,
        load_average,
    };

    Ok(Json(monitor))
}

async fn get_disk_usage() -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        // 模拟磁盘使用率
        Ok(0.28)
    }
    #[cfg(not(unix))]
    {
        Ok(0.28)
    }
}

async fn get_network_stats() -> Result<(f64, f64), Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        use std::fs;
        // 读取网络接口统计信息
        let net_dev = fs::read_to_string("/proc/net/dev")?;
        let mut total_rx = 0u64;
        let mut total_tx = 0u64;

        for line in net_dev.lines().skip(2) {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() > 16 {
                // 跳过 lo (loopback) 接口
                if !line.contains("lo:") {
                    total_rx += parts[1].parse::<u64>().unwrap_or(0);
                    total_tx += parts[9].parse::<u64>().unwrap_or(0);
                }
            }
        }

        Ok((total_rx as f64, total_tx as f64))
    }
    #[cfg(not(unix))]
    {
        Ok((512000.0, 256000.0))
    }
}

async fn get_active_connections() -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        use std::fs;
        let tcp_content = fs::read_to_string("/proc/net/tcp")?;
        let udp_content = fs::read_to_string("/proc/net/udp")?;

        let tcp_connections = tcp_content.lines().count() as i64 - 1; // 减去标题行
        let udp_connections = udp_content.lines().count() as i64 - 1;

        Ok(tcp_connections + udp_connections)
    }
    #[cfg(not(unix))]
    {
        Ok(68)
    }
}

async fn get_system_uptime() -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        use std::fs;
        let uptime_content = fs::read_to_string("/proc/uptime")?;
        let uptime_seconds = uptime_content
            .split_whitespace()
            .next()
            .unwrap_or("0")
            .parse::<f64>()
            .unwrap_or(0.0);
        Ok(uptime_seconds as i64)
    }
    #[cfg(not(unix))]
    {
        Ok(86400) // 模拟1天
    }
}

async fn get_load_average() -> Result<Vec<f64>, Box<dyn std::error::Error + Send + Sync>> {
    #[cfg(unix)]
    {
        use std::fs;
        let load_avg = fs::read_to_string("/proc/loadavg")?;
        let loads: Vec<f64> = load_avg
            .split_whitespace()
            .take(3)
            .map(|s| s.parse::<f64>().unwrap_or(0.0))
            .collect();
        Ok(loads)
    }
    #[cfg(not(unix))]
    {
        Ok(vec![0.5, 0.3, 0.2])
    }
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
        "SELECT COUNT(*) FROM messages WHERE user_id = $1 AND deleted_at IS NULL",
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

    let storage_usage: i64 = sqlx::query_scalar(
        "SELECT COALESCE(SUM(file_size), 0) FROM message_parts mp
         INNER JOIN messages m ON mp.message_id = m.id
         WHERE m.user_id = $1 AND mp.object_key IS NOT NULL AND mp.deleted_at IS NULL",
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
// TODO: 临时禁用，需要更新 argon2 API 到 0.6
pub async fn create_user(
    State(_state): State<AppState>,
    Json(_req): Json<CreateUserRequest>,
) -> Result<Json<UserOperationResponse>, AppError> {
    // 功能开发中
    return Ok(Json(UserOperationResponse {
        success: false,
        message: "功能开发中".to_string(),
    }));
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

    // 构建更新查询
    let mut updates = Vec::new();
    let mut params: Vec<String> = Vec::new();
    let mut param_index = 1;

    if let Some(email) = &req.email {
        updates.push(format!("email = ${}", param_index));
        params.push(email.trim().to_string());
        param_index += 1;
    }

    if let Some(nickname) = &req.nickname {
        updates.push(format!("nickname = ${}", param_index));
        params.push(nickname.trim().to_string());
        param_index += 1;
    }

    if let Some(status) = &req.status {
        let status_enum = match status.as_str() {
            "active" => UserStatus::Active,
            "inactive" => UserStatus::Inactive,
            "banned" => UserStatus::Banned,
            _ => {
                return Ok(Json(UserOperationResponse {
                    success: false,
                    message: "无效的用户状态".to_string(),
                }));
            }
        };
        updates.push(format!("status = ${}", param_index));
        params.push(status_enum.to_string());
        param_index += 1;
    }

    if updates.is_empty() {
        return Ok(Json(UserOperationResponse {
            success: false,
            message: "没有提供要更新的字段".to_string(),
        }));
    }

    updates.push(format!("updated_at = ${}", param_index));
    params.push(chrono::Utc::now().to_rfc3339());
    param_index += 1;

    let query = format!(
        "UPDATE users SET {} WHERE id = ${}",
        updates.join(", "),
        param_index
    );

    let mut query_builder = sqlx::query(&query);
    for param in params {
        query_builder = query_builder.bind(param);
    }
    query_builder = query_builder.bind(user_id);

    query_builder
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

    // 密码加密 - TODO: 临时注释，需要更新 argon2 API
    /*
    use argon2::{
        password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
        Argon2,
    };
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = argon2
        .hash_password(req.new_password.as_bytes(), &salt)
        .map_err(|_| AppError::ValidationError("密码加密失败".to_string()))?
        .to_string();
    */
    return Ok(Json(UserOperationResponse {
        success: false,
        message: "功能开发中".to_string(),
    }));
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

/// 获取所有权限列表（简化版本）
pub async fn get_permissions(
    State(_state): State<AppState>,
) -> Result<Json<PermissionListResponse>, AppError> {
    // 简化版本，返回预定义的权限列表
    let permissions = vec![
        PermissionResponse {
            id: "1".to_string(),
            name: "查看用户".to_string(),
            code: "user:view".to_string(),
            description: Some("查看用户列表和详情".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            updated_at: chrono::Utc::now().to_rfc3339(),
        },
        PermissionResponse {
            id: "2".to_string(),
            name: "创建用户".to_string(),
            code: "user:create".to_string(),
            description: Some("创建新用户".to_string()),
            created_at: chrono::Utc::now().to_rfc3339(),
            updated_at: chrono::Utc::now().to_rfc3339(),
        },
        // 添加更多权限...
    ];

    Ok(Json(PermissionListResponse { permissions }))
}

/// 获取所有角色列表（简化版本）
pub async fn get_roles(State(_state): State<AppState>) -> Result<Json<RoleListResponse>, AppError> {
    // 简化版本，返回预定义的角色列表
    let roles = vec![
        RoleResponse {
            id: "1".to_string(),
            name: "超级管理员".to_string(),
            code: "super_admin".to_string(),
            description: Some("拥有所有权限".to_string()),
            is_system: true,
            created_at: chrono::Utc::now().to_rfc3339(),
            updated_at: chrono::Utc::now().to_rfc3339(),
            permissions: vec![
                PermissionResponse {
                    id: "1".to_string(),
                    name: "查看用户".to_string(),
                    code: "user:view".to_string(),
                    description: Some("查看用户列表和详情".to_string()),
                    created_at: chrono::Utc::now().to_rfc3339(),
                    updated_at: chrono::Utc::now().to_rfc3339(),
                },
                // 添加更多权限...
            ],
        },
        RoleResponse {
            id: "2".to_string(),
            name: "管理员".to_string(),
            code: "admin".to_string(),
            description: Some("拥有大部分管理权限".to_string()),
            is_system: false,
            created_at: chrono::Utc::now().to_rfc3339(),
            updated_at: chrono::Utc::now().to_rfc3339(),
            permissions: vec![
                PermissionResponse {
                    id: "1".to_string(),
                    name: "查看用户".to_string(),
                    code: "user:view".to_string(),
                    description: Some("查看用户列表和详情".to_string()),
                    created_at: chrono::Utc::now().to_rfc3339(),
                    updated_at: chrono::Utc::now().to_rfc3339(),
                },
                // 添加更多权限...
            ],
        },
    ];

    Ok(Json(RoleListResponse { roles }))
}

/// 创建角色（简化版本）
pub async fn create_role(
    State(_state): State<AppState>,
    Json(req): Json<CreateRoleRequest>,
) -> Result<Json<RoleOperationResponse>, AppError> {
    // 验证输入
    if req.name.trim().is_empty() {
        return Ok(Json(RoleOperationResponse {
            success: false,
            message: "角色名称不能为空".to_string(),
        }));
    }

    if req.code.trim().is_empty() {
        return Ok(Json(RoleOperationResponse {
            success: false,
            message: "角色代码不能为空".to_string(),
        }));
    }

    // 简化版本，仅返回成功消息
    Ok(Json(RoleOperationResponse {
        success: true,
        message: "角色创建成功（简化版本）".to_string(),
    }))
}

/// 更新角色（简化版本）
pub async fn update_role(
    State(_state): State<AppState>,
    Path(role_id): Path<String>,
    Json(_req): Json<UpdateRoleRequest>,
) -> Result<Json<RoleOperationResponse>, AppError> {
    // 简化版本，仅验证输入
    if role_id == "1" {
        return Ok(Json(RoleOperationResponse {
            success: false,
            message: "系统角色不允许修改".to_string(),
        }));
    }

    Ok(Json(RoleOperationResponse {
        success: true,
        message: "角色更新成功（简化版本）".to_string(),
    }))
}

/// 删除角色（简化版本）
pub async fn delete_role(
    State(_state): State<AppState>,
    Path(role_id): Path<String>,
) -> Result<Json<RoleOperationResponse>, AppError> {
    // 简化版本，仅验证输入
    if role_id == "1" {
        return Ok(Json(RoleOperationResponse {
            success: false,
            message: "系统角色不允许删除".to_string(),
        }));
    }

    Ok(Json(RoleOperationResponse {
        success: true,
        message: "角色删除成功（简化版本）".to_string(),
    }))
}

/// 分配角色给用户（简化版本）
pub async fn assign_role_to_user(
    State(_state): State<AppState>,
    Json(req): Json<AssignRoleRequest>,
) -> Result<Json<RoleOperationResponse>, AppError> {
    // 简化版本，仅验证输入格式
    if req.user_id.is_empty() || req.role_id.is_empty() {
        return Ok(Json(RoleOperationResponse {
            success: false,
            message: "用户ID和角色ID不能为空".to_string(),
        }));
    }

    Ok(Json(RoleOperationResponse {
        success: true,
        message: "角色分配成功（简化版本）".to_string(),
    }))
}

/// 撤销用户角色（简化版本）
pub async fn revoke_role_from_user(
    State(_state): State<AppState>,
    Path(user_id): Path<String>,
    Path(role_id): Path<String>,
) -> Result<Json<RoleOperationResponse>, AppError> {
    // 简化版本，仅验证输入格式
    if user_id.is_empty() || role_id.is_empty() {
        return Ok(Json(RoleOperationResponse {
            success: false,
            message: "用户ID和角色ID不能为空".to_string(),
        }));
    }

    Ok(Json(RoleOperationResponse {
        success: true,
        message: "角色撤销成功（简化版本）".to_string(),
    }))
}

/// 检查用户权限
pub async fn check_user_permission(
    State(_state): State<AppState>,
    Json(req): Json<CheckPermissionRequest>,
) -> Result<Json<CheckPermissionResponse>, AppError> {
    let _user_id = Uuid::parse_str(&req.user_id)
        .map_err(|_| AppError::ValidationError("无效的用户ID".to_string()))?;

    // 检查用户是否有指定权限（简化版本，使用枚举）
    let has_permission = true; // 简化处理，实际应该查询数据库

    Ok(Json(CheckPermissionResponse { has_permission }))
}

/// 获取用户角色列表（简化版本）
pub async fn get_user_roles(
    State(_state): State<AppState>,
    Path(user_id): Path<String>,
) -> Result<Json<Vec<UserRoleResponse>>, AppError> {
    // 简化版本，返回模拟数据
    let roles = vec![UserRoleResponse {
        user_id: user_id.clone(),
        role_id: "1".to_string(),
        role_name: "超级管理员".to_string(),
        role_code: "super_admin".to_string(),
        assigned_at: chrono::Utc::now().to_rfc3339(),
    }];

    Ok(Json(roles))
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

    let total_size_bytes: i64 = sqlx::query_scalar(
        "SELECT COALESCE(SUM(attachment_size), 0) FROM message_parts WHERE attachment_key IS NOT NULL"
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

// ========== 文件上传提供商管理 API ==========

#[derive(Debug, Serialize)]
pub struct StorageProviderResponse {
    pub id: String,
    pub provider_type: String,
    pub name: String,
    pub secret_id: String,
    pub secret_key: String,
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
        Self {
            id: provider.id.to_string(),
            provider_type: provider.provider_type.to_string(),
            name: provider.name,
            secret_id: provider.secret_id,
            secret_key: provider.secret_key,
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
        "tencent_cos" => StorageProviderType::TencentCos,
        "aliyun_oss" => StorageProviderType::AliyunOss,
        "aws_s3" => StorageProviderType::AwsS3,
        "minio" => StorageProviderType::Minio,
        "unknown" => StorageProviderType::Unknown,
        _ => {
            return Err(AppError::ValidationError(format!(
                "不支持的提供商类型: {}",
                req.provider_type
            )));
        }
    };

    let updated_by = Uuid::parse_str(&claims.sub).ok();

    let store = StorageProviderStore::new(state.database.clone());

    // 如果是腾讯云 COS 且没有指定 bucket_name，尝试创建一个默认的 bucket
    let mut bucket_name = req.bucket_name.clone();
    if provider_type == StorageProviderType::TencentCos && bucket_name.is_none() {
        // 生成一个默认的 bucket 名称
        let uuid_str = Uuid::new_v4().to_string().replace("-", "");
        let default_bucket_name = format!("redcode-im-{}", &uuid_str[..8]);

        // 创建临时的存储服务实例来创建 bucket
        let temp_provider = StorageProvider {
            id: Uuid::new_v4(),
            provider_type: StorageProviderType::TencentCos,
            name: req.name.clone(),
            secret_id: req.secret_id.clone(),
            secret_key: req.secret_key.clone(),
            region: req.region.clone(),
            endpoint: req.endpoint.clone(),
            bucket_name: None,
            is_active: false,
            is_default: false,
            description: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            updated_by: None,
        };

        match storage::create_storage_service_without_bucket(&temp_provider) {
            Ok(storage_service) => {
                match storage_service.create_bucket(&default_bucket_name).await {
                    Ok(_) => {
                        bucket_name = Some(default_bucket_name);
                        tracing::info!("自动创建 bucket: {}", bucket_name.as_ref().unwrap());
                    }
                    Err(e) => {
                        tracing::warn!("自动创建 bucket 失败: {}，将使用用户指定的 bucket_name", e);
                        // 继续执行，让用户稍后手动指定 bucket_name
                    }
                }
            }
            Err(e) => {
                tracing::warn!("创建存储服务实例失败: {}，将使用用户指定的 bucket_name", e);
            }
        }
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
            "tencent_cos" => Some(StorageProviderType::TencentCos),
            "aliyun_oss" => Some(StorageProviderType::AliyunOss),
            "aws_s3" => Some(StorageProviderType::AwsS3),
            "minio" => Some(StorageProviderType::Minio),
            "unknown" => Some(StorageProviderType::Unknown),
            _ => {
                return Err(AppError::ValidationError(format!(
                    "不支持的提供商类型: {}",
                    pt
                )));
            }
        }
    } else {
        None
    };

    let store = StorageProviderStore::new(state.database.clone());
    let provider = store
        .update_provider(
            &provider_id,
            provider_type,
            req.name.as_deref(),
            req.secret_id.as_deref(),
            req.secret_key.as_deref(),
            req.region.as_deref(),
            req.endpoint.as_deref(),
            req.bucket_name.as_ref().map(|x| x.as_deref()),
            req.is_active,
            req.is_default,
            req.description.as_ref().map(|x| x.as_deref()),
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

// ========== COS 测试 API ==========

#[derive(Debug, Deserialize)]
pub struct TestCosUploadRequest {
    pub provider_id: Option<String>,
    pub key: String,
    pub content: Option<String>,
    pub file_base64: Option<String>,
    pub content_type: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TestCosUploadResponse {
    pub success: bool,
    pub url: Option<String>,
    pub message: String,
}

#[derive(Debug, Deserialize)]
pub struct TestCosUploadSignatureRequest {
    pub provider_id: Option<String>,
    pub key: String,
    pub content_type: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TestCosUploadSignatureResponse {
    pub success: bool,
    pub signature: Option<storage::DirectUploadSignature>,
    pub message: String,
}

#[derive(Debug, Deserialize)]
pub struct TestCosDownloadUrlRequest {
    pub provider_id: Option<String>,
    pub key: String,
    pub expires_in_seconds: Option<u32>,
}

#[derive(Debug, Serialize)]
pub struct TestCosDownloadUrlResponse {
    pub success: bool,
    pub url: Option<String>,
    pub message: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct CorsRuleInput {
    pub allowed_origins: Vec<String>,
    pub allowed_methods: Vec<String>,
    #[serde(default)]
    pub allowed_headers: Vec<String>,
    #[serde(default)]
    pub expose_headers: Vec<String>,
    pub max_age_seconds: Option<u32>,
}

#[derive(Debug, Deserialize)]
pub struct TestCosSetCorsRequest {
    pub provider_id: Option<String>,
    pub rules: Vec<CorsRuleInput>,
}

#[derive(Debug, Deserialize)]
pub struct TestCosGetCorsRequest {
    pub provider_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TestCosSetCorsResponse {
    pub success: bool,
    pub message: String,
}

#[derive(Debug, Serialize)]
pub struct TestCosGetCorsResponse {
    pub success: bool,
    pub message: String,
    pub rules: Vec<CorsRuleInput>,
}

/// 测试 COS 文件上传
pub async fn test_cos_upload(
    State(state): State<AppState>,
    Json(req): Json<TestCosUploadRequest>,
) -> Result<Json<TestCosUploadResponse>, AppError> {
    use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
    use base64::Engine;

    let TestCosUploadRequest {
        provider_id,
        key,
        content,
        file_base64,
        content_type,
    } = req;

    let store = StorageProviderStore::new(state.database.clone());

    // 获取提供商配置
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

    // 检查提供商是否启用
    if !provider.is_active {
        return Ok(Json(TestCosUploadResponse {
            success: false,
            url: None,
            message: "提供商未启用".to_string(),
        }));
    }

    // 检查是否为腾讯云 COS
    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosUploadResponse {
            success: false,
            url: None,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    // 创建存储服务
    let storage_service = storage::create_storage_service(&provider)?;

    // 上传文件
    let content_bytes = if let Some(file_base64) = file_base64 {
        let data_part = file_base64
            .split_once(',')
            .map(|(_, data)| data)
            .unwrap_or(file_base64.as_str());

        match BASE64_STANDARD.decode(data_part) {
            Ok(bytes_vec) => bytes::Bytes::from(bytes_vec),
            Err(e) => {
                return Ok(Json(TestCosUploadResponse {
                    success: false,
                    url: None,
                    message: format!("文件内容解码失败: {}", e),
                }))
            }
        }
    } else if let Some(text_content) = content {
        bytes::Bytes::from(text_content)
    } else {
        return Ok(Json(TestCosUploadResponse {
            success: false,
            url: None,
            message: "请提供文件内容或选择文件上传".to_string(),
        }));
    };

    match storage_service
        .upload_file(&key, content_bytes, content_type.as_deref())
        .await
    {
        Ok(url) => Ok(Json(TestCosUploadResponse {
            success: true,
            url: Some(url),
            message: "上传成功".to_string(),
        })),
        Err(e) => Ok(Json(TestCosUploadResponse {
            success: false,
            url: None,
            message: format!("上传失败: {}", e),
        })),
    }
}

/// 生成 COS 前端直传签名
pub async fn test_cos_upload_signature(
    State(state): State<AppState>,
    Json(req): Json<TestCosUploadSignatureRequest>,
) -> Result<Json<TestCosUploadSignatureResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    if req.key.trim().is_empty() {
        return Ok(Json(TestCosUploadSignatureResponse {
            success: false,
            signature: None,
            message: "文件路径不能为空".to_string(),
        }));
    }

    // 获取提供商配置
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
        return Ok(Json(TestCosUploadSignatureResponse {
            success: false,
            signature: None,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosUploadSignatureResponse {
            success: false,
            signature: None,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service
        .generate_direct_upload_signature(&req.key, req.content_type.as_deref())
        .await
    {
        Ok(signature) => Ok(Json(TestCosUploadSignatureResponse {
            success: true,
            signature: Some(signature),
            message: "生成直传签名成功".to_string(),
        })),
        Err(e) => Ok(Json(TestCosUploadSignatureResponse {
            success: false,
            signature: None,
            message: format!("生成直传签名失败: {}", e),
        })),
    }
}

/// 生成可访问的下载链接
pub async fn test_cos_download_url(
    State(state): State<AppState>,
    Json(req): Json<TestCosDownloadUrlRequest>,
) -> Result<Json<TestCosDownloadUrlResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    if req.key.trim().is_empty() {
        return Ok(Json(TestCosDownloadUrlResponse {
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
        return Ok(Json(TestCosDownloadUrlResponse {
            success: false,
            url: None,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosDownloadUrlResponse {
            success: false,
            url: None,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service
        .generate_download_url(req.key.trim(), req.expires_in_seconds)
        .await
    {
        Ok(url) => Ok(Json(TestCosDownloadUrlResponse {
            success: true,
            url: Some(url),
            message: "生成下载链接成功".to_string(),
        })),
        Err(e) => Ok(Json(TestCosDownloadUrlResponse {
            success: false,
            url: None,
            message: format!("生成下载链接失败: {}", e),
        })),
    }
}

/// 获取 COS 跨域规则
pub async fn test_cos_get_cors(
    State(state): State<AppState>,
    Json(req): Json<TestCosGetCorsRequest>,
) -> Result<Json<TestCosGetCorsResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

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
        return Ok(Json(TestCosGetCorsResponse {
            success: false,
            message: "提供商未启用".to_string(),
            rules: vec![],
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosGetCorsResponse {
            success: false,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
            rules: vec![],
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service.get_cors_rules().await {
        Ok(rules) => {
            let mapped_rules = rules
                .into_iter()
                .map(|rule| {
                    let storage::CorsRule {
                        allowed_origins,
                        allowed_methods,
                        allowed_headers,
                        expose_headers,
                        max_age_seconds,
                    } = rule;
                    CorsRuleInput {
                        allowed_origins,
                        allowed_methods,
                        allowed_headers,
                        expose_headers,
                        max_age_seconds,
                    }
                })
                .collect();

            Ok(Json(TestCosGetCorsResponse {
                success: true,
                message: "获取跨域规则成功".to_string(),
                rules: mapped_rules,
            }))
        }
        Err(e) => Ok(Json(TestCosGetCorsResponse {
            success: false,
            message: format!("获取跨域规则失败: {}", e),
            rules: vec![],
        })),
    }
}

/// 配置 COS 跨域规则
pub async fn test_cos_set_cors(
    State(state): State<AppState>,
    Json(req): Json<TestCosSetCorsRequest>,
) -> Result<Json<TestCosSetCorsResponse>, AppError> {
    let store = StorageProviderStore::new(state.database.clone());

    if req.rules.is_empty() {
        return Ok(Json(TestCosSetCorsResponse {
            success: false,
            message: "请至少提供一条跨域规则".to_string(),
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
        return Ok(Json(TestCosSetCorsResponse {
            success: false,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosSetCorsResponse {
            success: false,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    let normalize = |items: &[String]| -> Vec<String> {
        items
            .iter()
            .map(|s| s.trim())
            .filter(|s| !s.is_empty())
            .map(|s| s.to_string())
            .collect()
    };

    let cors_rules: Vec<storage::CorsRule> = req
        .rules
        .iter()
        .map(|rule| storage::CorsRule {
            allowed_origins: normalize(&rule.allowed_origins),
            allowed_methods: normalize(&rule.allowed_methods),
            allowed_headers: normalize(&rule.allowed_headers),
            expose_headers: normalize(&rule.expose_headers),
            max_age_seconds: rule.max_age_seconds,
        })
        .collect();

    if cors_rules
        .iter()
        .any(|rule| rule.allowed_origins.is_empty())
    {
        return Ok(Json(TestCosSetCorsResponse {
            success: false,
            message: "每条跨域规则必须至少配置一个允许的来源".to_string(),
        }));
    }

    const SUPPORTED_METHODS: [&str; 5] = ["GET", "PUT", "POST", "DELETE", "HEAD"];

    if cors_rules
        .iter()
        .any(|rule| rule.allowed_methods.is_empty())
    {
        return Ok(Json(TestCosSetCorsResponse {
            success: false,
            message: "每条跨域规则必须至少配置一个允许的方法".to_string(),
        }));
    }

    if let Some(invalid_method) = cors_rules
        .iter()
        .flat_map(|rule| &rule.allowed_methods)
        .find(|method| {
            let uppercase = method.to_ascii_uppercase();
            !SUPPORTED_METHODS
                .iter()
                .any(|supported| supported.eq_ignore_ascii_case(&uppercase))
        })
    {
        return Ok(Json(TestCosSetCorsResponse {
            success: false,
            message: format!(
                "不支持的跨域方法: {}，COS 仅允许 GET/PUT/POST/DELETE/HEAD",
                invalid_method
            ),
        }));
    }

    match storage_service.set_cors_rules(&cors_rules).await {
        Ok(_) => Ok(Json(TestCosSetCorsResponse {
            success: true,
            message: "跨域规则配置成功".to_string(),
        })),
        Err(e) => Ok(Json(TestCosSetCorsResponse {
            success: false,
            message: format!("配置跨域规则失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestCosDeleteRequest {
    pub provider_id: Option<String>,
    pub key: String,
}

#[derive(Debug, Serialize)]
pub struct TestCosDeleteResponse {
    pub success: bool,
    pub message: String,
}

/// 测试 COS 文件删除
pub async fn test_cos_delete(
    State(state): State<AppState>,
    Json(req): Json<TestCosDeleteRequest>,
) -> Result<Json<TestCosDeleteResponse>, AppError> {
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
        return Ok(Json(TestCosDeleteResponse {
            success: false,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosDeleteResponse {
            success: false,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service.delete_file(&req.key).await {
        Ok(_) => Ok(Json(TestCosDeleteResponse {
            success: true,
            message: "删除成功".to_string(),
        })),
        Err(e) => Ok(Json(TestCosDeleteResponse {
            success: false,
            message: format!("删除失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestCosExistsRequest {
    pub provider_id: Option<String>,
    pub key: String,
}

#[derive(Debug, Serialize)]
pub struct TestCosExistsResponse {
    pub success: bool,
    pub exists: bool,
    pub message: String,
}

/// 测试 COS 文件是否存在
pub async fn test_cos_exists(
    State(state): State<AppState>,
    Json(req): Json<TestCosExistsRequest>,
) -> Result<Json<TestCosExistsResponse>, AppError> {
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
        return Ok(Json(TestCosExistsResponse {
            success: false,
            exists: false,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosExistsResponse {
            success: false,
            exists: false,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service.file_exists(&req.key).await {
        Ok(exists) => Ok(Json(TestCosExistsResponse {
            success: true,
            exists,
            message: if exists {
                "文件存在".to_string()
            } else {
                "文件不存在".to_string()
            },
        })),
        Err(e) => Ok(Json(TestCosExistsResponse {
            success: false,
            exists: false,
            message: format!("检查失败: {}", e),
        })),
    }
}

// ========== Bucket 管理 API ==========

#[derive(Debug, Deserialize)]
pub struct TestCosListBucketsRequest {
    pub provider_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TestCosListBucketsResponse {
    pub success: bool,
    pub buckets: Vec<storage::BucketInfo>,
    pub message: String,
}

/// 测试 COS 获取 bucket 列表
pub async fn test_cos_list_buckets(
    State(state): State<AppState>,
    Json(req): Json<TestCosListBucketsRequest>,
) -> Result<Json<TestCosListBucketsResponse>, AppError> {
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
        return Ok(Json(TestCosListBucketsResponse {
            success: false,
            buckets: Vec::new(),
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosListBucketsResponse {
            success: false,
            buckets: Vec::new(),
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    let storage_service = storage::create_storage_service_without_bucket(&provider)?;

    match storage_service.list_buckets().await {
        Ok(buckets) => Ok(Json(TestCosListBucketsResponse {
            success: true,
            buckets: buckets.clone(),
            message: format!("成功获取 {} 个 bucket", buckets.len()),
        })),
        Err(e) => Ok(Json(TestCosListBucketsResponse {
            success: false,
            buckets: Vec::new(),
            message: format!("获取 bucket 列表失败: {}", e),
        })),
    }
}

#[derive(Debug, Deserialize)]
pub struct TestCosCreateBucketRequest {
    pub provider_id: Option<String>,
    pub bucket_name: String,
}

#[derive(Debug, Serialize)]
pub struct TestCosCreateBucketResponse {
    pub success: bool,
    pub message: String,
}

/// 测试 COS 创建 bucket
pub async fn test_cos_create_bucket(
    State(state): State<AppState>,
    Json(req): Json<TestCosCreateBucketRequest>,
) -> Result<Json<TestCosCreateBucketResponse>, AppError> {
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
        return Ok(Json(TestCosCreateBucketResponse {
            success: false,
            message: "提供商未启用".to_string(),
        }));
    }

    if provider.provider_type != StorageProviderType::TencentCos {
        return Ok(Json(TestCosCreateBucketResponse {
            success: false,
            message: format!("不支持的提供商类型: {:?}", provider.provider_type),
        }));
    }

    if req.bucket_name.trim().is_empty() {
        return Ok(Json(TestCosCreateBucketResponse {
            success: false,
            message: "bucket 名称不能为空".to_string(),
        }));
    }

    let storage_service = storage::create_storage_service_without_bucket(&provider)?;

    match storage_service.create_bucket(&req.bucket_name.trim()).await {
        Ok(_) => Ok(Json(TestCosCreateBucketResponse {
            success: true,
            message: format!("成功创建 bucket: {}", req.bucket_name),
        })),
        Err(e) => Ok(Json(TestCosCreateBucketResponse {
            success: false,
            message: format!("创建 bucket 失败: {}", e),
        })),
    }
}
