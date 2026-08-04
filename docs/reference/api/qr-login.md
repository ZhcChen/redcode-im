# 扫码登录接口

PC 端显示二维码，手机端已登录用户扫码确认，PC 端实时登录，无需输入密码。

- 版本：API 2.0.0
- 二维码会话有效期：5 分钟
- 实时通道：WebSocket `qr_subscribe`（事件编号 24，见 `websocket.md`）；
  REST 轮询作为兜底

## 完整流程

```text
PC 端                       服务端                       手机端
  |  POST /auth/qr/sessions   |                            |
  |-------------------------->|                            |
  |  { qrId, expiresAt }      |                            |
  |<--------------------------|                            |
  |  WS qr_subscribe(qrId)    |                            |
  |-------------------------->|                            |
  |                           |  POST .../confirm(登录态)   |
  |                           |<---------------------------|
  |  WS qr_status_changed     |                            |
  |  {confirmed, loginCode}  |                            |
  |<--------------------------|                            |
  |  POST /auth/refresh       |                            |
  |  {refresh_token:loginCode}|                            |
  |-------------------------->|                            |
  |  { token }                |                            |
  |<--------------------------|                            |
```

## 1. 创建扫码会话（PC 端，匿名）

- **方法**：`POST`
- **路径**：`/auth/qr/sessions`
- **认证**：否

响应：

```json
{
  "qrId": "550e8400-e29b-41d4-a716-446655440000",
  "expiresAt": "2026-08-04T10:05:00Z"
}
```

客户端将 `qrId` 渲染为二维码内容并展示，同时建立 WebSocket 订阅结果。

## 2. 轮询会话状态（PC 端，匿名）

- **方法**：`GET`
- **路径**：`/auth/qr/sessions/{qr_id}`
- **认证**：否

响应：

```json
{ "status": "pending" }
```

状态取值：

| status | 说明 |
|---|---|
| `pending` | 等待手机端确认 |
| `confirmed` | 已确认，响应带一次性 `loginCode` |
| `cancelled` | 已被取消 |
| `expired` | 已过期或 `loginCode` 已被消费 |

确认后的响应（**一次性**，再次轮询返回 `expired`）：

```json
{
  "status": "confirmed",
  "loginCode": "<refresh-token>"
}
```

## 3. 手机端确认（需登录）

- **方法**：`POST`
- **路径**：`/auth/qr/sessions/{qr_id}/confirm`
- **认证**：是（手机端已登录 token）

请求体（可选）：

```json
{
  "device_name": "PC Browser",
  "platform": "macos"
}
```

响应：

```json
{ "success": true }
```

- 会话非 `pending` 或已过期时返回 `50001 BusinessError`（客户端应提示刷新二维码）。
- 确认成功后，PC 端 WS 收到 `qr_status_changed`：

```json
{
  "type": "qr_status_changed",
  "qr_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "confirmed",
  "login_code": "<refresh-token>"
}
```

## 4. PC 端取消（匿名）

- **方法**：`POST`
- **路径**：`/auth/qr/sessions/{qr_id}/cancel`
- **认证**：否

响应：

```json
{ "success": true }
```

取消后 PC 端 WS 收到 `qr_status_changed`（`status=cancelled`）。会话已处理后
无法再取消（`50001`）。

## 5. 用 loginCode 换取访问令牌

`loginCode` 本质是一次性 refresh token，PC 端调用标准刷新接口完成登录：

```http
POST /auth/refresh
Content-Type: application/json

{ "refresh_token": "<loginCode>" }
```

成功后返回 `{ token, user, ... }`，PC 端即完成登录；`loginCode` 只能使用一次。
