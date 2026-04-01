# 错误处理文档

## 统一错误响应格式

Backend 错误响应统一返回以下协议：

```json
{
  "code": 42201,
  "message_key": "version.platform_unsupported",
  "message": "Unsupported platform: bad. Supported platforms: windows, macos, ios, android, linux.",
  "message_params": {
    "platform": "bad",
    "supported_platforms": "windows, macos, ios, android, linux"
  },
  "details": null
}
```

字段说明：

- `code`：稳定错误码，对应 `AppError` 的分类。
- `message_key`：稳定协议键，客户端应优先依赖它做分支判断。
- `message`：面向展示的本地化文案，由服务端根据 `Accept-Language` 生成。
- `message_params`：可选，占位符参数。
- `details`：可选，仅在安全场景下返回；数据库/内部错误默认隐藏细节。

## 语言协商规则

1. 优先读取请求头 `Accept-Language`。
2. 当前内建语言：`zh-CN`、`en-US`。
3. 不支持的语言回退到 `zh-CN`。
4. 若某个 `message_key` 暂无翻译，则回退返回 `message_key` 本身。

## 客户端使用约定

- **逻辑判断只看 `message_key`**，不要依赖 `message` 文案。
- `message` 仅用于展示，可随语言变化。
- 需要插值时，优先使用 `message_params`。

## 错误码范围

| 范围 | HTTP 状态码 | 类型 |
|------|-------------|------|
| 40001-40099 | 401 | 认证相关 |
| 40301-40399 | 403 | 权限相关 |
| 40401-40499 | 404 | 资源不存在 |
| 40901-40999 | 409 | 冲突相关 |
| 42201-42299 | 400 | 验证/输入相关 |
| 42901-42999 | 429 | 限流相关 |
| 50001-50099 | 422 | 业务逻辑错误 |
| 50101-50199 | 500 | 数据库错误 |
| 50201-50299 | 500 | 缓存错误 |
| 50301-50399 | 500/503 | 内部错误 / 服务不可用 |

## Handler 侧推荐写法

### 1. 直接绑定稳定 key

```rust
return Err(
    AppError::ValidationError(String::new())
        .with_message_key("feedback.content_required")
);
```

### 2. 带插值参数

```rust
return Err(
    AppError::ValidationError(String::new()).with_message_key_and_params(
        "version.platform_unsupported",
        Some(BTreeMap::from([
            ("platform".to_string(), platform.to_string()),
            ("supported_platforms".to_string(), SUPPORTED_VERSION_PLATFORMS.to_string()),
        ])),
    )
);
```

### 3. 内部错误统一遮蔽细节

```rust
let raw = serde_json::to_string(&policy).map_err(|e| {
    AppError::InternalError(String::new()).with_message_key_and_params(
        "upload_policy.serialize_failed",
        Some(BTreeMap::from([("reason".to_string(), e.to_string())])),
    )
})?;
```

## 响应示例

### 英文错误响应

```http
GET /versions/latest/download-url?platform=bad&channel=stable
Accept-Language: en-US
```

```json
{
  "code": 42201,
  "message_key": "version.platform_unsupported",
  "message": "Unsupported platform: bad. Supported platforms: windows, macos, ios, android, linux.",
  "message_params": {
    "platform": "bad",
    "supported_platforms": "windows, macos, ios, android, linux"
  },
  "details": null
}
```

### 不支持语言时回退中文

```http
POST /rooms/{id}/messages/read_until
Accept-Language: fr-FR
```

```json
{
  "code": 40301,
  "message_key": "room.membership_required",
  "message": "您不是当前房间成员",
  "message_params": null,
  "details": null
}
```

## 验证命令

```bash
cd backend && cargo test i18n --lib -- --test-threads=1
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml up -d external-mock postgres redis-session redis-cache backend
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml run --rm go-tests \
  go test ./backend/system ./backend/versions ./backend/rooms ./backend/messages -v
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml down -v --remove-orphans
```
