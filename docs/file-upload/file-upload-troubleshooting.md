# 文件上传错误排查指南

## 快速诊断流程

### 1. 确认问题类型
首先确定错误发生的阶段：
- [ ] 前端获取签名失败
- [ ] 前端直传到COS失败
- [ ] 后端处理上传结果失败
- [ ] 文件验证失败

### 2. 检查配置状态
- [ ] 环境变量是否正确配置
- [ ] 存储提供商是否启用
- [ ] 用户权限是否正常
- [ ] 网络连接是否正常

## 详细错误排查

### 🔥 签名生成错误

#### 错误1: 存储提供商未配置
**错误信息**: `Storage provider not found`
**排查步骤**:
1. 检查管理后台是否配置了默认存储提供商
2. 确认存储提供商状态为启用
3. 验证访问密钥是否正确

**解决方案**：登录管理后台配置存储提供商  
路径：系统管理 → 存储提供商 → 添加/编辑（设置默认 + 启用）

#### 错误2: COS权限配置错误
**错误信息**: `创建HTTP客户端失败`
**排查步骤**:
1. 检查COS控制台权限设置
2. 确认密钥是否有读写权限
3. 验证桶是否存在

**COS控制台检查项**:
- [ ] 密钥ID和密钥是否正确
- [ ] 桶是否存在且有写权限
- [ ] 跨域配置(CORS)是否正确设置
- [ ] 存储桶策略是否允许相关操作

#### 错误3: 用户权限不足
**错误信息**: `用户不在该房间，无法上传附件`
**排查步骤**:
1. 确认用户是否在目标房间中
2. 检查房间成员表数据
3. 验证JWT token是否有效

**数据库查询**:
```sql
-- 检查用户是否在房间中
SELECT * FROM room_members
WHERE user_id = '用户UUID'
AND room_id = '房间UUID'
AND deleted_at IS NULL;

-- 检查房间是否存在
SELECT * FROM rooms
WHERE id = '房间UUID'
AND deleted_at IS NULL;
```

### 🔍 文件验证错误

#### 错误1: 不支持的文件类型
**错误信息**: `不支持的文件类型: application/pdf`
**常见问题**:
- 上传了PDF文件但只允许图片
- 上传了可执行文件
- MIME类型不匹配

**解决方案**:
```typescript
// 前端验证文件类型
const allowedTypes = ['image/jpeg', 'image/png', 'audio/webm'];
if (!allowedTypes.includes(file.type)) {
  throw new Error(`不支持的文件类型: ${file.type}`);
}
```

#### 错误2: 文件大小超限
**错误信息**: `文件大小超出限制，最大允许5MB`
**排查步骤**:
1. 检查文件实际大小
2. 确认文件类型对应的大小限制
3. 考虑压缩文件

**动态上传策略（Upload Policy）**:
> 自 2025-12 起，文件大小/数量/MIME 白名单等限制已由后端动态下发（Upload Policy），客户端应从 `GET /system/upload-policy` 获取实时配置。

**默认大小限制参考**（`builtin-v1` 策略）:
- 头像: 5MB
- 图片: 5MB
- 音频: 20MB
- 视频: 100MB
- 文档/压缩包/其它: 50MB
- 单条消息附件总大小: 100MB
- 单条消息最大附件数: 10

**管理员可通过**：`PUT /api/admin/settings/upload-policy` 或管理后台「通用设置 → 上传策略」调整上述限制。

#### 错误3: 上传完成校验失败（size/hash）
**错误信息**:
- `附件大小校验失败：期望 xxx 字节，实际 yyy 字节`
- `附件哈希校验失败，请重新上传`
**说明**：commit 阶段后端会通过 COS `HEAD` 获取对象元数据校验大小；对 `md5` 且 `ETag` 可判定为单文件 MD5 时会做哈希校验。

### ⚡ COS直传错误

#### 错误1: 403 Forbidden
**错误信息**: `上传文件失败`
**排查步骤**:
```bash
# 1. 测试COS连接
curl -X PUT "https://bucket-name.cos.region.myqcloud.com/test.txt" \
  -H "Authorization: q-sign-algorithm=sha1;..." \
  -H "Host: bucket-name.cos.region.myqcloud.com" \
  -d "test"

# 2. 检查签名生成逻辑
# 查看后端日志中的签名内容
tail -f /path/to/logs/app.log | grep "signature"
```

