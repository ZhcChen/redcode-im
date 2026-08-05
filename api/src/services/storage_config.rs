use std::{env, sync::Arc, time::Duration};

use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use async_trait::async_trait;
use aws_credential_types::Credentials;
use aws_sdk_s3::{
    config::{Builder as S3ConfigBuilder, Region},
    Client as S3Client,
};
use base64::Engine;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    crypto::secret::SecretCrypto,
    database::{
        models::ObjectStorageConfigRecord,
        object_storage_config_store::{
            CreateObjectStorageConfigVersionInput, ObjectStorageConfigStore,
        },
        storage_provider_store::StorageProviderStore,
        Database,
    },
    AppError,
};

pub const PROVIDER_S3_COMPATIBLE: &str = "s3_compatible";
pub const SOURCE_DATABASE: &str = "database";
pub const SOURCE_ENV_FALLBACK: &str = "env_fallback";
pub const STATUS_ACTIVE: &str = "active";
pub const STATUS_SUPERSEDED: &str = "superseded";
pub const STATUS_ROLLED_BACK: &str = "rolled_back";

const DEFAULT_REGION: &str = "us-east-1";
const DEFAULT_PRIVATE_BUCKET: &str = "redcode-im-private";
const DEFAULT_UPLOAD_URL_TTL_SECONDS: u32 = 900;
const DEFAULT_DOWNLOAD_URL_TTL_SECONDS: u32 = 600;
const DEFAULT_PROVIDER_SYNC_NAME: &str = "system-s3-runtime";
const DEFAULT_PROVIDER_SYNC_DESCRIPTION: &str = "由对象存储运行时配置同步";

#[derive(Debug, Clone)]
pub struct BootstrapConfig {
    pub provider: String,
    pub endpoint: String,
    pub region: String,
    pub key_id: String,
    pub application_key: String,
    pub private_bucket: String,
    pub public_bucket: String,
    pub public_base_url: String,
    pub upload_url_ttl: Duration,
    pub download_url_ttl: Duration,
    pub last_applied_by: Option<String>,
    pub last_applied_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
}

impl BootstrapConfig {
    pub fn from_env() -> Self {
        let region = env_with_legacy("REDCODE_IM_S3_REGION", "REDCODE_IM_B2_REGION");
        let endpoint = apply_legacy_storage_scheme(env_with_legacy(
            "REDCODE_IM_S3_ENDPOINT",
            "REDCODE_IM_B2_ENDPOINT",
        ));
        Self {
            provider: PROVIDER_S3_COMPATIBLE.to_string(),
            endpoint,
            region,
            key_id: env_with_legacy("REDCODE_IM_S3_ACCESS_KEY", "REDCODE_IM_B2_KEY_ID"),
            application_key: env_with_legacy(
                "REDCODE_IM_S3_SECRET_KEY",
                "REDCODE_IM_B2_APPLICATION_KEY",
            ),
            private_bucket: env_with_legacy(
                "REDCODE_IM_S3_PRIVATE_BUCKET",
                "REDCODE_IM_B2_PRIVATE_BUCKET",
            ),
            public_bucket: env_with_legacy(
                "REDCODE_IM_S3_PUBLIC_BUCKET",
                "REDCODE_IM_B2_PUBLIC_BUCKET",
            ),
            public_base_url: env_with_legacy(
                "REDCODE_IM_S3_PUBLIC_BASE_URL",
                "REDCODE_IM_B2_PUBLIC_BASE_URL",
            ),
            upload_url_ttl: parse_duration_env_with_legacy(
                "REDCODE_IM_S3_UPLOAD_URL_TTL",
                "REDCODE_IM_B2_UPLOAD_URL_TTL",
                DEFAULT_UPLOAD_URL_TTL_SECONDS,
            ),
            download_url_ttl: parse_duration_env_with_legacy(
                "REDCODE_IM_S3_DOWNLOAD_URL_TTL",
                "REDCODE_IM_B2_DOWNLOAD_URL_TTL",
                DEFAULT_DOWNLOAD_URL_TTL_SECONDS,
            ),
            last_applied_by: None,
            last_applied_at: None,
            updated_at: None,
        }
    }
}

