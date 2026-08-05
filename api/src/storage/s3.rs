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
const DEFAULT_REGION: &str = "us-east-1";

fn is_storage_network_disabled() -> bool {
    std::env::var("REDCODE_IM_STORAGE_DISABLE_NETWORK")
        .ok()
        .is_some_and(|value| matches!(value.trim().to_ascii_lowercase().as_str(), "1" | "true"))
}

pub(crate) fn sanitize_endpoint(endpoint: &str) -> String {
    let endpoint = endpoint.trim().trim_end_matches('/');
    if endpoint.is_empty() {
        String::new()
    } else if endpoint.starts_with("http://") || endpoint.starts_with("https://") {
        endpoint.to_string()
    } else {
        format!("https://{endpoint}")
    }
}

fn ensure_endpoint_url(endpoint: &str) -> String {
    sanitize_endpoint(endpoint)
}

fn presign_public_endpoint() -> Option<String> {
    std::env::var("REDCODE_IM_S3_PRESIGN_PUBLIC_ENDPOINT")
        .or_else(|_| std::env::var("REDCODE_IM_B2_PRESIGN_PUBLIC_ENDPOINT"))
        .ok()
        .map(|value| value.trim().trim_end_matches('/').to_string())
        .filter(|value| !value.is_empty())
}

