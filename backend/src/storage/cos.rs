use crate::error::AppError;
use crate::storage::{BucketInfo, CorsRule, DirectUploadSignature, StorageService};
use async_trait::async_trait;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use bytes::Bytes;
use hmac::{Hmac, Mac};
use reqwest::StatusCode;
use sha1::{Digest, Sha1};
use std::collections::BTreeMap;
use time::OffsetDateTime;
use tracing::{debug, error, warn};

type HmacSha1 = Hmac<Sha1>;

const DEFAULT_SIGNATURE_TTL: i64 = 3600;
const MAX_SIGNATURE_TTL: i64 = 24 * 3600;

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
            endpoint: sanitize_endpoint(&endpoint),
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
            endpoint: sanitize_endpoint(&endpoint),
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
        let host = self.resolve_object_host();
        self.generate_signature_v1_with_host_and_ttl(
            method,
            path,
            headers,
            timestamp,
            &host,
            None,
            DEFAULT_SIGNATURE_TTL,
        )
    }

    /// 生成腾讯云 COS API v1 签名（指定 host）
    fn generate_signature_v1_with_host(
        &self,
        method: &str,
        path: &str,
        headers: &BTreeMap<String, String>,
        timestamp: i64,
        host: &str,
        query_params: Option<&BTreeMap<String, String>>,
    ) -> String {
        self.generate_signature_v1_with_host_and_ttl(
            method,
            path,
            headers,
            timestamp,
            host,
            query_params,
            DEFAULT_SIGNATURE_TTL,
        )
    }

    fn generate_signature_v1_with_host_and_ttl(
        &self,
        method: &str,
        path: &str,
        headers: &BTreeMap<String, String>,
        timestamp: i64,
        host: &str,
        query_params: Option<&BTreeMap<String, String>>,
        ttl_seconds: i64,
    ) -> String {
        let duration = clamp_signature_ttl(ttl_seconds);
        let start_time = timestamp;
        let end_time = timestamp + duration;
        let key_time = format!("{};{}", start_time, end_time);

        let sanitized_host = sanitize_endpoint(host);
        let canonical_path = if path.is_empty() { "/" } else { path };
        let (header_list, canonical_headers) = build_canonical_headers(headers, &sanitized_host);
        let (param_list, canonical_params) = build_canonical_params(query_params);

        let http_method = method.to_ascii_lowercase();
        let http_string = format!(
            "{}\n{}\n{}\n{}\n",
            http_method, canonical_path, canonical_params, canonical_headers
        );

        debug!("HttpString (hex): {}", hex::encode(http_string.as_bytes()));
        debug!("HttpString (text): {:?}", http_string);

        let mut hasher = Sha1::new();
        hasher.update(http_string.as_bytes());
        let http_string_sha1 = hex::encode(hasher.finalize());

        let string_to_sign = format!("sha1\n{}\n{}\n", key_time, http_string_sha1);

        debug!("StringToSign: {:?}", string_to_sign);
        debug!("HttpString SHA1: {}", http_string_sha1);
        debug!("KeyTime: {}", key_time);

        let mut sign_key_mac = HmacSha1::new_from_slice(self.secret_key.as_bytes())
            .expect("HMAC can take key of any size");
        sign_key_mac.update(key_time.as_bytes());
        let sign_key_hex = hex::encode(sign_key_mac.finalize().into_bytes());

        let mut signature_mac = HmacSha1::new_from_slice(sign_key_hex.as_bytes())
            .expect("HMAC can take key of any size");
        signature_mac.update(string_to_sign.as_bytes());
        let signature = hex::encode(signature_mac.finalize().into_bytes());

        let header_list_str = header_list.join(";");
        let param_list_str = param_list.join(";");

        debug!("Signature: {}", signature);
        debug!("Header list: {}", header_list_str);
        debug!("Param list: {}", param_list_str);

        format!(
            "q-sign-algorithm=sha1&q-ak={}&q-sign-time={}&q-key-time={}&q-header-list={}&q-url-param-list={}&q-signature={}",
            self.secret_id,
            key_time,
            key_time,
            header_list_str,
            param_list_str,
            signature
        )
    }

    /// 获取完整的 URL
    fn get_full_url(&self, key: &str) -> String {
        let host = self.resolve_object_host();
        let encoded_key = encode_object_key(key);
        format!("https://{}/{}", host, encoded_key)
    }

    fn resolve_object_host(&self) -> String {
        if self.bucket_name.is_empty() {
            return self.endpoint.clone();
        }

        let endpoint = self.endpoint.clone();

        if endpoint.is_empty() {
            format!("{}.cos.{}.myqcloud.com", self.bucket_name, self.region)
        } else if endpoint.contains(&self.bucket_name) {
            endpoint
        } else if endpoint.contains(".cos.") || endpoint.contains(".myqcloud.com") {
            format!("{}.{}", self.bucket_name, endpoint)
        } else {
            endpoint
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

        debug!(
            "开始上传文件到 COS: key={}, size={} bytes",
            key,
            content.len()
        );

        // 构建请求路径
        let path = build_uri_pathname(key);

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
            .header("Host", self.resolve_object_host())
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
            error!(
                "上传文件失败: key={}, status={}, body={}",
                key, status, body
            );
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

        let path = build_uri_pathname(key);
        let headers_map = BTreeMap::new();
        let authorization = self.generate_signature_v1("DELETE", &path, &headers_map, timestamp);

        let url = self.get_full_url(key);
        let response = self
            .client
            .delete(&url)
            .header("Authorization", authorization)
            .header("Host", self.resolve_object_host())
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
            warn!(
                "删除文件失败: key={}, status={}, body={}",
                key, status, body
            );
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

        let path = build_uri_pathname(key);
        let headers_map = BTreeMap::new();
        let authorization = self.generate_signature_v1("HEAD", &path, &headers_map, timestamp);

        let url = self.get_full_url(key);
        let response = self
            .client
            .head(&url)
            .header("Authorization", authorization)
            .header("Host", self.resolve_object_host())
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
        let authorization = self.generate_signature_v1_with_host(
            "GET",
            path,
            &headers_map,
            timestamp,
            service_endpoint,
            None,
        );

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

        debug!(
            "开始创建 COS bucket: name={}, region={}",
            bucket_name, self.region
        );

        // 创建 bucket 的路径
        let path = "/";
        let mut headers_map = BTreeMap::new();
        headers_map.insert("x-cos-acl".to_string(), "private".to_string());

        // 使用 bucket.cos.region.myqcloud.com 格式
        let bucket_endpoint = format!("{}.cos.{}.myqcloud.com", bucket_name, self.region);
        let authorization = self.generate_signature_v1_with_host(
            "PUT",
            path,
            &headers_map,
            timestamp,
            &bucket_endpoint,
            None,
        );

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
            warn!(
                "创建 bucket 失败: name={}, status={}, body={}",
                bucket_name, status, body
            );
            Err(AppError::InternalError(format!(
                "创建bucket失败: {} - {}",
                status, body
            )))
        }
    }

    async fn get_cors_rules(&self) -> Result<Vec<CorsRule>, AppError> {
        if self.bucket_name.is_empty() {
            return Err(AppError::ValidationError(
                "未配置 bucket 名称，无法获取跨域规则".to_string(),
            ));
        }

        let headers_map = BTreeMap::new();
        let mut query_params = BTreeMap::new();
        query_params.insert("cors".to_string(), String::new());

        let timestamp = OffsetDateTime::now_utc().unix_timestamp();
        let bucket_endpoint = self.resolve_object_host();

        let authorization = self.generate_signature_v1_with_host(
            "GET",
            "/",
            &headers_map,
            timestamp,
            &bucket_endpoint,
            Some(&query_params),
        );

        let url = format!("https://{}/?cors", bucket_endpoint);
        let response = self
            .client
            .get(&url)
            .header("Authorization", authorization)
            .header("Host", &bucket_endpoint)
            .send()
            .await
            .map_err(|e| {
                error!("获取 COS 跨域规则失败: error={}", e);
                AppError::InternalError(format!("获取跨域规则失败: {}", e))
            })?;

        let status = response.status();
        let body = response.text().await.unwrap_or_default();

        if status == StatusCode::NOT_FOUND {
            debug!("未配置 COS 跨域规则，返回空列表");
            return Ok(vec![]);
        }

        if !status.is_success() {
            error!("获取跨域规则失败: status={}, body={}", status, body);
            return Err(AppError::InternalError(format!(
                "获取跨域规则失败: {} - {}",
                status, body
            )));
        }

        if body.trim().is_empty() {
            return Ok(vec![]);
        }

        parse_cors_configuration_xml(&body)
    }

    async fn set_cors_rules(&self, rules: &[CorsRule]) -> Result<(), AppError> {
        if self.bucket_name.is_empty() {
            return Err(AppError::ValidationError(
                "未配置 bucket 名称，无法设置跨域规则".to_string(),
            ));
        }

        if rules.is_empty() {
            return Err(AppError::ValidationError("跨域规则不能为空".to_string()));
        }

        let xml_body = build_cors_configuration_xml(rules);
        let md5_digest = md5::compute(xml_body.as_bytes());
        let content_md5 = BASE64_STANDARD.encode(md5_digest.0);

        let mut headers_map = BTreeMap::new();
        headers_map.insert("Content-Type".to_string(), "application/xml".to_string());
        headers_map.insert("Content-MD5".to_string(), content_md5.clone());

        let mut query_params = BTreeMap::new();
        query_params.insert("cors".to_string(), String::new());

        let timestamp = OffsetDateTime::now_utc().unix_timestamp();
        let bucket_endpoint = self.resolve_object_host();

        let authorization = self.generate_signature_v1_with_host(
            "PUT",
            "/",
            &headers_map,
            timestamp,
            &bucket_endpoint,
            Some(&query_params),
        );

        let url = format!("https://{}/?cors", bucket_endpoint);
        let response = self
            .client
            .put(&url)
            .header("Authorization", authorization)
            .header("Host", &bucket_endpoint)
            .header("Content-Type", "application/xml")
            .header("Content-MD5", content_md5)
            .body(xml_body.clone())
            .send()
            .await
            .map_err(|e| {
                error!("设置 COS 跨域规则失败: error={}", e);
                AppError::InternalError(format!("配置跨域规则失败: {}", e))
            })?;

        if response.status().is_success() {
            debug!("成功设置 COS 跨域规则");
            Ok(())
        } else {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            error!("设置跨域规则失败: status={}, body={}", status, body);
            Err(AppError::InternalError(format!(
                "配置跨域规则失败: {} - {}",
                status, body
            )))
        }
    }

    async fn generate_direct_upload_signature(
        &self,
        key: &str,
        content_type: Option<&str>,
    ) -> Result<DirectUploadSignature, AppError> {
        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();
        let path = build_uri_pathname(key);

        let mut headers_map = BTreeMap::new();
        if let Some(ct) = content_type {
            if !ct.trim().is_empty() {
                headers_map.insert("Content-Type".to_string(), ct.trim().to_string());
            }
        }

        let authorization = self.generate_signature_v1("PUT", &path, &headers_map, timestamp);
        let host = self.resolve_object_host();
        let encoded_key = encode_object_key(key);
        let url = format!("https://{}/{}", host, encoded_key);

        let mut response_headers = BTreeMap::new();
        response_headers.insert("Authorization".to_string(), authorization);
        if let Some(ct) = content_type {
            if !ct.trim().is_empty() {
                response_headers.insert("Content-Type".to_string(), ct.trim().to_string());
            }
        }

        Ok(DirectUploadSignature {
            url,
            method: "PUT".to_string(),
            headers: response_headers,
            key: key.to_string(),
        })
    }

    async fn generate_download_url(
        &self,
        key: &str,
        expires_in: Option<u32>,
    ) -> Result<String, AppError> {
        if key.trim().is_empty() {
            return Err(AppError::ValidationError(
                "文件路径（key）不能为空".to_string(),
            ));
        }

        let now = OffsetDateTime::now_utc();
        let timestamp = now.unix_timestamp();
        // 签名计算时需要使用带 / 前缀的原始路径（与上传签名一致）
        // 腾讯云 COS 签名规范要求 canonical_path 以 / 开头
        let path = build_uri_pathname(key);

        let headers_map = BTreeMap::new();
        let host = self.resolve_object_host();
        let ttl = expires_in
            .map(|v| v as i64)
            .unwrap_or(DEFAULT_SIGNATURE_TTL);

        let authorization = self.generate_signature_v1_with_host_and_ttl(
            "GET",
            &path,
            &headers_map,
            timestamp,
            &host,
            None,
            ttl,
        );

        let encoded_key = encode_object_key(key);
        let base_url = format!("https://{}/{}", host, encoded_key);
        let separator = if base_url.contains('?') { '&' } else { '?' };
        Ok(format!("{}{}{}", base_url, separator, authorization))
    }
}

