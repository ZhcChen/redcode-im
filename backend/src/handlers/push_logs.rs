use axum::{
    extract::{Extension, Query, State},
    response::Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tracing::info;
use uuid::Uuid;

use crate::database::push_log_store::{
    PushLogQueryParams as StorePushLogQueryParams, PushLogStore,
};
use crate::error::AppError;
use crate::i18n::{localizer::default_localizer, message::MessageParams};
use crate::middleware::current_request_locale;
use crate::models::Claims;
use crate::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PushLogQueryParams {
    pub push_id: Option<String>,
    pub user_id: Option<String>,
    pub device_id: Option<String>,
    pub platform: Option<String>,
    pub channel: Option<String>,
    pub provider: Option<String>,
    pub event_type: Option<String>,
    pub success: Option<bool>,
    pub room_id: Option<String>,
    pub message_id: Option<String>,
    pub request_id: Option<String>,
    pub keyword: Option<String>,
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PushLogEntry {
    pub id: String,
    pub push_id: String,
    pub user_id: String,
    pub username: Option<String>,
    pub nickname: Option<String>,
    pub device_id: String,
    pub platform: String,
    pub channel: String,
    pub provider: String,
    pub event_type: String,
    pub room_id: Option<String>,
    pub message_id: Option<String>,
    pub request_id: Option<String>,
    pub title: Option<String>,
    pub body: Option<String>,
    pub data: serde_json::Value,
    pub attempt: i32,
    pub success: bool,
    pub error: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PushLogsResponse {
    pub logs: Vec<PushLogEntry>,
    pub total: i64,
    pub limit: i64,
    pub offset: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PushLogCleanupRequest {
    pub retention_days: i64,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PushLogCleanupResponse {
    pub success: bool,
    pub deleted_count: u64,
    pub message: String,
}

fn push_logs_validation_error(message_key: &'static str) -> AppError {
    AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn push_logs_validation_error_with_params(
    message_key: &'static str,
    params: MessageParams,
) -> AppError {
    AppError::ValidationError(String::new()).with_message_key_and_params(message_key, Some(params))
}

fn push_logs_localized_message(
    message_key: &'static str,
    params: Option<&MessageParams>,
) -> String {
    let localizer = default_localizer();
    let locale =
        current_request_locale().unwrap_or_else(|| localizer.fallback_locale().to_string());
    localizer.localize(&locale, message_key, params)
}

/// 查询 push 发送日志（需要管理员权限）
pub async fn list_push_logs(
    State(state): State<AppState>,
    Extension(_claims): Extension<Claims>,
    Query(params): Query<PushLogQueryParams>,
) -> Result<Json<PushLogsResponse>, AppError> {
    let store = PushLogStore::new(state.database.pool());

    let store_params = StorePushLogQueryParams {
        push_id: parse_uuid_optional(params.push_id.as_deref())?,
        user_id: parse_uuid_optional(params.user_id.as_deref())?,
        device_id: params.device_id,
        platform: params.platform,
        channel: params.channel,
        provider: params.provider,
        event_type: params.event_type,
        success: params.success,
        room_id: parse_uuid_optional(params.room_id.as_deref())?,
        message_id: parse_uuid_optional(params.message_id.as_deref())?,
        request_id: parse_uuid_optional(params.request_id.as_deref())?,
        keyword: params.keyword,
        start_time: params.start_time,
        end_time: params.end_time,
        limit: params.limit,
        offset: params.offset,
    };

    let result = store
        .query(&store_params)
        .await
        .map_err(AppError::DatabaseError)?;

    let logs = result
        .logs
        .into_iter()
        .map(|entry| PushLogEntry {
            id: entry.id.to_string(),
            push_id: entry.push_id.to_string(),
            user_id: entry.user_id.to_string(),
            username: entry.username,
            nickname: entry.nickname,
            device_id: entry.device_id,
            platform: entry.platform,
            channel: entry.channel,
            provider: entry.provider,
            event_type: entry.event_type,
            room_id: entry.room_id.map(|id| id.to_string()),
            message_id: entry.message_id.map(|id| id.to_string()),
            request_id: entry.request_id.map(|id| id.to_string()),
            title: entry.title,
            body: entry.body,
            data: entry.data,
            attempt: entry.attempt,
            success: entry.success,
            error: entry.error,
            created_at: entry.created_at.to_rfc3339(),
        })
        .collect();

    Ok(Json(PushLogsResponse {
        logs,
        total: result.total,
        limit: result.limit,
        offset: result.offset,
    }))
}

/// 清理 push 发送日志（需要管理员权限）
pub async fn cleanup_push_logs(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<PushLogCleanupRequest>,
) -> Result<Json<PushLogCleanupResponse>, AppError> {
    if req.retention_days < 1 {
        return Err(push_logs_validation_error(
            "admin.log_cleanup_retention_days_invalid",
        ));
    }

    info!(
        "管理员 {} 请求清理 push_logs，保留 {} 天内的日志",
        claims.sub, req.retention_days
    );

    let store = PushLogStore::new(state.database.pool());
    let deleted_count = store
        .cleanup(req.retention_days)
        .await
        .map_err(AppError::DatabaseError)?;

    let message_params = MessageParams::from([
        ("deleted_count".to_string(), deleted_count.to_string()),
        ("retention_days".to_string(), req.retention_days.to_string()),
    ]);

    Ok(Json(PushLogCleanupResponse {
        success: true,
        deleted_count,
        message: push_logs_localized_message(
            "admin.push_log_cleanup_success",
            Some(&message_params),
        ),
    }))
}

fn parse_uuid_optional(value: Option<&str>) -> Result<Option<Uuid>, AppError> {
    let Some(value) = value else {
        return Ok(None);
    };

    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }

    Ok(Some(Uuid::parse_str(trimmed).map_err(|_| {
        push_logs_validation_error_with_params(
            "admin.push_log_query_uuid_invalid",
            MessageParams::from([("value".to_string(), trimmed.to_string())]),
        )
    })?))
}

#[cfg(test)]
mod push_logs_i18n_tests {
    use super::parse_uuid_optional;

    #[test]
    fn parse_uuid_optional_invalid_returns_stable_key_and_params() {
        let error = parse_uuid_optional(Some("not-a-uuid")).expect_err("invalid uuid should fail");

        assert_eq!(
            error.response_message_key(),
            "admin.push_log_query_uuid_invalid"
        );
        let params = error.message_params().expect("params present");
        assert_eq!(params["value"], "not-a-uuid");
        assert_eq!(
            error.localized_message(),
            "\u{65e0}\u{6548}\u{7684} UUID: not-a-uuid"
        );
    }

    #[test]
    fn push_logs_errors_should_not_embed_legacy_uuid_literal() {
        let source = include_str!("push_logs.rs");
        let legacy = "\u{65e0}\u{6548}\u{7684} UUID";

        assert!(
            !source.contains(legacy),
            "push_logs uuid validation should not embed legacy literal: {legacy}"
        );
    }
}
