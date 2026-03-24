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

### 6.1 `chat.attachment.download_url`

用途：为当前房间内已存在于消息中的附件生成临时下载链接，供 renderer 后续通过 Electron 宿主能力保存到本地。

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
