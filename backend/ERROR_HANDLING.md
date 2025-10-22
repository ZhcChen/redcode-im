# 错误处理文档

## 统一错误响应格式

所有 API 错误响应都遵循以下格式：

```json
{
  "code": 40001,
  "message": "Unauthorized: Invalid token",
  "details": "Token validation failed"  // 可选字段
}
```

## 错误码体系

### 认证相关错误 (40001-40099)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 40001 | 401 | 未授权 (Unauthorized) |
| 40002 | 401 | 无效的 Token (InvalidToken) |
| 40003 | 401 | Token 已过期 (TokenExpired) |
| 40004 | 401 | 无效的用户名或密码 (InvalidCredentials) |

### 权限相关错误 (40301-40399)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 40301 | 403 | 禁止访问 (Forbidden) |
| 40302 | 403 | 权限不足 (InsufficientPermission) |

### 资源相关错误 (40401-40499)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 40401 | 404 | 资源不存在 (NotFound) |

### 验证相关错误 (42201-42299)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 42201 | 400 | 验证失败 (ValidationError) |
| 42202 | 400 | 无效的输入 (InvalidInput) |

### 冲突相关错误 (40901-40999)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 40901 | 409 | 资源已存在 (AlreadyExists) |

### 限流相关错误 (42901-42999)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 42901 | 429 | 超过速率限制 (RateLimitExceeded) |
| 42902 | 429 | 请求过于频繁 (TooManyRequests) |

### 业务逻辑错误 (50001-50099)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 50001 | 422 | 业务逻辑错误 (BusinessError) |

### 数据库错误 (50101-50199)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 50101 | 500 | 数据库错误 (DatabaseError) |

### 缓存错误 (50201-50299)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 50201 | 500 | 缓存错误 (CacheError) |

### 系统错误 (50301-50399)

| 错误码 | HTTP 状态码 | 说明 |
|-------|-----------|------|
| 50301 | 500 | 内部错误 (InternalError) |
| 50302 | 503 | 服务不可用 (ServiceUnavailable) |

## 使用示例

### 在 Handler 中使用

```rust
use crate::error::AppError;

pub async fn register(
    State(state): State<AppState>,
    Json(payload): Json<CreateUserRequest>,
) -> Result<Json<UserInfo>, AppError> {
    // 验证错误
    if payload.username.len() < 3 {
        return Err(AppError::ValidationError(
            "Username must be at least 3 characters".to_string()
        ));
    }

    // 资源已存在错误
    if store.username_exists(&payload.username).await? {
        return Err(AppError::AlreadyExists(
            format!("Username '{}' already exists", payload.username)
        ));
    }

    // 数据库错误会自动转换
    let user = store.create_user(payload).await?;

    Ok(Json(user))
}
```

### 使用宏快速创建错误

```rust
use crate::app_error;

// 未授权
return Err(app_error!(unauthorized, "Invalid credentials"));

// 资源不存在
return Err(app_error!(not_found, "User not found"));

// 验证错误
return Err(app_error!(validation, "Invalid email format"));

// 权限不足
return Err(app_error!(forbidden, "Access denied"));

// 资源冲突
return Err(app_error!(conflict, "Username already exists"));

// 限流
return Err(app_error!(rate_limit, "Too many requests"));

// 业务错误
return Err(app_error!(business, "Cannot delete own account"));

// 内部错误
return Err(app_error!(internal, "Unexpected error occurred"));
```

## 错误响应示例

### 验证错误示例

**请求:**
```bash
POST /auth/register
Content-Type: application/json

{
  "username": "ab",
  "email": "test@example.com",
  "password": "123456"
}
```

**响应:**
```json
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "code": 42201,
  "message": "Username must be at least 3 characters",
  "details": "Validation error: Username must be at least 3 characters"
}
```

### 认证错误示例

**请求:**
```bash
POST /auth/login
Content-Type: application/json

{
  "username": "testuser",
  "password": "wrongpassword"
}
```

**响应:**
```json
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{
  "code": 40004,
  "message": "Invalid username or password"
}
```

### 限流错误示例

**请求:**
```bash
POST /rooms/{room_id}/messages
Authorization: Bearer {token}
Content-Type: application/json

{
  "content": "Hello"
}
```

**响应:**
```json
HTTP/1.1 429 Too Many Requests
Content-Type: application/json

{
  "code": 42901,
  "message": "Message rate limit exceeded: max 30 messages per 10 seconds",
  "details": "Rate limit exceeded: Message rate limit exceeded: max 30 messages per 10 seconds"
}
```

## 测试

运行错误处理测试脚本：

```bash
# 确保后端服务正在运行
cargo run

# 在另一个终端运行测试
./test_error_handling.sh
```

## 注意事项

1. **敏感信息保护**: 数据库错误和内部错误不会暴露详细信息给客户端
2. **一致性**: 所有错误都通过 `AppError` 返回，确保格式统一
3. **日志记录**: 所有错误都会自动记录到日志中
4. **自动转换**: `sqlx::Error` 和 `redis::RedisError` 会自动转换为 `AppError`
5. **HTTP 状态码**: 错误码和 HTTP 状态码是映射关系，客户端可以同时使用两者
