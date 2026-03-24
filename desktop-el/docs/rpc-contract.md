# desktop-el stdio RPC 契约

本文档定义 `Renderer -> Preload -> Electron Main -> Go core` 的最小 RPC 协议约束。协议消息仅允许通过 Go 子进程 `stdin/stdout` 传输，编码格式为 **NDJSON**（每条 JSON 消息独立一行，以 `\n` 结尾）。

## 1. 消息类型

所有消息都必须包含 `type` 字段，取值仅允许：

- `request`
- `response`
- `event`

### 1.1 Request

```json
{
  "type": "request",
  "id": "req-123",
  "method": "core.ping",
  "params": { "any": "json" },
  "timeout_ms": 3000
}
```

- `id`: 必填，字符串；用于和 `response.id` 一一对应。
- `method`: 必填，字符串；格式见事件/方法命名规范。
- `params`: 可选，任意 JSON。
- `timeout_ms`: 可选，正整数（毫秒）；由服务端用于创建 request scope 超时上下文。

### 1.2 Response

```json
{
  "type": "response",
  "id": "req-123",
  "result": { "any": "json" },
  "error": { "code": "timeout", "message": "request timeout" }
}
```

- `id`: 必填，必须等于对应 request 的 `id`。
- `result` 与 `error` 二选一：
  - 成功时：`result` 存在，`error` 为空。
  - 失败时：`error` 存在，`result` 可省略。

### 1.3 Event

```json
{
  "type": "event",
  "event": "core.status.updated",
  "data": { "online": true }
}
```

- `event`: 必填，事件名。
- `data`: 可选，任意 JSON。

## 2. 错误码

协议层错误码如下（Go 与 Electron TypeScript 必须保持一致）：

- `parse_error`: 无法解析 JSON（例如非法 JSON）。
- `invalid_request`: 消息结构非法或缺失关键字段。
- `method_not_found`: 未注册 method。
- `invalid_params`: 参数格式不符合 method 约束。
- `internal`: 未分类内部错误。
- `timeout`: request 超时（包括 `timeout_ms` 触发）。
- `canceled`: request 被取消（上游 context cancel / Abort）。

错误对象格式：

```json
{
  "code": "timeout",
  "message": "request timeout"
}
```

## 3. 命名规范

- method/event 均采用 `domain.action[.detail]` 风格，全部小写，使用 `.` 分段。
- 推荐域名前缀：
  - `core.*`：核心状态与能力
  - `auth.*`：鉴权相关
  - `chat.*`：会话/消息相关
- 示例：
  - method: `core.ping`
  - event: `core.status.updated`

## 4. 超时与取消语义

- 调用方可在 `request.timeout_ms` 指定单次调用超时。
- 服务端对每个 request 创建独立上下文：
  - 若调用方取消：返回 `canceled`。
  - 若到达 deadline：返回 `timeout`。
- handler 必须感知 `ctx.Done()` 并尽快退出，避免僵尸任务。
- Renderer 若通过 `AbortSignal` 取消调用，Electron Main 必须在本地桥接层转发同一 `request.id` 的取消信号，并映射为 Go request context 的 cancel。
- 上述取消控制仅存在于 Electron 内部 IPC，不新增任何 HTTP/WebSocket 本地服务端口，也不扩展 `stdio` 协议消息类型。

## 5. 传输与日志边界

- 协议消息：**仅允许**出现在 `stdin/stdout` NDJSON 流中。
- `stderr`: **仅用于日志**（诊断、调试、告警），禁止输出协议消息。
- Electron Main 读取 `stderr` 时只做日志记录，不进行协议反序列化。

## 6. 当前已落地的业务 RPC

### 6.1 `chat.send`

用途：发送文本消息，或发送由 renderer 先完成上传后再提交的附件消息。`desktop-el` 当前最小闭环已经支持纯文本消息与单附件消息。

请求参数：