/// 解析 CORS 配置响应 XML
fn parse_cors_configuration_xml(xml: &str) -> Result<Vec<CorsRule>, AppError> {
    let rule_pattern = regex::Regex::new(r"(?s)<CORSRule>(.*?)</CORSRule>").unwrap();
    let mut rules = Vec::new();

    for caps in rule_pattern.captures_iter(xml) {
        let block = caps.get(1).map(|m| m.as_str()).unwrap_or_default();

        let allowed_origins = extract_xml_values(block, "AllowedOrigin");
        let allowed_methods = extract_xml_values(block, "AllowedMethod");
        let allowed_headers = extract_xml_values(block, "AllowedHeader");
        let expose_headers = extract_xml_values(block, "ExposeHeader");
        let max_age =
            extract_xml_value(block, "MaxAgeSeconds").and_then(|value| value.parse::<u32>().ok());

        if allowed_origins.is_empty() || allowed_methods.is_empty() {
            // 忽略无效规则
            continue;
        }

        rules.push(CorsRule {
            allowed_origins,
            allowed_methods,
            allowed_headers,
            expose_headers,
            max_age_seconds: max_age,
        });
    }

    Ok(rules)
}

fn extract_xml_values(block: &str, tag: &str) -> Vec<String> {
    let pattern = format!(r"<{tag}>(.*?)</{tag}>", tag = tag);
    let regex = regex::Regex::new(&pattern).unwrap();
    regex
        .captures_iter(block)
        .map(|cap| xml_unescape(cap.get(1).map(|m| m.as_str()).unwrap_or_default().trim()))
        .filter(|value| !value.is_empty())
        .collect()
}

