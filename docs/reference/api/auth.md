# 认证与登录接口

## 概述

本系统采用 JWT (JSON Web Token) 进行身份认证，支持以下认证方式：
- 用户名密码登录
- 手机号验证码登录
- 管理员登录（独立的 Token 体系）

### Token 机制
- **access_token**: 短期有效的访问令牌，用于 API 请求认证
- **refresh_token**: 长期有效的刷新令牌，用于无感刷新 access_token

---

## 公开路由

### POST /auth/register — 用户注册

创建新的用户账户，包含用户名、邮箱和密码等信息。

- 需要认证：否
- 标识：register

#### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": ["username", "email", "password"],
  "properties": {
    "username": {
      "type": "string",
      "description": "用户名，长度至少3个字符",
      "minLength": 3,
      "example": "testuser"
    },
    "email": {
      "type": "string",
      "format": "email",
      "description": "有效的邮箱地址",
      "example": "user@example.com"
    },
    "password": {
      "type": "string",
      "description": "密码，长度至少6个字符",
      "minLength": 6,
      "example": "password123"
    },
    "nickname": {
      "type": "string",
      "description": "用户昵称（可选）",
      "example": "测试用户"
    }
  }
}
```
- 示例：
```json
{
  "username": "testuser",
  "email": "test@example.com",
  "password": "password123",
  "nickname": "测试用户"
}
```

#### 响应
##### HTTP 200
注册成功
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "testuser",
  "email": "test@example.com",
  "nickname": "测试用户",
  "avatar_url": null,
  "status": "active"
}
```

##### HTTP 400
请求参数错误
```json
{
  "error": "Username must be at least 3 characters"
}
```

##### HTTP 409
用户名或邮箱已存在
```json
{
  "error": "Username already exists"
}
```

---

### POST /auth/login — 用户登录

使用用户名和密码进行身份验证，成功后返回JWT token。

- 需要认证：否
- 标识：login

#### 请求体
- Content-Type：application/json
```json
{
  "username": "testuser",
  "password": "password123"
}
```

#### 响应
##### HTTP 200
登录成功
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "testuser",
    "email": "test@example.com",
    "nickname": "测试用户",
    "avatar_url": null,
    "status": "active"
  }
}
```

##### HTTP 401
用户名或密码错误
```json
{
  "error": "Invalid username or password"
}
```

---

### POST /auth/login/oauth — 第三方登录（OAuth/OIDC）

客户端获取第三方 `id_token` 后，调用该接口完成登录或注册并返回 Token。

- 需要认证：否
- 标识：login_oauth
- 支持 provider：`google` / `apple`

#### 请求体
- Content-Type：application/json
```json
{
  "provider": "google",
  "id_token": "..."
}
```

#### 响应
##### HTTP 200
登录成功（返回结构与 `/auth/login` 一致）

#### 环境变量
后端需要配置对应平台的 Client ID，用于校验 `id_token` 的 audience：

- `GOOGLE_OAUTH_CLIENT_ID`
- `APPLE_OAUTH_CLIENT_ID`

---

### POST /auth/sms/send — 发送登录验证码

向指定手机号发送一次性登录验证码，验证码有效期5分钟。

- 需要认证：否
- 标识：send_sms

#### 请求体
```json
{
  "phone": "13800138000"
}
```

#### 响应
##### HTTP 200
验证码发送成功
```json
{
  "success": true,
  "message": "验证码已发送"
}
```

##### HTTP 400
请求参数错误
```json
{
  "error": "手机号不能为空"
}
```

---

### POST /auth/login/sms — 验证码登录

使用手机号和验证码完成无密码登录，验证码需通过发送接口获取。

- 需要认证：否
- 标识：login_sms

#### 请求体
```json
{
  "phone": "13800138000",
  "code": "123456"
}
```

#### 响应
##### HTTP 200
登录成功
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "13800138000",
    "email": "user@example.com",
    "nickname": "测试用户",
    "avatar_url": null,
    "status": "active"
  }
}
```

##### HTTP 400
验证码错误或已过期
```json
{
  "error": "验证码错误或已过期"
}
```

---

### POST /auth/refresh — 刷新访问令牌

使用 refresh_token 获取新的 access_token，实现无感刷新。

- 需要认证：否
- 标识：refresh_token

