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

**解决方案**:
```bash
# 检查环境变量
echo $COS_SECRET_ID
echo $COS_SECRET_KEY
echo $COS_REGION

# 登录管理后台配置存储提供商
# 路径: 系统管理 → 存储提供商 → 添加/编辑
```

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

**大小限制参考**:
- 头像: 5MB
- 图片: 10MB
- 音频: 20MB
- 视频: 100MB
- 文档: 50MB

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
// 必须以 "avatars/用户ID/" 开头(头像)
```

## 调试工具和命令

### 1. 后端调试
```bash
# 查看实时日志
tail -f /path/to/logs/app.log | grep -E "(upload|signature|COS)"

# 检查数据库连接
psql -h localhost -U username -d database -c "SELECT NOW();"

# 测试存储提供商配置
curl -X GET "http://localhost:8080/api/admin/storage-providers/default" \
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

**文档版本**: v1.0
**更新时间**: 2024-11-07
**维护者**: 开发团队