fn extract_xml_value(block: &str, tag: &str) -> Option<String> {
    let pattern = format!(r"<{tag}>(.*?)</{tag}>", tag = tag);
    let regex = regex::Regex::new(&pattern).unwrap();
    regex
        .captures(block)
        .map(|cap| xml_unescape(cap.get(1).map(|m| m.as_str()).unwrap_or_default().trim()))
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

fn build_cors_configuration_xml(rules: &[CorsRule]) -> String {
    let mut xml = String::from("<CORSConfiguration>");
    for rule in rules {
        xml.push_str("<CORSRule>");

        for origin in &rule.allowed_origins {
            xml.push_str("<AllowedOrigin>");
            xml.push_str(&xml_escape(origin));
            xml.push_str("</AllowedOrigin>");
        }

        for method in &rule.allowed_methods {
            xml.push_str("<AllowedMethod>");
            xml.push_str(&xml_escape(method));
            xml.push_str("</AllowedMethod>");
        }

        for header in &rule.allowed_headers {
            xml.push_str("<AllowedHeader>");
            xml.push_str(&xml_escape(header));
            xml.push_str("</AllowedHeader>");
        }

        for header in &rule.expose_headers {
            xml.push_str("<ExposeHeader>");
            xml.push_str(&xml_escape(header));
            xml.push_str("</ExposeHeader>");
        }

        if let Some(max_age) = rule.max_age_seconds {
            xml.push_str("<MaxAgeSeconds>");
            xml.push_str(&max_age.to_string());
            xml.push_str("</MaxAgeSeconds>");
        }

        xml.push_str("</CORSRule>");
    }
    xml.push_str("</CORSConfiguration>");
    xml
}

fn xml_escape(value: &str) -> String {
    let mut escaped = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&apos;"),
            _ => escaped.push(ch),
        }
    }
    escaped
}