```json
{
  "room_id": "room-2",
  "content": "",
  "parts": [
    {
      "type": "image",
      "key": "messages/room-2/demo.png",
      "name": "demo.png",
      "mime": "image/png",
      "size": 2048,
      "width": 1280,
      "height": 720
    }
  ],
  "quoted_message_id": "msg-100"
}
```

- `room_id`: 必填，房间 ID。
- `content`: 可选，纯文本消息内容。
- `parts`: 可选，消息分片数组；当前 renderer 已使用它发送附件消息。
- `quoted_message_id`: 可选，引用消息 ID。

`parts` 约束：

- `parts[*].type` 允许：`text`、`image`、`audio`、`video`、`file`。
- `text` part 使用 `text` 字段。
- 附件 part 使用 `key`，并可选带上 `name`、`mime`、`size`、`width`、`height`、`duration_ms`、`thumbnail_key`。
- 调用方至少要提供 `content` 或 `parts` 之一。

成功返回：

```json
{
  "code": 200,
  "success": true,
  "message": "消息发送成功",
  "data": {
    "id": "msg-101",
    "room_id": "room-2",
    "sender_id": "user-1",
    "sender_username": "alice",
    "content": "",
    "message_type": "image",
    "created_at": "2026-03-24T09:30:00Z",
    "parts": [
      {
        "position": 0,
        "part_type": "image",
        "attachment": {
          "key": "messages/room-2/demo.png",
          "name": "demo.png",
          "mime": "image/png",
          "size": 2048,
          "width": 1280,
          "height": 720
        }
      }
    ]
  }
}
```

约束：

- 附件消息必须先走上传相关 RPC 拿到 `key`，必要时完成 direct upload / multipart upload 与 `chat.attachment.upload.commit`，最后再调用 `chat.send(parts)`。
- 文件字节不通过 stdio 传输，不经 Electron main / Go core 中转。

### 6.2 `chat.attachment.download_url`

用途：为当前房间内已存在于消息中的附件生成临时下载链接，供 renderer 后续用于图片 / 视频 / 音频预览，或通过 Electron 宿主能力保存到本地。

请求参数：

```json
{
  "room_id": "room-2",
  "key": "messages/room-2/demo.pdf",
  "expires_in_seconds": 900
}
```

- `room_id`: 必填，房间 ID。
- `key`: 必填，消息附件 object key。
- `expires_in_seconds`: 可选，临时下载 URL 有效期（秒）。

成功返回：

```json
{
  "code": 200,
  "success": true,
  "message": "生成附件下载链接成功",
  "data": {
    "success": true,
    "message": "生成附件下载链接成功",
    "download_url": "https://example.com/signed-download-url"
  }
}
```

约束：

- renderer 不直接请求 backend 附件下载接口，必须经由 Go core 调用。
- `data.download_url` 来自 backend 原始成功对象；Go core 仅负责桥接与 envelope 统一，不在本地开启 HTTP 服务。
- renderer 既可把该 URL 绑定到 `img` / `video` / `audio` 进行内联预览，也可交给 Electron 壳层保存到本地。

### 6.3 `chat.attachment.signature`

用途：为 direct upload 场景申请对象 key 与 signed URL。

请求参数：

```json
{
  "room_id": "room-2",
  "part_type": "image",
  "filename": "demo.png",
  "content_type": "image/png",
  "file_size": 2048,
  "hash_value": "sha256-hex",
  "hash_alg": 2
}
```

- `room_id`: 必填，房间 ID。
- `part_type`: 必填，`image` / `audio` / `video` / `file`。
- `filename`、`content_type`、`file_size`: 用于 backend 生成上传签名与落库元数据。
- `hash_value`、`hash_alg`: 可选，用于对象复用 / 去重；当前 renderer 默认使用 `SHA-256`，`hash_alg = 2`。

成功返回：

