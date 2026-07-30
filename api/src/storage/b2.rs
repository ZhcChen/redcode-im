use crate::error::AppError;
use crate::storage::{BucketInfo, DirectUploadSignature, ObjectHead, StorageService};
use async_trait::async_trait;
use aws_credential_types::Credentials;
use aws_sdk_s3::{
    config::{Builder as S3ConfigBuilder, Region},
    presigning::PresigningConfig,
    primitives::ByteStream,
    types::{CompletedMultipartUpload, CompletedPart},
    Client,
};
use bytes::Bytes;
use std::{collections::BTreeMap, time::Duration};
use tracing::{debug, error, warn};
use uuid::Uuid;

const DEFAULT_SIGNATURE_TTL: i64 = 900;
const MAX_SIGNATURE_TTL: i64 = 24 * 3600;
const DEFAULT_REGION: &str = "us-east-005";

fn is_storage_network_disabled() -> bool {
    std::env::var("REDCODE_IM_STORAGE_DISABLE_NETWORK")
        .ok()
        .is_some_and(|value| matches!(value.trim().to_ascii_lowercase().as_str(), "1" | "true"))
}

fn storage_request_scheme() -> &'static str {
    match std::env::var("REDCODE_IM_STORAGE_SCHEME") {
        Ok(v) if v.trim().eq_ignore_ascii_case("http") => "http",
        _ => "https",
    }
}

pub(crate) fn sanitize_endpoint(endpoint: &str) -> String {
    endpoint
        .trim()
        .trim_start_matches("https://")
        .trim_start_matches("http://")
        .trim_start_matches("//")
        .trim_end_matches('/')
        .to_string()
}

fn ensure_endpoint_url(endpoint: &str) -> String {
    let sanitized = sanitize_endpoint(endpoint);
    if sanitized.is_empty() {
        String::new()
    } else {
        format!("{}://{}", storage_request_scheme(), sanitized)
    }
}

fn presign_public_endpoint() -> Option<String> {
    std::env::var("REDCODE_IM_B2_PRESIGN_PUBLIC_ENDPOINT")
        .ok()
        .map(|value| value.trim().trim_end_matches('/').to_string())
        .filter(|value| !value.is_empty())
}

fn rewrite_presigned_url_for_client(raw_url: String) -> String {
    let Some(public_endpoint) = presign_public_endpoint() else {
        return raw_url;
    };

    let Ok(mut original) = reqwest::Url::parse(&raw_url) else {
        return raw_url;
    };
    let Ok(public) = reqwest::Url::parse(&public_endpoint) else {
        return raw_url;
    };

    let _ = original.set_scheme(public.scheme());
    let _ = original.set_host(public.host_str());
    let _ = original.set_port(public.port());
    original.to_string()
}

fn normalize_region(region: &str) -> String {
    let trimmed = region.trim();
    if trimmed.is_empty() {
        DEFAULT_REGION.to_string()
    } else {
        trimmed.to_string()
    }
}

fn normalize_object_key(key: &str) -> &str {
    key.trim().trim_start_matches('/')
}

fn encode_object_key(key: &str) -> String {
    normalize_object_key(key)
        .split('/')
        .filter(|segment| !segment.is_empty())
        .map(|segment| urlencoding::encode(segment).to_string())
        .collect::<Vec<_>>()
        .join("/")
}

pub(crate) fn clamp_signature_ttl(ttl_seconds: i64) -> i64 {
    if ttl_seconds <= 0 {
        DEFAULT_SIGNATURE_TTL
    } else {
        ttl_seconds.min(MAX_SIGNATURE_TTL)
    }
}

fn normalize_etag(value: &str) -> String {
    value.trim().trim_matches('"').to_string()
}

fn map_presigned_headers<'a>(
    headers: impl Iterator<Item = (&'a str, &'a str)>,
) -> BTreeMap<String, String> {
    headers
        .map(|(name, value)| (name.to_string(), value.to_string()))
        .collect()
}

fn is_not_found_error_message(message: &str) -> bool {
    let normalized = message.trim().to_ascii_lowercase();
    normalized.contains("notfound")
        || normalized.contains("no such key")
        || normalized.contains("nosuchkey")
        || normalized.contains("status code: 404")
        || normalized.contains("http status: 404")
}

