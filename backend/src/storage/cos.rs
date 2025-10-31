use crate::error::AppError;
use crate::storage::{BucketInfo, StorageService};
use async_trait::async_trait;
use bytes::Bytes;
use hmac::{Hmac, Mac};
use sha1::{Digest, Sha1};
use std::collections::BTreeMap;
use std::fmt::Write;
use time::OffsetDateTime;
use tracing::{debug, error, warn};
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

    /// 创建一个不需要 bucket_name 的实例（用于列表和创建 bucket）
    pub fn new_without_bucket(
        secret_id: String,
        secret_key: String,
        region: String,
        endpoint: String,
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
            bucket_name: String::new(), // 空字符串表示未指定 bucket
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
        self.generate_signature_v1_with_host(method, path, headers, timestamp, &self.endpoint)
    }

    /// 生成腾讯云 COS API v1 签名（指定 host）
    fn generate_signature_v1_with_host(
        &self,
        method: &str,
        path: &str,
        headers: &BTreeMap<String, String>,
        timestamp: i64,
        host: &str,
    ) -> String {
        let start_time = timestamp;
        let end_time = timestamp + 3600;
        let key_time = format!("{};{}", start_time, end_time);

        // 1. 构建 HttpString
        // HttpString = HttpMethod + "\n" + HttpUri + "\n" + HttpParameters + "\n" + HttpHeaders + "\n"
        let mut http_string = format!("{}\n{}\n", method.to_uppercase(), path);

        // HttpParameters 为空（没有查询参数），但需要保留换行符
        http_string.push_str("\n");

        // HttpHeaders（按字典序排序）
        // 收集所有需要签名的 headers（x-cos- 开头的和 host）
        let mut header_map = BTreeMap::new();
        
        // 添加 x-cos- 开头的 headers
        for (key, value) in headers {
            let key_lower = key.to_lowercase();
            if key_lower.starts_with("x-cos-") {
                header_map.insert(key_lower.clone(), value.clone());
            }
        }
        
        // 添加 host header（必须包含）
        header_map.insert("host".to_string(), host.to_string());

        // 构建 header_list 和 header_str（按字典序）
        let mut header_list = Vec::new();
        let mut header_str = String::new();
        
        for (key, value) in &header_map {
            header_list.push(key.clone());
            write!(header_str, "{}:{}\n", key, value).unwrap();
        }

        http_string.push_str(&header_str);
        // HttpString 最后需要一个换行符
        http_string.push_str("\n");

        // 调试输出：打印 HttpString（用于排查签名问题）
        debug!("HttpString (hex): {}", hex::encode(http_string.as_bytes()));
        debug!("HttpString (text): {:?}", http_string);

        // 2. 计算 HttpString 的 SHA1
        let mut hasher = Sha1::new();
        hasher.update(http_string.as_bytes());
        let http_string_sha1 = hex::encode(hasher.finalize());

        // 3. 构建 StringToSign
        // StringToSign = Sha1 + "\n" + ExpireTime + "\n" + SHA1(HttpString) + "\n"
        let string_to_sign = format!("sha1\n{}\n{}\n", key_time, http_string_sha1);

        debug!("StringToSign: {:?}", string_to_sign);
        debug!("HttpString SHA1: {}", http_string_sha1);

        // 4. 计算 SignKey = HMAC-SHA1(SecretKey, KeyTime)
        let mut sign_key_mac = HmacSha1::new_from_slice(self.secret_key.as_bytes())
            .expect("HMAC can take key of any size");
        sign_key_mac.update(key_time.as_bytes());
        let sign_key = sign_key_mac.finalize();

        // 5. 计算 Signature = HMAC-SHA1(SignKey, StringToSign)
        let mut signature_mac = HmacSha1::new_from_slice(&sign_key.into_bytes())
            .expect("HMAC can take key of any size");
        signature_mac.update(string_to_sign.as_bytes());
        let signature = hex::encode(signature_mac.finalize().into_bytes());

        // 6. 构建 header list 字符串
        let header_list_str = header_list.join(";");

        // 7. 构建 Authorization header
        format!(
            "q-sign-algorithm=sha1&q-ak={}&q-sign-time={}&q-key-time={}&q-header-list={}&q-url-param-list=&q-signature={}",
            self.secret_id,
            key_time,
            key_time,
            header_list_str,
            signature
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

        debug!("开始上传文件到 COS: key={}, size={} bytes", key, content.len());

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
            .map_err(|e| {
                error!("上传文件到 COS 失败: key={}, error={}", key, e);
                AppError::InternalError(format!("上传文件失败: {}", e))
            })?;

        if response.status().is_success() {
            debug!("文件上传成功: key={}, url={}", key, url);
            Ok(url)
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!("上传文件失败: key={}, status={}, body={}", key, status, body);
            Err(AppError::InternalError(format!(
                "上传文件失败: {} - {}",
                status, body
            )))
        }
    }

    async fn delete_file(&self, key: &str) -> Result<(), AppError> {
        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();

        debug!("开始删除 COS 文件: key={}", key);

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
            .map_err(|e| {
                error!("删除 COS 文件失败: key={}, error={}", key, e);
                AppError::InternalError(format!("删除文件失败: {}", e))
            })?;

        if response.status().is_success() || response.status() == 204 {
            debug!("文件删除成功: key={}", key);
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            warn!("删除文件失败: key={}, status={}, body={}", key, status, body);
            Err(AppError::InternalError(format!(
                "删除文件失败: {} - {}",
                status, body
            )))
        }
    }

    async fn file_exists(&self, key: &str) -> Result<bool, AppError> {
        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();

        debug!("检查 COS 文件是否存在: key={}", key);

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
            .map_err(|e| {
                error!("检查 COS 文件是否存在失败: key={}, error={}", key, e);
                AppError::InternalError(format!("检查文件是否存在失败: {}", e))
            })?;

        let exists = response.status().is_success();
        debug!("文件存在性检查完成: key={}, exists={}", key, exists);
        Ok(exists)
    }

    fn get_file_url(&self, key: &str) -> String {
        self.get_full_url(key)
    }

    async fn list_buckets(&self) -> Result<Vec<BucketInfo>, AppError> {
        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();

        debug!("开始获取 COS bucket 列表");

        // 获取 bucket 列表的路径
        let path = "/";
        let headers_map = BTreeMap::new();
        
        // 使用 service.cos.myqcloud.com 作为服务端点
        let service_endpoint = "service.cos.myqcloud.com";
        let authorization = self.generate_signature_v1_with_host("GET", path, &headers_map, timestamp, service_endpoint);
        
        let url = format!("https://{}", service_endpoint);

        let response = self
            .client
            .get(&url)
            .header("Authorization", authorization)
            .header("Host", service_endpoint)
            .send()
            .await
            .map_err(|e| {
                error!("获取 COS bucket 列表失败: error={}", e);
                AppError::InternalError(format!("获取bucket列表失败: {}", e))
            })?;

        if response.status().is_success() {
            let body = response.text().await.unwrap_or_default();
            // 解析 XML 响应
            let buckets = parse_list_buckets_response(&body)?;
            debug!("成功获取 {} 个 bucket", buckets.len());
            Ok(buckets)
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!("获取 bucket 列表失败: status={}, body={}", status, body);
            Err(AppError::InternalError(format!(
                "获取bucket列表失败: {} - {}",
                status, body
            )))
        }
    }

    async fn create_bucket(&self, bucket_name: &str) -> Result<(), AppError> {
        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();

        debug!("开始创建 COS bucket: name={}, region={}", bucket_name, self.region);

        // 创建 bucket 的路径
        let path = "/";
        let mut headers_map = BTreeMap::new();
        headers_map.insert("x-cos-acl".to_string(), "private".to_string());
        
        // 使用 bucket.cos.region.myqcloud.com 格式
        let bucket_endpoint = format!("{}.cos.{}.myqcloud.com", bucket_name, self.region);
        let authorization = self.generate_signature_v1_with_host("PUT", path, &headers_map, timestamp, &bucket_endpoint);
        
        let url = format!("https://{}", bucket_endpoint);

        let response = self
            .client
            .put(&url)
            .header("Authorization", authorization)
            .header("Host", &bucket_endpoint)
            .header("x-cos-acl", "private")
            .send()
            .await
            .map_err(|e| {
                error!("创建 COS bucket 失败: name={}, error={}", bucket_name, e);
                AppError::InternalError(format!("创建bucket失败: {}", e))
            })?;

        if response.status().is_success() || response.status() == 200 {
            debug!("Bucket 创建成功: name={}", bucket_name);
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            warn!("创建 bucket 失败: name={}, status={}, body={}", bucket_name, status, body);
            Err(AppError::InternalError(format!(
                "创建bucket失败: {} - {}",
                status, body
            )))
        }
    }
}

