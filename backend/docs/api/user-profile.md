# 用户资料 API

涵盖当前用户信息维护、密码修改以及头像直传流程。

## 数据模型补充

`GET /auth/me`、`GET /users/:user_id`、`PATCH /users/me` 返回的用户结构新增以下字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `avatar_object_key` | string 或 `null` | 对象存储中的头像 Key，用于后续校验是否需要刷新本地缓存 |

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

- **方法**: `PATCH`
- **路径**: `/users/me`
- **认证**: Bearer Token

请求体（全部字段可选，提交前请做前端校验）

```json
{
  "nickname": "新昵称",
  "avatar_url": "https://cdn.example.com/avatars/...",
  "avatar_object_key": "avatars/..."
}
```

返回当前用户完整信息（见上表）。

注意事项：

- `avatar_url` 与 `avatar_object_key` 在头像直传 commit 时自动更新，客户端通常无需重复调用。
- 昵称长度限制 1~20 字符，服务端会作校验。

## 2. 修改密码

- **方法**: `POST`
- **路径**: `/users/me/password`
- **认证**: Bearer Token

```json
{
  "old_password": "oldpass123",
  "new_password": "newpass456"
}
```

成功响应：

```json
{
  "success": true,
  "message": "修改密码成功"
}
```

常见错误：

| 状态码 | 场景 | 返回 | 说明 |
| --- | --- | --- | --- |
| 400 | 旧密码错误 | `{ "code": 42201, "message": "Old password is incorrect" }` | 校验失败 |
| 400 | 新密码过短 | `{ "code": 42201, "message": "New password must be at least 6 characters" }` | 长度限制 |

## 3. 查询用户信息

- **方法**: `GET`
- **路径**: `/users/:user_id`
- **认证**: Bearer Token

返回目标用户公开信息，未找到返回 404。

## 4. 头像直传流程

头像上传采用「前端直传对象存储 + 后端确认」模式，需保证默认存储提供商（`/api/admin/storage-providers/default`）已配置并启用腾讯 COS。流程如下：

### 4.1 获取直传签名

- **方法**: `POST`
- **路径**: `/users/me/avatar/direct-upload`
- **认证**: Bearer Token

请求体：

```json
{
  "content_type": "image/png"
}
```

响应：

```json
{
  "success": true,
  "message": "生成头像直传签名成功",
  "key": "avatars/{user-id}/20251104160135-8fd3aa12.png",
  "signature": {
    "url": "https://<bucket>.cos.<region>.myqcloud.com/avatars/...",
    "method": "PUT",
    "headers": {
      "Authorization": "q-sign-algorithm=...",
      "Content-Type": "image/png"
    },
    "key": "avatars/{user-id}/20251104160135-8fd3aa12.png"
  }
}
```

前端需使用返回的 `url`、`method`、`headers` 直接请求 COS（通常通过 `fetch`/`axios`/`http` 上传二进制文件）。

### 4.2 提交上传结果

- **方法**: `POST`
- **路径**: `/users/me/avatar/commit`
- **认证**: Bearer Token

请求体：

```json
{
  "key": "avatars/{user-id}/20251104160135-8fd3aa12.png",
  "delete_previous": true,
  "expires_in_seconds": 600
}
```

`delete_previous` 默认为 `true`，表示在更新成功后后台会尝试删除旧头像。

成功响应：

```json
{
  "success": true,
  "message": "头像更新成功",
  "download_url": "https://<bucket>.cos.<region>.myqcloud.com/...&sign=..."
}
```

同时服务端会更新用户资料中的 `avatar_url` 与 `avatar_object_key` 字段。客户端可选择：

1. 直接使用 `download_url` 缓存文件（有效期默认 600 秒）；
2. 或者调用下方下载接口随用随取。

### 4.3 获取头像下载链接

- **方法**: `GET`
- **路径**: `/users/me/avatar/url`
- **认证**: Bearer Token

查询参数：

| 参数 | 类型 | 必填 | 默认 | 说明 |
| --- | --- | --- | --- | --- |
| `expires_in_seconds` | `int` | 否 | 600 | 有效期，范围 60~86400 |

响应：

```json
{
  "success": true,
  "message": "获取头像下载链接成功",
  "download_url": "https://..."
}
```

### 4.4 兼容接口（即将废弃）

`POST /users/me/avatar` 仍返回 DiceBear 占位头像地址，仅用于开发阶段兼容，预计后续移除，新的客户端应改用直传流程。

## 附录：公开端点列表

- `GET /` – 服务信息
- `GET /healthz` – 健康检查
- `GET /ws?token=...` – WebSocket 升级
- `POST /auth/register` - 用户注册
- `POST /auth/login` - 用户登录

