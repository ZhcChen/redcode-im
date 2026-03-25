# Desktop EL Group Owner Transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的现有群聊补齐“转让群主”最小闭环，并把群管理权限从粗粒度 `canManage` 拆成 owner-only / owner-admin / member-readonly 三档。

**Architecture:** 继续保持 Go core 承接 backend 群管理接口，renderer 只通过 stdio RPC 调用 Go core。当前切口只覆盖“群主转让 -> 成功后刷新群详情 / 群设置 / 会话列表”和“现有群管理按钮权限拆细”，不扩展到新的本地 HTTP 端口、复杂实时联动或大规模页面重构。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend room/group API

---

### Task 1: Go core 与 renderer API 群主转让能力

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束群主转让 RPC 与 renderer API**

新增测试，校验：
- Go core `chat.group.owner.transfer` 调 `POST /rooms/:room_id/transfer`
- 请求体为 `{ "new_owner_id": "..." }`
- renderer `ChatApi.transferGroupOwner` 调用上述 RPC 并映射 `{ roomId, ownerId }`

- [x] **Step 2: 跑 targeted tests 确认先失败**

Run: `go test ./internal/app -run 'TestAppChatGroupOwnerTransferReturnsEnvelope'`
Expected: FAIL，原因是 RPC 尚未注册

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是转让群主 API 尚未实现

- [x] **Step 3: 最小实现 RPC 与 API**

最小改动：
- Go core 增加群主转让 RPC
- renderer 增加 `ChatApi.transferGroupOwner`

- [x] **Step 4: 运行 targeted tests 确认转绿**

Run: `go test ./internal/app -run 'TestAppChatGroupOwnerTransferReturnsEnvelope'`
Expected: PASS

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: 权限模型与 ChatPanel 转让入口

**Files:**
- Modify: `desktop-el/renderer/src/utils/chat-group-permissions.ts`
- Modify: `desktop-el/renderer/src/utils/chat-group-permissions.test.ts`
- Create: `desktop-el/renderer/src/components/TransferGroupOwnerModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 先写权限红灯测试**

扩展 `resolveGroupManageState` 测试，明确：
- 群主拥有 owner-only 操作（管理员设置、转让群主、操作日志）
- 管理员只拥有 owner/admin 操作（成员管理、入群审核、禁言、群头像、群设置写侧）
- 普通成员保持只读，但仍可查看群规

- [x] **Step 2: 接入转让群主 modal 与按钮**

最小行为：
- 仅群主可见“转让群主”按钮
- 候选成员自动排除当前群主
- 选中成员后调用 `ChatApi.transferGroupOwner`

- [x] **Step 3: 成功后刷新当前群上下文**

成功后统一刷新：
- `loadChats`
- `loadGroupContext`
- `loadGroupSettings`

失败时保留当前页面状态并给出 notice。

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/utils/chat-group-permissions.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-owner-transfer-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P1-1` 中“完整成员面板 / 更细权限控制”的进度描述，标记本轮已完成的群主转让与权限拆细。

- [x] **Step 2: 跑完整验证**

Run: `go test ./...`
Expected: PASS

Run: `bun test`
Expected: 仍然只有既有 3 个 Electron named export mock 失败，且不新增失败项

Run: `bun run build`
Expected: PASS

- [x] **Step 3: 提交与推送**

```bash
git add docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-25-desktop-el-group-owner-transfer-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/utils/chat-group-permissions.ts \
  desktop-el/renderer/src/utils/chat-group-permissions.test.ts \
  desktop-el/renderer/src/components/TransferGroupOwnerModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support group owner transfer"
git push origin codex/desktop-el
```

- [x] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
