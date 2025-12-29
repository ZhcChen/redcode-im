# 文件上传架构文档

## 概述

本项目使用腾讯云对象存储（COS）作为文件存储后端，采用前端直传的方式进行文件上传。这种架构可以减少服务器负载，提高上传效率。

## 整体架构

```
前端应用 → 获取上传签名 → 直接上传到腾讯COS → 通知后端保存文件信息
    ↓              ↓                     ↓                    ↓
  用户选择    →  请求签名API    →  PUT文件到COS     →  提交上传完成
```

> **强制约定（MUST）**  
> - 本项目所有业务文件上传（头像、消息附件、群头像等）一律采用 **COS 直传** 架构；  
> - **后端不会也不允许新增通用的 `multipart/form-data` 上传接口**，只能提供：  
>   1. 直传签名接口（如 `/users/me/avatar/direct-upload`、`/rooms/{room_id}/messages/attachments/signature`）；  
>   2. 上传完成确认接口（如 `/users/me/avatar/commit` 等）；  
> - 如需新增任意上传场景，必须按照「签名 API → 前端直传 COS → Commit API」这一固定流程设计，不得自建“后端收文件流”的上传接口。

## 核心组件

### 1. 后端存储服务 (`backend/src/storage/`)

#### 1.1 腾讯COS服务实现 (`backend/src/storage/cos.rs`)
- **文件**: `backend/src/storage/cos.rs` (970+ 行)
- **功能**: 完整的腾讯云COS API实现
- **主要方法**:
  - `upload_file()` - 直接上传文件到COS
  - `generate_direct_upload_signature()` - 生成直传签名
  - `initiate_multipart_upload()` - 初始化分片上传会话
  - `generate_multipart_upload_part_signature()` - 生成分片上传签名（Part）
  - `complete_multipart_upload()` - 合并分片
  - `abort_multipart_upload()` - 取消分片上传
  - `delete_file()` - 删除COS文件
  - `file_exists()` - 检查文件是否存在
  - `head_object()` - 获取对象元数据（content-length/etag）
  - `generate_download_url()` - 生成下载链接

#### 1.2 存储服务抽象 (`backend/src/storage/mod.rs`)
```rust
pub trait StorageService {
    async fn upload_file(&self, key: &str, content: Bytes, content_type: Option<&str>) -> Result<String, AppError>;
    async fn generate_direct_upload_signature(&self, key: &str, content_type: Option<&str>) -> Result<DirectUploadSignature, AppError>;
    async fn head_object(&self, key: &str) -> Result<ObjectHead, AppError>;
    // ... 其他方法
}
```

### 2. 文件类型验证 (`backend/src/constants/file_types.rs`)

#### 2.1 支持的文件类型
```rust
// 头像文件类型
pub const AVATAR_ALLOWED_TYPES: &[&str] = &[
    "image/png", "image/jpeg", "image/jpg", "image/webp",
    "image/gif", "image/heic", "image/heif", "image/svg+xml",
];

// 音频文件类型
pub const AUDIO_ALLOWED_TYPES: &[&str] = &[
    "audio/webm", "audio/ogg", "audio/wav", "audio/mp3",
    "audio/mpeg", "audio/mp4", "audio/m4a", "audio/aac", "audio/flac",
];

// 图片文件类型
pub const IMAGE_ALLOWED_TYPES: &[&str] = &[
    // 包含头像类型 + 更多格式
    "image/bmp", "image/tiff",
];

// 视频文件类型
pub const VIDEO_ALLOWED_TYPES: &[&str] = &[
    "video/mp4", "video/webm", "video/ogg",
    "video/quicktime", "video/x-msvideo", "video/x-matroska",
];
```

#### 2.2 文件大小限制
```rust
pub const AVATAR_MAX_SIZE_BYTES: usize = 5 * 1024 * 1024;      // 5MB
pub const IMAGE_MAX_SIZE_BYTES: usize = 10 * 1024 * 1024;     // 10MB
pub const AUDIO_MAX_SIZE_BYTES: usize = 20 * 1024 * 1024;     // 20MB
pub const VIDEO_MAX_SIZE_BYTES: usize = 100 * 1024 * 1024;    // 100MB
pub const FILE_MAX_SIZE_BYTES: usize = 50 * 1024 * 1024;      // 50MB
```

### 3. 上传流程API

> **推荐（强烈）**：前端在请求签名前先计算文件 hash（md5/sha256）并上报 `hash_value/hash_alg`，同时上报 `file_size`。  
> 后端会：
> - 先尝试按 `hash + size` 命中 `file_upload_records(status=1)` 来复用已上传文件（秒传/去重）；
> - 若未命中则生成新的 `key + signature`；
> - 在 commit 阶段用 `HEAD` 校验对象存在性，并尽量校验大小/哈希，避免“误报完成/引用错文件”。

