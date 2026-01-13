# 认证与登录接口

## POST /auth/register — 用户注册

创建新的用户账户，包含用户名、邮箱和密码等信息。

- 需要认证：否
- 标识：register

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": [
    "username",
    "email",
    "password"
  ],
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

### 响应
#### HTTP 200
注册成功
示例：
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

#### HTTP 400
请求参数错误
示例：
```json
{
  "error": "Username must be at least 3 characters"
}
```

#### HTTP 409
用户名或邮箱已存在
示例：
```json
{
  "error": "Username already exists"
}
```

## POST /auth/sms/send — 发送登录验证码

向指定手机号发送一次性登录验证码，验证码有效期5分钟。

- 需要认证：否
- 标识：send_sms

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": [
    "phone"
  ],
  "properties": {
    "phone": {
      "type": "string",
      "description": "用户手机号，建议使用 E.164 格式",
      "example": "13800138000"
    }
  }
}
```
- 示例：
```json
{
  "phone": "13800138000"
}
```

### 响应
#### HTTP 200
验证码发送成功
示例：
```json
{
  "success": true,
  "message": "验证码已发送"
}
```

#### HTTP 400
请求参数错误
示例：
```json
{
  "error": "手机号不能为空"
}
```

## POST /auth/login/sms — 验证码登录

使用手机号和验证码完成无密码登录，验证码需通过发送接口获取。

- 需要认证：否
- 标识：login_sms

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": [
    "phone",
    "code"
  ],
  "properties": {
    "phone": {
      "type": "string",
      "description": "用户手机号",
      "example": "13800138000"
    },
    "code": {
      "type": "string",
      "description": "6位数字验证码",
      "example": "123456"
    }
  }
}
```
- 示例：
```json
{
  "phone": "13800138000",
  "code": "123456"
}
```

### 响应
#### HTTP 200
登录成功
示例：
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
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

#### HTTP 400
验证码错误或已过期
示例：
```json
{
  "error": "验证码错误或已过期"
}
```

## POST /auth/login — 用户登录

使用用户名和密码进行身份验证，成功后返回JWT token。

- 需要认证：否
- 标识：login

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": [
    "username",
    "password"
  ],
  "properties": {
    "username": {
      "type": "string",
      "description": "用户名",
      "example": "testuser"
    },
    "password": {
      "type": "string",
      "description": "密码",
      "example": "password123"
    }
  }
}
```
- 示例：
```json
{
  "username": "testuser",
  "password": "password123"
}
```

### 响应
#### HTTP 200
登录成功
示例：
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
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

#### HTTP 401
用户名或密码错误
示例：
```json
{
  "error": "Invalid username or password"
}
```

## GET /auth/me — 获取当前用户信息

获取当前登录用户的详细信息，需要提供有效的JWT token。

- 需要认证：是
- 标识：me

### 请求体
无

### 响应
#### HTTP 200
成功获取用户信息
示例：
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

#### HTTP 401
未授权访问
示例：
```json
{
  "error": "Unauthorized"
}
```