```json
{
  "code": 200,
  "success": true,
  "message": "获取附件上传签名成功",
  "data": {
    "success": true,
    "message": "获取附件上传签名成功",
    "key": "messages/room-2/demo.png",
    "signature": {
      "url": "https://example.com/signed-upload-url",
      "method": "PUT",
      "headers": {
        "Authorization": "signed-token"
      },
      "key": "messages/room-2/demo.png"
    }
  }
}
```

约束：

- `data.signature` 可能为空，表示 backend 命中可复用对象；renderer 直接复用 `key` 发送消息，不再上传文件字节，也不再调用 `chat.attachment.upload.commit`。
- direct upload 由 renderer 直接请求 object storage signed URL。

### 6.4 `chat.attachment.multipart.initiate`

用途：初始化 multipart upload，会返回对象 key 和分片上传会话。

请求参数与 `chat.attachment.signature` 基本一致，但 `file_size` 为必填。

成功返回：

```json
{
  "code": 200,
  "success": true,
  "message": "初始化分片上传成功",
  "data": {
    "success": true,
    "message": "初始化分片上传成功",
    "key": "messages/room-2/demo.zip",
    "session_id": "upload-session-1",
    "part_size": 5242880,
    "total_parts": 3
  }
}
```

约束：

- `session_id` 为空表示 backend 已命中可复用对象，renderer 直接复用 `key`。
- renderer 负责按 `part_size` 切片并逐片直传，不通过 stdio 传大文件。

### 6.5 `chat.attachment.multipart.part_signature`

用途：为 multipart upload 的单个分片申请 signed URL。

请求参数：

```json
{
  "session_id": "upload-session-1",
  "part_number": 1
}
```

成功返回：

```json
{
  "code": 200,
  "success": true,
  "message": "获取分片上传签名成功",
  "data": {
    "success": true,
    "message": "获取分片上传签名成功",
    "signature": {
      "url": "https://example.com/signed-part-url",
      "method": "PUT",
      "headers": {
        "Authorization": "signed-token"
      }
    }
  }
}
```

### 6.6 `chat.attachment.multipart.part_commit`

用途：在某个分片上传完成后，把该片的 `etag` 回写给 backend。

请求参数：

```json
{
  "session_id": "upload-session-1",
  "part_number": 1,
  "etag": "etag-1"
}
```

成功返回：

```json
{
  "code": 200,
  "success": true,
  "message": "分片提交成功",
  "data": {
    "success": true,
    "message": "分片提交成功"
  }
}
```

### 6.7 `chat.attachment.multipart.complete`

用途：所有分片上传完成后，通知 backend 完成 multipart upload。

请求参数：

```json
{
  "session_id": "upload-session-1",
  "parts": [
    {
      "part_number": 1,
      "etag": "etag-1"
    },
    {
      "part_number": 2,
      "etag": "etag-2"
    }
  ]
}
```

成功返回：与 `chat.attachment.multipart.part_commit` 相同的简单成功 envelope。

### 6.8 `chat.attachment.multipart.abort`

用途：multipart upload 过程中某片失败时，中止上传会话。

请求参数：

```json
{
  "session_id": "upload-session-1"
}
```

成功返回：与 `chat.attachment.multipart.part_commit` 相同的简单成功 envelope。

### 6.9 `chat.attachment.upload.commit`

用途：当 renderer 已完成 direct upload / multipart upload 后，通知 backend 将该对象标记为已完成上传，以便进入后续消息发送与哈希去重链路。

请求参数：

```json
{
  "room_id": "room-2",
  "key": "messages/room-2/demo.png",
  "file_size": 2048,
  "hash_value": "sha256-hex",
  "hash_alg": 2
}
```

成功返回：

```json
{
  "code": 200,
  "success": true,
  "message": "附件上传确认成功",
  "data": {
    "success": true,
    "message": "附件上传确认成功"
  }
}
```

约束：

- 只有在 renderer 实际上传了文件字节时才调用本 RPC。
- 若附件对象直接被 backend 复用（无 `signature` / 无 `session_id`），renderer 直接使用 `key` 发送消息即可。