pub struct BackblazeB2Service {
    region: String,
    endpoint: String,
    bucket_name: String,
    client: Client,
}

impl BackblazeB2Service {
    pub fn new(
        secret_id: String,
        secret_key: String,
        region: String,
        endpoint: String,
        bucket_name: String,
    ) -> Result<Self, AppError> {
        Ok(Self {
            region: normalize_region(&region),
            endpoint: sanitize_endpoint(&endpoint),
            bucket_name,
            client: build_client(&secret_id, &secret_key, &region, &endpoint)?,
        })
    }

    pub fn new_without_bucket(
        secret_id: String,
        secret_key: String,
        region: String,
        endpoint: String,
    ) -> Result<Self, AppError> {
        Ok(Self {
            region: normalize_region(&region),
            endpoint: sanitize_endpoint(&endpoint),
            bucket_name: String::new(),
            client: build_client(&secret_id, &secret_key, &region, &endpoint)?,
        })
    }

    fn require_bucket_name(&self) -> Result<&str, AppError> {
        let bucket_name = self.bucket_name.trim();
        if bucket_name.is_empty() {
            Err(AppError::ValidationError(
                "Backblaze B2 需要配置 bucket_name".to_string(),
            ))
        } else {
            Ok(bucket_name)
        }
    }

    fn get_full_url_with_bucket(&self, bucket_name: &str, key: &str) -> String {
        let encoded_key = encode_object_key(key);
        if encoded_key.is_empty() {
            format!("{}/{}", ensure_endpoint_url(&self.endpoint), bucket_name)
        } else {
            format!(
                "{}/{}/{}",
                ensure_endpoint_url(&self.endpoint),
                bucket_name,
                encoded_key
            )
        }
    }

    fn presigning_config(ttl_seconds: Option<u32>) -> Result<PresigningConfig, AppError> {
        let ttl = ttl_seconds
            .map(|value| value as i64)
            .unwrap_or(DEFAULT_SIGNATURE_TTL);
        PresigningConfig::expires_in(Duration::from_secs(clamp_signature_ttl(ttl) as u64))
            .map_err(|e| AppError::InternalError(format!("创建 B2 presign 配置失败: {}", e)))
    }
}

#[async_trait]
impl StorageService for BackblazeB2Service {
    async fn upload_file(
        &self,
        key: &str,
        content: Bytes,
        content_type: Option<&str>,
    ) -> Result<String, AppError> {
        if is_storage_network_disabled() {
            let url = self.get_file_url(key);
            debug!(
                "跳过 B2 upload_file（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}, url={}",
                key, url
            );
            return Ok(url);
        }

        let bucket_name = self.require_bucket_name()?;
        let mut request = self
            .client
            .put_object()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .body(ByteStream::from(content));
        if let Some(content_type) = content_type
            .map(str::trim)
            .filter(|value| !value.is_empty())
        {
            request = request.content_type(content_type);
        }

        request.send().await.map_err(|e| {
            error!("上传文件到 B2 失败: key={}, error={}", key, e);
            AppError::InternalError(format!("上传文件到 Backblaze B2 失败: {}", e))
        })?;

        Ok(self.get_file_url(key))
    }