fn xml_unescape(value: &str) -> String {
    value
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
}

fn sanitize_endpoint(endpoint: &str) -> String {
    let trimmed = endpoint.trim();
    let without_scheme = trimmed
        .trim_start_matches("https://")
        .trim_start_matches("http://")
        .trim_start_matches("//");
    let without_trailing = without_scheme.trim_end_matches('/');
    without_trailing.to_string()
}

fn build_canonical_headers(
    headers: &BTreeMap<String, String>,
    host: &str,
) -> (Vec<String>, String) {
    let mut header_map = BTreeMap::new();

    for (key, value) in headers {
        let value_trimmed = value.trim();
        if value_trimmed.is_empty() {
            continue;
        }
        header_map.insert(key.to_ascii_lowercase(), value_trimmed.to_string());
    }

    if !host.is_empty() {
        header_map.insert("host".to_string(), host.to_string());
    }

    let header_list = header_map.keys().cloned().collect::<Vec<_>>();

    let header_str = header_map
        .iter()
        .map(|(key, value)| {
            format!(
                "{}={}",
                urlencoding::encode(key),
                urlencoding::encode(value)
            )
        })
        .collect::<Vec<_>>()
        .join("&");

    (header_list, header_str)
}

fn build_canonical_params(params: Option<&BTreeMap<String, String>>) -> (Vec<String>, String) {
    if let Some(params) = params {
        let mut canonical = Vec::new();
        let mut param_list = Vec::new();

        for (key, value) in params {
            let key_lower = key.to_ascii_lowercase();
            canonical.push(format!(
                "{}={}",
                urlencoding::encode(&key_lower),
                urlencoding::encode(value)
            ));
            param_list.push(key_lower);
        }

        canonical.sort();
        param_list.sort();

        let canonical_str = canonical.join("&");

        (param_list, canonical_str)
    } else {
        (Vec::new(), String::new())
    }
}

