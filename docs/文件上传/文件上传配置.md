# 文件上传配置指南

## 概述

本文档详细说明了如何配置腾讯云COS作为文件存储后端，以及前端直传的完整配置步骤。  

> **重要说明（避免误用）**  
> - 后端只负责「签名生成 + 上传完成确认」，**不提供通用文件上传接口**；  
> - 任意新需求（头像、附件、群文件等）都必须走：  
>   `直传签名 API → 客户端直传 COS → Commit API 通知后端`；  
> - 任何试图在后端新增 `POST /upload`、`multipart/form-data` 上传的方案，均视为违反当前架构约定，不应实现。

## 1. 腾讯云COS配置

### 1.1 创建存储桶

1. 登录[腾讯云控制台](https://console.cloud.tencent.com/)
2. 进入对象存储COS服务
3. 创建存储桶：
   - **名称**: `redcode-im-files` (示例)
   - **地域**: 选择离用户最近的地域，如 `ap-shanghai`
   - **访问权限**: **私有读写**
   - **存储类型**: **标准存储**

### 1.2 配置跨域访问

1. 在存储桶列表中找到创建的存储桶
2. 点击存储桶名称进入配置页面
3. 选择 **安全管理 → 跨域访问CORS**
4. 添加CORS规则：

```json
{
  "AllowedOrigins": [
    "https://yourdomain.com",
    "http://localhost:3000",
    "http://localhost:5173"
  ],
  "AllowedMethods": [
    "GET",
    "PUT",
    "POST",
    "DELETE",
    "HEAD"
  ],
  "AllowedHeaders": [
    "*"
  ],
  "MaxAgeSeconds": 3600
}
```

### 1.3 获取访问密钥

1. 进入腾讯云控制台
2. 点击右上角头像 → **访问管理 → API密钥管理**
3. 创建子密钥（推荐）或使用主密钥
4. 保存密钥信息：
   - **SecretId**: `AKIDxxxxxxxxxxxxxxxxxxxxxx`
   - **SecretKey**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

## 2. 后端配置

### 2.1 环境变量配置

在部署环境中至少需要设置数据库连接（以及可选的清理策略参数）。  
**注意**：本项目的 COS 配置由管理后台写入数据库表 `storage_providers` 管理，后端不再读取 `COS_SECRET_ID/COS_SECRET_KEY` 等环境变量。

```bash
# 数据库配置
export DATABASE_URL="postgresql://user:password@localhost:5432/redcode_im"

# （可选）直传文件清理任务配置
export FILE_UPLOAD_CLEANUP_INTERVAL_SECONDS=3600
export FILE_UPLOAD_PENDING_TIMEOUT_SECONDS=21600
export FILE_UPLOAD_ORPHAN_DELETE_AFTER_SECONDS=604800
export FILE_UPLOAD_UNREFERENCED_RETENTION_SECONDS=2592000
export FILE_UPLOAD_CLEANUP_BATCH_SIZE=200
```

### 2.2 管理后台配置

1. 启动后端服务
2. 访问管理后台（通常为 `http://localhost:8080/admin`）
3. 进入 **系统管理 → 存储提供商**
4. 点击 **添加存储提供商**：

```json
{
  "name": "腾讯云COS",
  "provider_type": "tencent_cos",
  "secret_id": "AKIDxxxxxxxxxxxxxxxxxxxxxx",
  "secret_key": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "region": "ap-shanghai",
  "bucket_name": "redcode-im-files",
  "endpoint": "cos.ap-shanghai.myqcloud.com",
  "is_default": true,
  "is_active": true
}
```

### 2.3 验证配置

使用curl命令验证配置：

```bash
# 测试存储提供商配置
curl -X GET "http://localhost:8080/api/admin/storage-providers/default" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 测试头像上传签名生成
curl -X POST "http://localhost:8080/users/me/avatar/direct-upload" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "content_type": "image/jpeg",
    "file_size": 1024
  }'
```

## 3. 前端配置

### 3.1 环境变量配置

```bash
# API基础URL
export VITE_API_BASE_URL="http://localhost:8080"

# 上传相关配置
export VITE_MAX_FILE_SIZE="10485760"  # 10MB
export VITE_ALLOWED_FILE_TYPES="image/*,audio/*,video/*,application/pdf"
```

### 3.2 上传API配置

确保前端API配置正确（`desktop/src/api/http.ts`）：

```typescript
// 基础配置
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

// 请求拦截器配置
http.interceptors.request.use((config) => {
  const token = store.getters.token;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

http.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // token过期，重新登录
      store.dispatch('logout');
    }
    return Promise.reject(error);
  }
);
```

## 4. 路由配置

### 4.1 后端路由

确保路由配置正确（`backend/src/routes.rs`）：

```rust
// 头像上传相关路由
.route("/users/me/avatar/direct-upload", post(user::generate_avatar_direct_upload))
.route("/users/me/avatar/commit", post(user::commit_avatar_upload))
.route("/users/me/avatar/url", get(user::get_avatar_download_url))

// 消息附件上传路由
.route("/rooms/:room_id/messages/attachments/signature", post(message::generate_message_attachment_signature))
.route("/rooms/:room_id/messages/attachments/commit", post(message::commit_message_attachment_upload))
.route("/rooms/:room_id/messages/attachments/download", get(message::generate_message_attachment_download_url))
```

### 4.2 前端路由

确保API路径配置正确（`desktop/src/api/`）：

```typescript
// 头像API
export const UserApi = {
  generateAvatarDirectUpload: (params: { content_type: string; file_size?: number }) =>
    post<AvatarDirectUploadResponse>('/users/me/avatar/direct-upload', params),
  commitAvatarUpload: (params: { key: string; delete_previous?: boolean }) =>
    post<AvatarDownloadUrlResponse>('/users/me/avatar/commit', params),
  // ... 其他方法
};

// 消息API
export const MessageApi = {
  generateMessageAttachmentSignature: (params: {
    roomId: string;
    partType: 'text' | 'image' | 'video' | 'audio' | 'file';
    filename?: string;
    contentType?: string;
    fileSize?: number;
    hashValue?: string;
    hashAlg?: number;
  }) => post<MessageAttachmentSignatureResponse>(
    `/rooms/${params.roomId}/messages/attachments/signature`, params
  ),
  // ... 其他方法
};
```

## 5. 开发环境配置

### 5.1 Docker配置

```dockerfile
# backend/Dockerfile
FROM rust:1.70

# 设置环境变量
ENV COS_SECRET_ID=${COS_SECRET_ID}
ENV COS_SECRET_KEY=${COS_SECRET_KEY}
ENV COS_REGION=${COS_REGION}
ENV COS_BUCKET=${COS_BUCKET}
ENV COS_ENDPOINT=${COS_ENDPOINT}

# 构建和运行
WORKDIR /app
COPY . .
RUN cargo build --release
CMD ["cargo", "run", "--release"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  backend:
    build: ./backend
    environment:
      - COS_SECRET_ID=${COS_SECRET_ID}
      - COS_SECRET_KEY=${COS_SECRET_KEY}
      - COS_REGION=${COS_REGION}
      - COS_BUCKET=${COS_BUCKET}
      - COS_ENDPOINT=${COS_ENDPOINT}
      - DATABASE_URL=postgresql://postgres:password@db:5432/redcode_im
    ports:
      - "8080:8080"
    depends_on:
      - db
      - redis
```

### 5.2 环境变量文件

创建 `.env` 文件（不要提交到版本控制）：

```bash
# .env
# 腾讯云COS配置
COS_SECRET_ID=your_secret_id
COS_SECRET_KEY=your_secret_key
COS_REGION=ap-shanghai
COS_BUCKET=redcode-im-files
COS_ENDPOINT=cos.ap-shanghai.myqcloud.com

# 数据库配置
DATABASE_URL=postgresql://postgres:password@localhost:5432/redcode_im

# JWT配置
JWT_SECRET=your_jwt_secret
JWT_EXPIRES_IN=24h
```

## 6. 生产环境部署

### 6.1 安全配置

1. **使用子密钥**：创建专门用于应用的COS子密钥
2. **权限最小化**：只授予必要的读写权限
3. **定期轮换**：定期更换访问密钥
4. **IP白名单**：设置访问IP白名单（可选）

### 6.2 CORS配置

生产环境CORS配置：

```json
{
  "AllowedOrigins": [
    "https://your-production-domain.com"
  ],
  "AllowedMethods": [
    "GET",
    "PUT",
    "POST",
    "DELETE",
    "HEAD"
  ],
  "AllowedHeaders": [
    "Authorization",
    "Content-Type",
    "Content-Length"
  ],
  "MaxAgeSeconds": 3600
}
```

### 6.3 监控配置

```bash
# 添加日志监控
# 在应用启动脚本中添加
export RUST_LOG=debug
export RUST_LOG_STYLE=always

# 监控关键指标
# - 文件上传成功率
# - 平均上传时间
# - COS API错误率
```

## 7. 测试验证

### 7.1 功能测试

```typescript
// 测试头像上传
async function testAvatarUpload() {
  const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });

  // 1. 获取上传签名
  const signature = await UserApi.generateAvatarDirectUpload({
    content_type: file.type,
    file_size: file.size
  });

  // 2. 上传到COS
  const uploadResult = await fetch(signature.data.signature.url, {
    method: 'PUT',
    headers: signature.data.signature.headers,
    body: file
  });

  // 3. 提交上传
  const commitResult = await UserApi.commitAvatarUpload({
    key: signature.data.key,
    delete_previous: true
  });

  console.log('头像上传成功:', commitResult.data);
}
```

### 7.2 错误测试

```typescript
// 测试文件类型验证
async function testFileTypeValidation() {
  try {
    await UserApi.generateAvatarDirectUpload({
      content_type: 'application/pdf', // 不支持的类型
      file_size: 1024
    });
  } catch (error) {
    console.log('预期错误:', error.message);
    // 应该返回"不支持的文件类型"
  }
}

// 测试文件大小限制
async function testFileSizeLimit() {
  try {
    await UserApi.generateAvatarDirectUpload({
      content_type: 'image/jpeg',
      file_size: 10 * 1024 * 1024 // 超过5MB限制
    });
  } catch (error) {
    console.log('预期错误:', error.message);
    // 应该返回"文件大小超出限制"
  }
}
```

## 8. 故障排除

### 8.1 常见配置错误

| 错误现象 | 可能原因 | 解决方案 |
|---------|---------|---------|
| 403 Forbidden | COS权限不足 | 检查密钥配置和桶权限 |
| 404 Not Found | 存储桶不存在 | 确认桶名称和区域 |
| 签名不匹配 | 时间不同步 | 检查服务器时间同步 |
| 网络超时 | 防火墙限制 | 检查网络连通性 |

### 8.2 调试命令

```bash
# 检查COS连接
curl -v "https://your-bucket.cos.ap-shanghai.myqcloud.com/"

# 测试API连通性
curl -v "http://localhost:8080/users/me/avatar/direct-upload" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# 查看应用日志
docker-compose logs backend
```

## 9. 最佳实践

### 9.1 安全实践
- 使用HTTPS协议
- 定期轮换访问密钥
- 验证文件类型和大小
- 设置合理的权限策略

### 9.2 性能优化
- 实现文件压缩
- 使用CDN加速
- 添加缓存机制
- 实现断点续传

### 9.3 监控告警
- 监控上传成功率
- 跟踪错误率
- 设置存储空间告警
- 记录关键操作日志

---

**文档版本**: v1.0
**更新时间**: 2024-11-07
**维护者**: 开发团队
