use crate::database::file_upload_audit_store::FileUploadAuditStore;
use crate::database::file_upload_store::FileUploadStore;
use crate::database::models::{FileUploadAuditTask, StorageProviderType};
use crate::database::storage_provider_store::StorageProviderStore;
use crate::database::Database;
use crate::error::AppError;
use crate::storage;
use chrono::{DateTime, Duration, Utc};
use serde_json::json;
use tracing::{info, warn};
use uuid::Uuid;

const STATUS_RETRY: i16 = 3;

/// 审核任务配置（全部 env 可选）
#[derive(Debug, Clone)]
pub struct FileUploadAuditConfig {
    pub enabled: bool,
    pub batch_size: i64,
    pub lease_seconds: i64,
    pub max_attempts: i32,
    pub poll_interval_seconds: i64,
    pub retry_base_seconds: i64,
    pub retry_max_seconds: i64,
}

impl FileUploadAuditConfig {
    pub fn from_env() -> Self {
        fn read_i64(key: &str, default: i64) -> i64 {
            std::env::var(key)
                .ok()
                .and_then(|v| v.trim().parse::<i64>().ok())
                .unwrap_or(default)
        }

        fn read_i32(key: &str, default: i32) -> i32 {
            std::env::var(key)
                .ok()
                .and_then(|v| v.trim().parse::<i32>().ok())
                .unwrap_or(default)
        }

        let enabled = std::env::var("FILE_UPLOAD_AUDIT_ENABLED")
            .ok()
            .map(|v| v.trim().eq_ignore_ascii_case("true") || v.trim() == "1")
            .unwrap_or(true);

        Self {
            enabled,
            batch_size: read_i64("FILE_UPLOAD_AUDIT_BATCH_SIZE", 50),
            lease_seconds: read_i64("FILE_UPLOAD_AUDIT_LEASE_SECONDS", 120),
            max_attempts: read_i32("FILE_UPLOAD_AUDIT_MAX_ATTEMPTS", 12),
            poll_interval_seconds: read_i64("FILE_UPLOAD_AUDIT_POLL_INTERVAL_SECONDS", 15),
            retry_base_seconds: read_i64("FILE_UPLOAD_AUDIT_RETRY_BASE_SECONDS", 30),
            retry_max_seconds: read_i64("FILE_UPLOAD_AUDIT_RETRY_MAX_SECONDS", 3600),
        }
    }
}

/// 运行一次审核队列（抓取一批 due tasks 并处理）
pub async fn run_file_upload_audit_once(
    database: Database,
    cfg: &FileUploadAuditConfig,
) -> Result<(), AppError> {
    if !cfg.enabled {
        return Ok(());
    }

    let store = FileUploadAuditStore::new(database.clone());
    let tasks = store
        .claim_due_tasks(cfg.batch_size, cfg.lease_seconds)
        .await
        .map_err(|e| AppError::InternalError(format!("认领审核任务失败: {}", e)))?;

    if tasks.is_empty() {
        return Ok(());
    }

    info!("本轮认领到 {} 个审核任务", tasks.len());

    for task in tasks {
        if let Err(e) = process_task(database.clone(), cfg, &task).await {
            warn!(
                "处理审核任务失败: task_id={}, key={}, err={}",
                task.id, task.object_key, e
            );
        }
    }

    Ok(())
}

/// 触发单个任务“尽快执行”（不保证立即执行；用于业务入口侧切加速）
pub async fn trigger_task_now(
    database: Database,
    task_id: Uuid,
    cfg: &FileUploadAuditConfig,
) -> Result<(), AppError> {
    if !cfg.enabled {
        return Ok(());
    }

    let store = FileUploadAuditStore::new(database.clone());
    let claimed = store
        .claim_task_by_id(&task_id, cfg.lease_seconds)
        .await
        .map_err(|e| AppError::InternalError(format!("认领审核任务失败: {}", e)))?;

    let Some(task) = claimed else {
        return Ok(());
    };

    if let Err(e) = process_task(database, cfg, &task).await {
        warn!(
            "触发执行审核任务失败: task_id={}, key={}, err={}",
            task.id, task.object_key, e
        );
    }

    Ok(())
}

