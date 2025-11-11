# 头像重新登录后变成默认头像问题 - 调试指南

## 问题描述

1. 上传头像成功
2. 数据库中腾讯 COS key 已更新
3. 退出登录
4. 重新登录
5. **头像变成默认头像**

## 已添加的日志

### 标识符：`[AVATAR_SYNC_xxxxx]`

位置：`src/api/user.ts` - `syncAvatarCache`

记录信息：
- 当前用户信息（userId, avatar, avatarObjectKey, avatarLocalPath）
- 是否有本地缓存
- 下载 URL 获取结果
- 头像文件下载结果
- 缓存保存结果

## 测试步骤

### 第一步：上传头像

1. 登录账号
2. 进入设置页面
3. 点击头像，上传新头像
4. 等待上传成功
5. **记录日志**：查找头像上传相关日志

### 第二步：验证数据库

1. 检查数据库中的 `avatar_object_key` 字段
2. 确认是否已更新

### 第三步：退出登录

1. 点击退出登录
2. 观察是否跳转到登录页

### 第四步：重新登录

1. 输入账号密码
2. 点击登录
3. **记录日志**：查找 `[AVATAR_SYNC_xxxxx]` 日志
4. 观察头像是否正确显示

## 关键检查点

### 1. 登录时返回的用户信息

查找日志：
```
✅ 用户信息设置成功
```

检查用户信息中是否包含：
- `avatar`: 头像 URL
- `avatarObjectKey`: COS 对象键

### 2. syncAvatarCache 的执行

查找日志：
```
[AVATAR_SYNC_xxxxx] ========== 同步头像缓存 ==========
[AVATAR_SYNC_xxxxx] 当前用户: { ... }
```

检查：
- `hasUser`: 是否有用户
- `avatarObjectKey`: 是否有值（**关键**）
- `avatarLocalPath`: 本地缓存路径

### 3. avatarObjectKey 的值

如果 `avatarObjectKey` 为 `null` 或空字符串：
```
[AVATAR_SYNC_xxxxx] 无 avatarObjectKey，清除缓存
```

**这就是问题所在！** 登录时返回的用户信息中没有 `avatarObjectKey`。

### 4. 本地缓存检查

如果有 `avatarObjectKey`，检查本地缓存：
```
[AVATAR_SYNC_xxxxx] 检查本地缓存...
[AVATAR_SYNC_xxxxx] 找到本地缓存: /path/to/avatar
```

或者：
```
[AVATAR_SYNC_xxxxx] 本地缓存不存在，需要下载
```

### 5. 下载 URL 获取

```
[AVATAR_SYNC_xxxxx] 获取下载 URL...
[AVATAR_SYNC_xxxxx] 下载 URL 响应: { success: true, hasUrl: true }
```

如果失败：
```
[AVATAR_SYNC_xxxxx] 获取下载 URL 失败
```

### 6. 头像文件下载

```
[AVATAR_SYNC_xxxxx] 下载头像文件...
[AVATAR_SYNC_xxxxx] 下载响应: { success: true, hasBase64: true }
```

如果失败：
```
[AVATAR_SYNC_xxxxx] 下载头像失败: HTTP 404
```

### 7. 缓存保存

```
[AVATAR_SYNC_xxxxx] 保存到本地缓存...
[AVATAR_SYNC_xxxxx] 缓存保存成功: /path/to/avatar
[AVATAR_SYNC_xxxxx] ========== 同步完成（成功） ==========
```

## 可能的问题原因

### 原因 1: 登录 API 没有返回 avatarObjectKey ⭐ 最可能

**现象**：
```
[AVATAR_SYNC_xxxxx] 当前用户: { avatarObjectKey: null }
[AVATAR_SYNC_xxxxx] 无 avatarObjectKey，清除缓存
```

**原因**：
- 后端登录接口返回的用户信息中没有 `avatar_object_key` 字段
- 或者字段名不匹配

**解决方案**：
- 检查后端登录接口的返回数据
- 确保返回 `avatar_object_key` 字段
- 检查前端的字段映射是否正确

### 原因 2: 获取下载 URL 失败

**现象**：
```
[AVATAR_SYNC_xxxxx] 下载 URL 响应: { success: false }
[AVATAR_SYNC_xxxxx] 获取下载 URL 失败
```

**原因**：
- `/users/me/avatar/url` 接口返回失败
- Token 无效或过期

**解决方案**：
- 检查该接口的实现
- 确保 Token 有效

### 原因 3: 头像文件下载失败

**现象**：
```
[AVATAR_SYNC_xxxxx] 下载响应: { success: false }
[AVATAR_SYNC_xxxxx] 下载头像失败: HTTP 403
```

**原因**：
- COS 下载 URL 无效或过期
- 权限配置问题

**解决方案**：
- 检查 COS 配置
- 确保下载 URL 有效

### 原因 4: 本地缓存保存失败

**现象**：
```
[AVATAR_SYNC_xxxxx] 保存到本地缓存...
[AVATAR_SYNC_xxxxx] 同步头像缓存失败: Error: ...
```

**原因**：
- 文件系统权限问题
- 磁盘空间不足

**解决方案**：
- 检查应用数据目录权限
- 检查磁盘空间

## 预期的正常日志

```
[AVATAR_SYNC_1762830000000] ========== 同步头像缓存 ==========
[AVATAR_SYNC_1762830000000] force: true
[AVATAR_SYNC_1762830000000] 当前用户: {
  hasUser: true,
  userId: "123",
  avatar: "https://...",
  avatarObjectKey: "avatars/123/abc.jpg",  // ⭐ 关键：必须有值
  avatarLocalPath: null
}
[AVATAR_SYNC_1762830000000] 强制刷新，跳过缓存检查
[AVATAR_SYNC_1762830000000] 获取下载 URL...
[AVATAR_SYNC_1762830000000] 下载 URL 响应: {
  success: true,
  hasData: true,
  dataSuccess: true,
  hasUrl: true
}
[AVATAR_SYNC_1762830000000] 下载头像文件...
[AVATAR_SYNC_1762830000000] 下载响应: {
  success: true,
  hasData: true,
  hasBase64: true
}
[AVATAR_SYNC_1762830000000] 保存到本地缓存...
[AVATAR_SYNC_1762830000000] 缓存保存成功: /path/to/avatar
[AVATAR_SYNC_1762830000000] ========== 同步完成（成功） ==========
```

## 下一步

1. **执行测试流程**
2. **收集前端控制台日志**
3. **重点查找 `[AVATAR_SYNC_xxxxx]` 日志**
4. **检查 `avatarObjectKey` 的值**
5. **提供日志给我分析**

如果 `avatarObjectKey` 为 `null`，问题就在后端登录接口。