**常见原因**:
- 签名算法错误
- 时间不同步
- 签名过期
- 请求头格式错误

#### 错误2: 404 Not Found
**错误信息**: `文件上传失败`
**排查步骤**:
1. 确认桶名称和区域
2. 检查文件路径格式
3. 验证COS服务状态

**COS路径格式**:
```
正确格式: avatars/uuid/20241107123456_abc12345.jpg
错误格式: /avatars/uuid/file.jpg 或 avatars//file.jpg
```

#### 错误3: 签名不匹配
**错误信息**: `SignatureDoesNotMatch`
**排查步骤**:
1. 检查服务器时间同步
2. 验证签名算法实现
3. 确认请求头顺序

**时间同步检查**:
```bash
# 检查服务器时间
date
# 同步时间
sudo ntpdate -s time.apple.com
```

### 📦 分片上传错误

> 大文件（> 5MB）会自动走 COS Multipart Upload（分片直传）。

#### 错误1: 分片会话初始化失败
**错误信息**: `创建分片会话失败`
**排查步骤**:
1. 确认存储提供商配置正确且已启用
2. 检查 COS Bucket 权限是否包含 `InitiateMultipartUpload`
3. 查看后端日志中的详细错误

#### 错误2: 分片上传超时或中断
**错误信息**: `分片上传超时` / 网络中断
**排查步骤**:
1. 检查网络稳定性
2. 增加客户端重试机制
3. 查询分片会话状态：`GET /uploads/multipart/sessions/{session_id}`

**恢复中断的上传**:
- 分片会话信息保存在 `file_upload_multipart_sessions` 表
- 客户端可通过 `session_id` 查询已完成的分片，继续上传剩余分片
- 超时的会话会被后台清理任务自动 `abort`

#### 错误3: 分片合并失败
**错误信息**: `Complete multipart upload failed`
**排查步骤**:
1. 确认所有分片都已上传成功
2. 检查分片 ETag 是否正确记录
3. 查看 COS 控制台的分片上传记录

**数据库查询**:
```sql
-- 检查分片会话状态
SELECT id, status, total_parts, completed_parts, created_at
FROM file_upload_multipart_sessions
WHERE id = '会话UUID';

-- 检查各分片状态
SELECT part_number, etag, uploaded_at
FROM file_upload_multipart_parts
WHERE session_id = '会话UUID'
ORDER BY part_number;
```

### 🔧 后端处理错误

#### 错误1: 数据库连接错误
**错误信息**: `Database connection failed`
**排查步骤**:
1. 检查数据库连接池状态
2. 验证数据库服务是否运行
3. 确认连接字符串

#### 错误2: 文件路径验证失败
**错误信息**: `文件路径不合法`
**排查步骤**:
1. 检查文件路径格式
2. 验证用户ID匹配
3. 确认路径中不包含危险字符

**路径验证规则**:
```rust
// 不能包含 ".."
// 不能以 "/" 开头
// 头像必须以 "avatars/用户ID/" 开头
// 群头像必须以 "room_avatars/房间ID/" 开头
// 消息附件必须以 "messages/" 开头（允许跨房间复用历史附件 key）
```

#### 错误3: 上传成功但下载接口返回 404
**错误信息**: `附件不存在`
**说明**：附件下载链接接口会校验该 `key` 必须已被当前房间的消息引用（附件或缩略图）。  
如果你只是拿到了一个 `messages/...` 的 key，但还没把它写入该房间的消息（`POST /rooms/:room_id/messages`），则下载会被拒绝。

### 🧹 清理任务相关

如果出现“历史文件突然无法复用/下载”的情况，可能与清理策略有关（例如对象已被删除并标记为 `status=3`）。  
可通过环境变量调大保留期或关闭/降低清理频率：
- `FILE_UPLOAD_CLEANUP_INTERVAL_SECONDS`
- `FILE_UPLOAD_PENDING_TIMEOUT_SECONDS`
- `FILE_UPLOAD_ORPHAN_DELETE_AFTER_SECONDS`
- `FILE_UPLOAD_UNREFERENCED_RETENTION_SECONDS`

也可以直接查询 `file_upload_records` 状态：
```sql
SELECT object_key, status, uploaded_at, created_at, last_error
FROM file_upload_records
WHERE object_key = '你的 key'
LIMIT 1;
```

