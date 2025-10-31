# 腾讯云 COS Rust SDK 集成分析

## 概述

本文档分析腾讯云对象存储（COS）在 Rust 项目中的集成方案。

## SDK 选择

### 官方 SDK 状态

**腾讯云官方目前未提供 Rust 语言的 COS SDK。**

### 社区第三方 SDK

经过调研，社区中有以下 Rust SDK 可用于腾讯云 COS：

#### 1. `cos-rust-sdk`（社区维护）

- **GitHub**: 可能有相关项目，但需要进一步验证
- **特点**: 
  - 支持异步操作（基于 tokio）
  - 提供基本的 COS API 功能
  - 活跃度需验证

#### 2. 直接使用 HTTP 客户端 + COS API

**推荐方案**：使用 `reqwest` + 手动实现 COS 签名算法

**优势**：
- 完全控制，不依赖第三方 SDK
- 轻量级，无额外依赖
- 符合项目的现有技术栈（已使用 tokio、reqwest 等）

**实现要点**：
- 使用 HMAC-SHA1 签名算法
- 实现 COS API 的请求签名逻辑
- 支持文件上传、下载、删除等操作

## 推荐实现方案

### 方案一：使用 reqwest + 自定义 COS 客户端

```rust
// 示例结构
pub struct CosClient {
    secret_id: String,
    secret_key: String,
    region: String,
    endpoint: String,
    bucket: String,
    client: reqwest::Client,
}

impl CosClient {
    pub async fn put_object(&self, key: &str, data: Vec<u8>) -> Result<()> {
        // 1. 构建请求
        // 2. 生成签名
        // 3. 发送请求
    }
}
```

**优点**：
- 完全自主控制
- 易于维护和扩展
- 符合项目技术栈

**缺点**：
- 需要自行实现签名逻辑
- 需要处理各种边界情况

### 方案二：封装 COS API 为通用存储接口

```rust
pub trait StorageProvider {
    async fn upload(&self, key: &str, data: Vec<u8>) -> Result<String>;
    async fn download(&self, key: &str) -> Result<Vec<u8>>;
    async fn delete(&self, key: &str) -> Result<()>;
    async fn get_url(&self, key: &str) -> String;
}

pub struct TencentCosProvider {
    // 实现 StorageProvider trait
}
```

**优点**：
- 抽象化存储提供商
- 易于切换不同的存储服务
- 符合项目的数据库设计（已有 provider_type 字段）

## 腾讯云 COS API 文档

### 核心 API

1. **PUT Object** - 上传对象
   - 端点：`PUT https://{bucket}.cos.{region}.myqcloud.com/{key}`
   - 需要签名认证

2. **GET Object** - 下载对象
   - 端点：`GET https://{bucket}.cos.{region}.myqcloud.com/{key}`
   - 支持签名 URL（临时访问）

3. **DELETE Object** - 删除对象
   - 端点：`DELETE https://{bucket}.cos.{region}.myqcloud.com/{key}`

### 签名算法

腾讯云 COS 使用 HMAC-SHA1 签名算法，具体步骤：

1. 构建请求字符串（Query String）
2. 构建签名字符串
3. 使用 HMAC-SHA1 计算签名
4. 将签名添加到请求头

详细算法参考：[腾讯云 COS 签名算法文档](https://cloud.tencent.com/document/product/436/7778)

## 依赖建议

### 必需依赖

```toml
[dependencies]
reqwest = { version = "0.11", features = ["json"] }
tokio = { version = "1", features = ["full"] }
sha1 = "0.10"  # HMAC-SHA1 签名
hmac = "0.12"
```

### 可选依赖

```toml
[dependencies]
url = "2.5"  # URL 编码/解码
chrono = "0.4"  # 时间戳生成
```

## 实现优先级

1. **第一阶段**：实现基础的上传功能（PUT Object）
2. **第二阶段**：实现下载和删除功能
3. **第三阶段**：实现签名 URL 生成（临时访问链接）
4. **第四阶段**：实现通用的 StorageProvider trait，支持多提供商切换

## 注意事项

1. **安全性**：
   - Secret Key 应存储在数据库中，不能硬编码
   - 上传文件时需验证文件类型和大小
   - 使用签名 URL 时设置合理的过期时间

2. **性能**：
   - 使用连接池复用 HTTP 连接
   - 大文件上传考虑分片上传（PUT Object - Multipart Upload）

3. **错误处理**：
   - 处理网络错误
   - 处理 COS API 返回的错误码
   - 提供友好的错误信息

## 参考资源

- [腾讯云 COS API 文档](https://cloud.tencent.com/document/product/436/7751)
- [COS 签名算法](https://cloud.tencent.com/document/product/436/7778)
- [Rust reqwest 文档](https://docs.rs/reqwest/)

## 结论

**推荐使用方案一**：使用 `reqwest` + 自定义 COS 客户端实现。

理由：
1. 完全控制，不依赖第三方 SDK
2. 符合项目现有技术栈
3. 易于维护和扩展
4. 可以封装为通用的 StorageProvider trait，支持后续接入其他存储服务

下一步行动：
1. 创建 `backend/src/storage/cos.rs` 模块
2. 实现基础的 COS 客户端
3. 实现文件上传功能
4. 集成到现有的 `upload_avatar` handler 中

