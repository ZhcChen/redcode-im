use axum::{
    extract::{Extension, State},
    response::Json,
};
use serde::{Deserialize, Serialize};

use crate::database::settings_store::SettingsStore;
use crate::error::AppError;
use crate::models::convert::string_to_uuid;
use crate::models::Claims;
use crate::services::upload_policy::{
    get_upload_policy, invalidate_upload_policy_cache, UploadPolicy,
};
use crate::AppState;

#[derive(Debug, Serialize)]
pub struct UploadPolicyResponse {
    pub version: String,
    pub max_total_size_mb: i32,
    pub max_attachments_per_message: i32,
    pub max_size_mb_by_part_type: crate::services::upload_policy::UploadPolicyMaxSizeMbByPartType,
    pub mime_by_part_type: crate::services::upload_policy::UploadPolicyMimeByPartType,
    pub mime_whitelist: Vec<String>,
    pub audio_only: crate::services::upload_policy::AudioOnlyPolicy,
}

impl From<UploadPolicy> for UploadPolicyResponse {
    fn from(value: UploadPolicy) -> Self {
        let mime_whitelist = value.mime_whitelist();
        Self {
            version: value.version.clone(),
            max_total_size_mb: value.max_total_size_mb,
            max_attachments_per_message: value.max_attachments_per_message,
            max_size_mb_by_part_type: value.max_size_mb_by_part_type,
            mime_by_part_type: value.mime_by_part_type,
            mime_whitelist,
            audio_only: value.audio_only,
        }
    }
}

/// 获取上传策略（登录态）
///
/// - 用于客户端（Flutter/Desktop/Admin）统一附件大小/数量/MIME 白名单等限制
/// - 当后台未配置时，返回内置默认策略（与服务端校验保持一致）
pub async fn get_upload_policy_user(
    State(state): State<AppState>,
) -> Result<Json<UploadPolicyResponse>, AppError> {
    let policy = get_upload_policy(&state).await;
    Ok(Json(policy.into()))
}

#[derive(Debug, Serialize)]
pub struct UploadPolicyAdminResponse {
    pub policy: UploadPolicyResponse,
    pub updated_at: Option<String>,
    pub updated_by: Option<String>,
}

/// 获取上传策略（管理员）
pub async fn get_upload_policy_admin(
    State(state): State<AppState>,
) -> Result<Json<UploadPolicyAdminResponse>, AppError> {
    let store = SettingsStore::new(state.database.clone());
    let record = store
        .get_general_setting("upload_policy")
        .await
        .map_err(AppError::DatabaseError)?;

    let policy = get_upload_policy(&state).await;
    Ok(Json(UploadPolicyAdminResponse {
        policy: policy.into(),
        updated_at: record.as_ref().map(|r| r.updated_at.to_rfc3339()),
        updated_by: record
            .as_ref()
            .and_then(|r| r.updated_by)
            .map(|v| v.to_string()),
    }))
}

#[derive(Debug, Deserialize)]
pub struct UpdateUploadPolicyRequest {
    pub version: String,
    pub max_total_size_mb: i32,
    pub max_attachments_per_message: i32,
    pub max_size_mb_by_part_type: crate::services::upload_policy::UploadPolicyMaxSizeMbByPartType,
    pub mime_by_part_type: crate::services::upload_policy::UploadPolicyMimeByPartType,
    pub audio_only: crate::services::upload_policy::AudioOnlyPolicy,
}

/// 更新上传策略（管理员）
pub async fn update_upload_policy_admin(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(payload): Json<UpdateUploadPolicyRequest>,
) -> Result<Json<UploadPolicyAdminResponse>, AppError> {
    let editor_id = string_to_uuid(&claims.sub)?;

    let version = payload.version.trim();
    if version.is_empty() {
        return Err(AppError::ValidationError("version 不能为空".to_string()));
    }

    // 当前后端固定强制“语音不可混合其他内容”，暂不允许通过策略放开
    let default_audio_only = crate::services::upload_policy::AudioOnlyPolicy::default();
    if payload.audio_only.enabled != default_audio_only.enabled
        || payload.audio_only.force_single_attachment != default_audio_only.force_single_attachment
        || payload.audio_only.allow_text != default_audio_only.allow_text
    {
        return Err(AppError::ValidationError(
            "当前版本暂不支持修改 audio_only 规则".to_string(),
        ));
    }

    let max_total_size_mb = payload.max_total_size_mb.clamp(1, 10_000);
    let max_attachments_per_message = payload.max_attachments_per_message.clamp(0, 200);

    let mut policy = UploadPolicy {
        version: version.to_string(),
        max_total_size_mb,
        max_attachments_per_message,
        max_size_mb_by_part_type: payload.max_size_mb_by_part_type,
        mime_by_part_type: payload.mime_by_part_type,
        audio_only: default_audio_only,
    };

    // 防御：去掉空字符串，避免“空 MIME”被视为可用
    policy
        .mime_by_part_type
        .image
        .retain(|v| !v.trim().is_empty());
    policy
        .mime_by_part_type
        .video
        .retain(|v| !v.trim().is_empty());
    policy
        .mime_by_part_type
        .audio
        .retain(|v| !v.trim().is_empty());
    policy
        .mime_by_part_type
        .file
        .retain(|v| !v.trim().is_empty());

    // 防御：危险类型不允许出现在任何白名单里（即使管理员误填）
    let dangerous = crate::constants::DANGEROUS_FILE_TYPES;
    let is_dangerous = |mime: &str| dangerous.iter().any(|v| v.eq_ignore_ascii_case(mime));
    policy.mime_by_part_type.image.retain(|v| !is_dangerous(v));
    policy.mime_by_part_type.video.retain(|v| !is_dangerous(v));
    policy.mime_by_part_type.audio.retain(|v| !is_dangerous(v));
    policy.mime_by_part_type.file.retain(|v| !is_dangerous(v));

    // 统一为小写去重，避免多端判断出现歧义
    let normalize = |items: &mut Vec<String>| {
        for item in items.iter_mut() {
            *item = item.trim().to_ascii_lowercase();
        }
        items.sort();
        items.dedup();
    };
    normalize(&mut policy.mime_by_part_type.image);
    normalize(&mut policy.mime_by_part_type.video);
    normalize(&mut policy.mime_by_part_type.audio);
    normalize(&mut policy.mime_by_part_type.file);

    let raw = serde_json::to_string(&policy)
        .map_err(|e| AppError::InternalError(format!("序列化 upload policy 失败: {}", e)))?;

    let store = SettingsStore::new(state.database.clone());
    let saved = store
        .upsert_general_setting(
            "upload_policy",
            &raw,
            "上传策略：用于客户端统一附件大小/数量/MIME 白名单等限制",
            Some(editor_id),
        )
        .await
        .map_err(AppError::DatabaseError)?;

    invalidate_upload_policy_cache().await;

    Ok(Json(UploadPolicyAdminResponse {
        policy: policy.into(),
        updated_at: Some(saved.updated_at.to_rfc3339()),
        updated_by: saved.updated_by.map(|v| v.to_string()),
    }))
}