fn apply_legacy_storage_scheme(endpoint: String) -> String {
    let endpoint = endpoint.trim().trim_end_matches('/');
    if endpoint.is_empty() || endpoint.starts_with("http://") || endpoint.starts_with("https://") {
        return endpoint.to_string();
    }
    let scheme = std::env::var("REDCODE_IM_STORAGE_SCHEME")
        .unwrap_or_default()
        .trim()
        .to_ascii_lowercase();
    if matches!(scheme.as_str(), "http" | "https") {
        format!("{scheme}://{endpoint}")
    } else {
        endpoint.to_string()
    }
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct UpsertInput {
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

#[derive(Debug, Clone)]
pub struct RuntimeConfig {
    pub source: String,
    pub version: Option<i32>,
    pub provider: String,
    pub endpoint: String,
    pub region: String,
    pub key_id: String,
    pub application_key: String,
    pub private_bucket: String,
    pub public_bucket: String,
    pub public_base_url: String,
    pub upload_url_ttl: Duration,
    pub download_url_ttl: Duration,
    pub last_applied_by: Option<String>,
    pub last_applied_at: Option<DateTime<Utc>>,
    pub rollback_source_version: Option<i32>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ConfigSummary {
    pub source: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<i32>,
    pub provider: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub endpoint: Option<String>,
    pub region: String,
    pub private_bucket: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub public_bucket: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub public_base_url: Option<String>,
    pub upload_url_ttl_seconds: u32,
    pub download_url_ttl_seconds: u32,
    pub key_id_configured: bool,
    pub application_key_configured: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_applied_by: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_applied_at: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rollback_source_version: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct HistoryItem {
    #[serde(flatten)]
    pub summary: ConfigSummary,
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub change_note: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub created_by: Option<String>,
    pub created_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub applied_by: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub applied_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ProbeAllowedBucket {
    pub id: Option<String>,
    pub name: Option<String>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ProbeStatus {
    Pass,
    Warn,
    Fail,
}

#[derive(Debug, Clone, Serialize)]
pub struct ProbeCheck {
    pub code: String,
    pub status: ProbeStatus,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ProbeAllowedScope {
    pub buckets: Vec<ProbeAllowedBucket>,
    pub name_prefix: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ProbeResult {
    pub status: ProbeStatus,
    pub allowed_capabilities: Vec<String>,
    pub required_runtime_capabilities: Vec<String>,
    pub missing_runtime_capabilities: Vec<String>,
    pub bucket_init_supported: bool,
    pub s3_api_url: Option<String>,
    pub allowed: ProbeAllowedScope,
    pub checks: Vec<ProbeCheck>,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum BucketInitItemStatus {
    Created,
    AlreadyExists,
    Skipped,
    Failed,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum BucketInitStatus {
    Success,
    Partial,
    Failed,
}

#[derive(Debug, Clone, Serialize)]
pub struct BucketInitItem {
    pub bucket_name: String,
    pub bucket_role: String,
    pub status: BucketInitItemStatus,
    pub message: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct BucketInitResult {
    pub status: BucketInitStatus,
    pub items: Vec<BucketInitItem>,
}

#[async_trait]
pub trait OpsExecutor: Send + Sync {
    async fn probe(&self, config: &RuntimeConfig) -> Result<ProbeResult, AppError>;
    async fn init_buckets(&self, config: &RuntimeConfig) -> Result<BucketInitResult, AppError>;
}

#[derive(Clone)]
pub struct StorageConfigService {
    store: ObjectStorageConfigStore,
    provider_store: StorageProviderStore,
    cipher: Option<Arc<dyn StorageSecretCipher>>,
    bootstrap: BootstrapConfig,
    ops: Arc<dyn OpsExecutor>,
}

impl StorageConfigService {
    pub fn new(database: Database) -> Self {
        Self {
            store: ObjectStorageConfigStore::new(database.clone()),
            provider_store: StorageProviderStore::new(database),
            cipher: build_storage_cipher(),
            bootstrap: BootstrapConfig::from_env(),
            ops: Arc::new(S3OpsExecutor),
        }
    }

    pub async fn current_runtime_config(&self) -> Result<RuntimeConfig, AppError> {
        if let Some(record) = self.store.get_active().await? {
            return self.runtime_config_from_record(record);
        }
        Ok(bootstrap_to_runtime_config(&self.bootstrap))
    }

    pub async fn get_current_summary(&self) -> Result<ConfigSummary, AppError> {
        Ok(summary_from_runtime_config(
            &self.current_runtime_config().await?,
        ))
    }

    pub async fn validate(&self, input: UpsertInput) -> Result<ConfigSummary, AppError> {
        let current = self.current_runtime_config().await?;
        let normalized = normalize_upsert_input(input)?;
        let resolved = self.resolve_runtime_config(&normalized, &current).await?;
        Ok(summary_from_runtime_config(&RuntimeConfig {
            source: current.source,
            ..resolved
        }))
    }

    pub async fn probe(
        &self,
        input: UpsertInput,
    ) -> Result<(ConfigSummary, ProbeResult), AppError> {
        let current = self.current_runtime_config().await?;
        let normalized = normalize_upsert_input(input)?;
        let resolved = self.resolve_runtime_config(&normalized, &current).await?;
        let summary = summary_from_runtime_config(&RuntimeConfig {
            source: current.source,
            ..resolved.clone()
        });
        let probe = self.ops.probe(&resolved).await?;
        Ok((summary, probe))
    }

    pub async fn apply(
        &self,
        input: UpsertInput,
        actor: Option<&str>,
        change_note: Option<&str>,
        updated_by: Option<Uuid>,
    ) -> Result<ConfigSummary, AppError> {
        let cipher = self
            .cipher
            .clone()
            .ok_or_else(|| AppError::InternalError("缺少 REDCODE_IM_STORAGE_CONFIG_CIPHER_KEY 或 DATA_ENCRYPTION_KEY/JWT_SECRET，无法加密运行时配置".to_string()))?;

        let current = self.current_runtime_config().await?;
        let normalized = normalize_upsert_input(input)?;
        let resolved = self.resolve_runtime_config(&normalized, &current).await?;

        let encrypted_key_id = encrypt_optional(cipher.as_ref(), &resolved.key_id)?;
        let encrypted_application_key =
            encrypt_optional(cipher.as_ref(), &resolved.application_key)?;
        let latest_version = self.store.get_latest_version().await?;

        let previous_active_version = if current.source == SOURCE_DATABASE {
            current.version
        } else {
            None
        };
        let previous_active_next_status =
            previous_active_version.map(|_| STATUS_SUPERSEDED.to_string());

        let record = self
            .store
            .create_version(CreateObjectStorageConfigVersionInput {
                provider: PROVIDER_S3_COMPATIBLE.to_string(),
                endpoint: optional_string(&resolved.endpoint),
                region: resolved.region.clone(),
                encrypted_key_id,
                encrypted_application_key,
                private_bucket: resolved.private_bucket.clone(),
                public_bucket: optional_string(&resolved.public_bucket),
                public_base_url: optional_string(&resolved.public_base_url),
                upload_url_ttl_seconds: resolved.upload_url_ttl.as_secs() as i32,
                download_url_ttl_seconds: resolved.download_url_ttl.as_secs() as i32,
                version: latest_version + 1,
                status: STATUS_ACTIVE.to_string(),
                rollback_source_version: None,
                change_note: optional_string(change_note.unwrap_or_default()),
                created_by: optional_string(actor.unwrap_or_default()),
                applied_by: optional_string(actor.unwrap_or_default()),
                activated_at: Some(Utc::now()),
                previous_active_version,
                previous_active_next_status,
            })
            .await?;

        let applied = self.runtime_config_from_record(record)?;
        self.sync_default_provider(&applied, updated_by).await?;
        Ok(summary_from_runtime_config(&applied))
    }

    pub async fn list_history(&self) -> Result<Vec<HistoryItem>, AppError> {
        let records = self.store.list_history().await?;
        Ok(records.into_iter().map(history_item_from_record).collect())
    }

    pub async fn init_buckets(&self) -> Result<(ConfigSummary, BucketInitResult), AppError> {
        let current = self.current_runtime_config().await?;
        let result = self.ops.init_buckets(&current).await?;
        Ok((summary_from_runtime_config(&current), result))
    }

    pub async fn rollback(
        &self,
        target_version: i32,
        actor: Option<&str>,
        reason: Option<&str>,
        updated_by: Option<Uuid>,
    ) -> Result<ConfigSummary, AppError> {
        if target_version <= 0 {
            return Err(AppError::ValidationError(
                "target_version 必须大于 0".to_string(),
            ));
        }

        let cipher = self
            .cipher
            .clone()
            .ok_or_else(|| AppError::InternalError("缺少 REDCODE_IM_STORAGE_CONFIG_CIPHER_KEY 或 DATA_ENCRYPTION_KEY/JWT_SECRET，无法加密运行时配置".to_string()))?;

        let current_record = self.store.get_active().await?.ok_or_else(|| {
            AppError::NotFound("当前没有可回滚的 active 对象存储配置".to_string())
        })?;
        if current_record.version == target_version {
            return Err(AppError::BusinessError(
                "当前已是目标版本，无需回滚".to_string(),
            ));
        }

        let target_record = self
            .store
            .get_by_version(target_version)
            .await?
            .ok_or_else(|| AppError::NotFound(format!("未找到版本 {}", target_version)))?;
        let target_runtime = self.runtime_config_from_record(target_record)?;
        let encrypted_key_id = encrypt_optional(cipher.as_ref(), &target_runtime.key_id)?;
        let encrypted_application_key =
            encrypt_optional(cipher.as_ref(), &target_runtime.application_key)?;
        let latest_version = self.store.get_latest_version().await?;

        let record = self
            .store
            .create_version(CreateObjectStorageConfigVersionInput {
                provider: PROVIDER_S3_COMPATIBLE.to_string(),
                endpoint: optional_string(&target_runtime.endpoint),
                region: target_runtime.region.clone(),
                encrypted_key_id,
                encrypted_application_key,
                private_bucket: target_runtime.private_bucket.clone(),
                public_bucket: optional_string(&target_runtime.public_bucket),
                public_base_url: optional_string(&target_runtime.public_base_url),
                upload_url_ttl_seconds: target_runtime.upload_url_ttl.as_secs() as i32,
                download_url_ttl_seconds: target_runtime.download_url_ttl.as_secs() as i32,
                version: latest_version + 1,
                status: STATUS_ACTIVE.to_string(),
                rollback_source_version: Some(target_version),
                change_note: optional_string(reason.unwrap_or_default()),
                created_by: optional_string(actor.unwrap_or_default()),
                applied_by: optional_string(actor.unwrap_or_default()),
                activated_at: Some(Utc::now()),
                previous_active_version: Some(current_record.version),
                previous_active_next_status: Some(STATUS_ROLLED_BACK.to_string()),
            })
            .await?;

        let rolled_back = self.runtime_config_from_record(record)?;
        self.sync_default_provider(&rolled_back, updated_by).await?;
        Ok(summary_from_runtime_config(&rolled_back))
    }

    pub async fn ensure_materialized_default_provider(&self) -> Result<(), AppError> {
        let current = self.current_runtime_config().await?;
        if !runtime_has_materializable_credentials(&current) {
            return Ok(());
        }
        let default_provider = self.provider_store.get_any_default_provider().await?;
        if !should_sync_materialized_provider(
            default_provider.as_ref().map(|item| item.name.as_str()),
        ) {
            return Ok(());
        }
        self.sync_default_provider(&current, None).await
    }

    fn runtime_config_from_record(
        &self,
        record: ObjectStorageConfigRecord,
    ) -> Result<RuntimeConfig, AppError> {
        let key_id = decrypt_optional(self.cipher.as_deref(), record.encrypted_key_id.as_deref())?;
        let application_key = decrypt_optional(
            self.cipher.as_deref(),
            record.encrypted_application_key.as_deref(),
        )?;

        Ok(RuntimeConfig {
            source: SOURCE_DATABASE.to_string(),
            version: Some(record.version),
            provider: normalize_provider(&record.provider),
            endpoint: normalize_s3_endpoint(record.endpoint.as_deref()),
            region: default_string(&record.region, DEFAULT_REGION),
            key_id,
            application_key,
            private_bucket: default_string(&record.private_bucket, DEFAULT_PRIVATE_BUCKET),
            public_bucket: record.public_bucket.unwrap_or_default(),
            public_base_url: record.public_base_url.unwrap_or_default(),
            upload_url_ttl: Duration::from_secs(record.upload_url_ttl_seconds.max(1) as u64),
            download_url_ttl: Duration::from_secs(record.download_url_ttl_seconds.max(1) as u64),
            last_applied_by: record.applied_by,
            last_applied_at: record.activated_at,
            rollback_source_version: record.rollback_source_version,
            updated_at: Some(record.updated_at),
        })
    }

    async fn resolve_runtime_config(
        &self,
        input: &UpsertInput,
        current: &RuntimeConfig,
    ) -> Result<RuntimeConfig, AppError> {
        let mut key_id = input.key_id.clone().unwrap_or_default().trim().to_string();
        if key_id.is_empty() {
            key_id = current.key_id.trim().to_string();
        }
        let mut application_key = input
            .application_key
            .clone()
            .unwrap_or_default()
            .trim()
            .to_string();
        if application_key.is_empty() {
            application_key = current.application_key.trim().to_string();
        }
        if key_id.is_empty() || application_key.is_empty() {
            return Err(AppError::ValidationError(
                "对象存储配置至少需要 Key ID 与 Application Key".to_string(),
            ));
        }

        let mut region = input.region.clone().unwrap_or_default().trim().to_string();
        let mut endpoint = input
            .endpoint
            .clone()
            .unwrap_or_default()
            .trim()
            .to_string();
        if region.is_empty() {
            if !current.region.trim().is_empty() {
                region = current.region.trim().to_string();
            } else {
                region = DEFAULT_REGION.to_string();
            }
        }
        if endpoint.is_empty() {
            endpoint = current.endpoint.trim().to_string();
        }
        endpoint = normalize_s3_endpoint(Some(endpoint.as_str()));
        if endpoint.is_empty() {
            return Err(AppError::ValidationError(
                "S3 兼容对象存储需要配置 endpoint".to_string(),
            ));
        }

        let mut private_bucket = input
            .private_bucket
            .clone()
            .unwrap_or_default()
            .trim()
            .to_string();
        if private_bucket.is_empty() {
            private_bucket = current.private_bucket.trim().to_string();
        }
        if private_bucket.is_empty() {
            private_bucket = DEFAULT_PRIVATE_BUCKET.to_string();
        }

        let public_bucket = input
            .public_bucket
            .clone()
            .unwrap_or_else(|| current.public_bucket.clone())
            .trim()
            .to_string();
        let public_base_url = input
            .public_base_url
            .clone()
            .unwrap_or_else(|| current.public_base_url.clone())
            .trim()
            .to_string();
        let upload_url_ttl = Duration::from_secs(
            input
                .upload_url_ttl_seconds
                .unwrap_or_else(|| current.upload_url_ttl.as_secs() as u32)
                .max(1) as u64,
        );
        let download_url_ttl = Duration::from_secs(
            input
                .download_url_ttl_seconds
                .unwrap_or_else(|| current.download_url_ttl.as_secs() as u32)
                .max(1) as u64,
        );

        Ok(RuntimeConfig {
            source: current.source.clone(),
            version: current.version,
            provider: PROVIDER_S3_COMPATIBLE.to_string(),
            endpoint,
            region,
            key_id,
            application_key,
            private_bucket,
            public_bucket,
            public_base_url,
            upload_url_ttl,
            download_url_ttl,
            last_applied_by: current.last_applied_by.clone(),
            last_applied_at: current.last_applied_at,
            rollback_source_version: current.rollback_source_version,
            updated_at: current.updated_at,
        })
    }

    async fn sync_default_provider(
        &self,
        runtime: &RuntimeConfig,
        updated_by: Option<Uuid>,
    ) -> Result<(), AppError> {
        if !runtime_has_materializable_credentials(runtime) {
            return Ok(());
        }
        self.provider_store
            .upsert_default_s3_provider(
                DEFAULT_PROVIDER_SYNC_NAME,
                runtime.key_id.trim(),
                runtime.application_key.trim(),
                runtime.region.trim(),
                runtime.endpoint.trim(),
                runtime.private_bucket.trim(),
                Some(DEFAULT_PROVIDER_SYNC_DESCRIPTION),
                updated_by,
            )
            .await?;
        Ok(())
    }
}

pub async fn ensure_bootstrap_default_provider(database: Database) -> Result<(), AppError> {
    StorageConfigService::new(database)
        .ensure_materialized_default_provider()
        .await
}

fn summary_from_runtime_config(config: &RuntimeConfig) -> ConfigSummary {
    ConfigSummary {
        source: config.source.clone(),
        version: config.version,
        provider: normalize_provider(&config.provider),
        endpoint: optional_string(&config.endpoint),
        region: default_string(&config.region, DEFAULT_REGION),
        private_bucket: default_string(&config.private_bucket, DEFAULT_PRIVATE_BUCKET),
        public_bucket: optional_string(&config.public_bucket),
        public_base_url: optional_string(&config.public_base_url),
        upload_url_ttl_seconds: config.upload_url_ttl.as_secs() as u32,
        download_url_ttl_seconds: config.download_url_ttl.as_secs() as u32,
        key_id_configured: !config.key_id.trim().is_empty(),
        application_key_configured: !config.application_key.trim().is_empty(),
        last_applied_by: config.last_applied_by.clone(),
        last_applied_at: config.last_applied_at,
        rollback_source_version: config.rollback_source_version,
        updated_at: config.updated_at,
    }
}

fn history_item_from_record(record: ObjectStorageConfigRecord) -> HistoryItem {
    HistoryItem {
        summary: ConfigSummary {
            source: SOURCE_DATABASE.to_string(),
            version: Some(record.version),
            provider: normalize_provider(&record.provider),
            endpoint: record.endpoint.clone(),
            region: default_string(&record.region, DEFAULT_REGION),
            private_bucket: default_string(&record.private_bucket, DEFAULT_PRIVATE_BUCKET),
            public_bucket: record.public_bucket.clone(),
            public_base_url: record.public_base_url.clone(),
            upload_url_ttl_seconds: record.upload_url_ttl_seconds.max(1) as u32,
            download_url_ttl_seconds: record.download_url_ttl_seconds.max(1) as u32,
            key_id_configured: record
                .encrypted_key_id
                .as_deref()
                .map(|value| !value.trim().is_empty())
                .unwrap_or(false),
            application_key_configured: record
                .encrypted_application_key
                .as_deref()
                .map(|value| !value.trim().is_empty())
                .unwrap_or(false),
            last_applied_by: record.applied_by.clone(),
            last_applied_at: record.activated_at,
            rollback_source_version: record.rollback_source_version,
            updated_at: Some(record.updated_at),
        },
        status: default_string(&record.status, STATUS_ACTIVE),
        change_note: record.change_note,
        created_by: record.created_by,
        created_at: record.created_at,
        applied_by: record.applied_by,
        applied_at: record.activated_at,
    }
}

fn bootstrap_to_runtime_config(config: &BootstrapConfig) -> RuntimeConfig {
    let normalized = normalize_bootstrap_config(config.clone());
    RuntimeConfig {
        source: SOURCE_ENV_FALLBACK.to_string(),
        version: None,
        provider: normalized.provider,
        endpoint: normalized.endpoint,
        region: normalized.region,
        key_id: normalized.key_id,
        application_key: normalized.application_key,
        private_bucket: normalized.private_bucket,
        public_bucket: normalized.public_bucket,
        public_base_url: normalized.public_base_url,
        upload_url_ttl: normalized.upload_url_ttl,
        download_url_ttl: normalized.download_url_ttl,
        last_applied_by: normalized.last_applied_by,
        last_applied_at: normalized.last_applied_at,
        rollback_source_version: None,
        updated_at: normalized.updated_at,
    }
}

fn normalize_bootstrap_config(mut config: BootstrapConfig) -> BootstrapConfig {
    config.provider = normalize_provider(&config.provider);
    config.region = default_string(&config.region, DEFAULT_REGION);
    config.endpoint = normalize_s3_endpoint(Some(config.endpoint.as_str()));
    config.key_id = config.key_id.trim().to_string();
    config.application_key = config.application_key.trim().to_string();
    config.private_bucket = default_string(&config.private_bucket, DEFAULT_PRIVATE_BUCKET);
    config.public_bucket = config.public_bucket.trim().to_string();
    config.public_base_url = config.public_base_url.trim().to_string();
    if config.upload_url_ttl.as_secs() == 0 {
        config.upload_url_ttl = Duration::from_secs(DEFAULT_UPLOAD_URL_TTL_SECONDS as u64);
    }
    if config.download_url_ttl.as_secs() == 0 {
        config.download_url_ttl = Duration::from_secs(DEFAULT_DOWNLOAD_URL_TTL_SECONDS as u64);
    }
    config
}

fn normalize_upsert_input(input: UpsertInput) -> Result<UpsertInput, AppError> {
    Ok(UpsertInput {
        endpoint: normalize_optional_url(input.endpoint.as_deref())?,
        region: optional_string(input.region.unwrap_or_default()),
        key_id: optional_string(input.key_id.unwrap_or_default()),
        application_key: optional_string(input.application_key.unwrap_or_default()),
        private_bucket: optional_string(input.private_bucket.unwrap_or_default()),
        public_bucket: optional_string(input.public_bucket.unwrap_or_default()),
        public_base_url: normalize_optional_url(input.public_base_url.as_deref())?,
        upload_url_ttl_seconds: input.upload_url_ttl_seconds,
        download_url_ttl_seconds: input.download_url_ttl_seconds,
    })
}

fn normalize_s3_endpoint(endpoint: Option<&str>) -> String {
    let trimmed = endpoint.unwrap_or_default().trim().trim_end_matches('/');
    if trimmed.is_empty() {
        return String::new();
    }
    if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
        trimmed.to_string()
    } else {
        format!("https://{trimmed}")
    }
}

fn normalize_optional_url(value: Option<&str>) -> Result<Option<String>, AppError> {
    let trimmed = value.unwrap_or_default().trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    let normalized = normalize_s3_endpoint(Some(trimmed));
    let parsed = reqwest::Url::parse(&normalized)
        .map_err(|_| AppError::ValidationError(format!("无效 URL: {trimmed}")))?;
    if parsed.host_str().is_none() {
        return Err(AppError::ValidationError(format!("无效 URL: {trimmed}")));
    }
    Ok(Some(normalized))
}

fn default_string(value: &str, fallback: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        fallback.to_string()
    } else {
        trimmed.to_string()
    }
}

fn normalize_provider(value: &str) -> String {
    match value.trim() {
        "" | "backblaze_b2" | PROVIDER_S3_COMPATIBLE => PROVIDER_S3_COMPATIBLE.to_string(),
        other => other.to_string(),
    }
}

fn optional_string<T: AsRef<str>>(value: T) -> Option<String> {
    let trimmed = value.as_ref().trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

fn runtime_has_materializable_credentials(runtime: &RuntimeConfig) -> bool {
    !runtime.key_id.trim().is_empty()
        && !runtime.application_key.trim().is_empty()
        && !runtime.endpoint.trim().is_empty()
        && !runtime.region.trim().is_empty()
        && !runtime.private_bucket.trim().is_empty()
}

fn should_sync_materialized_provider(default_name: Option<&str>) -> bool {
    default_name.is_none_or(|name| name.trim() == DEFAULT_PROVIDER_SYNC_NAME)
}

trait StorageSecretCipher: Send + Sync {
    fn encrypt(&self, plaintext: &str) -> Result<String, AppError>;
    fn decrypt(&self, ciphertext: &str) -> Result<String, AppError>;
}

struct LegacySecretCipher {
    inner: SecretCrypto,
}

impl StorageSecretCipher for LegacySecretCipher {
    fn encrypt(&self, plaintext: &str) -> Result<String, AppError> {
        self.inner
            .encrypt_to_base64(plaintext)
            .map_err(AppError::InternalError)
    }

    fn decrypt(&self, ciphertext: &str) -> Result<String, AppError> {
        self.inner
            .decrypt_from_base64(ciphertext)
            .map_err(AppError::InternalError)
    }
}

struct DedicatedStorageConfigCipher {
    cipher: Aes256Gcm,
}

impl DedicatedStorageConfigCipher {
    fn from_env_key(encoded_key: &str) -> Result<Self, AppError> {
        let decoded = decode_storage_cipher_key(encoded_key)?;
        if decoded.len() != 32 {
            return Err(AppError::ValidationError(
                "REDCODE_IM_STORAGE_CONFIG_CIPHER_KEY 需要是 base64 编码后的 32 字节密钥"
                    .to_string(),
            ));
        }

        let cipher = Aes256Gcm::new_from_slice(&decoded)
            .map_err(|err| AppError::InternalError(format!("初始化对象存储配置密钥失败: {err}")))?;
        Ok(Self { cipher })
    }
}

impl StorageSecretCipher for DedicatedStorageConfigCipher {
    fn encrypt(&self, plaintext: &str) -> Result<String, AppError> {
        let mut nonce_bytes = [0u8; 12];
        rand::RngCore::fill_bytes(&mut rand::thread_rng(), &mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);
        let ciphertext = self
            .cipher
            .encrypt(nonce, plaintext.as_bytes())
            .map_err(|err| AppError::InternalError(format!("加密对象存储配置失败: {err}")))?;

        let mut payload = Vec::with_capacity(nonce_bytes.len() + ciphertext.len());
        payload.extend_from_slice(&nonce_bytes);
        payload.extend_from_slice(&ciphertext);
        Ok(base64::engine::general_purpose::STANDARD.encode(payload))
    }

    fn decrypt(&self, ciphertext: &str) -> Result<String, AppError> {
        let payload = base64::engine::general_purpose::STANDARD
            .decode(ciphertext.trim().as_bytes())
            .map_err(|err| AppError::InternalError(format!("解码对象存储配置密文失败: {err}")))?;
        if payload.len() < 12 {
            return Err(AppError::InternalError(
                "对象存储配置密文格式无效".to_string(),
            ));
        }

        let (nonce_bytes, sealed) = payload.split_at(12);
        let nonce = Nonce::from_slice(nonce_bytes);
        let plaintext = self
            .cipher
            .decrypt(nonce, sealed)
            .map_err(|err| AppError::InternalError(format!("解密对象存储配置失败: {err}")))?;

        String::from_utf8(plaintext)
            .map_err(|err| AppError::InternalError(format!("对象存储配置明文编码无效: {err}")))
    }
}

fn decode_storage_cipher_key(value: &str) -> Result<Vec<u8>, AppError> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(AppError::ValidationError(
            "REDCODE_IM_STORAGE_CONFIG_CIPHER_KEY 不能为空".to_string(),
        ));
    }

    for encoding in [
        &base64::engine::general_purpose::STANDARD,
        &base64::engine::general_purpose::URL_SAFE,
        &base64::engine::general_purpose::STANDARD_NO_PAD,
        &base64::engine::general_purpose::URL_SAFE_NO_PAD,
    ] {
        if let Ok(decoded) = encoding.decode(trimmed.as_bytes()) {
            return Ok(decoded);
        }
    }

    Err(AppError::ValidationError(
        "REDCODE_IM_STORAGE_CONFIG_CIPHER_KEY 必须是有效的 base64 字符串".to_string(),
    ))
}

fn build_storage_cipher() -> Option<Arc<dyn StorageSecretCipher>> {
    if let Ok(explicit_key) = env::var("REDCODE_IM_STORAGE_CONFIG_CIPHER_KEY") {
        let cipher = DedicatedStorageConfigCipher::from_env_key(&explicit_key).ok()?;
        return Some(Arc::new(cipher));
    }

    SecretCrypto::new()
        .ok()
        .map(|inner| Arc::new(LegacySecretCipher { inner }) as Arc<dyn StorageSecretCipher>)
}

fn encrypt_optional(
    cipher: &dyn StorageSecretCipher,
    value: &str,
) -> Result<Option<String>, AppError> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    Ok(Some(cipher.encrypt(trimmed)?))
}

fn decrypt_optional(
    cipher: Option<&dyn StorageSecretCipher>,
    value: Option<&str>,
) -> Result<String, AppError> {
    let trimmed = value.unwrap_or_default().trim();
    if trimmed.is_empty() {
        return Ok(String::new());
    }
    let cipher = cipher.ok_or_else(|| {
        AppError::InternalError("当前缺少对象存储配置密钥，无法解密历史版本".to_string())
    })?;
    cipher.decrypt(trimmed)
}

fn env_with_legacy(primary: &str, legacy: &str) -> String {
    env::var(primary)
        .ok()
        .filter(|value| !value.trim().is_empty())
        .or_else(|| env::var(legacy).ok())
        .unwrap_or_default()
}

fn parse_duration_env_with_legacy(primary: &str, legacy: &str, default_seconds: u32) -> Duration {
    let raw = env_with_legacy(primary, legacy);
    let trimmed = raw.trim().to_ascii_lowercase();
    if trimmed.is_empty() {
        return Duration::from_secs(default_seconds as u64);
    }
    if let Ok(seconds) = trimmed.parse::<u64>() {
        return Duration::from_secs(seconds.max(1));
    }

    let (number, unit) = trimmed.split_at(trimmed.len().saturating_sub(1));
    if let Ok(value) = number.parse::<u64>() {
        let seconds = match unit {
            "s" => value,
            "m" => value * 60,
            "h" => value * 3600,
            _ => default_seconds as u64,
        };
        return Duration::from_secs(seconds.max(1));
    }
    Duration::from_secs(default_seconds as u64)
}

#[derive(Debug, Default)]
struct S3OpsExecutor;

#[async_trait]
impl OpsExecutor for S3OpsExecutor {
    async fn probe(&self, config: &RuntimeConfig) -> Result<ProbeResult, AppError> {
        let required_capabilities = vec![
            "s3:ListBucket".to_string(),
            "s3:GetObject".to_string(),
            "s3:PutObject".to_string(),
            "s3:DeleteObject".to_string(),
        ];
        let client = build_s3_client(
            &config.key_id,
            &config.application_key,
            &config.region,
            &config.endpoint,
        )
        .await?;
        let mut allowed_buckets = Vec::new();
        let mut checks = Vec::new();
        match client.list_buckets().send().await {
            Ok(output) => {
                allowed_buckets = output
                    .buckets()
                    .iter()
                    .map(|bucket| ProbeAllowedBucket {
                        id: None,
                        name: bucket.name().map(str::to_string),
                    })
                    .collect();
                checks.push(ProbeCheck {
                    code: "list_buckets".to_string(),
                    status: ProbeStatus::Pass,
                    message: "S3 Bucket 列表读取成功。".to_string(),
                });
            }
            Err(err) => checks.push(ProbeCheck {
                code: "list_buckets".to_string(),
                status: ProbeStatus::Warn,
                message: format!("无法列出全部 Bucket，将继续验证已配置 Bucket: {err}"),
            }),
        }
        let mut accessible_bucket_count = 0;
        for (role, bucket) in [
            ("private", config.private_bucket.trim()),
            ("public", config.public_bucket.trim()),
        ] {
            if bucket.is_empty() {
                continue;
            }
            let exists = client.head_bucket().bucket(bucket).send().await.is_ok();
            if exists {
                accessible_bucket_count += 1;
                if !allowed_buckets
                    .iter()
                    .any(|item| item.name.as_deref() == Some(bucket))
                {
                    allowed_buckets.push(ProbeAllowedBucket {
                        id: None,
                        name: Some(bucket.to_string()),
                    });
                }
            }
            checks.push(ProbeCheck {
                code: format!("{role}_bucket"),
                status: if exists {
                    ProbeStatus::Pass
                } else {
                    ProbeStatus::Warn
                },
                message: if exists {
                    format!("{role} bucket {bucket} 可访问。")
                } else {
                    format!("{role} bucket {bucket} 不存在或当前凭据无权访问。")
                },
            });
        }

        if accessible_bucket_count == 0 {
            checks.push(ProbeCheck {
                code: "s3_connection".to_string(),
                status: ProbeStatus::Fail,
                message: "S3 endpoint、凭据或已配置 Bucket 均未通过访问验证。".to_string(),
            });
        } else {
            checks.push(ProbeCheck {
                code: "s3_connection".to_string(),
                status: ProbeStatus::Pass,
                message: "S3 endpoint、凭据与已配置 Bucket 验证成功。".to_string(),
            });
        }

        let status = aggregate_probe_status(&checks);
        Ok(ProbeResult {
            status,
            allowed_capabilities: Vec::new(),
            required_runtime_capabilities: required_capabilities,
            missing_runtime_capabilities: Vec::new(),
            bucket_init_supported: true,
            s3_api_url: Some(config.endpoint.clone()),
            allowed: ProbeAllowedScope {
                buckets: allowed_buckets,
                name_prefix: None,
            },
            checks,
        })
    }

    async fn init_buckets(&self, config: &RuntimeConfig) -> Result<BucketInitResult, AppError> {
        let client = build_s3_client(
            &config.key_id,
            &config.application_key,
            &config.region,
            &config.endpoint,
        )
        .await?;

        let mut items = Vec::new();
        if !config.private_bucket.trim().is_empty() {
            items.push(init_single_bucket(&client, config.private_bucket.trim(), "private").await);
        }
        if !config.public_bucket.trim().is_empty()
            && config.public_bucket.trim() != config.private_bucket.trim()
        {
            items.push(init_single_bucket(&client, config.public_bucket.trim(), "public").await);
        }

        let status = aggregate_bucket_init_status(&items);
        Ok(BucketInitResult { status, items })
    }
}

async fn build_s3_client(
    key_id: &str,
    application_key: &str,
    region: &str,
    endpoint: &str,
) -> Result<S3Client, AppError> {
    let mut builder = S3ConfigBuilder::new()
        .behavior_version_latest()
        .region(Region::new(region.to_string()))
        .credentials_provider(Credentials::new(
            key_id.trim(),
            application_key.trim(),
            None,
            None,
            "storage-config",
        ))
        .force_path_style(true);
    if !endpoint.trim().is_empty() {
        builder = builder.endpoint_url(endpoint.trim());
    }
    Ok(S3Client::from_conf(builder.build()))
}

async fn init_single_bucket(
    client: &S3Client,
    bucket_name: &str,
    bucket_role: &str,
) -> BucketInitItem {
    if client
        .head_bucket()
        .bucket(bucket_name)
        .send()
        .await
        .is_ok()
    {
        return BucketInitItem {
            bucket_name: bucket_name.to_string(),
            bucket_role: bucket_role.to_string(),
            status: BucketInitItemStatus::AlreadyExists,
            message: "当前 key 的允许桶范围已包含该 Bucket。".to_string(),
        };
    }
    match client.create_bucket().bucket(bucket_name).send().await {
        Ok(_) => BucketInitItem {
            bucket_name: bucket_name.to_string(),
            bucket_role: bucket_role.to_string(),
            status: BucketInitItemStatus::Created,
            message: "Bucket 创建成功。".to_string(),
        },
        Err(err) => BucketInitItem {
            bucket_name: bucket_name.to_string(),
            bucket_role: bucket_role.to_string(),
            status: BucketInitItemStatus::Failed,
            message: format!("创建 Bucket 失败: {err}"),
        },
    }
}

fn aggregate_probe_status(checks: &[ProbeCheck]) -> ProbeStatus {
    if checks.iter().any(|check| check.status == ProbeStatus::Fail) {
        ProbeStatus::Fail
    } else if checks.iter().any(|check| check.status == ProbeStatus::Warn) {
        ProbeStatus::Warn
    } else {
        ProbeStatus::Pass
    }
}

fn aggregate_bucket_init_status(items: &[BucketInitItem]) -> BucketInitStatus {
    let has_failed = items
        .iter()
        .any(|item| item.status == BucketInitItemStatus::Failed);
    let has_success = items.iter().any(|item| {
        item.status == BucketInitItemStatus::Created
            || item.status == BucketInitItemStatus::AlreadyExists
            || item.status == BucketInitItemStatus::Skipped
    });

    match (has_success, has_failed) {
        (true, true) => BucketInitStatus::Partial,
        (true, false) => BucketInitStatus::Success,
        _ => BucketInitStatus::Failed,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Mutex, OnceLock};

    fn env_lock() -> &'static Mutex<()> {
        static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        LOCK.get_or_init(|| Mutex::new(()))
    }

    struct TestEnvGuard {
        key: &'static str,
        previous: Option<String>,
    }

    impl TestEnvGuard {
        fn set(key: &'static str, value: &str) -> Self {
            let previous = env::var(key).ok();
            env::set_var(key, value);
            Self { key, previous }
        }

        fn remove(key: &'static str) -> Self {
            let previous = env::var(key).ok();
            env::remove_var(key);
            Self { key, previous }
        }
    }

    impl Drop for TestEnvGuard {
        fn drop(&mut self) {
            if let Some(previous) = &self.previous {
                env::set_var(self.key, previous);
            } else {
                env::remove_var(self.key);
            }
        }
    }

    #[test]
    fn normalize_s3_endpoint_requires_explicit_endpoint() {
        assert_eq!(normalize_s3_endpoint(None), "");
    }

    #[test]
    fn normalize_s3_endpoint_preserves_http_and_adds_default_scheme() {
        assert_eq!(
            normalize_s3_endpoint(Some("http://rustfs:9000/")),
            "http://rustfs:9000"
        );
        assert_eq!(
            normalize_s3_endpoint(Some("rustfs:9000")),
            "https://rustfs:9000"
        );
    }

    #[test]
    fn bootstrap_applies_legacy_storage_scheme_to_bare_endpoint() {
        let _lock = env_lock().lock().unwrap();
        let _primary = TestEnvGuard::remove("REDCODE_IM_S3_ENDPOINT");
        let _legacy = TestEnvGuard::set("REDCODE_IM_B2_ENDPOINT", "rustfs:9000");
        let _scheme = TestEnvGuard::set("REDCODE_IM_STORAGE_SCHEME", "http");

        assert_eq!(BootstrapConfig::from_env().endpoint, "http://rustfs:9000");
    }

    #[test]
    fn bootstrap_sync_only_updates_system_managed_default_provider() {
        assert!(should_sync_materialized_provider(None));
        assert!(should_sync_materialized_provider(Some("system-s3-runtime")));
        assert!(should_sync_materialized_provider(Some(
            " system-s3-runtime "
        )));
        assert!(!should_sync_materialized_provider(Some("admin-custom-s3")));
    }

    #[test]
    fn normalize_provider_maps_legacy_b2_value_to_s3_compatible() {
        assert_eq!(normalize_provider("backblaze_b2"), PROVIDER_S3_COMPATIBLE);
        assert_eq!(normalize_provider("s3_compatible"), PROVIDER_S3_COMPATIBLE);
        assert_eq!(normalize_provider(""), PROVIDER_S3_COMPATIBLE);
    }

    #[test]
    fn s3_environment_takes_precedence_over_legacy_b2_environment() {
        let _lock = env_lock().lock().unwrap();
        let _primary = TestEnvGuard::set("REDCODE_IM_S3_ENDPOINT", "http://rustfs:9000");
        let _legacy = TestEnvGuard::set("REDCODE_IM_B2_ENDPOINT", "https://legacy.example");

        assert_eq!(
            env_with_legacy("REDCODE_IM_S3_ENDPOINT", "REDCODE_IM_B2_ENDPOINT"),
            "http://rustfs:9000"
        );
    }

    #[test]
    fn s3_environment_falls_back_to_legacy_b2_environment() {
        let _lock = env_lock().lock().unwrap();
        let _primary = TestEnvGuard::remove("REDCODE_IM_S3_ENDPOINT");
        let _legacy = TestEnvGuard::set("REDCODE_IM_B2_ENDPOINT", "https://legacy.example");

        assert_eq!(
            env_with_legacy("REDCODE_IM_S3_ENDPOINT", "REDCODE_IM_B2_ENDPOINT"),
            "https://legacy.example"
        );
    }

    #[test]
    fn parse_duration_env_accepts_suffixes() {
        let _lock = env_lock().lock().unwrap();
        let _primary = TestEnvGuard::set("TEST_DURATION_ENV", "15m");
        let _legacy = TestEnvGuard::remove("TEST_DURATION_ENV_LEGACY");
        assert_eq!(
            parse_duration_env_with_legacy("TEST_DURATION_ENV", "TEST_DURATION_ENV_LEGACY", 1,)
                .as_secs(),
            900
        );
    }

    #[test]
    fn aggregate_probe_status_prefers_fail_then_warn() {
        assert_eq!(
            aggregate_probe_status(&[
                ProbeCheck {
                    code: "a".into(),
                    status: ProbeStatus::Pass,
                    message: String::new(),
                },
                ProbeCheck {
                    code: "b".into(),
                    status: ProbeStatus::Warn,
                    message: String::new(),
                },
            ]),
            ProbeStatus::Warn
        );
    }

    #[test]
    fn build_storage_cipher_prefers_dedicated_env_key() {
        let _lock = env_lock().lock().unwrap();
        let _dedicated = TestEnvGuard::set(
            "REDCODE_IM_STORAGE_CONFIG_CIPHER_KEY",
            "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
        );
        let _data = TestEnvGuard::remove("DATA_ENCRYPTION_KEY");
        let _jwt = TestEnvGuard::remove("JWT_SECRET");

        let cipher = build_storage_cipher().expect("cipher should be created");
        let encrypted = cipher.encrypt("hello-s3").expect("encrypt should work");
        let decrypted = cipher.decrypt(&encrypted).expect("decrypt should work");

        assert_eq!(decrypted, "hello-s3");
    }

    #[test]
    fn build_storage_cipher_falls_back_to_legacy_secret_crypto() {
        let _lock = env_lock().lock().unwrap();
        let _dedicated = TestEnvGuard::remove("REDCODE_IM_STORAGE_CONFIG_CIPHER_KEY");
        let _data = TestEnvGuard::set("DATA_ENCRYPTION_KEY", "legacy-secret-key");
        let _jwt = TestEnvGuard::remove("JWT_SECRET");

        let cipher = build_storage_cipher().expect("fallback cipher should be created");
        let encrypted = cipher.encrypt("legacy").expect("encrypt should work");
        let decrypted = cipher.decrypt(&encrypted).expect("decrypt should work");

        assert_eq!(decrypted, "legacy");
    }
}
