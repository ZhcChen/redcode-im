# 腾讯 COS 私有读文件访问说明

## 核心概念

**所有文件（图片、视频、音频等）都存储在腾讯 COS，且配置为私有读**

这意味着：
- ❌ 不能直接通过 URL 访问文件（会返回 403 Forbidden）
- ✅ 必须通过 `object_key` 获取临时下载地址
- ✅ 临时下载地址有时效性（通常 1-24 小时）

## 数据库字段说明

### 用户头像示例

```sql
-- users 表
avatar_url: 'https://xxx.cos.ap-guangzhou.myqcloud.com/avatars/user123/avatar.jpg'  -- COS 文件地址（私有，不可直接访问）
avatar_object_key: 'avatars/user123/avatar.jpg'  -- COS 对象键（用于获取临时下载地址）
```

### 字段用途

| 字段 | 用途 | 是否可直接访问 |
|------|------|----------------|
| `*_url` | COS 文件地址，保留用于记录 | ❌ 否（私有读） |
| `*_object_key` | COS 对象键，用于获取临时下载地址 | ✅ 是（通过 API） |

## 文件访问流程

### 1. 上传文件

```
用户选择文件
  ↓
前端调用上传 API
  ↓
后端返回：
  - file_url: COS 文件地址（私有）
  - object_key: COS 对象键
  ↓
保存到数据库
```

### 2. 访问文件

```
前端需要显示文件
  ↓
检查本地缓存（通过 object_key）
  ↓
如果缓存不存在或过期：
  ↓
调用 API 获取临时下载地址
  - 输入：object_key
  - 输出：临时下载 URL（有效期 1-24 小时）
  ↓
下载文件到本地缓存
  ↓
使用本地缓存路径显示文件
```

## 头像访问实现

### 数据结构

```typescript
interface UserInfo {
  id: string
  avatar: string              // COS 文件地址（私有，不可直接访问）
  avatarObjectKey: string     // COS 对象键（用于获取临时下载地址）
  avatarLocalPath: string     // 本地缓存路径（临时下载地址或本地文件路径）
}
```

### 显示优先级

```typescript
const userAvatarSrc = computed(() => {
  // 1. 优先使用本地缓存路径（临时下载地址）
  if (currentUser.value.avatarLocalPath) {
    return currentUser.value.avatarLocalPath
  }
  
  // 2. 如果没有本地缓存，触发获取临时下载地址
  // （通过 syncAvatarCache 函数）
  
  // 3. 默认头像
  return defaultAvatarUrl
})
```

### 关键函数：syncAvatarCache

**位置**: `src/api/user.ts`

**功能**: 
1. 检查本地缓存是否存在且有效
2. 如果不存在，通过 `avatarObjectKey` 获取临时下载地址
3. 下载文件到本地缓存
4. 更新 `avatarLocalPath`

**调用时机**:
- 登录成功后
- 账号切换后
- 头像上传成功后
- 本地缓存过期后

**代码示例**:
```typescript
// 登录后同步头像缓存
await UserApi.syncAvatarCache(true)

// 账号切换后同步头像缓存
await UserApi.syncAvatarCache(false)
```

## API 接口

### 获取头像临时下载地址

**接口**: `GET /users/me/avatar/url`

**参数**:
```typescript
{
  expires_in_seconds?: number  // 有效期（秒），默认 600
}
```

**返回**:
```typescript
{
  success: true,
  download_url: "https://xxx.cos.ap-guangzhou.myqcloud.com/avatars/user123/avatar.jpg?sign=..."
}
```

### 上传头像

**接口**: `POST /users/me/avatar/direct-upload`

**流程**:
1. 获取直传签名
2. 直接上传到 COS
3. 提交头像配置
4. 返回 `avatar_url` 和 `avatar_object_key`

## 本地缓存机制

### AvatarCache 工具

**位置**: `src/utils/avatar-cache.ts`

