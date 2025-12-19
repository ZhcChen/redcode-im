use axum::{
    extract::{Extension, Path, State},
    response::Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::database::file_upload_multipart_store::FileUploadMultipartStore;
use crate::database::file_upload_store::FileUploadStore;
use crate::error::AppError;
use crate::models::Claims;
use crate::storage;
use crate::storage::DirectUploadSignature;
use crate::AppState;

#[derive(Debug, Serialize)]
pub struct MultipartSessionInfo {
    pub session_id: String,
    pub object_key: String,
    pub part_size: i32,
    pub total_parts: i32,
    pub status: i16,
    pub uploaded_parts: serde_json::Value,
}

#[derive(Debug, Serialize)]
pub struct MultipartSessionResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub session: Option<MultipartSessionInfo>,
}

pub async fn get_multipart_session(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<MultipartSessionResponse>, AppError> {
    let session_uuid = Uuid::parse_str(session_id.trim())
        .map_err(|_| AppError::ValidationError("无效的 session_id".to_string()))?;

    let requester_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = FileUploadMultipartStore::new(state.database.clone());
    let session = store
        .get_session(&session_uuid)
        .await
        .map_err(|e| AppError::InternalError(format!("读取分片会话失败: {}", e)))?
        .ok_or_else(|| AppError::NotFound("分片会话不存在".to_string()))?;

    if session.creator_id != requester_id || session.creator_is_admin != claims.is_admin {
        return Err(AppError::Forbidden("无权限访问该分片会话".to_string()));
    }

    Ok(Json(MultipartSessionResponse {
        success: true,
        message: "ok".to_string(),
        session: Some(MultipartSessionInfo {
            session_id: session.id.to_string(),
            object_key: session.object_key,
            part_size: session.part_size,
            total_parts: session.total_parts,
            status: session.status,
            uploaded_parts: session.uploaded_parts,
        }),
    }))
}

#[derive(Debug, Deserialize)]
pub struct PartSignatureRequest {
    pub part_number: i32,
}

#[derive(Debug, Serialize)]
pub struct PartSignatureResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub signature: Option<DirectUploadSignature>,
}

pub async fn generate_multipart_part_signature(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<PartSignatureRequest>,
) -> Result<Json<PartSignatureResponse>, AppError> {
    let session_uuid = Uuid::parse_str(session_id.trim())
        .map_err(|_| AppError::ValidationError("无效的 session_id".to_string()))?;

    if req.part_number <= 0 {
        return Err(AppError::ValidationError(
            "part_number 必须大于 0".to_string(),
        ));
    }

    let requester_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = FileUploadMultipartStore::new(state.database.clone());
    let session = store
        .get_session(&session_uuid)
        .await
        .map_err(|e| AppError::InternalError(format!("读取分片会话失败: {}", e)))?
        .ok_or_else(|| AppError::NotFound("分片会话不存在".to_string()))?;

    if session.creator_id != requester_id || session.creator_is_admin != claims.is_admin {
        return Err(AppError::Forbidden("无权限访问该分片会话".to_string()));
    }

    if session.status != 0 {
        return Err(AppError::ValidationError(
            "分片会话已结束，无法继续签名".to_string(),
        ));
    }

    if session.total_parts > 0 && req.part_number > session.total_parts {
        return Err(AppError::ValidationError(format!(
            "part_number 超出范围（1..={}）",
            session.total_parts
        )));
    }

    let provider = crate::handlers::user::load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    if provider.id != session.storage_provider_id {
        return Err(AppError::ValidationError(
            "分片会话的存储提供商与当前默认提供商不一致".to_string(),
        ));
    }

    let signature = storage_service
        .generate_multipart_upload_part_signature(
            &session.object_key,
            &session.upload_id,
            req.part_number,
            session.content_type.as_deref(),
        )
        .await?;

    Ok(Json(PartSignatureResponse {
        success: true,
        message: "ok".to_string(),
        signature: Some(signature),
    }))
}

#[derive(Debug, Deserialize)]
pub struct PartCommitRequest {
    pub part_number: i32,
    pub etag: String,
}

#[derive(Debug, Serialize)]
pub struct PartCommitResponse {
    pub success: bool,
    pub message: String,
}

pub async fn commit_multipart_part(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<PartCommitRequest>,
) -> Result<Json<PartCommitResponse>, AppError> {
    let session_uuid = Uuid::parse_str(session_id.trim())
        .map_err(|_| AppError::ValidationError("无效的 session_id".to_string()))?;

    if req.part_number <= 0 {
        return Err(AppError::ValidationError(
            "part_number 必须大于 0".to_string(),
        ));
    }

    if req.etag.trim().is_empty() {
        return Err(AppError::ValidationError("etag 不能为空".to_string()));
    }

    let requester_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = FileUploadMultipartStore::new(state.database.clone());
    let session = store
        .get_session(&session_uuid)
        .await
        .map_err(|e| AppError::InternalError(format!("读取分片会话失败: {}", e)))?
        .ok_or_else(|| AppError::NotFound("分片会话不存在".to_string()))?;

    if session.creator_id != requester_id || session.creator_is_admin != claims.is_admin {
        return Err(AppError::Forbidden("无权限访问该分片会话".to_string()));
    }

    if session.status != 0 {
        return Err(AppError::ValidationError(
            "分片会话已结束，无法提交分片".to_string(),
        ));
    }

    if session.total_parts > 0 && req.part_number > session.total_parts {
        return Err(AppError::ValidationError(format!(
            "part_number 超出范围（1..={}）",
            session.total_parts
        )));
    }

    store
        .upsert_part_etag(&session_uuid, req.part_number, req.etag.trim())
        .await
        .map_err(|e| AppError::InternalError(format!("写入分片进度失败: {}", e)))?;

    Ok(Json(PartCommitResponse {
        success: true,
        message: "ok".to_string(),
    }))
}