async fn process_task(
    database: Database,
    cfg: &FileUploadAuditConfig,
    task: &FileUploadAuditTask,
) -> Result<(), AppError> {
    let audit_store = FileUploadAuditStore::new(database.clone());
    let upload_store = FileUploadStore::new(database.clone());

    if task.attempts >= cfg.max_attempts && task.status == STATUS_RETRY {
        let _ = audit_store
            .mark_failed(&task.id, "超过最大重试次数，已停止处理")
            .await;
        let _ = upload_store
            .mark_failed_by_key(
                &task.storage_provider_id,
                &task.object_key,
                Some("审核任务超过最大重试次数"),
            )
            .await;
        return Ok(());
    }

    let provider_store = StorageProviderStore::new(database.clone());
    let provider = provider_store
        .get_provider_by_id(&task.storage_provider_id)
        .await?
        .ok_or_else(|| AppError::NotFound("存储提供商不存在".to_string()))?;

    if !provider.is_active {
        let _ = audit_store
            .mark_retry(
                &task.id,
                "存储提供商未启用，稍后重试",
                next_retry_at(cfg, task.attempts),
            )
            .await;
        return Ok(());
    }

    if provider.provider_type != StorageProviderType::BackblazeB2 {
        let _ = audit_store
            .mark_failed(&task.id, "当前审核链路仅支持 Backblaze B2")
            .await;
        return Ok(());
    }

    let storage_service = storage::create_storage_service(&provider)?;
    match storage_service.head_object(&task.object_key).await {
        Ok(object_head) => {
            let audited_at = Utc::now();
            let result = json!({
                "vendor": "backblaze_b2",
                "check": "head_object",
                "provider_type": provider.provider_type.to_string(),
                "media_kind": normalize_media_kind(&task.media_kind),
                "content_length": object_head.content_length,
                "etag": object_head.etag,
            });

            let _ = audit_store
                .mark_approved(&task.id, audited_at, result)
                .await;
            let _ = upload_store
                .mark_completed_by_key(&provider.id, &task.object_key)
                .await;
        }
        Err(AppError::NotFound(_)) => {
            let _ = audit_store
                .mark_retry(
                    &task.id,
                    "对象尚未同步到 Backblaze B2，稍后重试",
                    Utc::now() + Duration::seconds(cfg.poll_interval_seconds.max(1)),
                )
                .await;
        }
        Err(err) => {
            let _ = audit_store
                .mark_retry(
                    &task.id,
                    &format!("{}", err),
                    next_retry_at(cfg, task.attempts),
                )
                .await;
        }
    }

    Ok(())
}

fn next_retry_at(cfg: &FileUploadAuditConfig, attempts: i32) -> DateTime<Utc> {
    let capped_attempts = attempts.max(0).min(30) as u32;
    let base = cfg.retry_base_seconds.max(1);
    let multiplier = 1_i64.checked_shl(capped_attempts).unwrap_or(i64::MAX);
    let mut delay = base.saturating_mul(multiplier);
    if delay > cfg.retry_max_seconds {
        delay = cfg.retry_max_seconds;
    }
    Utc::now() + Duration::seconds(delay.max(1))
}

fn normalize_media_kind(value: &str) -> &str {
    match value.trim().to_ascii_lowercase().as_str() {
        "image" => "image",
        "video" => "video",
        "audio" => "audio",
        "text" => "text",
        "document" => "document",
        _ => "unknown",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_media_kind() {
        assert_eq!(normalize_media_kind("image"), "image");
        assert_eq!(normalize_media_kind(" VIDEO "), "video");
        assert_eq!(normalize_media_kind("other"), "unknown");
    }

    #[test]
    fn test_next_retry_at_caps_delay() {
        let cfg = FileUploadAuditConfig {
            enabled: true,
            batch_size: 50,
            lease_seconds: 120,
            max_attempts: 12,
            poll_interval_seconds: 15,
            retry_base_seconds: 30,
            retry_max_seconds: 60,
        };

        let next = next_retry_at(&cfg, 10);
        let diff = (next - Utc::now()).num_seconds();
        assert!(diff <= 60 && diff >= 1, "unexpected retry delay: {diff}");
    }
}
