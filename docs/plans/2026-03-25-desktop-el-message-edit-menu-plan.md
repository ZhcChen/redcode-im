# Desktop EL Message Edit Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐消息编辑与更完整消息操作菜单最小闭环，并把 backend 现有 `message_update(edited)` 通过 Go core / renderer 接到当前会话局部更新链路。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务 RPC、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增本地 HTTP 端口，不改 backend 协议，只补 `chat.edit` RPC、renderer 侧消息菜单 / 编辑弹层 / 复制入口，并把 `chat.delete` 在 UI 语义上统一视为“撤回”。

**Tech Stack:** Vue 3、TypeScript、Bun、Go 1.25、stdio RPC、现有 `ChatPanel` / `ChatApi` / `go-core`

---

### Task 1: 先用测试钉住 `chat.edit` RPC 与 edited realtime 映射

**Files:**
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`
- Modify: `desktop-el/renderer/src/api/chat.ts`

- [x] **Step 1: 为 Go core `chat.edit` 写红灯测试**

覆盖最小行为：
- `chat.edit` 正确把 `room_id` / `message_id` / `content` 发到 backend `PATCH /rooms/:room_id/messages/:message_id`
- 成功时返回更新后的消息 envelope

- [x] **Step 2: 为 renderer `ChatApi.editMessage` 与 `message_update(edited)` 写红灯测试**

覆盖最小行为：
- `ChatApi.editMessage()` 通过 `chat.edit` RPC 调 go-core，并映射 `ChatMessage`
- `mapChatRealtimeEvent()` 对 `message_update` 额外映射：
  - `editedAt`
  - `content`
  - `isDeleted`

- [x] **Step 3: 跑定向测试确认先失败**

Run:
- `go test ./internal/app -run TestAppChatEdit -count=1`
- `bun test renderer/src/api/chat.test.ts`

Expected:
- 新增 `chat.edit` 相关 case FAIL
- 新增 `message_update(edited)` 相关 case FAIL

### Task 2: 实现 Go core `chat.edit` 与 renderer API 映射

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`

- [x] **Step 1: 在 Go core chat service 增加编辑消息参数与请求方法**

最小新增：
- `EditMessageParams`
- `Service.EditMessage(...)`

- [x] **Step 2: 在 RPC 注册层暴露 `chat.edit`**

最小要求：
- 参数校验沿用现有 `unmarshalParams`
- 统一复用现有 RPC error 映射

- [x] **Step 3: 在 renderer `ChatApi` 增加 `editMessage` 并补齐 realtime 映射字段**

最小要求：
- `ChatApi.editMessage({ roomId, messageId, content })`
- `ChatRealtimeEvent["message_update"]` 追加 `editedAt` / `content`
- `mapChatRealtimeEvent()` 能正确识别 deleted / edited 两类更新

- [x] **Step 4: 回跑定向测试**

Run:
- `go test ./internal/app -run TestAppChatEdit -count=1`
- `bun test renderer/src/api/chat.test.ts`

Expected: PASS

### Task 3: 接入消息菜单、复制、编辑与撤回文案

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 先为消息菜单 / 编辑态补最小本地状态**

最小状态：
- 当前打开菜单的消息 ID
- 当前编辑中的消息
- 编辑输入框草稿

- [x] **Step 2: 接入统一消息“更多”菜单**

最小入口：
- 每条非系统消息提供“更多”按钮
- 菜单按消息能力展示：
  - 复制
  - 引用
  - 转发
  - 置顶 / 取消置顶
  - 反应
  - 编辑（仅自己发送的纯文本消息）
  - 已读成员（仅自己发送且非本地临时消息）
  - 撤回 / 移除

- [x] **Step 3: 接入复制与编辑闭环**

最小要求：
- 复制仅处理可见文本内容
- 编辑仅支持自己发送的纯文本、非已删除、非本地失败消息
- 编辑成功后原位更新当前消息

- [x] **Step 4: 接入 edited realtime 局部收敛**

最小要求：
- 收到当前房间 `message_update` 且带 `editedAt` / `content` 时，优先局部 patch 当前消息
- 删除型 `message_update` 继续沿用现有 reload 收敛策略

- [x] **Step 5: 把 `chat.delete` 的用户文案统一成“撤回”**

最小要求：
- 自己的已发送消息菜单项显示“撤回”
- 本地 failed/sending 消息继续显示“移除”

### Task 4: 回归验证、更新 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-edit-menu-plan.md`

- [x] **Step 1: 跑定向验证**

Run:
- `go test ./internal/app -run TestAppChatEdit -count=1`
- `bun test renderer/src/api/chat.test.ts`

Expected: PASS

- [x] **Step 2: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`
- `cd desktop-el/go-core && go test ./...`

Expected:
- `bun test` PASS
- `bun run build` PASS
- `go test ./...` PASS

- [x] **Step 3: 回填 backlog**

将 `P0-1` 中“撤回与更完整的消息操作菜单仍未迁移”更新为当前真实剩余缺口。

- [x] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-message-edit-menu-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support message edit menu"
git push origin codex/desktop-el
```

- [x] **Step 5: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
