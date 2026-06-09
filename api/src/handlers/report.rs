use axum::{
    extract::{Extension, Query, State},
    response::Json,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    database::{
        file_upload_audit_store::FileUploadAuditStore,
        file_upload_store::FileUploadStore,
        message_store::MessageStore,
        report_store::{AdminReportListFilters, ReportAttachmentInsert, ReportInsert, ReportStore},
        user_store::UserStore,
    },
    error::AppError,
    handlers::user::load_default_storage_provider,
    models::Claims,
    redis::cache::CacheManager,
    redis::models::CacheKeys,
    storage,
    storage::DirectUploadSignature,
    AppState,
};

#[derive(Debug, Deserialize)]
pub struct ReportAttachmentSignatureRequest {
    pub filename: Option<String>,
    pub content_type: String,
    pub file_size: usize,
    /// 文件哈希值（由前端计算并上报，十六进制字符串）
    pub hash_value: Option<String>,
    /// 哈希算法：1=md5, 2=sha256；缺省视为 1
    pub hash_alg: Option<i16>,
}

#[derive(Debug, Serialize)]
pub struct ReportAttachmentSignatureResponse {
    pub success: bool,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub key: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub signature: Option<DirectUploadSignature>,
}

#[derive(Debug, Deserialize)]
pub struct ReportAttachmentUploadCommitRequest {
    pub key: String,
    pub hash_value: Option<String>,
    pub hash_alg: Option<i16>,
    pub file_size: Option<usize>,
}

