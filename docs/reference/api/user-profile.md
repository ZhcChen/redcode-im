# 用户资料 API

涵盖当前用户信息维护、密码修改以及头像直传流程。

## 数据模型补充

`GET /auth/me`、`GET /users/{user_id}`、`PATCH /users/me` 返回的用户结构包含以下字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `avatar_object_key` | string 或 `null` | 对象存储中的头像 Key，用于客户端判断本地缓存是否需要刷新 |

示例：

```json
{
  "id": "8c7c4f01-9b51-4cbf-aac0-2f0d13f0c9a4",
  "username": "testuser",
  "email": "test@example.com",
  "nickname": "新昵称",
  "avatar_url": "https://cdn.example.com/avatars/8c7c4f/avatar.png",
  "avatar_object_key": "avatars/8c7c4f01-9b51-4cbf-aac0-2f0d13f0c9a4/20251104160012-5f7a9e3b.png",
  "status": "active"
}
```

## 1. 更新用户资料

- **方法**：`PATCH`
- **路径**：`/users/me`
- **认证**：Bearer Token

请求体（全部字段可选，提交前请做前端校验）：

```json
{
  "nickname": "新昵称",
  "avatar_url": "https://cdn.example.com/avatars/...",
  "avatar_object_key": "avatars/..."
}
```

注意事项：

- `avatar_url` 与 `avatar_object_key` 通常在头像直传 commit 时自动更新，客户端一般无需手动写入。

## 2. 修改密码

- **方法**：`POST`
- **路径**：`/users/me/password`
- **认证**：Bearer Token

请求体：

```json
{
  "old_password": "oldpass123",
  "new_password": "newpass456"
}
```

成功响应（示例）：

```json
{
  "success": true,
  "message": "修改密码成功"
}
```

常见错误（示例）：

| 状态码 | 场景 | 返回 | 说明 |
| --- | --- | --- | --- |
| 400 | 旧密码错误 | `{ \"code\": 42201, \"message\": \"Old password is incorrect\" }` | 校验失败 |
| 400 | 新密码过短 | `{ \"code\": 42201, \"message\": \"New password must be at least 6 characters\" }` | 长度限制 |

## 3. 查询用户信息

- **方法**：`GET`
- **路径**：`/users/{user_id}`
- **认证**：Bearer Token

返回目标用户公开信息，未找到返回 404。

## 4. 头像直传流程

头像上传采用「前端直传对象存储 + 后端确认」模式。请先确保默认存储提供商（`/api/admin/storage-providers/default`）已配置并启用（S3 兼容对象存储）。

### 4.1 获取直传签名

- **方法**：`POST`
- **路径**：`/users/me/avatar/direct-upload`
- **认证**：Bearer Token

请求体：

```json
{
  "content_type": "image/png",
  "file_size": 123456,
  "hash_value": "d41d8cd98f00b204e9800998ecf8427e",
  "hash_alg": 1
}
```

响应（示例）：

```json
{
  "success": true,
  "message": "生成头像直传签名成功",
  "key": "avatars/{user-id}/20251104160135-8fd3aa12.png",
  "signature": {
    "url": "http://rustfs:9000/<bucket>/avatars/...",
    "method": "PUT",
    "headers": {
      "Authorization": "AWS4-HMAC-SHA256 Credential=...",
      "Content-Type": "image/png"
    },
    "key": "avatars/{user-id}/20251104160135-8fd3aa12.png"
  }
}
```

> 如果提供了 `hash_value + file_size` 且后端已记录相同文件的上传记录，可能返回 `signature: null`，表示可复用既有对象；此时前端无需重复上传，只需调用 commit 绑定该 key。

### 4.2 提交上传结果

- **方法**：`POST`
- **路径**：`/users/me/avatar/commit`
- **认证**：Bearer Token

请求体：

```json
{
  "key": "avatars/{user-id}/20251104160135-8fd3aa12.png",
  "delete_previous": true,
  "expires_in_seconds": 600
}
```

成功响应（示例）：

```json
{
  "success": true,
  "message": "头像更新成功",
  "download_url": "http://rustfs:9000/<bucket>/avatars/...?..."
}
```

### 4.3 获取头像下载链接

- **方法**：`GET`
- **路径**：`/users/me/avatar/url`
- **认证**：Bearer Token

查询参数：

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `expires_in_seconds` | int | 否 | 600 | 有效期，范围 60~86400 |

响应（示例）：

```json
{
  "success": true,
  "message": "获取头像下载链接成功",
  "download_url": "https://..."
}
```

### 4.4 旧版接口说明

历史上存在 `POST /users/me/avatar`（直接上传头像）的兼容实现；当前后端已统一采用“直传 + commit”流程，对新客户端不再提供该接口。

## 相关文档

- [API 参考（全量路由）](../../../docs/reference/api/api-reference.md)
- [文件上传排障](../operations/troubleshooting.md)
