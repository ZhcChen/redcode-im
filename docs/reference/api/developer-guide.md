# RedCode IM API 第三方接入指南

> 面向希望实现自有 IM 客户端（App / Web / 桌面 / 机器人）的开发者、爱好者与
> 业务方。所有客户端连接**同一套服务端数据**：账号、好友、群组、消息、收藏与
> 设备均共通。

- 文档版本：API 2.0.0
- 协议：REST（JSON）+ WebSocket（JSON / Protocol Buffers）
- 接口权威来源：`docs/reference/api/api-reference.md` 与 `api/src/routes.rs`

## 1. 基础信息

| 环境 | HTTP | WebSocket |
|---|---|---|
| 本地开发 | `http://localhost:8010` | `ws://localhost:8010/ws` |
| 已部署实例 | 由部署方提供（HTTPS） | `wss://<host>/ws` |

请求体统一使用 `Content-Type: application/json`；除公开接口外，请求头携带：

```
Authorization: Bearer <access_token>
```

## 2. 认证与 Token 生命周期

### 2.1 注册与登录

1. `POST /auth/register` 创建账号（`username` + `password` 必填，`nickname`
   可选；邮箱登录兼容链路默认关闭）。
2. `POST /auth/login` 登录，响应包含：

```json
{
  "token": "<access_token>",
  "refresh_token": "<refresh_token>",
  "deviceId": "可选",
  "user": { "id": "...", "username": "..." }
}
```

- `access_token`（JWT）：有效期 24 小时，用于请求认证。
- `refresh_token`：有效期 30 天（滑动续期），用于无感刷新；**只应保存在
  安全存储中，不应暴露给其他客户端**。

### 2.2 刷新

```http
POST /auth/refresh
Content-Type: application/json

{ "refresh_token": "<refresh_token>" }
```

返回新的 `token`，并在服务端续期 refresh_token。

### 2.3 设备标识（推荐）

登录/注册/短信登录请求体可携带 `device_id`、`device_name`、`platform`，用于
「登录设备管理」：

```json
{
  "username": "alice",
  "password": "pass123456",
  "device_id": "11111111-1111-1111-1111-111111111111",
  "device_name": "Alice iPhone",
  "platform": "ios"
}
```

- `device_id`：客户端自行生成的稳定 UUID；同一账号多端互不影响。
- 不传时服务端自动生成，设备管理列表仍会登记一条记录。
- 管理接口见 `auth-devices.md`：列出设备、撤销设备（撤销后该设备
  access/refresh 全部失效，并断开其 WS 会话）。

### 2.4 扫码登录（PC 端）

PC 创建二维码会话 → 手机端已登录用户确认 → PC 端通过 WebSocket `qr_subscribe`
实时收到结果（REST 轮询兜底）。完整流程见 `qr-login.md`。

## 3. 最小端到端闭环

以下流程覆盖「注册 → 登录 → 创建群聊 → 发消息 → WS 实时接收」：

```bash
# 1. 注册
curl -X POST http://localhost:8010/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"dev_alice","password":"pass123456","nickname":"Alice"}'

# 2. 登录（保存 token / refresh_token / user.id）
curl -X POST http://localhost:8010/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"dev_alice","password":"pass123456","device_name":"macOS","platform":"macos"}'

# 3. 创建群聊
curl -X POST http://localhost:8010/rooms \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Dev Room","room_type":"group","member_ids":[]}'

# 4. 发消息
curl -X POST http://localhost:8010/rooms/$ROOM_ID/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"content":"hello im 2.0"}'

# 5. WebSocket 实时接收（见 websocket.md）
# ws://localhost:8010/ws?token=$TOKEN&format=json
```

## 4. 请求、响应与错误约定

- **成功响应**不强制统一 envelope：有的接口返回业务对象，有的返回
  `{success,message}`。请以 **HTTP 状态码**为第一判断依据，再按接口文档解析。
- **错误响应**统一结构：

```json
{
  "code": 42201,
  "message": "错误信息",
  "details": "可选的详细信息"
}
```

> 例外：路由鉴权失败（未携带/无效 Bearer token 导致 401、非管理员访问导致
> 403）由中间件直接返回状态码，响应体为空，不返回上述 JSON。

| HTTP | code 段 | 含义 |
|---|---|---|
| 401 | 40001-40004 | 未认证 / 无效 token / 过期 / 凭据错误 |
| 403 | 40301-40302 | 无权限（如非群成员、被拉黑） |
| 404 | 40401 | 资源不存在 |
| 409 | 40901-40902 | 冲突（如重复操作） |
| 400 | 42201-42202 | 参数验证失败（HTTP 400，错误码沿用 422 段） |
| 429 | 42901-42902 | 限流 |
| 500/503 | 50101-50302 | 服务端错误 / 服务不可用 |

## 5. 限流

- 服务端按来源 IP 对请求限流，`/healthz`、`/metrics`、`/favicon.ico` 除外。
- 触发时返回 `429 Too Many Requests`；建议客户端做指数退避重试。
- 具体阈值与窗口由部署方配置，公开实例请以部署方公布为准。

## 6. WebSocket 实时通道

- 入口：`/ws?token=<access_token>&format=json|proto`
- 连接后发送 `auth` 事件完成绑定；可订阅房间实时消息、群公告更新、扫码登录
  结果等事件。
- 事件清单与字段见 `websocket.md`。

## 7. 数据共通与开放边界

- 所有客户端共享同一套账号、好友、群组、消息、收藏与设备数据。
- 消息正文默认由服务端存储；需要端到端加密的消息走加密专用通道
  （见 `e2ee.md`）。
- 黑名单、群公告、消息收藏均为服务端生效的公共能力，任何客户端实现都会
  保持一致语义。

## 8. 版本兼容性承诺

- 当前 API 版本：**2.0.0**，与客户端 2.0 版本面一致。
- 2.0.x 内只做 additive 变更（新增接口/字段），不破坏既有请求语义；客户端
  应容忍响应中出现未知字段。
- 破坏性变更（改路径、改必填项、删除字段）进入下一个大版本，并会提前在
  版本管理文档（`version-management.md`）公告。

## 9. 文档导航

- [README](./README.md)：文档索引
- [认证与登录](./auth.md)、[登录设备管理](./auth-devices.md)、
  [扫码登录](./qr-login.md)
- [用户资料](./user-profile.md)、[黑名单](./user-block.md)
- [好友](./friends.md)、[会话/房间](./chats.md)、[群公告](./group-announcement.md)
- [消息](./messages.md)、[WebSocket](./websocket.md)
- [数据模型](./models.md)、[全量接口清单](./api-reference.md)
