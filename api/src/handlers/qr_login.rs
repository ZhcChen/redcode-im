use axum::{
    extract::{Path, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::qr_login_store::QrLoginStore;
use crate::error::AppError;
use crate::handlers::auth::{generate_and_store_refresh_token, register_login_device};
use crate::models::{Claims, convert::string_to_uuid};
use crate::websocket::ServerPush;

const QR_TTL_MINUTES: i64 = 5;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateQrSessionResponse {
    pub qr_id: String,
    pub expires_at: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct QrSessionStatusResponse {
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub login_code: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct ConfirmQrSessionRequest {
    #[serde(default)]
    pub device_name: Option<String>,
    #[serde(default)]
    pub platform: Option<String>,
}

/// POST /auth/qr/sessions（PC 端创建，匿名）
pub async fn create_session(
    State(state): State<crate::AppState>,
) -> Result<Json<CreateQrSessionResponse>, AppError> {
    let store = QrLoginStore::new(state.database.clone());
    let (qr_token, expires_at) = store.create(QR_TTL_MINUTES).await?;

    Ok(Json(CreateQrSessionResponse {
        qr_id: qr_token.to_string(),
        expires_at: expires_at.to_rfc3339(),
    }))
}

/// GET /auth/qr/sessions/{qr_id}（PC 端轮询，匿名；confirmed 时一次性返回 login_code）
pub async fn get_session(
    State(state): State<crate::AppState>,
    Path(qr_id): Path<Uuid>,
) -> Result<Json<QrSessionStatusResponse>, AppError> {
    let store = QrLoginStore::new(state.database.clone());
    let record = store
        .get(qr_id)
        .await?
        .ok_or_else(|| AppError::NotFound("扫码会话不存在".to_string()))?;

    if record.status == "pending" && record.expires_at <= chrono::Utc::now() {
        store.mark_expired_if_needed(qr_id).await?;
        return Ok(Json(QrSessionStatusResponse {
            status: "expired".to_string(),
            login_code: None,
        }));
    }

    if record.status == "confirmed" {
        let login_code = store.consume_login_code(qr_id).await?;
        if login_code.is_some() {
            return Ok(Json(QrSessionStatusResponse {
                status: "confirmed".to_string(),
                login_code,
            }));
        }
        // login_code 已被取走：会话已消费，视为 expired
        return Ok(Json(QrSessionStatusResponse {
            status: "expired".to_string(),
            login_code: None,
        }));
    }

    Ok(Json(QrSessionStatusResponse {
        status: record.status,
        login_code: None,
    }))
}

/// POST /auth/qr/sessions/{qr_id}/confirm（手机端，需登录）
pub async fn confirm_session(
    State(state): State<crate::AppState>,
    Extension(claims): Extension<Claims>,
    Path(qr_id): Path<Uuid>,
    Json(payload): Json<ConfirmQrSessionRequest>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = string_to_uuid(&claims.sub)
        .map_err(|e| AppError::InvalidToken(format!("Invalid user ID in token: {}", e)))?;

    let store = QrLoginStore::new(state.database.clone());
    let record = store
        .get(qr_id)
        .await?
        .ok_or_else(|| AppError::NotFound("扫码会话不存在".to_string()))?;

    if record.status != "pending" {
        return Err(AppError::BusinessError(
            "扫码会话已处理，请刷新二维码".to_string(),
        ));
    }
    if record.expires_at <= chrono::Utc::now() {
        store.mark_expired_if_needed(qr_id).await?;
        return Err(AppError::BusinessError(
            "二维码已过期，请刷新后重试".to_string(),
        ));
    }

    let device_id = Uuid::new_v4().to_string();
    register_login_device(
        &state,
        &user_id.to_string(),
        &device_id,
        payload.device_name.as_deref(),
        payload.platform.as_deref(),
    )
    .await?;
    let login_code =
        generate_and_store_refresh_token(&state, &user_id.to_string(), false, Some(&device_id))
            .await?;

    let confirmed = store.confirm(qr_id, user_id, &login_code).await?;
    if !confirmed {
        return Err(AppError::BusinessError(
            "扫码会话已处理，请刷新二维码".to_string(),
        ));
    }

    state
        .connection_manager
        .send_to_qr(
            qr_id,
            ServerPush::QrStatusChanged {
                qr_id,
                status: "confirmed".to_string(),
                login_code: Some(login_code),
            },
        )
        .await;

    Ok(Json(serde_json::json!({ "success": true })))
}

/// POST /auth/qr/sessions/{qr_id}/cancel（PC 端取消，匿名）
pub async fn cancel_session(
    State(state): State<crate::AppState>,
    Path(qr_id): Path<Uuid>,
) -> Result<Json<serde_json::Value>, AppError> {
    let store = QrLoginStore::new(state.database.clone());
    let cancelled = store.cancel(qr_id).await?;
    if !cancelled {
        return Err(AppError::BusinessError(
            "扫码会话已处理，无法取消".to_string(),
        ));
    }

    state
        .connection_manager
        .send_to_qr(
            qr_id,
            ServerPush::QrStatusChanged {
                qr_id,
                status: "cancelled".to_string(),
                login_code: None,
            },
        )
        .await;

    Ok(Json(serde_json::json!({ "success": true })))
}
