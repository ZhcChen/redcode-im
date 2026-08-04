# API 2.0 对外开放接口合同核对记录

## 标题信息

- 主题：`docs/reference/api/` 2.0 对外开放接口合同与实际代码一致性核对
- 关联计划：`docs/plans/2026-08-04-004-docs-api-2-0-open-contract-plan.md`
- 审查范围：5 个新增文档、8 个更新文档，以及 6 组 2.0 新接口
  （个性签名、黑名单、群公告、消息收藏、登录设备、扫码登录）对应的
  `api/src/routes.rs`、`api/src/handlers/*`、`api/src/websocket/`、
  `api/proto/ws.proto`、`api/src/models/`
- 负责人：Codex
- 日期：2026-08-04

## 核对方法

- 文档关键词覆盖：`users/blocked`、`announcement`、`favorite`、
  `auth/devices`、`auth/qr`、`signature`、`qr_subscribe`、
  `qr_status_changed`、`group_announcement_updated`
- 逐接口对照 handler 的方法/路径/认证/请求/响应/错误路径
- WS 事件号与 `ws.proto`、`websocket/protocol.rs` 对照
- 数据模型与 `api/src/models/` 对照
- 全部相对链接有效性检查（35 个）

## 确认与代码一致的部分

- 6 组新接口路由/方法/认证与 `routes.rs`、handler 一致
- 黑名单幂等、自拉黑校验、双向阻断（私聊创建/发消息/好友申请）有实现
- 群公告权限与 WS 事件 23 推送（含删除 `content: null`）一致
- 消息收藏幂等、本人可见、分页一致
- 扫码会话 TTL 5 分钟、四状态、一次性 `loginCode`、50001、事件 24 一致
- `ws.proto`：`qr_subscribe = 6`、服务端事件 23/24、字段编号 1-4/1-3 一致
- `UserInfo.signature`、`LoginResponse.deviceId`、6 个新模型字段一致
- access token 24h、refresh token 30 天滑动续期、错误码体系一致

## 发现的问题与修复

### 已修复（文档与代码对齐）

1. 验证类错误状态码：文档多处写 `422`，实际为 HTTP 400 + code 42201，
   已统一（`user-block.md` / `group-announcement.md` / `messages.md` /
   `developer-guide.md` 错误表）。
2. 黑名单拦截端点：文档写 `POST /rooms`（private），实际该端点拒绝
   private 类型，真正 403 的是 `POST /friends/{friend_user_id}/chat`，已更正。
3. `websocket.md` / `api-reference.md`：事件统计 5/22 → 6/24；
   协议路径 `api/src/proto/ws.proto` → `api/proto/ws.proto`；
   最后更新日期、版本基线统一到 2026-08-04 / 2.0.0。
4. `qr-login.md`：`qr_subscribe` 事件编号表述更正为客户端事件 6，
   服务端结果事件 24 为 `qr_status_changed`。
5. 注册/刷新设备字段：注册请求中的设备字段不生效、刷新请求只接受
   `refresh_token`，文档已按实现修正；JWT Claims 补充 `device_id`。
6. REST 错误示例统一为 `{code, message, details}`，并注明鉴权中间件
   失败（401/403）返回空响应体（`auth.md` / `messages.md` / `friends.md` /
   `chats.md`）。

### 已修复（实现补齐，commit `12ccbbdc`）

设备撤销行为：文档承诺“撤销后断开 WebSocket 会话”，此前仅清理 refresh
token。现 `revoke_device` 会按 user+device 触发对应连接退出，先推送
`{"type":"error","message":"设备已被撤销，连接即将关闭"}` 再关闭连接；
新增 `disconnect_device` 单元测试。

### 已修复（实现补齐，commit `cdd9160f`）

全局 IP 限流：`middleware/security.rs` 的 `rate_limit_middleware` 此前已
编写但未挂载。现默认启用（60 秒窗口 / 6000 次，`RATE_LIMIT_*` env 可配），
跳过 `/healthz` `/readyz` `/metrics` `/favicon.ico`，429 返回统一
`ErrorResponse` JSON；新增限流单元测试。

### 可接受的残留项（设计决策）

- 已撤销设备的 access token 为无状态 JWT，未做黑名单，TTL（24h）内仍有效；
  文档已如实声明，建议客户端收到撤销提示后清理本地登录态。
- 注册接口携带的 `device_id` / `device_name` / `platform` 不登记设备，
  设备在首次登录/短信登录时登记；文档已注明。
- `friends.md` / `chats.md` 等 1.0 遗留文档的错误示例已统一，但部分
  接口细节仍为旧版描述，后续可按需继续对齐。

## 验证结果

- `make api.test`：全部通过（单元 + 集成，含 websocket_integration 10 项）
- 新增单测：`disconnect_device`、限流计数、429 JSON、跳过 healthz 均通过
- `git diff --check`：通过
- 文档相对链接检查：35 个链接无断链
- 关键词检索：9 个合同关键词均可命中