## 调试工具和命令

### 1. 后端调试
```bash
# 查看实时日志
tail -f /path/to/logs/app.log | grep -E "(upload|signature|COS)"

# 检查数据库连接
psql -h localhost -U username -d database -c "SELECT NOW();"

# 测试存储提供商配置
curl -X GET "http://localhost:8010/api/admin/storage-providers/default" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 2. 前端调试
```javascript
// 浏览器控制台调试
console.log('上传参数:', {
  contentType: file.type,
  fileSize: file.size,
  fileName: file.name
});

// 查看网络请求详情
// 开发者工具 → Network → 查看请求/响应详情
```

### 3. COS调试工具
```bash
# COS CLI工具
coscli ls cos://bucket-name/
coscli upload file.txt cos://bucket-name/test.txt
coscli head cos://bucket-name/test.txt
```

## 常见问题和解决方案

### Q1: 上传成功但无法下载
**可能原因**:
- 文件路径生成错误
- 下载链接过期
- 存储桶权限问题

**解决方案**:
1. 检查生成的文件路径格式
2. 验证下载链接生成逻辑
3. 更新存储桶公开读取权限

### Q2: 部署后无法上传文件
**可能原因**:
- 环境变量未正确设置
- 生产环境COS配置不同
- 网络防火墙限制

**解决方案**:
1. 确认生产环境配置
2. 检查安全组规则
3. 验证外网访问权限

### Q3: 大文件上传经常失败
**可能原因**:
- 网络不稳定
- 超时设置过短
- 文件格式问题

**解决方案**:
1. 增加重试机制
2. 调整超时时间
3. 实现分片上传

## 性能优化建议

### 1. 前端优化
```typescript
// 添加重试机制
async function uploadWithRetry(file, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const result = await uploadFile(file);
      return result;
    } catch (error) {
      console.log(`上传失败，重试 ${i + 1}/${maxRetries}:`, error);
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
}

// 添加进度监控
function uploadWithProgress(file, onProgress) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.upload.onprogress = (e) => {
      const progress = (e.loaded / e.total) * 100;
      onProgress(progress);
    };
    // ... 上传逻辑
  });
}
```

### 2. 后端优化
```rust
// 缓存签名结果
static SIGNATURE_CACHE: Arc<Mutex<HashMap<String, (String, Instant)>>> = Arc::new(Mutex::new(HashMap::new()));

pub async fn get_cached_signature(key: &str) -> Option<String> {
    let cache = SIGNATURE_CACHE.lock().await;
    if let Some((signature, expires_at)) = cache.get(key) {
        if Instant::now() < expires_at {
            return Some(signature);
        }
        cache.remove(key);
    }
    None
}
```

## 2025-11-08 自动化排障套件

- **一键复现**：设置 `VITE_AUTO_UPLOAD_TEST=true` 并运行 `bun run tauri dev`，桌面端会自动登录账号 `alice`（验证码 `666666`）、触发头像上传、30 秒后自动退出，日志写入 `~/Library/Application Support/com.chen.bear-chat-tauri/logs/app.log`。
- **关键日志标签**：`avatarUploadPrepared`（检查 `injectToken/forceStreaming/Content-Length`）、`HTTP_REQUEST`（确认参数未被覆盖）、`avatarUploadRawResponse`（记录 COS PUT 返回码）。
- **常见后端报错**：如果 `app.log` 或后端输出 `ColumnNotFound("avatar_object_key")`、`ColumnNotFound("status")`，请确认数据库已完成迁移（启动 backend 执行 `Database::migrate`，或按 `MIGRATIONS` 顺序执行 `base.sql` + `migrations/*.sql`），并确保 `UserStore::update_user` 的 `RETURNING` 列包含对应字段。
- **日志轮转**：桌面端启动时会自动归档旧 `app.log`，无需手动清理即可获取最近一次上传流程。

## 监控和报警

### 1. 关键指标监控
- 文件上传成功率 (目标: >99%)
- 平均上传时间 (目标: <10s)
- 错误类型分布
- 存储使用量

### 2. 报警规则
- 上传成功率 <95%
- 平均上传时间 >30s
- COS API错误率 >1%
- 存储空间使用率 >80%

---

**文档版本**: v1.2
**更新时间**: 2025-12-31
**维护者**: 开发团队
