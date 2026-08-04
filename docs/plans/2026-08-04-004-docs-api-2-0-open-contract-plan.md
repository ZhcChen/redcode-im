---
title: "docs: API 2.0 对外开放接口合同文档整理"
date: 2026-08-04
type: docs
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
execution: docs
status: completed
---

# docs: API 2.0 对外开放接口合同文档整理

## Goal Capsule

- **目标：** 将 `docs/reference/api/` 从 1.0 时代的内部记录整理为可对外发布的
  API 2.0 接口合同：覆盖本轮新增的 6 组能力（个性签名、黑名单、群公告、
  消息收藏、登录设备管理、扫码登录），并补齐 REST / WebSocket / 数据模型 /
  第三方接入指南，使外部开发者、爱好者或业务方仅凭文档即可实现自己的 IM
  客户端并与本服务共享同一套数据。
- **权威顺序：** 运行时与 API 合同 > 自动化测试 > 当前源码（`api/src/routes.rs`
  与 `api/src/websocket/`）> 文档。文档内容以当前代码为准。
- **执行策略：** 按「基础与入门 → REST 新接口 → WS 协议 → 数据模型与全量清单」
  分单元推进，每单元一个小提交；不改动任何 API 行为与源码。

---

## Product Contract

### Summary

`api/` 已升级到 2.0.0 并补齐 6 组新能力，但 `docs/reference/api/` 仍停留在
1.0 版本：README 标注 1.0.0 / 2025-11-04，六组新接口在 REST 参考、WS 协议、
数据模型文档中均无记录。本计划补齐全部文档并统一版本基线，形成一套可交付给
第三方的接口合同。

### Problem Frame

- README/api-overview 的版本与索引过时（仍为 1.0.0，缺 6 组新接口）。
- `api-reference.md` 全量清单缺 `users/blocked`、`announcement`、`favorite`、
  `auth/devices`、`auth/qr`。
- `websocket.md` 只有服务端事件 1~22，缺 23（群公告）与 24（扫码状态），
  客户端事件缺 `qr_subscribe`。
- `models.md` 的 `UserInfo` 缺 `signature`、`LoginResponse` 缺 `device_id`，
  缺黑名单/设备/扫码会话/公告/收藏相关模型。
- `auth.md` / `user-profile.md` / `messages.md` 未记录登录设备参数、
  个性签名与消息收藏接口。
- 没有面向第三方开发者的接入指南（注册 → 登录 → WS 连接 → 收发消息的最小闭环
  与错误码/限流约定）。

### Requirements

- R1. 版本基线：`docs/reference/api/` 全部文档统一到 API 2.0.0，更新 README
  日期与索引。
- R2. 第三方接入指南：新增 `docs/reference/api/developer-guide.md`，包含 base
  URL、Bearer 认证、错误响应结构、限流说明、最小端到端流程、兼容性声明。
- R3. 黑名单文档：新增 `docs/reference/api/user-block.md`，覆盖拉黑/取消/列表
  三接口及私聊发消息、创建私聊、好友申请的拦截语义。
- R4. 群公告文档：新增 `docs/reference/api/group-announcement.md`，覆盖
  GET/PUT/DELETE 与群主/管理员/成员权限，并引用 WS 事件 23。
- R5. 消息收藏文档：在 `messages.md` 补收藏/取消/列表三接口（幂等、本人可见、
  分页）。
- R6. 登录设备文档：新增 `docs/reference/api/auth-devices.md`，覆盖设备列表、
  撤销、登录/刷新携带 `device_id/device_name/platform` 与设备级 refresh 失效。
- R7. 扫码登录文档：新增 `docs/reference/api/qr-login.md`，覆盖创建/轮询/确认/
  取消与一次性 `login_code`，并引用 WS `qr_subscribe` / 事件 24。
- R8. 既有文档同步：`api-reference.md` 补全量清单；`auth.md` 补设备参数；
  `user-profile.md` 补 `signature`；`models.md` 补新字段与新模型；
  `websocket.md` 补 `qr_subscribe` 与事件 23/24（JSON + protobuf 双格式）。

### Scope Boundaries

- 不生成 OpenAPI/Swagger 规范文件（文档保持 Markdown 结构，与现状一致）。
- 不修改任何 API 源码、迁移与测试；本计划仅文档。
- 不编写第三方客户端示例工程；指南只提供 curl 级最小示例。
- 不承诺公开部署策略（域名、备案、配额），只整理接口合同本身。

