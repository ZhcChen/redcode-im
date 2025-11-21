use axum::{extract::State, http::StatusCode, Json};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use tracing::error;
use uuid::Uuid;

use crate::services::geolocation;

use crate::error::AppError;
use crate::AppState;

#[derive(Debug, Serialize, Deserialize)]
pub struct UserHeartbeatLog {
    pub id: Uuid,
    pub user_id: Uuid,
    pub ip_address: String,
    pub user_agent: Option<String>,
    pub connection_id: String,
    pub heartbeat_at: DateTime<Utc>,
    pub node_id: Option<String>,
    pub device_info: Option<serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UserLoginHistory {
    pub id: Uuid,
    pub user_id: Uuid,
    pub ip_address: String,
    pub user_agent: Option<String>,
    pub login_method: String,
    pub login_at: DateTime<Utc>,
    pub logout_at: Option<DateTime<Utc>>,
    pub session_duration: Option<String>, // 格式化的时长字符串
    pub success: bool,
    pub failure_reason: Option<String>,
    pub device_info: Option<serde_json::Value>,
    pub location_info: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
pub struct CreateHeartbeatLogRequest {
    pub user_id: Uuid,
    pub ip_address: String,
    pub user_agent: Option<String>,
    pub connection_id: String,
    pub node_id: Option<String>,
    pub device_info: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
pub struct CreateLoginHistoryRequest {
    pub user_id: Uuid,
    pub ip_address: String,
    pub user_agent: Option<String>,
    pub login_method: String,
    pub success: bool,
    pub failure_reason: Option<String>,
    pub device_info: Option<serde_json::Value>,
}

pub async fn create_heartbeat_log(
    State(state): State<crate::AppState>,
    Json(request): Json<CreateHeartbeatLogRequest>,
) -> Result<Json<UserHeartbeatLog>, AppError> {
    let row = sqlx::query(
        r#"
        INSERT INTO user_heartbeat_logs (user_id, ip_address, user_agent, connection_id, node_id, device_info)
        VALUES ($1, $2::inet, $3, $4, $5, $6)
        RETURNING id, user_id, ip_address::text, user_agent, connection_id, heartbeat_at, node_id, device_info
        "#,
    )
    .bind(request.user_id)
    .bind(&request.ip_address)
    .bind(&request.user_agent)
    .bind(&request.connection_id)
    .bind(&request.node_id)
    .bind(&request.device_info)
    .fetch_one(&state.database.pool)
    .await
    .map_err(|e| {
        tracing::error!("创建心跳日志失败: {}", e);
        AppError::DatabaseError(e)
    })?;

    let log = UserHeartbeatLog {
        id: row.try_get("id")?,
        user_id: row.try_get("user_id")?,
        ip_address: row.try_get("ip_address")?,
        user_agent: row.try_get("user_agent")?,
        connection_id: row.try_get("connection_id")?,
        heartbeat_at: row.try_get("heartbeat_at")?,
        node_id: row.try_get("node_id")?,
        device_info: row.try_get("device_info")?,
    };

    Ok(Json(log))
}

pub async fn create_login_history(
    State(state): State<crate::AppState>,
    Json(request): Json<CreateLoginHistoryRequest>,
) -> Result<Json<UserLoginHistory>, AppError> {
    let row = sqlx::query(
        r#"
        INSERT INTO user_login_history (user_id, ip_address, user_agent, login_method, success, failure_reason, device_info)
        VALUES ($1, $2::inet, $3, $4, $5, $6, $7)
        RETURNING id, user_id, ip_address::text, user_agent, login_method, login_at, logout_at, session_duration, success, failure_reason, device_info, location_info
        "#,
    )
    .bind(request.user_id)
    .bind(&request.ip_address)
    .bind(&request.user_agent)
    .bind(&request.login_method)
    .bind(request.success)
    .bind(&request.failure_reason)
    .bind(&request.device_info)
    .fetch_one(&state.database.pool)
    .await
    .map_err(|e| {
        tracing::error!("创建登录历史失败: {}", e);
        AppError::DatabaseError(e)
    })?;

    let log = UserLoginHistory {
        id: row.try_get("id")?,
        user_id: row.try_get("user_id")?,
        ip_address: row.try_get("ip_address")?,
        user_agent: row.try_get("user_agent")?,
        login_method: row.try_get("login_method")?,
        login_at: row.try_get("login_at")?,
        logout_at: row.try_get("logout_at")?,
        session_duration: row.try_get::<Option<String>, _>("session_duration")?,
        success: row.try_get("success")?,
        failure_reason: row.try_get("failure_reason")?,
        device_info: row.try_get("device_info")?,
        location_info: row.try_get("location_info")?,
    };

    Ok(Json(log))
}

pub async fn update_login_logout(
    State(state): State<crate::AppState>,
    axum::extract::Path(log_id): axum::extract::Path<Uuid>,
) -> Result<StatusCode, AppError> {
    sqlx::query(
        r#"
        UPDATE user_login_history
        SET logout_at = NOW()
        WHERE id = $1 AND logout_at IS NULL
        "#,
    )
    .bind(log_id)
    .execute(&state.database.pool)
    .await
    .map_err(|e| {
        tracing::error!("更新登出时间失败: {}", e);
        AppError::DatabaseError(e)
    })?;

    Ok(StatusCode::NO_CONTENT)
}

pub async fn get_user_login_history(
    State(state): State<crate::AppState>,
    axum::extract::Path(user_id): axum::extract::Path<Uuid>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<UserLoginHistory>>, AppError> {
    let limit: i64 = params
        .get("limit")
        .and_then(|s| s.parse().ok())
        .unwrap_or(50);
    let offset: i64 = params
        .get("offset")
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);

    let rows = sqlx::query(
        r#"
        SELECT id, user_id, ip_address::text, user_agent, login_method, login_at, logout_at,
               session_duration, success, failure_reason, device_info, location_info
        FROM user_login_history
        WHERE user_id = $1
        ORDER BY login_at DESC
        LIMIT $2 OFFSET $3
        "#,
    )
    .bind(user_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(&state.database.pool)
    .await
    .map_err(|e| {
        tracing::error!("查询用户登录历史失败: {}", e);
        AppError::DatabaseError(e)
    })?;

    let history: Vec<UserLoginHistory> = rows
        .into_iter()
        .map(|row| -> Result<UserLoginHistory, AppError> {
            Ok(UserLoginHistory {
                id: row.try_get("id")?,
                user_id: row.try_get("user_id")?,
                ip_address: row.try_get("ip_address")?,
                user_agent: row.try_get("user_agent")?,
                login_method: row.try_get("login_method")?,
                login_at: row.try_get("login_at")?,
                logout_at: row.try_get("logout_at")?,
                session_duration: row.try_get::<Option<String>, _>("session_duration")?,
                success: row.try_get("success")?,
                failure_reason: row.try_get("failure_reason")?,
                device_info: row.try_get("device_info")?,
                location_info: row.try_get("location_info")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(history))
}

pub async fn get_user_heartbeat_logs(
    State(state): State<crate::AppState>,
    axum::extract::Path(user_id): axum::extract::Path<Uuid>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Vec<UserHeartbeatLog>>, AppError> {
    let limit: i64 = params
        .get("limit")
        .and_then(|s| s.parse().ok())
        .unwrap_or(100);
    let offset: i64 = params
        .get("offset")
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);
    let since = params
        .get("since")
        .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok());

    let mut query = r#"
        SELECT id, user_id, ip_address::text, user_agent, connection_id, heartbeat_at, node_id, device_info
        FROM user_heartbeat_logs
        WHERE user_id = $1
    "#.to_string();

    let mut param_count = 1;
    let mut bind_values: Vec<Box<dyn sqlx::Encode<'_, sqlx::Postgres> + Send + Sync>> =
        vec![Box::new(user_id)];

    if let Some(since_dt) = since {
        param_count += 1;
        query.push_str(&format!(" AND heartbeat_at >= ${}", param_count));
        bind_values.push(Box::new(since_dt.with_timezone(&Utc)));
    }

    query.push_str(&format!(
        " ORDER BY heartbeat_at DESC LIMIT ${} OFFSET ${}",
        param_count + 1,
        param_count + 2
    ));
    bind_values.push(Box::new(limit));
    bind_values.push(Box::new(offset));

    // 由于sqlx的复杂绑定，这里简化处理，直接使用时间字符串
    let rows = if let Some(since_dt) = since {
        sqlx::query(
            r#"
            SELECT id, user_id, ip_address::text, user_agent, connection_id, heartbeat_at, node_id, device_info
            FROM user_heartbeat_logs
            WHERE user_id = $1 AND heartbeat_at >= $2
            ORDER BY heartbeat_at DESC
            LIMIT $3 OFFSET $4
            "#,
        )
        .bind(user_id)
        .bind(since_dt.with_timezone(&Utc))
        .bind(limit)
        .bind(offset)
        .fetch_all(&state.database.pool)
        .await
    } else {
        sqlx::query(
            r#"
            SELECT id, user_id, ip_address::text, user_agent, connection_id, heartbeat_at, node_id, device_info
            FROM user_heartbeat_logs
            WHERE user_id = $1
            ORDER BY heartbeat_at DESC
            LIMIT $2 OFFSET $3
            "#,
        )
        .bind(user_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(&state.database.pool)
        .await
    }.map_err(|e| {
        tracing::error!("查询用户心跳日志失败: {}", e);
        AppError::DatabaseError(e)
    })?;

    let logs: Vec<UserHeartbeatLog> = rows
        .into_iter()
        .map(|row| -> Result<UserHeartbeatLog, AppError> {
            Ok(UserHeartbeatLog {
                id: row.try_get("id")?,
                user_id: row.try_get("user_id")?,
                ip_address: row.try_get("ip_address")?,
                user_agent: row.try_get("user_agent")?,
                connection_id: row.try_get("connection_id")?,
                heartbeat_at: row.try_get("heartbeat_at")?,
                node_id: row.try_get("node_id")?,
                device_info: row.try_get("device_info")?,
            })
        })
        .collect::<Result<Vec<_>, _>>()?;

    Ok(Json(logs))
}

pub async fn get_user_geolocation(
    State(_state): State<crate::AppState>,
    axum::extract::Path(user_id): axum::extract::Path<Uuid>,
) -> Result<Json<Option<serde_json::Value>>, AppError> {
    if let Some(geolocation_service) = geolocation::get_geolocation_service() {
        let geolocation = geolocation_service.get_user_geolocation(&user_id).await?;
        match geolocation {
            Some(loc) => Ok(Json(Some(serde_json::to_value(loc).map_err(|e| {
                error!("序列化地理位置信息失败: {}", e);
                AppError::DatabaseError(sqlx::Error::RowNotFound)
            })?))),
            None => Ok(Json(None)),
        }
    } else {
        Ok(Json(None))
    }
}

/// 获取全球用户分布数据（用于地图显示）
pub async fn get_global_user_distribution(
    State(_state): State<AppState>,
) -> Result<Json<Vec<crate::services::geolocation::UserLocationMapData>>, AppError> {
    if let Some(geolocation_service) = crate::services::geolocation::get_geolocation_service() {
        let distribution = geolocation_service.get_global_user_distribution().await?;
        Ok(Json(distribution))
    } else {
        Err(AppError::InternalError("地理位置服务未初始化".to_string()))
    }
}
