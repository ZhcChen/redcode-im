pub mod cos;

use crate::database::models::{StorageProvider, StorageProviderType};
use crate::error::AppError;
use crate::i18n::message::MessageParams;
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

/// CORS 规则
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CorsRule {
    pub allowed_origins: Vec<String>,
    pub allowed_methods: Vec<String>,
    #[serde(default)]
    pub allowed_headers: Vec<String>,
    #[serde(default)]
    pub expose_headers: Vec<String>,
    pub max_age_seconds: Option<u32>,
}

fn storage_validation_error(message_key: &'static str) -> AppError {
    AppError::ValidationError(String::new()).with_message_key(message_key)
}

fn storage_validation_error_with_params(
    message_key: &'static str,
    params: MessageParams,
) -> AppError {
    AppError::ValidationError(String::new()).with_message_key_and_params(message_key, Some(params))
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
        Err(storage_validation_error("storage.object_head_unsupported"))
    }

    /// 获取文件访问 URL
    fn get_file_url(&self, key: &str) -> String;

    /// 获取所有 bucket 列表
    async fn list_buckets(&self) -> Result<Vec<BucketInfo>, AppError>;

    /// 创建 bucket
    async fn create_bucket(&self, bucket_name: &str) -> Result<(), AppError>;

    /// 获取跨域规则
    async fn get_cors_rules(&self) -> Result<Vec<CorsRule>, AppError> {
        Err(storage_validation_error("storage.cors_get_unsupported"))
    }

    /// 设置跨域规则
    async fn set_cors_rules(&self, _rules: &[CorsRule]) -> Result<(), AppError> {
        Err(storage_validation_error("storage.cors_set_unsupported"))
    }

    /// 生成用于前端直传的签名信息
    async fn generate_direct_upload_signature(
        &self,
        _key: &str,
        _content_type: Option<&str>,
    ) -> Result<DirectUploadSignature, AppError> {
        Err(storage_validation_error(
            "storage.direct_upload_unsupported",
        ))
    }

    /// 初始化 Multipart Upload 会话（用于大文件分片直传）
    async fn initiate_multipart_upload(
        &self,
        _key: &str,
        _content_type: Option<&str>,
    ) -> Result<String, AppError> {
        Err(storage_validation_error("storage.multipart_unsupported"))
    }

    /// 生成 Upload Part 的直传签名（PUT partNumber + uploadId）
    async fn generate_multipart_upload_part_signature(
        &self,
        _key: &str,
        _upload_id: &str,
        _part_number: i32,
        _content_type: Option<&str>,
    ) -> Result<DirectUploadSignature, AppError> {
        Err(storage_validation_error("storage.multipart_unsupported"))
    }

    /// 完成 Multipart Upload（合并分片）
    async fn complete_multipart_upload(
        &self,
        _key: &str,
        _upload_id: &str,
        _parts: &[(i32, String)],
    ) -> Result<(), AppError> {
        Err(storage_validation_error("storage.multipart_unsupported"))
    }

    /// 中止 Multipart Upload（清理分片会话）
    async fn abort_multipart_upload(&self, _key: &str, _upload_id: &str) -> Result<(), AppError> {
        Err(storage_validation_error("storage.multipart_unsupported"))
    }

    /// 生成带过期时间的下载 URL
    async fn generate_download_url(
        &self,
        _key: &str,
        _expires_in: Option<u32>,
    ) -> Result<String, AppError> {
        Err(storage_validation_error("storage.download_url_unsupported"))
    }
}

/// 创建存储服务实例
pub fn create_storage_service(
    provider: &StorageProvider,
) -> Result<Box<dyn StorageService>, AppError> {
    match provider.provider_type {
        StorageProviderType::TencentCos => {
            if provider.bucket_name.is_none() {
                return Err(storage_validation_error(
                    "storage.bucket_name_required_for_tencent_cos",
                ));
            }
            Ok(Box::new(cos::TencentCosService::new(
                provider.secret_id.clone(),
                provider.secret_key.clone(),
                provider.region.clone(),
                provider.endpoint.clone(),
                provider.bucket_name.clone().unwrap(),
            )?))
        }
        _ => Err(storage_validation_error_with_params(
            "storage.provider_type_unsupported",
            MessageParams::from([(
                "provider_type".to_string(),
                provider.provider_type.to_string(),
            )]),
        )),
    }
}

