---
title: "feat: API 2.0 接口能力补齐（黑名单/设备/群公告/收藏/签名/扫码登录）"
date: 2026-08-04
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
execution: code
status: completed
---

# feat: API 2.0 接口能力补齐

## Goal Capsule

- **目标：** 与 2.0 客户端（`app/` 2.0.0）同一版本面补齐 API 常规 IM 能力缺口：
  个性签名、黑名单、群公告、消息收藏、登录设备管理、扫码登录（含 WebSocket
  实时交互）。API 版本保持 `2.0.0`（已对齐）。
- **权威顺序：** 运行时与 API 合同 > 自动化测试 > 当前源码 > 本计划。
- **执行策略：** 每个能力独立闭环：migration -> model/store -> handler/route
  -> 集成测试 -> 提交。不改动既有接口语义；新接口全部 additive。
- **停止条件：** 需要修改既有迁移文件、破坏既有消息/加密/鉴权契约，或扫码
  协议需要自定义密码原语时，停止对应单元并回 `ce:brainstorm` 深化。

---

## Product Contract

### Summary

`api/` 已覆盖核心 IM 闭环且版本为 2.0.0；对照常规 IM 能力面，缺口集中在
黑名单、登录设备管理、群公告、消息收藏、个性签名与扫码登录。本计划补齐这些
能力，其中扫码登录同时扩展 WebSocket 协议，使 PC 端可实时收到扫码结果，不依赖
纯轮询。

### Problem Frame

- 用户无法阻止特定用户的消息与好友申请（无黑名单）。
- 用户无法查看/下线自己的登录设备（会话为单用户单会话模型）。
- 群主/管理员无法发布群公告，新成员无法获取群公告历史。
- 消息无法收藏，也没有收藏列表入口。
- 用户资料缺少个性签名字段（DB 与 API 均无）。
- PC 扫码登录没有服务端会话与 WS 实时通知协议。
- 用户自助注销（`DELETE /users/me`）已存在，仅做补强验证，不重建。

### Requirements

- R1. 个性签名：`users.signature` 列，`UserInfo` 增加 `signature`，`PATCH
  /users/me` 支持更新，公开资料返回。
- R2. 黑名单：拉黑/取消/列表；被拉黑用户不能向拉黑者发送私聊消息或发起好友
  申请；拉黑不影响已存在历史消息读取。
- R3. 群公告：每群至多一条当前公告（保留历史或覆盖式）；群主/管理员可发布与
  删除；群成员可读；发布后向群在线成员推送 WS 事件。
- R4. 消息收藏：收藏/取消收藏消息（仅本人可见）；收藏列表分页；重复收藏幂等。
- R5. 登录设备管理：登录时登记设备（名称/平台/最后活跃）；列出设备；撤销设备
  后该设备 access/refresh 失效并断开其 WS 会话；撤销/登出语义明确。
- R6. 扫码登录：PC 创建二维码会话（短 TTL）；手机端确认；PC 端通过 WS
  `qr_subscribe` 实时接收结果，同时 REST 轮询兜底；二维码会话一次性使用。
- R7. 注销补强：`DELETE /users/me` 增加清理 Push 设备与 refresh token；已删除
  用户发送/接收被拒绝。
- R8. 所有新接口通过 Rust 集成测试覆盖正常路径与权限/校验错误路径。

### Scope Boundaries

- 不引入即时通信的新密码协议；扫码登录复用现有 JWT + refresh token。
- 不改造既有单会话 Redis 模型为多会话模型；设备管理以 DB 设备表 + 按设备
  revoke 现有会话/refresh 的方式实现，保持迁移风险最小。
- 不做 B 组可选能力（撤回、草稿同步、定时消息、分组标签、presence、翻译、
  语音转文字、邀请链接）。

---

## API 设计

### 个性签名

- `PATCH /users/me`：`UpdateUserRequest` 增加 `signature?: string`
- `GET /users/me`、`GET /users/{id}`、好友/群成员资料：`UserInfo.signature`

### 黑名单

- `GET /users/blocked`：拉黑列表（分页）
- `POST /users/blocked`：`{ "userId": string }` 拉黑（幂等）
- `DELETE /users/blocked/{user_id}`：取消拉黑
- 拦截点：私聊 `POST /rooms`（private 房间创建）、`POST
  /rooms/{room_id}/messages`（对方拉黑我时）、好友申请 `POST /friends/requests`

### 群公告

- `GET /rooms/{room_id}/announcement`：群公告（无则 404/空）
- `PUT /rooms/{room_id}/announcement`：发布/更新（群主/管理员）
- `DELETE /rooms/{room_id}/announcement`：删除（群主/管理员）
- WS 推送：`ServerPush::GroupAnnouncementUpdated { room_id, announcement }`

### 消息收藏

- `POST /rooms/{room_id}/messages/{message_id}/favorite`：收藏（幂等）
- `DELETE /rooms/{room_id}/messages/{message_id}/favorite`：取消
- `GET /messages/favorites`：本人收藏列表（分页，按收藏时间倒序）

### 登录设备管理