#### 3.1 头像上传API

**获取上传签名**
- **端点**: `POST /users/me/avatar/direct-upload`
- **请求体**:
```json
{
  "content_type": "image/jpeg",
  "file_size": 1024000,
  "hash_value": "e3b0c44298fc1c149afbf4c8996fb924",
  "hash_alg": 1
}
```
- **响应**:
```json
{
  "success": true,
  "message": "生成头像直传签名成功",
  "key": "avatars/uuid/20241107123456_abc12345.jpg",
  "signature": {
    "url": "https://bucket-name.cos.region.myqcloud.com/avatars/uuid/20241107123456_abc12345.jpg",
    "method": "PUT",
    "headers": {
      "Authorization": "q-sign-algorithm=sha1;...",
      "Host": "bucket-name.cos.region.myqcloud.com"
    }
  }
}
```

> 如果命中去重逻辑：响应会返回 `key`，但 `signature` 为空；此时无需再上传与 commit，可直接使用该 `key` 进行业务提交。

**提交上传完成**
- **端点**: `POST /users/me/avatar/commit`
- **请求体**:
```json
{
  "key": "avatars/uuid/20241107123456_abc12345.jpg",
  "expires_in_seconds": 3600,
  "delete_previous": true
}
```

#### 3.2 消息附件上传API

**获取上传签名**
- **端点**: `POST /rooms/{room_id}/messages/attachments/signature`
- **请求体**:
```json
{
  "part_type": "audio",
  "filename": "voice_123456789.webm",
  "content_type": "audio/webm",
  "file_size": 1048576,
  "hash_value": "e3b0c44298fc1c149afbf4c8996fb924",
  "hash_alg": 1
}
```

**提交附件上传完成**
- **端点**: `POST /rooms/{room_id}/messages/attachments/commit`
- **请求体**:
```json
{
  "key": "messages/{any-room-id}/audios_20251213/abcdef01.webm",
  "file_size": 1048576,
  "hash_value": "e3b0c44298fc1c149afbf4c8996fb924",
  "hash_alg": 1
}
```

**获取附件下载链接**
- **端点**: `GET /rooms/{room_id}/messages/attachments/download?key=...`
- **说明**：后端会校验该 `key` 必须已被当前房间的消息引用（附件或缩略图），否则返回 404，避免“仅凭 object_key 即可下载任意文件”。

## 4. 去重/秒传与 `file_upload_records`

后端会把直传文件记录到 `file_upload_records` 表中，用于：
- 按 `hash + size` 去重复用（秒传）
- 跟踪上传状态（避免复用尚未完成上传的文件）
- 为空间统计与清理任务提供基础数据

`status` 约定：
- `0` 上传中/待确认（已发签名，未确认）
- `1` 上传完成（可复用）
- `2` 上传失败（不可复用）
- `3` 已删除（对象已被清理，不再允许复用）

## 5. 后台清理任务（回收 COS 空间）

后端启动后会定时清理 `file_upload_records` 与对象存储中的“脏数据/无引用对象”：
- `status=0` 且创建时间超过阈值：视为“直传超时未确认”，标记失败；若对象长期无引用则删除
- `status=1` 但业务侧已无任何引用，且超过保留期：删除对象并标记为已删除

可通过环境变量配置（默认值在括号内）：
- `FILE_UPLOAD_CLEANUP_INTERVAL_SECONDS`（3600）：清理任务执行间隔
- `FILE_UPLOAD_PENDING_TIMEOUT_SECONDS`（21600=6h）：pending 超时阈值
- `FILE_UPLOAD_ORPHAN_DELETE_AFTER_SECONDS`（604800=7d）：超时且无引用对象的删除阈值
- `FILE_UPLOAD_UNREFERENCED_RETENTION_SECONDS`（2592000=30d）：completed 但无引用对象的保留期
- `FILE_UPLOAD_CLEANUP_BATCH_SIZE`（200）：单次批处理条数

### 6. 前端直传实现

#### 4.1 头像上传流程 (`desktop/src/api/user.ts`)
```typescript
// 1. 获取上传签名
const directResp = await post<AvatarDirectUploadResponse>(
  '/users/me/avatar/direct-upload',
  { content_type, file_size }
);

// 2. 直接上传到COS
const uploadResponse = await fetch(signature.url, {
  method: signature.method || 'PUT',
  headers: signature.headers,
  body: fileBuffer
});

// 3. 提交上传完成
const commitResp = await post<AvatarDownloadUrlResponse>(
  '/users/me/avatar/commit',
  { key, delete_previous: true }
);
```

