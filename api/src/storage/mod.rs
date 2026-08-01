pub mod s3;

use crate::database::models::{StorageProvider, StorageProviderType};
use crate::error::AppError;
use async_trait::async_trait;
use bytes::Bytes;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Bucket 信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BucketInfo {
    pub name: String,
    pub region: String,
    pub creation_date: Option<String>,
}

/// 前端直传所需的签名信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DirectUploadSignature {
    pub url: String,
    pub method: String,
    pub headers: BTreeMap<String, String>,
    pub key: String,
}

/// 对象基础元数据（用于上传完成校验与清理任务）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ObjectHead {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content_length: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub etag: Option<String>,
}

/// 存储服务 trait
#[async_trait]
pub trait StorageService: Send + Sync {
    /// 上传文件
    async fn upload_file(
        &self,
        key: &str,
        content: Bytes,
        content_type: Option<&str>,
    ) -> Result<String, AppError>;

    /// 删除文件
    async fn delete_file(&self, key: &str) -> Result<(), AppError>;

    /// 检查文件是否存在
    async fn file_exists(&self, key: &str) -> Result<bool, AppError>;

    /// 获取对象基础元数据（默认不支持）
    async fn head_object(&self, _key: &str) -> Result<ObjectHead, AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持对象元数据查询".to_string(),
        ))
    }

    /// 获取文件访问 URL
    fn get_file_url(&self, key: &str) -> String;

    /// 获取所有 bucket 列表
    async fn list_buckets(&self) -> Result<Vec<BucketInfo>, AppError>;

    /// 创建 bucket
    async fn create_bucket(&self, bucket_name: &str) -> Result<(), AppError>;

    /// 生成用于前端直传的签名信息
    async fn generate_direct_upload_signature(
        &self,
        _key: &str,
        _content_type: Option<&str>,
    ) -> Result<DirectUploadSignature, AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持前端直传上传".to_string(),
        ))
    }

    /// 初始化 Multipart Upload 会话（用于大文件分片直传）
    async fn initiate_multipart_upload(
        &self,
        _key: &str,
        _content_type: Option<&str>,
    ) -> Result<String, AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持大文件分片直传".to_string(),
        ))
    }

    /// 生成 Upload Part 的直传签名（PUT partNumber + uploadId）
    async fn generate_multipart_upload_part_signature(
        &self,
        _key: &str,
        _upload_id: &str,
        _part_number: i32,
        _content_type: Option<&str>,
    ) -> Result<DirectUploadSignature, AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持大文件分片直传".to_string(),
        ))
    }

    /// 完成 Multipart Upload（合并分片）
    async fn complete_multipart_upload(
        &self,
        _key: &str,
        _upload_id: &str,
        _parts: &[(i32, String)],
    ) -> Result<(), AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持大文件分片直传".to_string(),
        ))
    }

    /// 中止 Multipart Upload（清理分片会话）
    async fn abort_multipart_upload(&self, _key: &str, _upload_id: &str) -> Result<(), AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持大文件分片直传".to_string(),
        ))
    }

    /// 生成带过期时间的下载 URL
    async fn generate_download_url(
        &self,
        _key: &str,
        _expires_in: Option<u32>,
    ) -> Result<String, AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持生成下载链接".to_string(),
        ))
    }
}

/// 创建存储服务实例
pub fn create_storage_service(
    provider: &StorageProvider,
) -> Result<Box<dyn StorageService>, AppError> {
    match provider.provider_type {
        StorageProviderType::S3Compatible => {
            if provider.bucket_name.is_none() {
                return Err(AppError::ValidationError(
                    "S3 兼容对象存储需要配置 bucket_name".to_string(),
                ));
            }
            Ok(Box::new(s3::S3CompatibleService::new(
                provider.secret_id.clone(),
                provider.secret_key.clone(),
                provider.region.clone(),
                provider.endpoint.clone(),
                provider.bucket_name.clone().unwrap(),
            )?))
        }
        _ => Err(AppError::ValidationError(format!(
            "不支持的存储提供商类型: {:?}",
            provider.provider_type
        ))),
    }
}

/// 创建存储服务实例（不需要 bucket_name，用于列表和创建 bucket）
pub fn create_storage_service_without_bucket(
    provider: &StorageProvider,
) -> Result<Box<dyn StorageService>, AppError> {
    match provider.provider_type {
        StorageProviderType::S3Compatible => {
            Ok(Box::new(s3::S3CompatibleService::new_without_bucket(
                provider.secret_id.clone(),
                provider.secret_key.clone(),
                provider.region.clone(),
                provider.endpoint.clone(),
            )?))
        }
        _ => Err(AppError::ValidationError(format!(
            "不支持的存储提供商类型: {:?}",
            provider.provider_type
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::models::StorageProviderType;
    use chrono::Utc;
    use uuid::Uuid;

    #[test]
    fn test_s3_sanitize_endpoint_preserves_scheme_and_trims_trailing_slash() {
        assert_eq!(
            crate::storage::s3::sanitize_endpoint("http://rustfs:9000/"),
            "http://rustfs:9000"
        );
        assert_eq!(
            crate::storage::s3::sanitize_endpoint("rustfs:9000"),
            "https://rustfs:9000"
        );
    }

    #[test]
    fn test_s3_clamp_signature_ttl_uses_default_and_max() {
        assert_eq!(crate::storage::s3::clamp_signature_ttl(0), 900);
        assert_eq!(crate::storage::s3::clamp_signature_ttl(100), 100);
        assert_eq!(crate::storage::s3::clamp_signature_ttl(999_999), 86_400);
    }

    #[test]
    fn test_s3_get_file_url_uses_rustfs_path_style_endpoint() {
        let service = crate::storage::s3::S3CompatibleService::new(
            "access-key".to_string(),
            "secret-key".to_string(),
            "us-east-1".to_string(),
            "http://rustfs:9000/".to_string(),
            "redcode-im-private".to_string(),
        )
        .expect("service should build");

        let url = service.get_file_url("avatars/demo user.png");
        assert!(
            url.starts_with("http://rustfs:9000/redcode-im-private/"),
            "unexpected host/path style url: {url}"
        );
        assert!(
            url.ends_with("/redcode-im-private/avatars/demo%20user.png"),
            "unexpected encoded object key: {url}"
        );
    }

    #[test]
    fn test_create_storage_service_supports_s3_provider() {
        let provider = StorageProvider {
            id: Uuid::new_v4(),
            provider_type: StorageProviderType::S3Compatible,
            name: "rustfs".to_string(),
            secret_id: "access-key".to_string(),
            secret_key: "secret-key".to_string(),
            region: "us-east-1".to_string(),
            endpoint: "http://rustfs:9000".to_string(),
            bucket_name: Some("redcode-im-private".to_string()),
            is_active: true,
            is_default: true,
            description: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            updated_by: None,
        };

        let result = create_storage_service(&provider);
        assert!(result.is_ok(), "S3-compatible provider should be accepted");
    }

    #[test]
    fn test_create_storage_service_rejects_unknown_provider() {
        let provider = StorageProvider {
            id: Uuid::new_v4(),
            provider_type: StorageProviderType::Unknown,
            name: "unknown".to_string(),
            secret_id: "key-id".to_string(),
            secret_key: "application-key".to_string(),
            region: "us-east-1".to_string(),
            endpoint: "http://rustfs:9000".to_string(),
            bucket_name: Some("demo-private-bucket".to_string()),
            is_active: true,
            is_default: false,
            description: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            updated_by: None,
        };

        let result = create_storage_service(&provider);
        assert!(result.is_err(), "unknown provider must be rejected");
    }
}