    async fn delete_file(&self, key: &str) -> Result<(), AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 B2 delete_file（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}",
                key
            );
            return Ok(());
        }

        let bucket_name = self.require_bucket_name()?;
        self.client
            .delete_object()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .send()
            .await
            .map_err(|e| {
                error!("删除 B2 文件失败: key={}, error={}", key, e);
                AppError::InternalError(format!("删除 Backblaze B2 文件失败: {}", e))
            })?;
        Ok(())
    }

    async fn file_exists(&self, key: &str) -> Result<bool, AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 B2 file_exists（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}",
                key
            );
            return Ok(true);
        }

        match self.head_object(key).await {
            Ok(_) => Ok(true),
            Err(AppError::NotFound(_)) => Ok(false),
            Err(e) => Err(e),
        }
    }

    async fn head_object(&self, key: &str) -> Result<ObjectHead, AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 B2 head_object（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}",
                key
            );
            return Ok(ObjectHead {
                content_length: None,
                etag: None,
            });
        }

        let bucket_name = self.require_bucket_name()?;
        let output = self
            .client
            .head_object()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .send()
            .await
            .map_err(|e| {
                let message = e.to_string();
                if is_not_found_error_message(&message) {
                    AppError::NotFound("对象不存在".to_string())
                } else {
                    error!("获取 B2 对象元数据失败: key={}, error={}", key, message);
                    AppError::InternalError(format!(
                        "获取 Backblaze B2 对象元数据失败: {}",
                        message
                    ))
                }
            })?;

        Ok(ObjectHead {
            content_length: output.content_length().map(|value| value as u64),
            etag: output.e_tag().map(normalize_etag),
        })
    }

    fn get_file_url(&self, key: &str) -> String {
        let bucket_name = self.bucket_name.trim();
        if bucket_name.is_empty() {
            ensure_endpoint_url(&self.endpoint)
        } else {
            self.get_full_url_with_bucket(bucket_name, key)
        }
    }

    async fn list_buckets(&self) -> Result<Vec<BucketInfo>, AppError> {
        if is_storage_network_disabled() {
            debug!("跳过 B2 list_buckets（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）");
            return Ok(Vec::new());
        }

        let output = self.client.list_buckets().send().await.map_err(|e| {
            error!("获取 B2 bucket 列表失败: {}", e);
            AppError::InternalError(format!("获取 Backblaze B2 bucket 列表失败: {}", e))
        })?;

        Ok(output
            .buckets()
            .iter()
            .map(|bucket| BucketInfo {
                name: bucket.name().unwrap_or_default().to_string(),
                region: self.region.clone(),
                creation_date: bucket.creation_date().map(|value| value.to_string()),
            })
            .collect())
    }

    async fn create_bucket(&self, bucket_name: &str) -> Result<(), AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 B2 create_bucket（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: name={}",
                bucket_name
            );
            return Ok(());
        }

        let bucket_name = bucket_name.trim();
        if bucket_name.is_empty() {
            return Err(AppError::ValidationError("bucket 名称不能为空".to_string()));
        }

        self.client
            .create_bucket()
            .bucket(bucket_name)
            .send()
            .await
            .map_err(|e| {
                let message = e.to_string();
                warn!(
                    "创建 B2 bucket 失败: name={}, error={}",
                    bucket_name, message
                );
                AppError::InternalError(format!("创建 Backblaze B2 bucket 失败: {}", message))
            })?;

        Ok(())
    }

    async fn generate_direct_upload_signature(
        &self,
        key: &str,
        content_type: Option<&str>,
    ) -> Result<DirectUploadSignature, AppError> {
        let bucket_name = self.require_bucket_name()?;
        let mut request = self
            .client
            .put_object()
            .bucket(bucket_name)
            .key(normalize_object_key(key));
        if let Some(content_type) = content_type
            .map(str::trim)
            .filter(|value| !value.is_empty())
        {
            request = request.content_type(content_type);
        }

        let presigned = request
            .presigned(Self::presigning_config(None)?)
            .await
            .map_err(|e| AppError::InternalError(format!("生成 B2 上传签名失败: {}", e)))?;

        Ok(DirectUploadSignature {
            url: rewrite_presigned_url_for_client(presigned.uri().to_string()),
            method: presigned.method().to_string(),
            headers: map_presigned_headers(presigned.headers()),
            key: key.to_string(),
        })
    }

    async fn initiate_multipart_upload(
        &self,
        key: &str,
        content_type: Option<&str>,
    ) -> Result<String, AppError> {
        if is_storage_network_disabled() {
            let upload_id = Uuid::new_v4().simple().to_string();
            debug!(
                "跳过 B2 initiate_multipart_upload（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}, upload_id={}",
                key, upload_id
            );
            return Ok(upload_id);
        }

        let bucket_name = self.require_bucket_name()?;
        let mut request = self
            .client
            .create_multipart_upload()
            .bucket(bucket_name)
            .key(normalize_object_key(key));
        if let Some(content_type) = content_type
            .map(str::trim)
            .filter(|value| !value.is_empty())
        {
            request = request.content_type(content_type);
        }

        let output = request.send().await.map_err(|e| {
            AppError::InternalError(format!("初始化 Backblaze B2 分片上传失败: {}", e))
        })?;

        output.upload_id().map(str::to_string).ok_or_else(|| {
            AppError::InternalError("初始化分片上传成功但未返回 upload_id".to_string())
        })
    }

    async fn generate_multipart_upload_part_signature(
        &self,
        key: &str,
        upload_id: &str,
        part_number: i32,
        _content_type: Option<&str>,
    ) -> Result<DirectUploadSignature, AppError> {
        if part_number <= 0 {
            return Err(AppError::ValidationError(
                "part_number 必须大于 0".to_string(),
            ));
        }

        let bucket_name = self.require_bucket_name()?;
        let presigned = self
            .client
            .upload_part()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .upload_id(upload_id)
            .part_number(part_number)
            .presigned(Self::presigning_config(None)?)
            .await
            .map_err(|e| AppError::InternalError(format!("生成 B2 分片上传签名失败: {}", e)))?;

        Ok(DirectUploadSignature {
            url: rewrite_presigned_url_for_client(presigned.uri().to_string()),
            method: presigned.method().to_string(),
            headers: map_presigned_headers(presigned.headers()),
            key: key.to_string(),
        })
    }

    async fn complete_multipart_upload(
        &self,
        key: &str,
        upload_id: &str,
        parts: &[(i32, String)],
    ) -> Result<(), AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 B2 complete_multipart_upload（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}, upload_id={}, parts={}",
                key,
                upload_id,
                parts.len()
            );
            return Ok(());
        }

        if parts.is_empty() {
            return Err(AppError::ValidationError(
                "完成分片上传时 parts 不能为空".to_string(),
            ));
        }

        let bucket_name = self.require_bucket_name()?;
        let completed_parts = parts
            .iter()
            .map(|(part_number, etag)| {
                CompletedPart::builder()
                    .part_number(*part_number)
                    .e_tag(normalize_etag(etag))
                    .build()
            })
            .collect::<Vec<_>>();

        let completed_upload = CompletedMultipartUpload::builder()
            .set_parts(Some(completed_parts))
            .build();

        self.client
            .complete_multipart_upload()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .upload_id(upload_id)
            .multipart_upload(completed_upload)
            .send()
            .await
            .map_err(|e| {
                AppError::InternalError(format!("完成 Backblaze B2 分片上传失败: {}", e))
            })?;

        Ok(())
    }

    async fn abort_multipart_upload(&self, key: &str, upload_id: &str) -> Result<(), AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 B2 abort_multipart_upload（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}, upload_id={}",
                key, upload_id
            );
            return Ok(());
        }

        let bucket_name = self.require_bucket_name()?;
        self.client
            .abort_multipart_upload()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .upload_id(upload_id)
            .send()
            .await
            .map_err(|e| {
                AppError::InternalError(format!("中止 Backblaze B2 分片上传失败: {}", e))
            })?;
        Ok(())
    }

    async fn generate_download_url(
        &self,
        key: &str,
        expires_in: Option<u32>,
    ) -> Result<String, AppError> {
        let bucket_name = self.require_bucket_name()?;
        let presigned = self
            .client
            .get_object()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .presigned(Self::presigning_config(expires_in)?)
            .await
            .map_err(|e| AppError::InternalError(format!("生成 B2 下载链接失败: {}", e)))?;

        Ok(rewrite_presigned_url_for_client(
            presigned.uri().to_string(),
        ))
    }
}

fn build_client(
    secret_id: &str,
    secret_key: &str,
    region: &str,
    endpoint: &str,
) -> Result<Client, AppError> {
    let credentials = Credentials::new(
        secret_id.trim(),
        secret_key.trim(),
        None,
        None,
        "redcode-im-backblaze-b2",
    );
    let region = Region::new(normalize_region(region));
    let endpoint_url = ensure_endpoint_url(endpoint);

    let mut builder = S3ConfigBuilder::new()
        .behavior_version_latest()
        .credentials_provider(credentials)
        .region(region)
        .force_path_style(true);
    if !endpoint_url.is_empty() {
        builder = builder.endpoint_url(endpoint_url);
    }

    Ok(Client::from_conf(builder.build()))
}
