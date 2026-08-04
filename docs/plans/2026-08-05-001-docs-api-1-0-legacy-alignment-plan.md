---
title: "docs: API 1.0 遗留文档对齐收尾"
date: 2026-08-05
type: docs
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
execution: docs
status: active
---

# docs: API 1.0 遗留文档对齐收尾

## Goal Capsule

- **目标：** 将 `docs/reference/api/` 中剩余的 1.0 遗留专题文档
  （`friends.md`、`chats.md`、`version-management.md`、`system.md`，
  以及抽查 `e2ee.md`、`admin-storage.md`、`file-upload-hash.md`）对齐到当前
  代码，使「专题文档 → api-reference → routes.rs」三层互相一致，达到可对外
  发布状态。只改文档，不改动任何 API 行为与源码。
- **权威顺序：** 运行时与 API 合同 > 自动化测试 > 当前源码
  （`api/src/routes.rs` 与 `api/src/handlers/`）> 文档。文档内容以当前代码为准。
- **执行顺序：** P0 补全四个专题文档 -> P1 抽查对齐三个较新文档 ->
  P2 路由覆盖核对与收口。
- **停止条件：** 任一文档出现与代码不一致的路径、方法、认证、响应字段或
  错误语义描述且未裁决时，保持未完成状态；不提交半成品。

## 摸底结果

| 文档 | 状态 | 主要缺口 |
|---|---|---|
| `friends.md` | 缺 3 个接口 | `GET /friends`、`PATCH /friends/{id}/remark`、`DELETE /friends/{id}` |
| `chats.md` | 缺未读/设置类 | `GET /unread_counts`、`GET /rooms/{id}/unread_count`、`POST /rooms/{id}/notification-settings`、`POST /rooms/{id}/pin` |
| `version-management.md` | 缺热更新 | `GET /versions/hot-update*`、`POST /versions/hot-update/report`、`/api/admin/hot-updates*` |
| `system.md` | 覆盖过少 | 仅 /healthz、/；缺 `/readyz`、公开设置等 |
| `e2ee.md` / `admin-storage.md` / `file-upload-hash.md` | 较新 | 抽查对齐设备/KeyPackage/epoch、storage-config、multipart 路由 |
| `api-reference.md` | 覆盖较全 | 尾部技术栈/统计信息需核对 |
| `api-overview.md` | 覆盖较全 | 管理后台只给入口，可接受 |

## 文档清单

### P0 更新

- `docs/reference/api/friends.md` — 补好友列表/备注/删除接口
- `docs/reference/api/chats.md` — 补未读计数、通知设置、置顶
- `docs/reference/api/version-management.md` — 补热更新客户端/管理接口
- `docs/reference/api/system.md` — 补 `/readyz` 与公开设置接口

### P1 抽查更新

- `docs/reference/api/e2ee.md`
- `docs/reference/api/admin-storage.md`
- `docs/reference/api/file-upload-hash.md`

### P2 收口

- `docs/reference/api/api-reference.md`（如有不符则更新）
- 路由覆盖核对脚本（一次性，不入库或放入 `scripts/` 供复用）

## Implementation Units

### U1. friends.md

- 补 `GET /friends`、`PATCH /friends/{friend_user_id}/remark`、
  `DELETE /friends/{friend_user_id}`，字段与 `api/src/handlers/friend.rs`
  一致；保留已有黑名单拦截说明。
- 验证：`rg` 三个路径可命中；方法与认证与 routes.rs 一致。

### U2. chats.md

- 补 `GET /unread_counts`、`GET /rooms/{room_id}/unread_count`、
  `POST /rooms/{room_id}/notification-settings`、`POST /rooms/{room_id}/pin`，
  与 `chat_history.rs` / `room.rs` 一致。
- 验证：四个路径可命中；响应字段抽查与 handler 一致。

### U3. version-management.md

- 补热更新客户端接口与 Admin 管理小节，复用 api-reference 已有内容并核对
  handler。
- 验证：`hot-update` 关键词命中；路径与 routes.rs 一致。

### U4. system.md

- 补 `/readyz`、公开设置接口（privacy-policy、user-agreement、general、
  app-name、captcha），其余系统能力导航到 api-reference。
- 验证：新增路径可命中。

### U5. e2ee/admin-storage/file-upload-hash 抽查

- 对照 `/e2ee/*`、`/api/admin/storage-*`、`/uploads/multipart/*` 路由与
  handler，修正过时字段与描述。
- 验证：无与代码冲突的路径/字段声明。

### U6. 路由覆盖核对与收口

- 提取 `api/src/routes.rs` 全部路径，与 api-reference + 专题文档对比，
  输出未覆盖清单并逐条裁决（补充或豁免）。
- 更新 api-reference 尾部元信息（技术栈/统计，若与实际不符）。
- 全部相对链接检查、`git diff --check`。
- 补 `docs/reviews/2026-08-05-api-1-0-docs-alignment-review.md`。

## Verification Contract

- `rg` 覆盖：`GET /friends`、`/remark`、`/unread_counts`、
  `notification-settings`、`hot-update`、`/readyz` 在 `docs/reference/api/`
  中可检索。
- 文档内相对链接可用；无断链。
- `git diff --check` 通过；无源码/迁移/测试文件改动。
- 路由覆盖清单无未裁决项（每条路由有文档或明确豁免理由）。

## Definition of Done

- P0 四个专题文档补齐；P1 三个文档抽查一致；P2 收口完成。
- 提交按 U1-U5 拆分，每单元一个 Conventional Commit 并推送；U6 一次 review
  文档提交。
