use crate::error::AppError;
use crate::storage::StorageService;
use async_trait::async_trait;
use bytes::Bytes;
use hmac::{Hmac, Mac};
use sha1::Sha1;
use std::collections::BTreeMap;
use std::fmt::Write;
use time::OffsetDateTime;
use urlencoding::encode;

type HmacSha1 = Hmac<Sha1>;

/// 腾讯云 COS 服务实现
pub struct TencentCosService {
    secret_id: String,
    secret_key: String,
    region: String,
    endpoint: String,
    bucket_name: String,
    client: reqwest::Client,
}

impl TencentCosService {
    pub fn new(
        secret_id: String,
        secret_key: String,
        region: String,
        endpoint: String,
        bucket_name: String,
    ) -> Result<Self, AppError> {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .map_err(|e| AppError::InternalError(format!("创建HTTP客户端失败: {}", e)))?;

        Ok(Self {
            secret_id,
            secret_key,
            region,
            endpoint,
            bucket_name,
            client,
        })
    }

    /// 生成腾讯云 COS API v1 签名
    fn generate_signature_v1(
        &self,
        method: &str,
        path: &str,
        headers: &BTreeMap<String, String>,
        timestamp: i64,
    ) -> String {
        // 构建签名字符串
        let mut sign_string = format!("{}\n{}\n", method, path);

        // 添加 HTTP headers (按字典序排序)
        let mut header_list = Vec::new();
        let mut header_str = String::new();
        
        for (key, value) in headers {
            let key_lower = key.to_lowercase();
            if key_lower.starts_with("x-cos-") {
                header_list.push(key_lower.clone());
                write!(header_str, "{}:{}\n", key_lower, value).unwrap();
            }
        }

        // 添加 Host header
        header_list.push("host".to_string());
        write!(header_str, "host:{}\n", self.endpoint).unwrap();

        sign_string.push_str(&header_str);
        sign_string.push_str(&format!("{}\n", timestamp));

        // 构建 header list 字符串
        let header_list_str = header_list.join(";");

        // 计算 HMAC-SHA1
        let mut mac = HmacSha1::new_from_slice(self.secret_key.as_bytes())
            .expect("HMAC can take key of any size");
        mac.update(sign_string.as_bytes());
        let result = mac.finalize();
        let signature_hex = hex::encode(result.into_bytes());

        // 构建 Authorization header
        format!(
            "q-sign-algorithm=sha1&q-ak={}&q-sign-time={};{}&q-key-time={};{}&q-header-list={}&q-url-param-list=&q-signature={}",
            self.secret_id,
            timestamp,
            timestamp + 3600,
            timestamp,
            timestamp + 3600,
            header_list_str,
            signature_hex
        )
    }

    /// 获取完整的 URL
    fn get_full_url(&self, key: &str) -> String {
        // 如果 endpoint 已经包含 bucket，直接使用
        if self.endpoint.contains(&self.bucket_name) {
            format!("https://{}/{}", self.endpoint, encode(key))
        } else {
            format!("https://{}.cos.{}.myqcloud.com/{}", self.bucket_name, self.region, encode(key))
        }
    }
}

#[async_trait]
impl StorageService for TencentCosService {
    async fn upload_file(
        &self,
        key: &str,
        content: Bytes,
        content_type: Option<&str>,
    ) -> Result<String, AppError> {
        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();

        // 构建请求路径
        let path = format!("/{}", encode(key));

        // 构建 headers
        let mut headers_map = BTreeMap::new();
        let content_type_str = content_type.unwrap_or("application/octet-stream");
        headers_map.insert("Content-Type".to_string(), content_type_str.to_string());

        // 生成签名
        let authorization = self.generate_signature_v1("PUT", &path, &headers_map, timestamp);

        // 发送 PUT 请求
        let url = self.get_full_url(key);
        let response = self
            .client
            .put(&url)
            .header("Authorization", authorization)
            .header("Host", &self.endpoint)
            .header("Content-Type", content_type_str)
            .body(content.to_vec())
            .send()
            .await
            .map_err(|e| AppError::InternalError(format!("上传文件失败: {}", e)))?;

        if response.status().is_success() {
            Ok(url)
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            Err(AppError::InternalError(format!(
                "上传文件失败: {} - {}",
                status, body
            )))
        }
    }

    async fn delete_file(&self, key: &str) -> Result<(), AppError> {
        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();

        let path = format!("/{}", encode(key));
        let headers_map = BTreeMap::new();
        let authorization = self.generate_signature_v1("DELETE", &path, &headers_map, timestamp);

        let url = self.get_full_url(key);
        let response = self
            .client
            .delete(&url)
            .header("Authorization", authorization)
            .header("Host", &self.endpoint)
            .send()
            .await
            .map_err(|e| AppError::InternalError(format!("删除文件失败: {}", e)))?;

        if response.status().is_success() || response.status() == 204 {
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            Err(AppError::InternalError(format!(
                "删除文件失败: {} - {}",
                status, body
            )))
        }
    }

    async fn file_exists(&self, key: &str) -> Result<bool, AppError> {
        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();

        let path = format!("/{}", encode(key));
        let headers_map = BTreeMap::new();
        let authorization = self.generate_signature_v1("HEAD", &path, &headers_map, timestamp);

        let url = self.get_full_url(key);
        let response = self
            .client
            .head(&url)
            .header("Authorization", authorization)
            .header("Host", &self.endpoint)
            .send()
            .await
            .map_err(|e| AppError::InternalError(format!("检查文件是否存在失败: {}", e)))?;

        Ok(response.status().is_success())
    }

    fn get_file_url(&self, key: &str) -> String {
        self.get_full_url(key)
    }
}