**功能**:
- 保存头像文件到本地
- 通过 `userId` 和 `objectKey` 查找缓存
- 返回本地文件路径（`convertFileSrc` 格式）

**缓存路径**:
```
macOS: ~/Library/Application Support/com.redcode.im/avatars/
Windows: %APPDATA%/com.redcode.im/avatars/
Linux: ~/.local/share/com.redcode.im/avatars/
```

**缓存文件名**:
```
{userId}_{objectKey_hash}.{ext}
```

## 其他文件类型

### 聊天图片/视频

**字段**:
- `media_url`: COS 文件地址（私有）
- `media_object_key`: COS 对象键

**访问流程**: 同头像

### 语音消息

**字段**:
- `audio_url`: COS 文件地址（私有）
- `audio_object_key`: COS 对象键

**访问流程**: 同头像

### 文件消息

**字段**:
- `file_url`: COS 文件地址（私有）
- `file_object_key`: COS 对象键

**访问流程**: 同头像

## 测试参考

### Admin 模块 COS 测试页面

**位置**: Admin 模块 → COS 测试页面

**功能**:
- 输入 `object_key`
- 获取临时下载地址
- 测试文件访问

**示例**:
```
输入: avatars/user123/avatar.jpg
输出: https://xxx.cos.ap-guangzhou.myqcloud.com/avatars/user123/avatar.jpg?sign=...
```

## 常见问题

### Q1: 为什么头像显示 403 错误？

**原因**: 直接使用了 `avatar_url`（私有地址）

**解决**: 
1. 检查是否调用了 `syncAvatarCache`
2. 检查 `avatarLocalPath` 是否有值
3. 检查 `avatarObjectKey` 是否存在

### Q2: 为什么重新登录后头像变成默认头像？

**原因**: 
1. 登录时没有返回 `avatar_object_key`
2. `syncAvatarCache` 没有被正确调用
3. 获取临时下载地址失败

**解决**:
1. 检查后端登录接口是否返回 `avatar_object_key`
2. 检查前端日志中的 `[AVATAR_SYNC_xxxxx]`
3. 检查 API `/users/me/avatar/url` 是否正常

### Q3: 临时下载地址的有效期是多久？

**答案**: 
- 默认 600 秒（10 分钟）
- 可以通过 `expires_in_seconds` 参数调整
- 建议设置为 3600 秒（1 小时）

### Q4: 本地缓存会过期吗？

**答案**: 
- 本地缓存文件不会自动过期
- 但如果 `object_key` 变化（如重新上传头像），会重新下载
- 可以通过 `force=true` 强制刷新缓存

## 最佳实践

### 1. 登录时立即同步头像

```typescript
// 登录成功后
await UserApi.syncAvatarCache(true)  // force=true，强制刷新
```

### 2. 账号切换时同步头像

```typescript
// 切换账号后
await UserApi.syncAvatarCache(false)  // force=false，优先使用缓存
```

### 3. 头像上传后更新缓存

```typescript
// 上传成功后
const result = await UserApi.uploadAvatar(file)
// uploadAvatar 内部会自动更新 avatarLocalPath
```

### 4. 定期清理过期缓存

```typescript
// 应用启动时
await AvatarCache.clearExpired()  // 清理超过 7 天的缓存
```

## 相关文件

- `src/api/user.ts` - 用户 API，包含头像上传和缓存同步
- `src/utils/avatar-cache.ts` - 头像缓存工具
- `src/components/Avatar.vue` - 头像显示组件
- `src/views/Settings.vue` - 设置页面，头像上传
- `src/store/index.ts` - 用户状态管理

## 注意事项

1. **永远不要直接使用 `*_url` 字段显示文件**
2. **始终通过 `*_object_key` 获取临时下载地址**
3. **使用本地缓存减少 API 调用**
4. **临时下载地址有时效性，需要定期刷新**
5. **所有文件类型（图片、视频、音频）都遵循相同的访问逻辑**