#### 请求体
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

#### 响应
##### HTTP 200
刷新成功
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

##### HTTP 401
refresh_token 无效或已过期
```json
{
  "error": "Invalid or expired refresh token"
}
```

---

## 管理员认证路由

### POST /auth/admin/login — 管理员登录

管理员账号登录，返回管理员专用 Token。

- 需要认证：否
- 标识：admin_login

#### 请求体
```json
{
  "username": "admin",
  "password": "admin123"
}
```

#### 响应
##### HTTP 200
登录成功
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "admin-uuid",
    "username": "admin",
    "nickname": "系统管理员",
    "status": "active"
  }
}
```

##### HTTP 401
用户名或密码错误
```json
{
  "error": "Invalid username or password"
}
```

---

### POST /auth/admin/refresh — 管理员刷新令牌

刷新管理员访问令牌。

- 需要认证：否
- 标识：admin_refresh_token

#### 请求体
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

#### 响应
##### HTTP 200
刷新成功
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

---

## 需要认证的路由

### GET /auth/me — 获取当前用户信息

获取当前登录用户的详细信息，需要提供有效的JWT token。

- 需要认证：是
- 标识：me

#### 请求头
```
Authorization: Bearer <your-jwt-token>
```

#### 响应
##### HTTP 200
成功获取用户信息
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "testuser",
  "email": "test@example.com",
  "nickname": "测试用户",
  "avatar_url": null,
  "avatar_object_key": null,
  "status": "active"
}
```

##### HTTP 401
未授权访问
```json
{
  "error": "Unauthorized"
}
```

---

### POST /auth/password/reset — 短信重置密码

通过短信验证码重置密码。

- 需要认证：是
- 标识：reset_password_with_sms

#### 请求体
```json
{
  "phone": "13800138000",
  "code": "123456",
  "new_password": "newpassword123"
}
```

#### 响应
##### HTTP 200
密码重置成功
```json
{
  "success": true,
  "message": "密码已重置"
}
```

---

## 管理员专用路由

> 以下接口需要管理员 Token（通过 `/auth/admin/login` 获取）

### GET /auth/admin/me — 获取当前管理员信息

获取当前登录管理员的详细信息。

- 需要认证：管理员
- 标识：get_current_admin_user

#### 响应
##### HTTP 200
```json
{
  "id": "admin-uuid",
  "username": "admin",
  "nickname": "系统管理员",
  "status": "active",
  "created_at": "2024-01-01T00:00:00Z"
}
```

---

### PATCH /auth/admin/me — 更新当前管理员信息

更新当前管理员的昵称等信息。

- 需要认证：管理员
- 标识：update_current_admin_user

#### 请求体
```json
{
  "nickname": "新管理员昵称"
}
```

#### 响应
##### HTTP 200
```json
{
  "success": true,
  "message": "更新成功"
}
```

---

### POST /auth/admin/me/password — 修改管理员密码

修改当前管理员密码。

- 需要认证：管理员
- 标识：change_current_admin_password

#### 请求体
```json
{
  "old_password": "oldpass123",
  "new_password": "newpass456"
}
```

#### 响应
##### HTTP 200
```json
{
  "success": true,
  "message": "密码修改成功"
}
```

##### HTTP 400
原密码错误
```json
{
  "error": "原密码错误"
}
```

---

## Token 说明

### JWT Claims 结构
```typescript
interface Claims {
  sub: string;       // 用户ID
  username: string;  // 用户名
  is_admin: boolean; // 是否为管理员Token
  exp: number;       // 过期时间戳
  iat: number;       // 签发时间戳
}
```

### Token 有效期
- **access_token**: 短期有效（建议 15 分钟 - 1 小时）
- **refresh_token**: 长期有效（建议 7 天 - 30 天）

### 使用方式
所有需要认证的 API 请求需要在 Header 中携带 JWT Token：
```
Authorization: Bearer <your-jwt-token>
```

### Token 刷新流程
1. 客户端检测到 access_token 即将过期或已过期
2. 使用 refresh_token 调用 `/auth/refresh` 接口
3. 获取新的 access_token 和 refresh_token
4. 更新本地存储的 token
5. 使用新的 access_token 继续请求

---

**文档最后更新**: 2026-01-13