- `GET /auth/devices`：当前账号设备列表（含当前设备标记）
- `POST /auth/devices/{device_id}/revoke`：撤销指定设备
- 登录/刷新响应增加 `deviceId`；JWT Claims 增加 `device_id`（可选，向后兼容）

### 扫码登录

- `POST /auth/qr/sessions`：创建扫码会话，返回 `{ qrId, expiresAt }`
- `GET /auth/qr/sessions/{qr_id}`：轮询状态（pending/confirmed/cancelled/
  expired；confirmed 返回一次性 `loginCode` 与 `refreshToken`）
- `POST /auth/qr/sessions/{qr_id}/confirm`：手机端确认（携带已登录 token）
- `POST /auth/qr/sessions/{qr_id}/cancel`：PC 端取消
- WS：`qr_subscribe { qr_id }` 订阅；`qr_result` 推送
  `{ qr_id, status, token }`；匿名 WS 连接在 Auth 前可发送 `qr_subscribe`

---

## 数据模型（新增 migration）

`20260804180000_api_2_0_capability_expansion.sql`：

- `users ADD COLUMN signature text`
- `user_blocks(id, blocker_id, blocked_id, created_at)` + 唯一约束
- `group_announcements(room_id PK, content, created_by, updated_by,
  created_at, updated_at)`（覆盖式单条）
- `message_favorites(id, user_id, room_id, message_id, created_at)` + 唯一约束
- `user_devices(id, user_id, device_name, platform, last_seen_at, created_at,
  revoked_at)` + 索引
- `qr_login_sessions(id, user_id NULL, status, qr_token, login_code,
  expires_at, created_at, confirmed_at, cancelled_at)` + 一次性索引

---

## Implementation Units

### U1. 个性签名

- migration 加列；`UserInfo`/`UpdateUserRequest`/DB user 模型扩展；
  `update_user` 支持签名；`db_user_to_api_user_info` 返回签名。
- 测试：更新成功、超长校验、公开资料返回。

### U2. 黑名单

- `user_blocks` 表 + store；三个接口；私聊建房间/发消息/好友申请拦截。
- 测试：拉黑幂等、取消、列表；被拉黑方发消息 403、好友申请 403。

### U3. 群公告

- `group_announcements` 表 + store；三个接口；WS 推送。
- 测试：仅群主/管理员可写、成员可读、非成员 403。

### U4. 消息收藏

- `message_favorites` 表 + store；三个接口；分页。
- 测试：收藏幂等、取消、列表隔离（A 看不到 B 的收藏）。

### U5. 登录设备管理

- `user_devices` 表；登录/刷新登记设备；Claims 增加 `device_id`；
  `GET /auth/devices`；`POST /auth/devices/{id}/revoke` 删除设备、
  失效其 refresh token（`auth:refresh:by-device:{device_id}` 集合）并断开 WS。
- 测试：多设备登录互不影响、撤销后 refresh 失败、撤销当前设备不误伤其他设备。

### U6. 扫码登录

- `qr_login_sessions` 表 + store；4 个 REST 接口；ws.proto 增加
  `qr_subscribe` / `qr_result`；匿名 WS 订阅与推送。
- 测试：创建-轮询-确认-登录全链路；一次性使用；过期；取消；WS 实时收到结果。

---

## Verification Contract

- `make api.test`：全部通过（新增集成测试 + 既有回归）。
- `git diff --check`；`make migration.guard` 通过。
- 既有 `/auth/login`、`/auth/refresh`、WS auth 行为不回归。

## Definition of Done

- R1-R8 全部落地并有测试证据。
- 新接口均为 additive，未改既有接口语义。
- 提交按 U1-U6 拆分，每单元一个 Conventional Commit 并推送。

## 执行结果（2026-08-04）

- U1 个性签名：`users.signature` + `UserInfo.signature` + `PATCH /users/me`。
- U2 黑名单：`/users/blocked` 拉黑/取消/列表；私聊发消息、创建私聊、好友申请
  双向拦截。
- U3 群公告：`/rooms/{id}/announcement` GET/PUT/DELETE；WS
  `group_announcement_updated`（JSON + protobuf）；修正 base.sql 遗留旧表。
- U4 消息收藏：`/rooms/{id}/messages/{mid}/favorite` + `/messages/favorites`。
- U5 登录设备管理：登录/刷新登记设备、`/auth/devices`、
  `/auth/devices/{id}/revoke`（批量失效 refresh token）。
- U6 扫码登录：`/auth/qr/sessions` 创建/轮询/确认/取消；一次性 login_code 换
  token；WS `qr_subscribe` / `qr_status_changed` 匿名实时推送。
- R7 注销补强：`DELETE /users/me` 增加停用 Push 设备与登录设备。
- 测试：`api/tests/api_2_0_capability_integration.rs` 9 项集成测试全部通过；
  `make api.test` 全量回归通过（含既有 auth/ws/e2ee 用例）。
- 提交：`ba295ad4`（迁移）→ `5d21d62e`（U1）→ `a5ce2c78`（U2）→
  `724c7d1c`（U3）→ `3fd6df9e`（U4）→ `420908dd`（U5）→ `2d7da501`（U6）。