fn normalize_object_key(key: &str) -> &str {
    let trimmed = key.trim_start_matches('/');
    if trimmed.is_empty() {
        key
    } else {
        trimmed
    }
}

fn build_uri_pathname(key: &str) -> String {
    let normalized = normalize_object_key(key);
    if normalized.starts_with('/') {
        normalized.to_string()
    } else {
        format!("/{}", normalized)
    }
}

fn encode_object_key(key: &str) -> String {
    let normalized = normalize_object_key(key);
    if normalized.is_empty() {
        String::new()
    } else {
        urlencoding::encode(normalized).to_string()
    }
}

fn clamp_signature_ttl(ttl_seconds: i64) -> i64 {
    if ttl_seconds <= 0 {
        DEFAULT_SIGNATURE_TTL
    } else {
        ttl_seconds.min(MAX_SIGNATURE_TTL)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_signature_matches_expected_format() {
        let service = TencentCosService {
            secret_id: "AKIDEXAMPLE".to_string(),
            secret_key: "SECRET".to_string(),
            region: "ap-shanghai".to_string(),
            endpoint: sanitize_endpoint("cos.ap-shanghai.myqcloud.com"),
            bucket_name: "examplebucket-1250000000".to_string(),
            client: reqwest::Client::builder().build().unwrap(),
        };

        let mut headers = BTreeMap::new();
        headers.insert("Content-Type".to_string(), "text/plain".to_string());

        let timestamp = 1_718_000_000;
        let authorization = service.generate_signature_v1_with_host(
            "PUT",
            "/example.txt",
            &headers,
            timestamp,
            "examplebucket-1250000000.cos.ap-shanghai.myqcloud.com",
            None,
        );

        assert!(authorization.starts_with("q-sign-algorithm=sha1&q-ak=AKIDEXAMPLE"));
        assert!(
            authorization.contains("q-header-list=content-type;host"),
            "header list missing expected entries: {}",
            authorization
        );
        assert!(
            authorization.contains("q-url-param-list="),
            "url param list missing: {}",
            authorization
        );
    }

    #[test]
    fn test_build_canonical_headers_includes_host_and_sorts() {
        let mut headers = BTreeMap::new();
        headers.insert("X-Cos-Acl".to_string(), "private".to_string());
        headers.insert("Content-Type".to_string(), "text/plain".to_string());

        let (header_list, canonical_headers) =
            build_canonical_headers(&headers, "bucket-125.cos.ap-shanghai.myqcloud.com");

        assert_eq!(
            header_list,
            vec![
                "content-type".to_string(),
                "host".to_string(),
                "x-cos-acl".to_string()
            ]
        );
        assert_eq!(
            canonical_headers,
            "content-type=text%2Fplain&host=bucket-125.cos.ap-shanghai.myqcloud.com&x-cos-acl=private"
        );
    }

    #[test]
    fn test_sanitize_endpoint_trims_scheme_and_trailing_slash() {
        assert_eq!(
            sanitize_endpoint("https://cos.ap-shanghai.myqcloud.com/"),
            "cos.ap-shanghai.myqcloud.com"
        );
        assert_eq!(
            sanitize_endpoint("cos.ap-shanghai.myqcloud.com"),
            "cos.ap-shanghai.myqcloud.com"
        );
    }

    #[test]
    fn test_resolve_object_host_with_base_endpoint() {
        let service = TencentCosService::new(
            "AKID".to_string(),
            "SECRET".to_string(),
            "ap-shanghai".to_string(),
            "cos.ap-shanghai.myqcloud.com".to_string(),
            "examplebucket-1250000000".to_string(),
        )
        .unwrap();

        assert_eq!(
            service.resolve_object_host(),
            "examplebucket-1250000000.cos.ap-shanghai.myqcloud.com"
        );
    }

    #[test]
    fn test_signature_example_matches_official_docs() {
        // 来自官方文档 https://cloud.tencent.com/document/product/1344/50456
        let sign_key_hex = "82f0e7ee09b1070dc6f3a37c41b01bc2eaf43ced";
        let string_to_sign =
            "sha1\n1671039836;1671043436\nd5c37ed1e8f7fd51d14853f8e9e81869f32fdc54\n";

        let mut signature_mac =
            HmacSha1::new_from_slice(sign_key_hex.as_bytes()).expect("HMAC key error");
        signature_mac.update(string_to_sign.as_bytes());
        let signature = hex::encode(signature_mac.finalize().into_bytes());

        assert_eq!(
            signature,
            "2fab8f7909236046e789b4ea483330ec6df91331".to_string()
        );
    }
}
