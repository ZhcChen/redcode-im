pub mod cos;

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

    /// 获取跨域规则
    async fn get_cors_rules(&self) -> Result<Vec<CorsRule>, AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持跨域规则查询".to_string(),
        ))
    }

    /// 设置跨域规则
    async fn set_cors_rules(&self, _rules: &[CorsRule]) -> Result<(), AppError> {
        Err(AppError::ValidationError(
            "当前存储提供商不支持跨域规则配置".to_string(),
        ))
    }

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
        StorageProviderType::TencentCos => {
            if provider.bucket_name.is_none() {
                return Err(AppError::ValidationError(
                    "腾讯云COS需要配置bucket_name".to_string(),
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
        StorageProviderType::TencentCos => {
            Ok(Box::new(cos::TencentCosService::new_without_bucket(
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