---

## 文档清单

### 新增

- `docs/reference/api/developer-guide.md` — 第三方接入指南（R2）
- `docs/reference/api/user-block.md` — 黑名单（R3）
- `docs/reference/api/group-announcement.md` — 群公告（R4）
- `docs/reference/api/auth-devices.md` — 登录设备管理（R6）
- `docs/reference/api/qr-login.md` — 扫码登录（R7）

### 更新

- `docs/reference/api/README.md` — 版本 2.0.0、日期、新索引（R1）
- `docs/reference/api/api-overview.md` — 接口导航补新接口（R1/R8）
- `docs/reference/api/api-reference.md` — 全量路由清单补 6 组接口（R8）
- `docs/reference/api/auth.md` — 设备参数与设备管理/扫码入口（R8）
- `docs/reference/api/user-profile.md` — `signature` 字段（R8）
- `docs/reference/api/messages.md` — 消息收藏接口（R5）
- `docs/reference/api/websocket.md` — `qr_subscribe`、事件 23/24（R8）
- `docs/reference/api/models.md` — 新字段与新模型（R8）

---

## Implementation Units

### U1. 基础与入门

- README 版本/日期/索引；api-overview 导航补新接口；新增 developer-guide.md。
- 验证：README 显示 2.0.0；overview 出现 6 组新接口入口；指南包含端到端闭环。

### U2. REST 新接口专题

- 新增 user-block.md、group-announcement.md、auth-devices.md、qr-login.md；
  messages.md 补收藏；user-profile.md 补 signature；auth.md 补设备参数。
- 验证：每个新接口文档包含方法、路径、认证、请求/响应示例与错误路径。

### U3. WebSocket 协议

- websocket.md 补客户端事件 `qr_subscribe`、服务端事件 23/24，JSON 与
  protobuf 字段双格式（对齐 `api/proto/ws.proto` 与 `websocket/protocol.rs`）。
- 验证：事件号与 ws.proto 一致（23/24），匿名订阅说明准确。

### U4. 数据模型与全量清单

- models.md 补 `UserInfo.signature`、`LoginResponse.device_id` 与新模型；
  api-reference.md 补 6 组接口的完整条目并更新目录。
- 验证：与 `api/src/models/`、`routes.rs` 抽查一致。

### U5. 验收与提交

- 全文关键词覆盖检查；文档间相对链接有效；`git diff --check`；
  按 U1-U4 拆分提交并推送。

---

## Verification Contract

- `rg` 覆盖：`users/blocked`、`announcement`、`favorite`、`auth/devices`、
  `auth/qr`、`signature`、`qr_subscribe`、`qr_status_changed`、
  `group_announcement_updated` 在 `docs/reference/api/` 中均可检索到。
- 文档内相对链接可用；README 版本为 2.0.0。
- `git diff --check` 通过；无源码/迁移/测试文件改动。

## Definition of Done

- R1-R8 全部落地并有可检索证据。
- 新增 5 个文档、更新 8 个文档，内容与当前源码一致。
- 提交按 U1-U4 拆分，每单元一个 Conventional Commit 并推送。

## 执行结果（2026-08-04）

- U1 基础与入门：新增 `developer-guide.md`；README 升级 2.0.0 / 2026-08-04 并
  补索引；api-overview 补 6 组新接口导航。
- U2 REST 专题：新增 `user-block.md`、`group-announcement.md`、
  `auth-devices.md`、`qr-login.md`；`messages.md` 补消息收藏；
  `user-profile.md` 补个性签名；`auth.md` 补设备参数与响应 `deviceId`。
- U3 WebSocket：`websocket.md` 补客户端事件 6 `qr_subscribe`（支持匿名订阅）、
  服务端事件 23 `group_announcement_updated`、24 `qr_status_changed`，含
  JSON 与 protobuf 字段。
- U4 模型与全量清单：`models.md` 补 `UserInfo.signature`、
  `LoginResponse.deviceId`、设备字段与 6 个 API 2.0 新模型；`api-reference.md`
  补黑名单/群公告/消息收藏/登录设备/扫码登录小节与目录锚点。
- 验收：9 个关键词全覆盖；文档相对链接无断链；`git diff --check` 通过；
  无源码/迁移/测试改动。
- 提交：`4151f4cb`（U1）→ `16d81b78`（U2）→ `21bc3998`（U3）→
  `5c60f53a`（U4）。