### 需要认证的端点

#### 用户相关
- `GET /auth/me` - 获取当前用户
- `PATCH /users/me` - 更新当前用户资料
- `POST /users/me/password` - 修改密码 ⭐ 新增
- `POST /users/me/avatar` - 上传头像（占位）⭐ 新增
- `GET /users/:user_id` - 查询用户信息 ⭐ 新增

#### 房间相关
- `POST /rooms` - 创建房间
- `GET /rooms` - 我的房间列表
- `POST /rooms/:room_id/join` - 加入房间
- `POST /rooms/:room_id/leave` - 离开房间
- `GET /rooms/:room_id/members` - 房间成员

#### 消息相关
- `POST /rooms/:room_id/messages` - 发送消息
- `GET /rooms/:room_id/messages` - 获取消息历史

## WebSocket 认证说明

### 方式 1: 握手时认证（推荐）

连接时在 URL 中传递 token：

```javascript
const token = "your_jwt_token_here";
const ws = new WebSocket(`ws://localhost:8010/ws?token=${token}`);

ws.onopen = () => {
  console.log("已连接并自动认证");
  // 收到 authed 事件确认
};
```

**优点**:
- 连接即认证，无需额外步骤
- Token 过期会在握手时被拒绝
- 更安全，防止未认证连接

### 方式 2: 连接后认证

先连接，后发送认证事件：

```javascript
const ws = new WebSocket("ws://localhost:8010/ws");

ws.onopen = () => {
  // 发送认证事件
  ws.send(JSON.stringify({
    type: "auth",
    token: "your_jwt_token_here"
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  if (data.type === "authed") {
    console.log("认证成功:", data.user_id);
  }
};
```

**优点**:
- 灵活，支持在连接后获取 token
- 可以重新认证

### Token 过期处理

WebSocket 已支持 Token 过期检测：

1. **握手时检测**: 握手时会验证 token 是否过期，过期则拒绝连接（返回 401）
2. **连接中检测**: Auth 事件中也会检测过期（建议客户端主动管理）

**客户端建议**:
```javascript
// 检查 token 是否即将过期
function isTokenExpiringSoon(token) {
  const payload = JSON.parse(atob(token.split('.')[1]));
  const now = Math.floor(Date.now() / 1000);
  return payload.exp - now < 300; // 5分钟内过期
}

// 重新连接逻辑
if (isTokenExpiringSoon(currentToken)) {
  // 刷新 token
  const newToken = await refreshToken();
  // 重新连接
  connectWebSocket(newToken);
}
```

## 测试示例

### 测试密码修改

```bash
# 1. 登录获取 token
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8010/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "oldpass123"}')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')

# 2. 修改密码
curl -X POST "http://localhost:8010/users/me/password" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "old_password": "oldpass123",
    "new_password": "newpass456"
  }'

# 3. 用新密码登录验证
curl -X POST "http://localhost:8010/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "newpass456"}'
```

### 测试查询用户

```bash
# 查询其他用户
curl -X GET "http://localhost:8010/users/{user_id}" \
  -H "Authorization: Bearer $TOKEN"
```

### 测试上传头像

```bash
# 上传头像（当前返回mock URL）
curl -X POST "http://localhost:8010/users/me/avatar" \
  -H "Authorization: Bearer $TOKEN"
```

## 数据库变更

### 新增方法

`UserStore::update_password()` - 更新用户密码

**实现**:
```sql
UPDATE users
SET password_hash = $1, updated_at = NOW()
WHERE id = $2 AND status = 'active' AND deleted_at IS NULL
```

## 安全考虑

1. **密码修改**: 需要验证旧密码，防止账号被盗用
2. **密码强度**: 新密码最少 6 位（建议前端增加更强验证）
3. **Token 过期**: WebSocket 握手时检查 token 是否过期
4. **权限隔离**: 只能修改自己的资料，查询其他用户信息是只读的
5. **头像上传**: 未来需要添加：
   - 文件类型白名单
   - 文件大小限制
   - 病毒扫描
   - 图片压缩

## 下一步开发建议

1. **头像上传实现** (6h)
   - 集成对象存储（MinIO/S3）
   - 实现文件上传处理
   - 图片压缩和缩略图

2. **邮箱验证** (4h)
   - 邮箱验证码发送
   - 验证码校验
   - 邮箱修改流程

3. **用户统计** (2h)
   - 用户在线状态
   - 最后活跃时间
   - 消息统计

4. **账号安全** (4h)
   - 登录历史
   - 设备管理
   - 异常登录检测