/// 创建存储服务实例（不需要 bucket_name，用于列表和创建 bucket）
pub fn create_storage_service_without_bucket(
    provider: &StorageProvider,
) -> Result<Box<dyn StorageService>, AppError> {
    match provider.provider_type {
        StorageProviderType::TencentCos => {
            Ok(Box::new(cos::TencentCosService::new_without_bucket(
                provider.secret_id.clone(),
                provider.secret_key.clone(),
                provider.region.clone(),
                provider.endpoint.clone(),
            )?))
        }
        _ => Err(storage_validation_error_with_params(
            "storage.provider_type_unsupported",
            MessageParams::from([(
                "provider_type".to_string(),
                provider.provider_type.to_string(),
            )]),
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use async_trait::async_trait;
    use bytes::Bytes;
    use chrono::Utc;
    use uuid::Uuid;

    struct DummyStorageService;

    #[async_trait]
    impl StorageService for DummyStorageService {
        async fn upload_file(
            &self,
            _key: &str,
            _content: Bytes,
            _content_type: Option<&str>,
        ) -> Result<String, AppError> {
            Ok("ok".to_string())
        }

        async fn delete_file(&self, _key: &str) -> Result<(), AppError> {
            Ok(())
        }

        async fn file_exists(&self, _key: &str) -> Result<bool, AppError> {
            Ok(false)
        }

        fn get_file_url(&self, key: &str) -> String {
            format!("https://example.invalid/{key}")
        }

        async fn list_buckets(&self) -> Result<Vec<BucketInfo>, AppError> {
            Ok(Vec::new())
        }

        async fn create_bucket(&self, _bucket_name: &str) -> Result<(), AppError> {
            Ok(())
        }
    }

    #[tokio::test]
    async fn storage_default_head_object_returns_stable_key() {
        let service = DummyStorageService;

        let error = service
            .head_object("demo")
            .await
            .expect_err("default head_object should be unsupported");

        assert_eq!(
            error.response_message_key(),
            "storage.object_head_unsupported"
        );
    }

    #[tokio::test]
    async fn storage_default_cors_methods_return_stable_keys() {
        let service = DummyStorageService;

        let get_error = service
            .get_cors_rules()
            .await
            .expect_err("default get_cors_rules should be unsupported");
        assert_eq!(
            get_error.response_message_key(),
            "storage.cors_get_unsupported"
        );

        let set_error = service
            .set_cors_rules(&[])
            .await
            .expect_err("default set_cors_rules should be unsupported");
        assert_eq!(
            set_error.response_message_key(),
            "storage.cors_set_unsupported"
        );
    }

    #[tokio::test]
    async fn storage_default_upload_helpers_return_stable_keys() {
        let service = DummyStorageService;

        let direct_error = service
            .generate_direct_upload_signature("demo", None)
            .await
            .expect_err("default direct upload signature should be unsupported");
        assert_eq!(
            direct_error.response_message_key(),
            "storage.direct_upload_unsupported"
        );

        let multipart_error = service
            .initiate_multipart_upload("demo", None)
            .await
            .expect_err("default multipart upload should be unsupported");
        assert_eq!(
            multipart_error.response_message_key(),
            "storage.multipart_unsupported"
        );

        let download_error = service
            .generate_download_url("demo", Some(60))
            .await
            .expect_err("default download url should be unsupported");
        assert_eq!(
            download_error.response_message_key(),
            "storage.download_url_unsupported"
        );
    }

    #[test]
    fn create_storage_service_requires_bucket_name_for_tencent_cos() {
        let error =
            match create_storage_service(&test_provider(StorageProviderType::TencentCos, None)) {
                Ok(_) => panic!("tencent cos should require bucket_name"),
                Err(error) => error,
            };

        assert_eq!(
            error.response_message_key(),
            "storage.bucket_name_required_for_tencent_cos"
        );
    }

    #[test]
    fn create_storage_service_rejects_unsupported_provider_type() {
        let error = match create_storage_service(&test_provider(
            StorageProviderType::Minio,
            Some("demo-bucket"),
        )) {
            Ok(_) => panic!("unsupported provider should fail"),
            Err(error) => error,
        };

        assert_eq!(
            error.response_message_key(),
            "storage.provider_type_unsupported"
        );
        let params = error.message_params().expect("params present");
        assert_eq!(params["provider_type"], "minio");
    }

    #[test]
    fn create_storage_service_without_bucket_rejects_unsupported_provider_type() {
        let error = match create_storage_service_without_bucket(&test_provider(
            StorageProviderType::AwsS3,
            Some("demo-bucket"),
        )) {
            Ok(_) => panic!("unsupported provider should fail"),
            Err(error) => error,
        };

        assert_eq!(
            error.response_message_key(),
            "storage.provider_type_unsupported"
        );
        let params = error.message_params().expect("params present");
        assert_eq!(params["provider_type"], "aws_s3");
    }

    #[test]
    fn storage_module_should_not_embed_legacy_free_strings() {
        let source = include_str!("mod.rs");

        for legacy in [
            "\u{5f53}\u{524d}\u{5b58}\u{50a8}\u{63d0}\u{4f9b}\u{5546}\u{4e0d}\u{652f}\u{6301}",
            "\u{817e}\u{8baf}\u{4e91}COS\u{9700}\u{8981}\u{914d}\u{7f6e}bucket_name",
            "\u{4e0d}\u{652f}\u{6301}\u{7684}\u{5b58}\u{50a8}\u{63d0}\u{4f9b}\u{5546}\u{7c7b}\u{578b}",
        ] {
            assert!(
                !source.contains(legacy),
                "storage module should not embed legacy literal: {legacy}"
            );
        }
    }

    fn test_provider(
        provider_type: StorageProviderType,
        bucket_name: Option<&str>,
    ) -> StorageProvider {
        let now = Utc::now();
        StorageProvider {
            id: Uuid::new_v4(),
            provider_type,
            name: "demo".to_string(),
            secret_id: "secret-id".to_string(),
            secret_key: "secret-key".to_string(),
            region: "ap-shanghai".to_string(),
            endpoint: "cos.example.com".to_string(),
            bucket_name: bucket_name.map(str::to_string),
            is_active: true,
            is_default: false,
            description: None,
            created_at: now,
            updated_at: now,
            updated_by: None,
        }
    }
}
