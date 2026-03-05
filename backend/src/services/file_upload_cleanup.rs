use crate::database::file_upload_audit_store::FileUploadAuditStore;
use crate::database::file_upload_store::FileUploadStore;
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::Database;
use crate::error::AppError;
use crate::storage;
use crate::storage::StorageService;
use chrono::{Duration, Utc};
use std::collections::HashMap;
use std::sync::Arc;
use tracing::{info, warn};
use uuid::Uuid;

fn infer_audit_scene_from_object_key(object_key: &str) -> &'static str {
    let key = object_key.trim();
    if key.starts_with("avatars/") {
        return "avatar";
    }
    if key.starts_with("room_avatars/") {
        return "room_avatar";
    }
    if key.starts_with("messages/") {
        return "message_attachment";
    }
    if key.starts_with("reports/") {
        return "report_attachment";
    }
    if key.starts_with("releases/") {
        return "version";
    }
    "unknown"
}

fn infer_media_kind_from_message_attachment_object_key(key: &str) -> &'static str {
    let trimmed = key.trim();
    if trimmed.contains("/images_") {
        return "image";
    }
    if trimmed.contains("/videos_") {
        return "video";
    }
    if trimmed.contains("/audios_") {
        return "audio";
    }
    if trimmed.contains("/files_") {
        return "document";
    }
    "unknown"
}

fn infer_media_kind_from_object_key(object_key: &str, content_type: Option<&str>) -> &'static str {
    if let Some(content_type) = content_type {
        let ct = content_type.trim().to_ascii_lowercase();
        if ct.starts_with("image/") {
            return "image";
        }
        if ct.starts_with("video/") {
            return "video";
        }
        if ct.starts_with("audio/") {
            return "audio";
        }
        if ct.starts_with("text/") {
            return "text";
        }
        return "document";
    }

    let key = object_key.trim();
    if key.starts_with("messages/") {
        return infer_media_kind_from_message_attachment_object_key(key);
    }
    if key.starts_with("avatars/") || key.starts_with("room_avatars/") {
        return "image";
    }
    if key.starts_with("reports/") {
        return "image";
    }
    if key.starts_with("releases/") {
        return "document";
    }
    "unknown"
}

#[derive(Debug, Clone)]
pub struct FileUploadCleanupConfig {
    /// pending 记录超时阈值（秒）：超过后视为“上传未确认”
    pub pending_timeout_seconds: i64,
    /// pending 且无引用对象的删除阈值（秒）：超过后会尝试删除 COS 对象以回收空间
    pub orphan_delete_after_seconds: i64,
    /// completed 但无引用对象的保留阈值（秒）：超过后会尝试删除 COS 对象以回收空间
    pub unreferenced_retention_seconds: i64,
    /// 单次批处理条数
    pub batch_size: i64,
}

impl FileUploadCleanupConfig {
    pub fn from_env() -> Self {
        fn read_i64(name: &str, default: i64) -> i64 {
            std::env::var(name)
                .ok()
                .and_then(|v| v.trim().parse::<i64>().ok())
                .filter(|v| *v > 0)
                .unwrap_or(default)
        }

        Self {
            // 默认：pending 超过 6 小时算“未确认”
            pending_timeout_seconds: read_i64("FILE_UPLOAD_PENDING_TIMEOUT_SECONDS", 6 * 3600),
            // 默认：pending 且无引用对象，7 天后删除（更安全，避免误删刚上传但暂未引用的文件）
            orphan_delete_after_seconds: read_i64(
                "FILE_UPLOAD_ORPHAN_DELETE_AFTER_SECONDS",
                7 * 24 * 3600,
            ),
            // 默认：completed 但无引用对象保留 30 天再删除（兼顾秒传收益与空间回收）
            unreferenced_retention_seconds: read_i64(
                "FILE_UPLOAD_UNREFERENCED_RETENTION_SECONDS",
                30 * 24 * 3600,
            ),
            batch_size: read_i64("FILE_UPLOAD_CLEANUP_BATCH_SIZE", 200),
        }
    }
}

async fn get_service_for_provider(
    services: &mut HashMap<Uuid, Arc<dyn StorageService>>,
    provider_store: &StorageProviderStore,
    provider_id: &Uuid,
) -> Result<Arc<dyn StorageService>, AppError> {
    if let Some(svc) = services.get(provider_id) {
        return Ok(svc.clone());
    }

    let provider = provider_store
        .get_provider_by_id(provider_id)
        .await
        .map_err(AppError::DatabaseError)?
        .ok_or_else(|| AppError::NotFound("未找到存储提供商配置".to_string()))?;

    if !provider.is_active {
        return Err(AppError::ValidationError(
            "存储提供商未启用，无法执行清理任务".to_string(),
        ));
    }

    let svc = storage::create_storage_service(&provider)?;
    let svc: Arc<dyn StorageService> = svc.into();
    services.insert(*provider_id, svc.clone());
    Ok(svc)
}

