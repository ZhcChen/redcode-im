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
