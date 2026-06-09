use axum::{
    extract::{Extension, Json, State},
    response::IntoResponse,
};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;

use crate::{
    models::Claims,
    services::storage_config::{StorageConfigService, UpsertInput},
    AppError, AppState,
};

#[derive(Debug, Deserialize)]
pub struct AdminStorageConfigPayload {
    pub endpoint: Option<String>,
    pub region: Option<String>,
    pub key_id: Option<String>,
    pub application_key: Option<String>,
    pub private_bucket: Option<String>,
    pub public_bucket: Option<String>,
    pub public_base_url: Option<String>,
    pub upload_url_ttl_seconds: Option<u32>,
    pub download_url_ttl_seconds: Option<u32>,
}

impl From<AdminStorageConfigPayload> for UpsertInput {
    fn from(value: AdminStorageConfigPayload) -> Self {
        UpsertInput {
            endpoint: value.endpoint,
            region: value.region,
            key_id: value.key_id,
            application_key: value.application_key,
            private_bucket: value.private_bucket,
            public_bucket: value.public_bucket,
            public_base_url: value.public_base_url,
            upload_url_ttl_seconds: value.upload_url_ttl_seconds,
            download_url_ttl_seconds: value.download_url_ttl_seconds,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct WrappedStorageConfigPayload {
    pub config: AdminStorageConfigPayload,
}

#[derive(Debug, Deserialize)]
pub struct ApplyStorageConfigPayload {
    pub config: AdminStorageConfigPayload,
    pub change_note: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct RollbackStorageConfigPayload {
    pub target_version: i32,
    pub reason: Option<String>,
}

pub async fn get_storage_config(
    State(state): State<AppState>,
) -> Result<impl IntoResponse, AppError> {
    let service = StorageConfigService::new(state.database.clone());
    let current = service.get_current_summary().await?;
    Ok(Json(json!({ "current": current })))
}

pub async fn validate_storage_config(
    State(state): State<AppState>,
    Json(payload): Json<WrappedStorageConfigPayload>,
) -> Result<impl IntoResponse, AppError> {
    let service = StorageConfigService::new(state.database.clone());
    let normalized = service.validate(payload.config.into()).await?;
    Ok(Json(json!({ "valid": true, "normalized": normalized })))
}

pub async fn probe_storage_config(
    State(state): State<AppState>,
    Json(payload): Json<WrappedStorageConfigPayload>,
) -> Result<impl IntoResponse, AppError> {
    let service = StorageConfigService::new(state.database.clone());
    let (normalized, probe) = service.probe(payload.config.into()).await?;
    Ok(Json(json!({ "normalized": normalized, "probe": probe })))
}

pub async fn apply_storage_config(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<ApplyStorageConfigPayload>,
) -> Result<impl IntoResponse, AppError> {
    let service = StorageConfigService::new(state.database.clone());
    let updated_by = Uuid::parse_str(&claims.sub).ok();
    let actor = optional_actor(&claims);
    let current = service
        .apply(
            payload.config.into(),
            actor,
            payload.change_note.as_deref(),
            updated_by,
        )
        .await?;
    Ok(Json(json!({
        "version": current.version,
        "applied_at": current.last_applied_at,
        "current": current,
    })))
}

pub async fn init_storage_buckets(
    State(state): State<AppState>,
) -> Result<impl IntoResponse, AppError> {
    let service = StorageConfigService::new(state.database.clone());
    let (current, result) = service.init_buckets().await?;
    Ok(Json(json!({ "current": current, "result": result })))
}

pub async fn list_storage_config_history(
    State(state): State<AppState>,
) -> Result<impl IntoResponse, AppError> {
    let service = StorageConfigService::new(state.database.clone());
    let list = service.list_history().await?;
    Ok(Json(json!({ "list": list })))
}

pub async fn rollback_storage_config(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<RollbackStorageConfigPayload>,
) -> Result<impl IntoResponse, AppError> {
    let service = StorageConfigService::new(state.database.clone());
    let updated_by = Uuid::parse_str(&claims.sub).ok();
    let actor = optional_actor(&claims);
    let current = service
        .rollback(
            payload.target_version,
            actor,
            payload.reason.as_deref(),
            updated_by,
        )
        .await?;
    Ok(Json(json!({
        "version": current.version,
        "rolled_back_from_version": current.rollback_source_version,
        "applied_at": current.last_applied_at,
        "current": current,
    })))
}

fn optional_actor(claims: &Claims) -> Option<&str> {
    let username = claims.username.trim();
    if username.is_empty() {
        None
    } else {
        Some(username)
    }
}