#[derive(Debug, Deserialize)]
pub struct CompleteMultipartRequest {
    pub parts: Vec<CompletedPart>,
}

#[derive(Debug, Deserialize)]
pub struct CompletedPart {
    pub part_number: i32,
    pub etag: String,
}

#[derive(Debug, Serialize)]
pub struct CompleteMultipartResponse {
    pub success: bool,
    pub message: String,
}

pub async fn complete_multipart_upload(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<CompleteMultipartRequest>,
) -> Result<Json<CompleteMultipartResponse>, AppError> {
    let session_uuid = Uuid::parse_str(session_id.trim())
        .map_err(|_| AppError::ValidationError("无效的 session_id".to_string()))?;

    if req.parts.is_empty() {
        return Err(AppError::ValidationError("parts 不能为空".to_string()));
    }

    let requester_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = FileUploadMultipartStore::new(state.database.clone());
    let session = store
        .get_session(&session_uuid)
        .await
        .map_err(|e| AppError::InternalError(format!("读取分片会话失败: {}", e)))?
        .ok_or_else(|| AppError::NotFound("分片会话不存在".to_string()))?;

    if session.creator_id != requester_id || session.creator_is_admin != claims.is_admin {
        return Err(AppError::Forbidden("无权限访问该分片会话".to_string()));
    }

    if session.status != 0 {
        return Err(AppError::ValidationError(
            "分片会话已结束，无法完成合并".to_string(),
        ));
    }

    let mut parts: Vec<(i32, String)> = Vec::with_capacity(req.parts.len());
    for part in &req.parts {
        if part.part_number <= 0 {
            return Err(AppError::ValidationError(
                "part_number 必须大于 0".to_string(),
            ));
        }
        if part.etag.trim().is_empty() {
            return Err(AppError::ValidationError("etag 不能为空".to_string()));
        }
        parts.push((part.part_number, part.etag.trim().to_string()));
    }

    parts.sort_by_key(|(n, _)| *n);
    parts.dedup_by_key(|(n, _)| *n);

    if session.total_parts > 0 {
        if parts.len() != session.total_parts as usize {
            return Err(AppError::ValidationError(format!(
                "分片数量不完整：期望 {} 个，实际 {} 个",
                session.total_parts,
                parts.len()
            )));
        }
        for (idx, (part_number, _)) in parts.iter().enumerate() {
            let expected = (idx as i32) + 1;
            if *part_number != expected {
                return Err(AppError::ValidationError(format!(
                    "分片编号不连续：期望 part_number={}，实际 {}",
                    expected, part_number
                )));
            }
        }
    }

    let provider = crate::handlers::user::load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    if provider.id != session.storage_provider_id {
        return Err(AppError::ValidationError(
            "分片会话的存储提供商与当前默认提供商不一致".to_string(),
        ));
    }

    storage_service
        .complete_multipart_upload(&session.object_key, &session.upload_id, &parts)
        .await?;

    let uploaded_parts_json = serde_json::json!(parts
        .iter()
        .map(|(n, etag)| (n.to_string(), serde_json::Value::String(etag.clone())))
        .collect::<serde_json::Map<String, serde_json::Value>>());

    let _ = store
        .mark_completed(&session_uuid, Some(&uploaded_parts_json))
        .await
        .map_err(|e| AppError::InternalError(format!("更新分片会话状态失败: {}", e)))?;

    // 若存在 file_upload_records 记录，尝试标记为完成（不存在则忽略）
    let upload_store = FileUploadStore::new(state.database.clone());
    let _ = upload_store
        .mark_completed_by_key(&provider.id, &session.object_key)
        .await;

    Ok(Json(CompleteMultipartResponse {
        success: true,
        message: "完成分片上传成功".to_string(),
    }))
}

#[derive(Debug, Serialize)]
pub struct AbortMultipartResponse {
    pub success: bool,
    pub message: String,
}

pub async fn abort_multipart_upload(
    State(state): State<AppState>,
    Path(session_id): Path<String>,
    Extension(claims): Extension<Claims>,
) -> Result<Json<AbortMultipartResponse>, AppError> {
    let session_uuid = Uuid::parse_str(session_id.trim())
        .map_err(|_| AppError::ValidationError("无效的 session_id".to_string()))?;

    let requester_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let store = FileUploadMultipartStore::new(state.database.clone());
    let session = store
        .get_session(&session_uuid)
        .await
        .map_err(|e| AppError::InternalError(format!("读取分片会话失败: {}", e)))?
        .ok_or_else(|| AppError::NotFound("分片会话不存在".to_string()))?;

    if session.creator_id != requester_id || session.creator_is_admin != claims.is_admin {
        return Err(AppError::Forbidden("无权限访问该分片会话".to_string()));
    }

    if session.status != 0 {
        return Ok(Json(AbortMultipartResponse {
            success: true,
            message: "分片会话已结束".to_string(),
        }));
    }

    let provider = crate::handlers::user::load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    if provider.id != session.storage_provider_id {
        return Err(AppError::ValidationError(
            "分片会话的存储提供商与当前默认提供商不一致".to_string(),
        ));
    }

    let _ = storage_service
        .abort_multipart_upload(&session.object_key, &session.upload_id)
        .await;

    let _ = store
        .mark_aborted(&session_uuid)
        .await
        .map_err(|e| AppError::InternalError(format!("更新分片会话状态失败: {}", e)))?;

    Ok(Json(AbortMultipartResponse {
        success: true,
        message: "已中止分片上传".to_string(),
    }))
}