#[derive(Debug, Serialize)]
pub struct ReportAttachmentUploadCommitResponse {
    pub success: bool,
    pub message: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReportTargetType {
    Room,
    User,
}

impl ReportTargetType {
    fn to_db_value(&self) -> i32 {
        match self {
            ReportTargetType::Room => 1,
            ReportTargetType::User => 2,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateReportRequest {
    pub target_type: ReportTargetType,
    pub target_id: String,
    pub content: String,
    pub attachment_keys: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct CreateReportResponse {
    pub success: bool,
    pub message: String,
    pub report_id: String,
}

fn infer_image_extension(filename: Option<&str>, content_type: &str) -> &'static str {
    if let Some(name) = filename {
        if let Some(ext) = name.rsplit('.').next() {
            let normalized = ext.trim().to_ascii_lowercase();
            match normalized.as_str() {
                "png" => return ".png",
                "jpg" | "jpeg" => return ".jpg",
                "webp" => return ".webp",
                "gif" => return ".gif",
                "heic" => return ".heic",
                "heif" => return ".heif",
                "bmp" => return ".bmp",
                "tiff" | "tif" => return ".tiff",
                _ => {}
            }
        }
    }

    let normalized = content_type.trim().to_ascii_lowercase();
    match normalized.as_str() {
        "image/png" => ".png",
        "image/jpg" | "image/jpeg" => ".jpg",
        "image/webp" => ".webp",
        "image/gif" => ".gif",
        "image/heic" => ".heic",
        "image/heif" => ".heif",
        "image/bmp" => ".bmp",
        "image/tiff" => ".tiff",
        _ => "",
    }
}

fn build_report_attachment_key(
    user_id: &Uuid,
    filename: Option<&str>,
    content_type: &str,
) -> String {
    let date = Utc::now().format("%Y%m%d");
    let random = Uuid::new_v4().simple().to_string();
    let ext = infer_image_extension(filename, content_type);
    format!("reports/{}/{}/{}{}", user_id, date, &random[..16], ext)
}

fn is_valid_report_attachment_object_key(key: &str, user_id: &Uuid) -> bool {
    let trimmed = key.trim();
    if trimmed.is_empty() {
        return false;
    }

    if trimmed.contains("..") || trimmed.contains('\\') {
        return false;
    }

    let prefix = format!("reports/{}/", user_id);
    trimmed.starts_with(&prefix)
}

pub async fn generate_report_attachment_signature(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<ReportAttachmentSignatureRequest>,
) -> Result<Json<ReportAttachmentSignatureResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let content_type = req.content_type.trim();
    if content_type.is_empty() {
        return Err(AppError::ValidationError(
            "content_type 不能为空".to_string(),
        ));
    }
    if !crate::constants::is_image_content_type(content_type) {
        return Err(AppError::ValidationError(
            "举报截图仅支持图片类型文件".to_string(),
        ));
    }

    // 举报截图属于普通图片附件，不应受头像 5MB 限制
    let max_size = crate::constants::IMAGE_MAX_SIZE_BYTES;
    if req.file_size == 0 || req.file_size > max_size {
        return Err(AppError::ValidationError(format!(
            "截图大小超出限制，最大允许{}MB",
            max_size / 1024 / 1024
        )));
    }

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    let key = build_report_attachment_key(&user_id, req.filename.as_deref(), content_type);

    // 若提供 hash 信息，则记录一条“上传中”的文件记录，供后续清理/追踪使用
    if let Some(hash_value) = req.hash_value.as_deref() {
        let hash_value = hash_value.trim();
        if !hash_value.is_empty() {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let upload_store = FileUploadStore::new(state.database.clone());
            let _ = upload_store
                .create_pending_record(
                    &provider.id,
                    &key,
                    hash_alg,
                    hash_value,
                    Some(req.file_size as i64),
                    Some(content_type),
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    let signature = storage_service
        .generate_direct_upload_signature(&key, Some(content_type))
        .await?;

    Ok(Json(ReportAttachmentSignatureResponse {
        success: true,
        message: "生成举报截图直传签名成功".to_string(),
        key: Some(key),
        signature: Some(signature),
    }))
}

pub async fn commit_report_attachment_upload(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<ReportAttachmentUploadCommitRequest>,
) -> Result<Json<ReportAttachmentUploadCommitResponse>, AppError> {
    let user_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let key = req.key.trim();
    if key.is_empty() {
        return Err(AppError::ValidationError("key 不能为空".to_string()));
    }

    if !is_valid_report_attachment_object_key(key, &user_id) {
        return Err(AppError::ValidationError("举报截图 key 不合法".to_string()));
    }

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    match storage_service.head_object(key).await {
        Ok(_) => {}
        Err(AppError::ValidationError(_)) => {
            if !storage_service.file_exists(key).await? {
                return Err(AppError::ValidationError(
                    "对象存储中尚未找到该截图，请稍后重试".to_string(),
                ));
            }
        }
        Err(AppError::NotFound(_)) => {
            return Err(AppError::ValidationError(
                "对象存储中尚未找到该截图，请稍后重试".to_string(),
            ));
        }
        Err(e) => return Err(e),
    }

    let upload_store = FileUploadStore::new(state.database.clone());

    // 若签名阶段未写入 hash 记录，但 commit 阶段上报了 hash，则补写 pending 记录
    if let (Some(ref hash_value), Some(file_size)) = (&req.hash_value, req.file_size) {
        let hash_value = hash_value.trim();
        if !hash_value.is_empty() && file_size > 0 {
            let hash_alg = req.hash_alg.unwrap_or(1);
            let _ = upload_store
                .create_pending_record(
                    &provider.id,
                    key,
                    hash_alg,
                    hash_value,
                    Some(file_size as i64),
                    None,
                )
                .await
                .map_err(AppError::from)?;
        }
    }

    let _ = upload_store
        .mark_completed_by_key(&provider.id, key)
        .await
        .map_err(AppError::from)?;

    // 写入内容审核任务（异步队列；违规会删除对象并记录原因）
    let record = upload_store
        .get_by_key(&provider.id, key)
        .await
        .map_err(AppError::from)?;
    let audit_store = FileUploadAuditStore::new(state.database.clone());
    let content_type = record.as_ref().and_then(|r| r.content_type.as_deref());
    let file_size = record
        .as_ref()
        .and_then(|r| r.file_size)
        .or(req.file_size.map(|v| v as i64));
    let _ = audit_store
        .upsert_task(
            &provider.id,
            key,
            "report_attachment",
            "image",
            content_type,
            file_size,
        )
        .await
        .map_err(AppError::from)?;

    Ok(Json(ReportAttachmentUploadCommitResponse {
        success: true,
        message: "举报截图上传完成".to_string(),
    }))
}

pub async fn create_report(
    State(state): State<AppState>,
    Extension(claims): Extension<Claims>,
    Json(req): Json<CreateReportRequest>,
) -> Result<Json<CreateReportResponse>, AppError> {
    let reporter_id = Uuid::parse_str(&claims.sub)
        .map_err(|_| AppError::InvalidToken("Invalid user ID in token".to_string()))?;

    let content = req.content.trim();
    if content.is_empty() {
        return Err(AppError::ValidationError("举报内容不能为空".to_string()));
    }

    let mut keys: Vec<String> = req
        .attachment_keys
        .into_iter()
        .map(|k| k.trim().to_string())
        .filter(|k| !k.is_empty())
        .collect();

    keys.sort();
    keys.dedup();

    if keys.is_empty() {
        return Err(AppError::ValidationError(
            "举报必须上传至少 1 张截图".to_string(),
        ));
    }

    // 校验 target
    let target_uuid = Uuid::parse_str(req.target_id.trim())
        .map_err(|_| AppError::ValidationError("target_id 不合法".to_string()))?;

    // 访问控制校验
    match req.target_type {
        ReportTargetType::Room => {
            let room_id = target_uuid;
            let store = MessageStore::new(state.database.pool());
            if !store.user_in_room(room_id, reporter_id).await? {
                return Err(AppError::Forbidden(
                    "用户不在该群聊，无法举报该群聊".to_string(),
                ));
            }
        }
        ReportTargetType::User => {
            if target_uuid == reporter_id {
                return Err(AppError::ValidationError("不能举报自己".to_string()));
            }
            let user_store = UserStore::new(state.database.clone());
            if user_store.find_by_id(&target_uuid).await?.is_none() {
                return Err(AppError::NotFound("举报目标用户不存在".to_string()));
            }
        }
    }

    let provider = load_default_storage_provider(&state).await?;
    let storage_service = storage::create_storage_service(&provider)?;

    for key in &keys {
        if !is_valid_report_attachment_object_key(key, &reporter_id) {
            return Err(AppError::ValidationError("举报截图 key 不合法".to_string()));
        }
        if !storage_service.file_exists(key).await? {
            return Err(AppError::ValidationError(
                "举报截图尚未上传完成，请稍后重试".to_string(),
            ));
        }
    }

    let report_id = crate::id::generate();

    let (target_room_id, target_user_id) = match req.target_type {
        ReportTargetType::Room => (Some(target_uuid), None),
        ReportTargetType::User => (None, Some(target_uuid)),
    };

    let store = ReportStore::new(state.database.pool());
    store
        .create_report(
            ReportInsert {
                id: report_id,
                reporter_id,
                target_type: req.target_type.to_db_value(),
                target_room_id,
                target_user_id,
                content: content.to_string(),
            },
            keys.into_iter()
                .map(|key| ReportAttachmentInsert {
                    object_key: key,
                    content_type: None,
                    file_size: None,
                })
                .collect(),
        )
        .await?;

    Ok(Json(CreateReportResponse {
        success: true,
        message: "举报已提交，感谢你的反馈".to_string(),
        report_id: report_id.to_string(),
    }))
}

#[derive(Debug, Deserialize)]
pub struct AdminReportListQuery {
    pub page: Option<i64>,
    #[serde(alias = "pageSize")]
    pub page_size: Option<i64>,
    #[serde(alias = "reporterId")]
    pub reporter_id: Option<String>,
    #[serde(alias = "targetType")]
    pub target_type: Option<String>,
    #[serde(alias = "targetId")]
    pub target_id: Option<String>,
    pub keyword: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AdminReportAttachmentInfo {
    pub key: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub download_url: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AdminReportItem {
    pub id: String,
    pub reporter_id: String,
    pub reporter_username: String,
    pub reporter_nickname: Option<String>,
    pub target_type: String,
    pub target_id: String,
    pub target_name: Option<String>,
    pub content: String,
    pub created_at: String,
    pub attachments: Vec<AdminReportAttachmentInfo>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AdminReportListResponse {
    pub reports: Vec<AdminReportItem>,
    pub total: i64,
    pub page: i64,
    pub page_size: i64,
}

fn parse_target_type(value: Option<&str>) -> Result<Option<i32>, AppError> {
    let Some(raw) = value else { return Ok(None) };
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    match trimmed {
        "room" => Ok(Some(1)),
        "user" => Ok(Some(2)),
        _ => Err(AppError::ValidationError(
            "target_type 仅支持 room/user".to_string(),
        )),
    }
}

pub async fn list_reports_admin(
    State(state): State<AppState>,
    Query(query): Query<AdminReportListQuery>,
) -> Result<Json<AdminReportListResponse>, AppError> {
    let page = query.page.unwrap_or(1).max(1);
    let page_size = query.page_size.unwrap_or(20).clamp(1, 100);
    let offset = (page - 1) * page_size;

    let reporter_id = if let Some(value) = query.reporter_id.as_deref() {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(
                Uuid::parse_str(trimmed)
                    .map_err(|_| AppError::ValidationError("reporter_id 不合法".to_string()))?,
            )
        }
    } else {
        None
    };

    let target_type = parse_target_type(query.target_type.as_deref())?;

    let mut target_room_id: Option<Uuid> = None;
    let mut target_user_id: Option<Uuid> = None;
    if let Some(value) = query.target_id.as_deref() {
        let trimmed = value.trim();
        if !trimmed.is_empty() {
            let uuid = Uuid::parse_str(trimmed)
                .map_err(|_| AppError::ValidationError("target_id 不合法".to_string()))?;
            match target_type {
                Some(1) => target_room_id = Some(uuid),
                Some(2) => target_user_id = Some(uuid),
                None => {
                    // 未指定类型时，两种都尝试匹配
                    target_room_id = Some(uuid);
                    target_user_id = Some(uuid);
                }
                _ => {}
            }
        }
    }

    let filters = AdminReportListFilters {
        reporter_id,
        target_type,
        target_room_id,
        target_user_id,
        keyword: query
            .keyword
            .as_deref()
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty()),
        limit: page_size,
        offset,
    };

    let store = ReportStore::new(state.database.pool());
    let total = store.count_admin_reports(&filters).await?;
    let rows = store.list_admin_reports(&filters).await?;
    let report_ids: Vec<Uuid> = rows.iter().map(|r| r.id).collect();
    let attachments = store.list_attachments_by_report_ids(&report_ids).await?;

    // 生成附件下载 URL（缓存）
    // 若当前环境未配置默认存储提供商，不应阻塞举报列表本身的查询；
    // 此时仅降级为不返回附件下载地址。
    let provider = if attachments.is_empty() {
        None
    } else {
        match load_default_storage_provider(&state).await {
            Ok(provider) => Some(provider),
            Err(AppError::NotFound(_)) => None,
            Err(err) => return Err(err),
        }
    };
    let storage_service = if let Some(provider) = provider.as_ref() {
        match storage::create_storage_service(provider) {
            Ok(service) => Some(service),
            Err(AppError::ValidationError(_)) => None,
            Err(err) => return Err(err),
        }
    } else {
        None
    };
    let cache_manager = storage_service
        .as_ref()
        .map(|_| CacheManager::new(state.redis.get_cache_client().clone()));
    let expires = 600u32;

    let mut attachment_map: std::collections::HashMap<Uuid, Vec<AdminReportAttachmentInfo>> =
        std::collections::HashMap::new();

    for item in attachments {
        let url = if let (Some(provider), Some(storage_service), Some(cache_manager)) = (
            provider.as_ref(),
            storage_service.as_ref(),
            cache_manager.as_ref(),
        ) {
            let cache_key = CacheKeys::download_url_cache(
                item.object_key.trim(),
                &provider.id.to_string(),
                expires,
            );

            if let Ok(Some(cached)) = cache_manager.get_cached_download_url(&cache_key).await {
                Some(cached)
            } else {
                match storage_service
                    .generate_download_url(item.object_key.trim(), Some(expires))
                    .await
                {
                    Ok(generated) => {
                        let ttl = (expires as f64 * 0.9) as u64;
                        let _ = cache_manager
                            .cache_download_url(&cache_key, &generated, ttl)
                            .await;
                        Some(generated)
                    }
                    Err(_) => None,
                }
            }
        } else {
            None
        };

        attachment_map
            .entry(item.report_id)
            .or_default()
            .push(AdminReportAttachmentInfo {
                key: item.object_key,
                download_url: url,
            });
    }

    let reports = rows
        .into_iter()
        .map(|row| {
            let (target_id, target_name, target_type_text) = match row.target_type {
                1 => (
                    row.target_room_id
                        .map(|id| id.to_string())
                        .unwrap_or_default(),
                    row.target_room_name,
                    "room".to_string(),
                ),
                2 => (
                    row.target_user_id
                        .map(|id| id.to_string())
                        .unwrap_or_default(),
                    row.target_user_nickname.or(row.target_user_username),
                    "user".to_string(),
                ),
                _ => ("".to_string(), None, "unknown".to_string()),
            };

            AdminReportItem {
                id: row.id.to_string(),
                reporter_id: row.reporter_id.to_string(),
                reporter_username: row.reporter_username,
                reporter_nickname: row.reporter_nickname,
                target_type: target_type_text,
                target_id,
                target_name,
                content: row.content,
                created_at: row.created_at.to_rfc3339(),
                attachments: attachment_map.remove(&row.id).unwrap_or_default(),
            }
        })
        .collect();

    Ok(Json(AdminReportListResponse {
        reports,
        total,
        page,
        page_size,
    }))
}