/// 解析 ListBuckets 响应 XML
fn parse_list_buckets_response(xml: &str) -> Result<Vec<BucketInfo>, AppError> {
    // 简化实现：使用正则表达式或 XML 解析器
    // 这里使用简单的字符串解析
    let mut buckets = Vec::new();
    
    // 查找所有 <Name> 标签
    let name_pattern = regex::Regex::new(r"<Name>(.*?)</Name>").unwrap();
    let location_pattern = regex::Regex::new(r"<Location>(.*?)</Location>").unwrap();
    let date_pattern = regex::Regex::new(r"<CreationDate>(.*?)</CreationDate>").unwrap();
    
    let names: Vec<&str> = name_pattern
        .captures_iter(xml)
        .map(|cap| cap.get(1).unwrap().as_str())
        .collect();
    
    let locations: Vec<&str> = location_pattern
        .captures_iter(xml)
        .map(|cap| cap.get(1).unwrap().as_str())
        .collect();
    
    let dates: Vec<&str> = date_pattern
        .captures_iter(xml)
        .map(|cap| cap.get(1).unwrap().as_str())
        .collect();
    
    for (i, name) in names.iter().enumerate() {
        buckets.push(BucketInfo {
            name: name.to_string(),
            region: locations.get(i).map(|s| s.to_string()).unwrap_or_default(),
            creation_date: dates.get(i).map(|s| Some(s.to_string())).unwrap_or(None),
        });
    }
    
    Ok(buckets)
}