pub async fn run_file_upload_cleanup(
    database: Database,
    cfg: &FileUploadCleanupConfig,
) -> Result<(), AppError> {
    let upload_store = FileUploadStore::new(database.clone());
    let audit_store = FileUploadAuditStore::new(database.clone());
    let provider_store = StorageProviderStore::new(database.clone());

    let mut services: HashMap<Uuid, Arc<dyn StorageService>> = HashMap::new();

    // 1) 清理超时 pending
    let pending_cutoff = Utc::now() - Duration::seconds(cfg.pending_timeout_seconds);
    let stale_pending = upload_store
        .list_stale_pending_records(pending_cutoff, cfg.batch_size)
        .await
        .map_err(AppError::DatabaseError)?;

    if !stale_pending.is_empty() {
        info!(
            "文件上传清理：发现 {} 条超时 pending 记录（cutoff={}）",
            stale_pending.len(),
            pending_cutoff
        );
    }

    for record in stale_pending {
        let key = record.object_key.as_str();

        // 若业务已引用该 key，则直接标记为 completed（有些客户端可能未走 commit）
        if upload_store
            .is_object_key_referenced(key)
            .await
            .map_err(AppError::DatabaseError)?
        {
            let _ = upload_store
                .mark_completed_by_key(&record.storage_provider_id, key)
                .await;

            // 若该 key 已被引用但客户端未走 commit，这里补写审核任务，确保“全量审核”
            let scene = infer_audit_scene_from_object_key(key);
            let media_kind = infer_media_kind_from_object_key(key, record.content_type.as_deref());
            if let Err(e) = audit_store
                .upsert_task(
                    &record.storage_provider_id,
                    key,
                    scene,
                    media_kind,
                    record.content_type.as_deref(),
                    record.file_size,
                )
                .await
            {
                warn!("写入文件审核任务失败: key={}, error={}", key, e);
            }
            continue;
        }

        let svc =
            get_service_for_provider(&mut services, &provider_store, &record.storage_provider_id)
                .await?;
        let head = svc.head_object(key).await;

        match head {
            Ok(_) => {
                // 已存在对象但未确认：先标记失败（不允许复用），超过更长阈值再删除对象
                let _ = upload_store
                    .mark_failed_by_key(&record.storage_provider_id, key, Some("直传超时未确认"))
                    .await;

                let delete_cutoff = Utc::now() - Duration::seconds(cfg.orphan_delete_after_seconds);
                if record.created_at < delete_cutoff {
                    match svc.delete_file(key).await {
                        Ok(_) => {
                            let _ = upload_store
                                .mark_deleted_by_key(
                                    &record.storage_provider_id,
                                    key,
                                    Some("超时且无引用，已删除对象"),
                                )
                                .await;
                        }
                        Err(e) => {
                            warn!("清理超时对象失败: key={}, error={}", key, e);
                        }
                    }
                }
            }
            Err(AppError::NotFound(_)) => {
                let _ = upload_store
                    .mark_failed_by_key(
                        &record.storage_provider_id,
                        key,
                        Some("直传超时且对象不存在"),
                    )
                    .await;
            }
            Err(AppError::ValidationError(_)) => {
                // provider 不支持 head：退化为 exists
                match svc.file_exists(key).await {
                    Ok(true) => {
                        let _ = upload_store
                            .mark_failed_by_key(
                                &record.storage_provider_id,
                                key,
                                Some("直传超时未确认"),
                            )
                            .await;
                    }
                    Ok(false) => {
                        let _ = upload_store
                            .mark_failed_by_key(
                                &record.storage_provider_id,
                                key,
                                Some("直传超时且对象不存在"),
                            )
                            .await;
                    }
                    Err(e) => warn!("检查对象存在性失败: key={}, error={}", key, e),
                }
            }
            Err(e) => {
                warn!("获取对象元数据失败: key={}, error={}", key, e);
            }
        }
    }

    // 2) 清理 completed 但无引用的旧对象（保留期后）
    let unref_cutoff = Utc::now() - Duration::seconds(cfg.unreferenced_retention_seconds);
    let old_completed = upload_store
        .list_old_completed_records(unref_cutoff, cfg.batch_size)
        .await
        .map_err(AppError::DatabaseError)?;

    if !old_completed.is_empty() {
        info!(
            "文件上传清理：发现 {} 条旧 completed 记录（cutoff={}）",
            old_completed.len(),
            unref_cutoff
        );
    }

    for record in old_completed {
        let key = record.object_key.as_str();
        if upload_store
            .is_object_key_referenced(key)
            .await
            .map_err(AppError::DatabaseError)?
        {
            continue;
        }

        let svc =
            get_service_for_provider(&mut services, &provider_store, &record.storage_provider_id)
                .await?;
        match svc.head_object(key).await {
            Ok(_) => match svc.delete_file(key).await {
                Ok(_) => {
                    let _ = upload_store
                        .mark_deleted_by_key(
                            &record.storage_provider_id,
                            key,
                            Some("无引用且已过保留期，已删除对象"),
                        )
                        .await;
                }
                Err(e) => warn!("删除无引用对象失败: key={}, error={}", key, e),
            },
            Err(AppError::NotFound(_)) => {
                let _ = upload_store
                    .mark_deleted_by_key(
                        &record.storage_provider_id,
                        key,
                        Some("对象不存在，已标记为删除"),
                    )
                    .await;
            }
            Err(AppError::ValidationError(_)) => {
                // provider 不支持 head：退化为 exists
                match svc.file_exists(key).await {
                    Ok(true) => match svc.delete_file(key).await {
                        Ok(_) => {
                            let _ = upload_store
                                .mark_deleted_by_key(
                                    &record.storage_provider_id,
                                    key,
                                    Some("无引用且已过保留期，已删除对象"),
                                )
                                .await;
                        }
                        Err(e) => warn!("删除无引用对象失败: key={}, error={}", key, e),
                    },
                    Ok(false) => {
                        let _ = upload_store
                            .mark_deleted_by_key(
                                &record.storage_provider_id,
                                key,
                                Some("对象不存在，已标记为删除"),
                            )
                            .await;
                    }
                    Err(e) => warn!("检查对象存在性失败: key={}, error={}", key, e),
                }
            }
            Err(e) => warn!("获取对象元数据失败: key={}, error={}", key, e),
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use once_cell::sync::Lazy;
    use std::sync::Mutex;

    static ENV_LOCK: Lazy<Mutex<()>> = Lazy::new(|| Mutex::new(()));

    struct EnvVarGuard {
        saved: Vec<(&'static str, Option<String>)>,
    }

    impl EnvVarGuard {
        fn apply(entries: &[(&'static str, Option<&str>)]) -> Self {
            let mut saved = Vec::with_capacity(entries.len());
            for (name, value) in entries {
                saved.push((*name, std::env::var(name).ok()));
                match value {
                    Some(v) => std::env::set_var(name, v),
                    None => std::env::remove_var(name),
                }
            }
            Self { saved }
        }
    }

    impl Drop for EnvVarGuard {
        fn drop(&mut self) {
            for (name, value) in &self.saved {
                match value {
                    Some(v) => std::env::set_var(name, v),
                    None => std::env::remove_var(name),
                }
            }
        }
    }

    #[test]
    fn test_infer_audit_scene_from_object_key() {
        assert_eq!(infer_audit_scene_from_object_key("avatars/user123.png"), "avatar");
        assert_eq!(infer_audit_scene_from_object_key("room_avatars/room456.jpg"), "room_avatar");
        assert_eq!(infer_audit_scene_from_object_key("messages/abc/file.pdf"), "message_attachment");
        assert_eq!(infer_audit_scene_from_object_key("reports/evidence.png"), "report_attachment");
        assert_eq!(infer_audit_scene_from_object_key("releases/v1.0.0.apk"), "version");
        assert_eq!(infer_audit_scene_from_object_key("unknown/path/file.txt"), "unknown");
        assert_eq!(infer_audit_scene_from_object_key(""), "unknown");
    }

    #[test]
    fn test_infer_audit_scene_with_whitespace() {
        assert_eq!(infer_audit_scene_from_object_key("  avatars/user.png  "), "avatar");
        assert_eq!(infer_audit_scene_from_object_key("\n messages/file.pdf \t"), "message_attachment");
    }

    #[test]
    fn test_infer_media_kind_from_message_attachment_object_key() {
        assert_eq!(infer_media_kind_from_message_attachment_object_key("messages/images_123.png"), "image");
        assert_eq!(infer_media_kind_from_message_attachment_object_key("messages/videos_456.mp4"), "video");
        assert_eq!(infer_media_kind_from_message_attachment_object_key("messages/audios_789.mp3"), "audio");
        assert_eq!(infer_media_kind_from_message_attachment_object_key("messages/files_abc.pdf"), "document");
        assert_eq!(infer_media_kind_from_message_attachment_object_key("messages/other.bin"), "unknown");
    }

    #[test]
    fn test_infer_media_kind_from_object_key_with_content_type() {
        assert_eq!(infer_media_kind_from_object_key("any/path.jpg", Some("image/jpeg")), "image");
        assert_eq!(infer_media_kind_from_object_key("any/path.mp4", Some("video/mp4")), "video");
        assert_eq!(infer_media_kind_from_object_key("any/path.mp3", Some("audio/mpeg")), "audio");
        assert_eq!(infer_media_kind_from_object_key("any/path.txt", Some("text/plain")), "text");
        assert_eq!(infer_media_kind_from_object_key("any/path.pdf", Some("application/pdf")), "document");
    }

    #[test]
    fn test_infer_media_kind_from_object_key_without_content_type() {
        // 头像
        assert_eq!(infer_media_kind_from_object_key("avatars/user.png", None), "image");
        assert_eq!(infer_media_kind_from_object_key("room_avatars/room.jpg", None), "image");

        // 举报附件
        assert_eq!(infer_media_kind_from_object_key("reports/evidence.png", None), "image");

        // 版本发布
        assert_eq!(infer_media_kind_from_object_key("releases/v1.0.apk", None), "document");

        // 消息附件
        assert_eq!(infer_media_kind_from_object_key("messages/images_123.png", None), "image");
        assert_eq!(infer_media_kind_from_object_key("messages/videos_456.mp4", None), "video");

        // 未知路径
        assert_eq!(infer_media_kind_from_object_key("unknown/path.bin", None), "unknown");
    }

    #[test]
    fn test_infer_media_kind_content_type_case_insensitive() {
        assert_eq!(infer_media_kind_from_object_key("test.jpg", Some("IMAGE/JPEG")), "image");
        assert_eq!(infer_media_kind_from_object_key("test.mp4", Some("Video/MP4")), "video");
        assert_eq!(infer_media_kind_from_object_key("test.mp3", Some(" Audio/MPEG ")), "audio");
    }

    #[test]
    fn test_file_upload_cleanup_config_defaults() {
        // 使用 from_env 时，如果环境变量未设置，应该使用默认值
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            ("FILE_UPLOAD_PENDING_TIMEOUT_SECONDS", None),
            ("FILE_UPLOAD_ORPHAN_DELETE_AFTER_SECONDS", None),
            ("FILE_UPLOAD_UNREFERENCED_RETENTION_SECONDS", None),
            ("FILE_UPLOAD_CLEANUP_BATCH_SIZE", None),
        ]);
        let config = FileUploadCleanupConfig::from_env();
        assert!(config.pending_timeout_seconds > 0);
        assert!(config.orphan_delete_after_seconds > 0);
        assert!(config.unreferenced_retention_seconds > 0);
        assert!(config.batch_size > 0);
    }

    #[test]
    fn test_file_upload_cleanup_config_from_env_custom_values() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            ("FILE_UPLOAD_PENDING_TIMEOUT_SECONDS", Some("7200")),
            ("FILE_UPLOAD_ORPHAN_DELETE_AFTER_SECONDS", Some("172800")),
            ("FILE_UPLOAD_UNREFERENCED_RETENTION_SECONDS", Some("172800")),
            ("FILE_UPLOAD_CLEANUP_BATCH_SIZE", Some("500")),
        ]);

        let config = FileUploadCleanupConfig::from_env();
        assert_eq!(config.pending_timeout_seconds, 7200);
        assert_eq!(config.orphan_delete_after_seconds, 172800);
        assert_eq!(config.unreferenced_retention_seconds, 172800);
        assert_eq!(config.batch_size, 500);
    }

    #[test]
    fn test_file_upload_cleanup_config_from_env_invalid_values_use_defaults() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvVarGuard::apply(&[
            ("FILE_UPLOAD_PENDING_TIMEOUT_SECONDS", Some("0")),
            ("FILE_UPLOAD_ORPHAN_DELETE_AFTER_SECONDS", Some("-1")),
            ("FILE_UPLOAD_UNREFERENCED_RETENTION_SECONDS", Some("invalid")),
            ("FILE_UPLOAD_CLEANUP_BATCH_SIZE", Some(" ")),
        ]);

        let config = FileUploadCleanupConfig::from_env();
        assert_eq!(config.pending_timeout_seconds, 6 * 3600);
        assert_eq!(config.orphan_delete_after_seconds, 7 * 24 * 3600);
        assert_eq!(config.unreferenced_retention_seconds, 30 * 24 * 3600);
        assert_eq!(config.batch_size, 200);
    }
}
