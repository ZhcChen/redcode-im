# 用户资料 API 使用文档

## 新增 API 端点

### 1. 更新用户资料

**端点**: `PATCH /users/me`
**认证**: 需要 Bearer Token

**请求体**:
```json
{
  "nickname": "新昵称",
  "avatar_url": "https://example.com/avatar.jpg"
}
```

**成功响应** (200):
```json
{
  "id": "uuid",
  "username": "testuser",
  "email": "test@example.com",
  "nickname": "新昵称",
  "avatar_url": "https://example.com/avatar.jpg",
  "status": "active"
}
```

### 2. 修改密码

**端点**: `POST /users/me/password`
**认证**: 需要 Bearer Token

**请求体**:
```json
{
  "old_password": "oldpass123",
  "new_password": "newpass456"
}
```

**成功响应** (200):
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

**错误响应**:
- **400** - 旧密码错误
  ```json
  {
    "code": 42201,
    "message": "Old password is incorrect"
  }
  ```
- **400** - 新密码太短
  ```json
  {
    "code": 42201,
    "message": "New password must be at least 6 characters"
  }
  ```

### 3. 查询用户信息

**端点**: `GET /users/:user_id`
**认证**: 需要 Bearer Token

**成功响应** (200):
```json
{
  "id": "uuid",
  "username": "someuser",
  "email": "user@example.com",
  "nickname": "Some User",
  "avatar_url": "https://example.com/avatar.jpg",
  "status": "active"
}
```

**错误响应**:
- **404** - 用户不存在
  ```json
  {
    "code": 40401,
    "message": "User {id} not found"
  }
  ```

### 4. 上传头像（占位接口）

**端点**: `POST /users/me/avatar`
**认证**: 需要 Bearer Token

**注意**: 当前为占位实现，返回示例头像 URL

**成功响应** (200):
```json
{
  "avatar_url": "https://api.dicebear.com/7.x/avataaars/svg?seed={user_id}"
}
```

**TODO**: 未来需要实现：
1. 接收 multipart/form-data 文件上传
2. 验证文件类型（支持 jpg, png, gif）
3. 验证文件大小（限制 2MB）
4. 上传到对象存储（S3/MinIO/OSS）
5. 返回实际文件访问 URL
6. 自动更新用户的 avatar_url 字段

## 完整 API 列表

### 公开端点（无需认证）
- `GET /` - 服务信息
- `GET /healthz` - 健康检查
- `GET /ws?token=xxx` - WebSocket 连接
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
