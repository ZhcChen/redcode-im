# 消息接口

## POST /rooms/:room_id/messages — 发送消息

向指定房间发送消息。需要认证。可选 message_type: text/image/file/system（默认 text）。

- 需要认证：是
- 标识：sendMessage

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": [
    "content"
  ],
  "properties": {
    "content": {
      "type": "string",
      "description": "消息内容",
      "example": "大家好"
    },
    "message_type": {
      "type": "string",
      "description": "消息类型，可选 text/image/file/system",
      "example": "text"
    }
  }
}
```
- 示例：
```json
{
  "content": "大家好",
  "message_type": "text"
}
```

### 响应
#### HTTP 200
发送成功，返回消息对象
示例：
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "room_id": "11111111-2222-3333-4444-555555555555",
  "sender_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "content": "大家好",
  "message_type": "text",
  "created_at": "2024-10-10T10:00:00Z",
  "updated_at": "2024-10-10T10:00:00Z"
}
```

#### HTTP 401
未授权
示例：
```json
{
  "error": "Unauthorized"
}
```

#### HTTP 403
非房间成员禁止发送
示例：
```json
{
  "error": "Not a room member"
}
```

## GET /rooms/:room_id/messages?limit=50 — 获取消息列表

按时间倒序获取房间最近消息。支持查询参数 limit(1-200)，默认50。需要认证。

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
未授权
示例：
```json
{
  "error": "Unauthorized"
}
```

#### HTTP 403
非房间成员禁止访问
示例：
```json
{
  "error": "Not a room member"
}
```

## 消息附件直传与哈希去重（COS）

> 以下接口用于客户端通过腾讯云 COS 直传消息附件（图片/视频/文件），并支持基于文件哈希的去重与 key 复用。

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

响应示例（需要实际上传 COS 的情况）：

```json
{
  "success": true,
  "message": "生成消息附件直传签名成功",
  "key": "messages/{room_id}/20251211120000_xxx/image_xxx.png",
  "signature": {
    "url": "https://<bucket>.cos.<region>.myqcloud.com/messages/...",
    "method": "PUT",
    "headers": {
      "Authorization": "q-sign-algorithm=...",
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

- `signature != null`：前端必须按照返回的 `url/method/headers` 上传文件到 COS；
- `signature == null`：前端无需上传 COS，可直接使用返回的 `key` 作为附件的 `object_key` 发送消息。

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