#### 4.2 语音消息上传流程 (`desktop/src/views/Chat.vue`)
```typescript
const handleVoiceSend = async (recording: any) => {
  // 1. 获取语音上传签名
  const signatureResponse = await MessageApi.generateMessageAttachmentSignature({
    roomId: selectedChat.value.id,
    partType: 4, // AUDIO_CONTENT_TYPE
    filename: `voice_${recording.id}.webm`,
    contentType: 'audio/webm',
    fileSize: recording.blob.size,
  });

  // 2. 直接上传到COS
  const uploadResponse = await fetch(signature.url, {
    method: signature.method || 'PUT',
    headers: { 'Content-Type': 'audio/webm' },
    body: recording.blob,
  });

  // 3. 创建语音消息
  const messageResponse = await MessageApi.sendMessage({
    groupId: selectedChat.value.id,
    content: '',
    parts: [{
      partType: 4,
      objectKey: key,
      originalName: `voice_${recording.id}.webm`,
      mimeType: 'audio/webm',
      duration: Math.round(recording.duration),
    }],
  });
};
```

## 错误处理场景

### 1. 文件类型验证错误
```json
{
  "success": false,
  "message": "不支持的文件类型: application/pdf"
}
```

### 2. 文件大小超限错误
```json
{
  "success": false,
  "message": "文件大小超出限制，最大允许5MB"
}
```

### 3. COS上传错误
- 网络超时
- 签名过期
- COS服务异常
- 权限不足

### 4. 签名生成错误
- 存储提供商配置错误
- 用户权限不足
- 房间权限验证失败

## 配置要求

### 1. 环境变量
```bash
# 腾讯云COS配置
COS_SECRET_ID=your_secret_id
COS_SECRET_KEY=your_secret_key
COS_REGION=ap-shanghai
COS_BUCKET=your_bucket_name
COS_ENDPOINT=cos.ap-shanghai.myqcloud.com
```

### 2. 存储提供商配置
需要通过管理后台配置默认的存储提供商，包括：
- 访问密钥
- 区域和桶名称
- 端点地址

## 安全考虑

### 1. 文件验证
- **类型验证**: 严格验证MIME类型，使用白名单机制
- **大小限制**: 根据文件类型设置合理的大小限制
- **危险文件**: 拒绝可执行文件和脚本文件
- **路径验证**: 防止目录遍历攻击

### 2. 签名安全
- **时效性**: 签名包含有效期，通常为1小时
- **权限控制**: 签名只能用于指定的文件和操作
- **访问控制**: 用户只能上传到自己的目录

### 3. 数据隔离
- **用户隔离**: 每个用户有独立的文件目录
- **房间隔离**: 消息附件按房间分类存储
- **路径安全**: 使用UUID和随机字符防止路径猜测

## 性能优化

### 1. 前端优化
- **分片上传**: 已实现（COS Multipart Upload，前端分片直传 + 后端会话/合并）
- **进度显示**: 实时显示上传进度
- **重试机制**: 网络失败时自动重试
- **并发控制**: 限制同时上传的文件数量

### 2. 后端优化
- **签名缓存**: 短时间内重复请求使用缓存签名
- **异步处理**: 文件上传不阻塞主流程
- **存储优化**: 使用CDN加速文件访问

## 监控和日志

### 1. 关键指标
- 文件上传成功率
- 平均上传时间
- 文件大小分布
- 错误类型统计

### 2. 日志记录
```rust
// 上传签名生成
debug!("生成文件上传签名: key={}, user_id={}", key, user_id);

// 文件验证
warn!("文件类型验证失败: type={}, user_id={}", content_type, user_id);

// COS上传结果
debug!("COS上传结果: key={}, status={}", key, status);
```

## 故障排查

### 1. 常见错误
- **403 Forbidden**: 检查COS权限配置和访问密钥
- **404 Not Found**: 检查桶名称和区域配置
- **403 SignatureDoesNotMatch**: 检查签名算法和时间同步
- **400 Bad Request**: 检查文件路径和参数格式

### 2. 调试步骤
1. 检查环境变量配置
2. 验证COS控制台权限设置
3. 检查网络连接和防火墙
4. 验证签名生成逻辑
5. 测试文件访问权限

## 未来扩展

### 1. 功能扩展
- 支持更多文件格式
- 实现文件压缩和转换
- 添加文件预览功能
- 支持批量上传

### 2. 性能扩展
- 添加断点续传
- 优化大文件处理
- 实现CDN加速

### 3. 安全扩展
- 添加文件病毒扫描
- 实现文件加密存储
- 增强访问控制
- 添加审计日志

---

**文档版本**: v1.1
**更新时间**: 2025-12-29
**维护者**: 开发团队
