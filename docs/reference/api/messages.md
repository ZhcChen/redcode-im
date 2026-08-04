# 消息接口

> 消息接口受全局消息运行模式影响。默认 `persist` 模式会服务端落库；`relay_only` 模式只实时转发，不写 `messages` / `message_parts`，且不把消息快照写入离线 Push 队列。历史、搜索、已读和消息变更类能力在 `relay_only` 下会降级，详见 `docs/reference/architecture/message-runtime-modes.md`。

## POST /rooms/:room_id/messages — 发送消息

向指定房间发送消息。需要认证。消息类型由 `parts` 归一化推导；纯 `content` 会作为文本消息发送。`persist` 模式写入服务端历史，`relay_only` 模式返回运行时消息快照并通过 WebSocket 实时广播；实时广播失败时返回 HTTP 503，客户端应保持未发送/可重试状态。

- 需要认证：是
- 标识：sendMessage

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "properties": {
    "content": {
      "type": "string",
      "description": "文本消息内容；当 parts 为空时必须提供非空 content",
      "example": "大家好"
    },
    "parts": {
      "type": "array",
      "description": "消息分片。支持 type=text/image/video/audio/file；附件 key 必须来自消息附件上传签名或提交链路；relay_only 下附件 key 必须属于当前房间前缀 messages/{room_id}/",
      "items": {
        "oneOf": [
          {
            "type": "object",
            "required": ["type", "text"],
            "properties": {
              "type": { "const": "text" },
              "text": { "type": "string" }
            }
          },
          {
            "type": "object",
            "required": ["type", "key"],
            "properties": {
              "type": { "enum": ["image", "video", "audio", "file"] },
              "key": { "type": "string" },
              "name": { "type": "string" },
              "mime": { "type": "string" },
              "size": { "type": "integer" },
              "width": { "type": "integer" },
              "height": { "type": "integer" },
              "duration_ms": { "type": "integer" },
              "thumbnail_key": { "type": "string" }
            }
          }
        ]
      }
    },
    "quoted_message_id": {
      "type": "string",
      "format": "uuid",
      "description": "可选引用消息 ID；relay_only 模式下不支持引用"
    }
  }
}
```
- 示例：
```json
{
  "content": "大家好"
}
```
- 附件/多分片示例：
```json
{
  "parts": [
    {
      "type": "text",
      "text": "看这张图"
    },
    {
      "type": "image",
      "key": "messages/{room-id}/images_20261010/abcdef01.png",
      "name": "demo.png",
      "mime": "image/png",
      "size": 12345,
      "width": 800,
      "height": 600
    }
  ]
}
```

### 响应
#### HTTP 200
发送成功，返回消息对象。`relay_only` 下响应结构相同，`message` 为运行时消息快照。
示例：
```json
{
  "message": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "room_id": "11111111-2222-3333-4444-555555555555",
    "sender_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    "sender_username": "alice",
    "sender_nickname": "Alice",
    "content": "大家好",
    "message_type": "text",
    "status": "sent",
    "created_at": "2024-10-10T10:00:00Z",
    "is_deleted": false,
    "is_edited": false,
    "is_pinned": false,
    "parts": []
  }
}
```

#### HTTP 401
未授权（未携带或携带无效的 `Authorization: Bearer <token>`；鉴权中间件层返回
空响应体，不返回 JSON）

#### HTTP 403
非房间成员禁止发送
示例：
```json
{
  "code": 40301,
  "message": "User xxx is not a member of room xxx"
}
```

#### HTTP 503
`relay_only` 实时广播失败或附件授权服务不可用。
示例：
```json
{
  "code": 50302,
  "message": "relay_only 消息实时广播失败，请稍后重试"
}
```

## POST /rooms/:room_id/messages/encrypted — 发送加密消息

向指定房间发送加密消息。需要认证。`encrypted_content` 必须是 Base64 编码的 RCML v1 envelope；`encryption_metadata` 只允许非敏感路由字段。客户端不得提交 `content_summary`，服务端统一使用固定占位 `[加密消息]`。`persist` 模式写入密文历史；`relay_only` 模式只返回运行时快照并通过 WebSocket 透传密文，不写服务端历史或离线 Push 消息快照。

### 请求体
```json
{
  "encrypted_content": "UkNNTAABAQAAAApjaXBoZXJ0ZXh0",
  "encryption_metadata": {
    "protocol": "mls",
    "version": 1,
    "epoch": 1,
    "sender_device_id": "550e8400-e29b-41d4-a716-446655440000",
    "content_type": "application",
    "control_message_id": "018f5be3-3277-7d45-a6f3-bd2ebc89f321"
  },
  "quoted_message_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

- RCML v1 二进制头为 `magic(4) + version(u16 BE) + kind(u8) + payload_length(u32 BE)`；`kind` 的 `1/2/3` 分别对应 `application/commit/welcome`。
- `protocol` 当前只接受 `mls`，`version` 当前只接受 `1`，`epoch` 必须大于 `0`。
- `content_type` 必须与 RCML envelope kind 一致；payload 上限为 16 MiB，声明长度必须与实际长度一致。
- `control_message_id` 可选，用于引用使当前 application 可处理的控制消息。
- 请求体和 `encryption_metadata` 均拒绝未知字段；提交 `content_summary`、未知协议版本或任意算法参数会失败，不会降级为明文发送。
- `quoted_message_id` 可选；`relay_only` 下不支持，返回 HTTP 400 ErrorResponse，`code=42201`，`message` 包含 `relay_only`。
- `relay_only` 实时广播失败返回 HTTP 503 ErrorResponse，`code=50302`。

### 响应
成功时返回与普通发送相同的 `{"message": ...}` 结构。`message.content` 固定为 `[加密消息]`，`message.encrypted_content` 与规范化后的 `message.encryption_metadata` 按服务端消息模型返回。

## GET /rooms/:room_id/messages?limit=50 — 获取消息列表

按时间倒序获取房间最近消息。支持查询参数 `limit`(1-200，默认50)、`before_id`、`since_id`；`before_id` 与 `since_id` 互斥。需要认证。`relay_only` 模式返回 HTTP 200 空列表。

- 需要认证：是
- 标识：listMessages

### 请求体
无

### 响应
#### HTTP 200
获取成功，返回消息数组（倒序）
示例：
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "room_id": "11111111-2222-3333-4444-555555555555",
    "sender_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    "content": "大家好",
    "message_type": "text",
    "created_at": "2024-10-10T10:00:00Z",
    "updated_at": "2024-10-10T10:00:00Z"
  }
]
```

#### HTTP 401
未授权（鉴权中间件层返回空响应体）

#### HTTP 403
非房间成员禁止访问
示例：
```json
{
  "code": 40301,
  "message": "User xxx is not a member of room xxx"
}
```

## 消息附件直传与哈希去重（对象存储）

> 以下接口用于客户端通过 S3 兼容对象存储 直传消息附件（图片/视频/文件），并支持基于文件哈希的去重与 key 复用。

### 1. 获取附件直传签名

- **方法**: `POST`
- **路径**: `/rooms/:room_id/messages/attachments/signature`
- **认证**: Bearer Token

请求体：

```json
{
  "part_type": "image",
  "filename": "example.png",
  "content_type": "image/png",
  "file_size": 123456,
  "hash_value": "d41d8cd98f00b204e9800998ecf8427e",
  "hash_alg": 1
}
```

字段说明：

| 字段         | 类型     | 必填 | 说明                                      |
| ------------ | -------- | ---- | ----------------------------------------- |
| `part_type`  | string   | 是   | `text`/`image`/`video`/`audio`/`file`    |
| `filename`   | string   | 否   | 原始文件名                               |
| `content_type` | string | 否   | MIME 类型，例如 `image/png`             |
| `file_size`  | number   | 否   | 文件大小（字节）                          |
| `hash_value` | string   | 否   | 文件哈希值（十六进制字符串，例如 MD5）   |
| `hash_alg`   | number   | 否   | 哈希算法，1=md5（默认）、2=sha256        |

响应示例（需要实际上传对象存储的情况）：

```json
{
  "success": true,
  "message": "生成消息附件直传签名成功",
  "key": "messages/{room_id}/20251211120000_xxx/image_xxx.png",
  "signature": {
    "url": "http://rustfs:9000/<bucket>/messages/...",
    "method": "PUT",
    "headers": {
      "Authorization": "AWS4-HMAC-SHA256 Credential=...",
      "Content-Type": "image/png"
    },
    "key": "messages/{room_id}/20251211120000_xxx/image_xxx.png"
  }
}
```

命中哈希去重、复用已有附件的响应示例：

```json
{
  "success": true,
  "message": "复用已上传的附件，未生成新的直传签名",
  "key": "messages/{room_id}/20251104160135_xxx/image_xxx.png",
  "signature": null
}
```

- `signature != null`：前端必须按照返回的 `url/method/headers` 上传文件到对象存储；
- `signature == null`：前端无需上传对象存储，可直接使用返回的 `key` 作为附件的 `object_key` 发送消息。

### 2. 附件上传完成通知（commit）

- **方法**: `POST`
- **路径**: `/rooms/:room_id/messages/attachments/commit`
- **认证**: Bearer Token

请求体：

```json
{
  "key": "messages/{room_id}/20251211120000_xxx/image_xxx.png",
  "hash_value": "d41d8cd98f00b204e9800998ecf8427e",
  "hash_alg": 1,
  "file_size": 123456
}
```

字段说明：

| 字段         | 类型     | 必填 | 说明                                      |
| ------------ | -------- | ---- | ----------------------------------------- |
| `key`        | string   | 是   | 已上传文件的 object key，必须以 `messages/{room_id}/` 开头 |
| `hash_value` | string   | 否   | 文件哈希值（建议与签名阶段保持一致）     |
| `hash_alg`   | number   | 否   | 哈希算法，1=md5（默认）、2=sha256        |
| `file_size`  | number   | 否   | 文件大小（字节）                          |

成功响应：

```json
{
  "success": true,
  "message": "附件上传完成"
}
```

说明：

- commit 接口用于将 `file_upload_records` 中的记录标记为 `status=1`（上传完成），使得同一哈希的文件在后续可以被复用；
- 若签名阶段未提供 `hash_value/file_size`，记录可能不存在，此时 commit 仍会返回成功，但该文件无法参与哈希去重。

### 3. 获取附件下载链接

- **方法**: `GET`
- **路径**: `/rooms/:room_id/messages/attachments/download`
- **认证**: Bearer Token
- **查询参数**: `key` 必填，`expires_in_seconds` 可选（默认 600 秒，持久化引用路径最大 86400 秒）

说明：

- `persist`：优先校验 `key` 必须已被当前房间的持久化消息分片引用（附件或缩略图），否则 fallback 检查未过期 relay-only 临时授权；两者均不存在返回 404，Redis 授权服务不可用返回 503。
- `relay_only`：校验发送时写入的 Redis TTL 临时授权；授权缺失/过期返回 404，Redis 授权服务不可用返回 503。
- `relay_only` 下附件 key 必须属于当前房间前缀 `messages/{room_id}/`，且发送前必须已经完成附件上传提交；跨房间或未提交的 object key 不会生成下载授权。
- 通过 relay-only 临时授权生成下载 URL 时，实际 `expires_in_seconds` 不会超过 Redis grant 剩余 TTL；切回 `persist` 后，TTL 内的 relay-only 附件仍可下载。

---

## 消息收藏（API 2.0）

收藏消息供本人快速回顾。收藏数据仅收藏者本人可见，服务端生效；重复收藏幂等。

- 版本：API 2.0.0
- 认证：以下接口均需要 `Authorization: Bearer <token>`

### 1. 收藏消息

- **方法**：`POST`
- **路径**：`/rooms/:room_id/messages/:message_id/favorite`
- **认证**：Bearer Token

响应：

```json
{ "success": true }
```

- 幂等：重复收藏返回成功。
- 非房间成员返回 `403`；消息不存在返回 `404`；消息不属于该房间返回
  HTTP 400（code 42201）。

### 2. 取消收藏

- **方法**：`DELETE`
- **路径**：`/rooms/:room_id/messages/:message_id/favorite`
- **认证**：Bearer Token

响应：

```json
{ "success": true }
```

- 未收藏该消息时返回 `404`。

### 3. 收藏列表

- **方法**：`GET`
- **路径**：`/messages/favorites`
- **认证**：Bearer Token

查询参数：

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `limit` | int | 50 | 每页数量，服务端限制 1-100 |
| `offset` | int | 0 | 偏移量 |

响应（按收藏时间倒序）：

```json
{
  "items": [
    {
      "messageId": "550e8400-e29b-41d4-a716-446655440000",
      "roomId": "550e8400-e29b-41d4-a716-446655440001",
      "senderId": "550e8400-e29b-41d4-a716-446655440002",
      "content": "重要通知",
      "messageType": "text",
      "messageCreatedAt": "2026-08-04T09:00:00Z",
      "favoritedAt": "2026-08-04T10:00:00Z"
    }
  ],
  "total": 1
}
```

- 只返回收藏者本人的收藏；不同用户之间的收藏数据相互隔离。