fn resolve_presign_endpoint(internal_endpoint: &str, public_endpoint: Option<&str>) -> String {
    public_endpoint
        .map(sanitize_endpoint)
        .unwrap_or_else(|| sanitize_endpoint(internal_endpoint))
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

pub struct S3CompatibleService {
    region: String,
    endpoint: String,
    bucket_name: String,
    client: Client,
    presign_client: Client,
}

impl S3CompatibleService {
    pub fn new(
        secret_id: String,
        secret_key: String,
        region: String,
        endpoint: String,
        bucket_name: String,
    ) -> Result<Self, AppError> {
        let public_endpoint = presign_public_endpoint();
        let presign_endpoint = resolve_presign_endpoint(&endpoint, public_endpoint.as_deref());
        Ok(Self {
            region: normalize_region(&region),
            endpoint: sanitize_endpoint(&endpoint),
            bucket_name,
            client: build_client(&secret_id, &secret_key, &region, &endpoint)?,
            presign_client: build_client(&secret_id, &secret_key, &region, &presign_endpoint)?,
        })
    }

    pub fn new_without_bucket(
        secret_id: String,
        secret_key: String,
        region: String,
        endpoint: String,
    ) -> Result<Self, AppError> {
        let public_endpoint = presign_public_endpoint();
        let presign_endpoint = resolve_presign_endpoint(&endpoint, public_endpoint.as_deref());
        Ok(Self {
            region: normalize_region(&region),
            endpoint: sanitize_endpoint(&endpoint),
            bucket_name: String::new(),
            client: build_client(&secret_id, &secret_key, &region, &endpoint)?,
            presign_client: build_client(&secret_id, &secret_key, &region, &presign_endpoint)?,
        })
    }

    fn require_bucket_name(&self) -> Result<&str, AppError> {
        let bucket_name = self.bucket_name.trim();
        if bucket_name.is_empty() {
            Err(AppError::ValidationError(
                "S3 兼容对象存储需要配置 bucket_name".to_string(),
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
            .map_err(|e| AppError::InternalError(format!("创建 S3 presign 配置失败: {}", e)))
    }
}

#[async_trait]
impl StorageService for S3CompatibleService {
    async fn upload_file(
        &self,
        key: &str,
        content: Bytes,
        content_type: Option<&str>,
    ) -> Result<String, AppError> {
        if is_storage_network_disabled() {
            let url = self.get_file_url(key);
            debug!(
                "跳过 S3 upload_file（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}, url={}",
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
            error!("上传文件到 S3 失败: key={}, error={}", key, e);
            AppError::InternalError(format!("上传文件到 S3 兼容对象存储 失败: {}", e))
        })?;

        Ok(self.get_file_url(key))
    }

    async fn delete_file(&self, key: &str) -> Result<(), AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 S3 delete_file（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}",
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
                error!("删除 S3 文件失败: key={}, error={}", key, e);
                AppError::InternalError(format!("删除 S3 兼容对象存储 文件失败: {}", e))
            })?;
        Ok(())
    }

    async fn file_exists(&self, key: &str) -> Result<bool, AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 S3 file_exists（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}",
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
                "跳过 S3 head_object（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}",
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
                let is_not_found = e
                    .as_service_error()
                    .is_some_and(|service_error| service_error.is_not_found());
                let message = e.to_string();
                if is_not_found || is_not_found_error_message(&message) {
                    AppError::NotFound("对象不存在".to_string())
                } else {
                    error!("获取 S3 对象元数据失败: key={}, error={}", key, message);
                    AppError::InternalError(format!(
                        "获取 S3 兼容对象存储 对象元数据失败: {}",
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
            debug!("跳过 S3 list_buckets（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）");
            return Ok(Vec::new());
        }

        let output = self.client.list_buckets().send().await.map_err(|e| {
            error!("获取 S3 bucket 列表失败: {}", e);
            AppError::InternalError(format!("获取 S3 兼容对象存储 bucket 列表失败: {}", e))
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
                "跳过 S3 create_bucket（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: name={}",
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
                    "创建 S3 bucket 失败: name={}, error={}",
                    bucket_name, message
                );
                AppError::InternalError(format!("创建 S3 兼容对象存储 bucket 失败: {}", message))
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
            .presign_client
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
            .map_err(|e| AppError::InternalError(format!("生成 S3 上传签名失败: {}", e)))?;

        Ok(DirectUploadSignature {
            url: presigned.uri().to_string(),
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
                "跳过 S3 initiate_multipart_upload（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}, upload_id={}",
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
            AppError::InternalError(format!("初始化 S3 兼容对象存储 分片上传失败: {}", e))
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
            .presign_client
            .upload_part()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .upload_id(upload_id)
            .part_number(part_number)
            .presigned(Self::presigning_config(None)?)
            .await
            .map_err(|e| AppError::InternalError(format!("生成 S3 分片上传签名失败: {}", e)))?;

        Ok(DirectUploadSignature {
            url: presigned.uri().to_string(),
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
                "跳过 S3 complete_multipart_upload（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}, upload_id={}, parts={}",
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
                AppError::InternalError(format!("完成 S3 兼容对象存储 分片上传失败: {}", e))
            })?;

        Ok(())
    }

    async fn abort_multipart_upload(&self, key: &str, upload_id: &str) -> Result<(), AppError> {
        if is_storage_network_disabled() {
            debug!(
                "跳过 S3 abort_multipart_upload（REDCODE_IM_STORAGE_DISABLE_NETWORK=1）: key={}, upload_id={}",
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
                AppError::InternalError(format!("中止 S3 兼容对象存储 分片上传失败: {}", e))
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
            .presign_client
            .get_object()
            .bucket(bucket_name)
            .key(normalize_object_key(key))
            .presigned(Self::presigning_config(expires_in)?)
            .await
            .map_err(|e| AppError::InternalError(format!("生成 S3 下载链接失败: {}", e)))?;

        Ok(presigned.uri().to_string())
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
        "redcode-im-s3-compatible",
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

#[cfg(test)]
mod tests {
    use super::{resolve_presign_endpoint, sanitize_endpoint};

    #[test]
    fn endpoint_normalization_preserves_explicit_http() {
        assert_eq!(
            sanitize_endpoint("http://rustfs:9000/"),
            "http://rustfs:9000"
        );
        assert_eq!(sanitize_endpoint("rustfs:9000"), "https://rustfs:9000");
    }

    #[test]
    fn public_endpoint_is_used_before_presigning() {
        assert_eq!(
            resolve_presign_endpoint("http://rustfs:9000", Some("https://im-test-1.codelib.cc/"),),
            "https://im-test-1.codelib.cc"
        );
        assert_eq!(
            resolve_presign_endpoint("http://rustfs:9000", None),
            "http://rustfs:9000"
        );
    }
}
