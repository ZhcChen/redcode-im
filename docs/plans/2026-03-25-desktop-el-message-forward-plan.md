# Desktop EL Message Forward Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐“单条消息转发”的最小闭环，让 renderer 通过 stdio RPC 调用 Go core，将任意可转发消息转发到目标会话并正确展示转发来源。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务核心、renderer 只通过 stdio RPC 与 Go core 交互。此批次只迁移单条消息转发，不顺带引入撤回、重发或新的本地 HTTP 服务端口。消息转发成功后复用现有 backend 广播链路和 renderer 刷新逻辑，避免复制旧 `desktop` 的多选转发复杂度。

**Tech Stack:** Go 1.25、TypeScript、Vue 3、Bun、stdio RPC、现有 backend `/rooms/{room_id}/messages/forward`

---

### Task 1: 补消息转发计划与失败测试

**Files:**
- Create: `docs/plans/2026-03-25-desktop-el-message-forward-plan.md`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 先写 Go core RPC 红灯测试**

新增 `TestAppChatForwardMessageReturnsEnvelope`，验证 `chat.forward` 会将 `room_id` 和 `original_message_id` 透传到 backend `/rooms/{room_id}/messages/forward`。

- [x] **Step 2: 运行 Go 测试确认先失败**

Run: `go test ./internal/app -run TestAppChatForwardMessageReturnsEnvelope`
Expected: FAIL，提示 `chat.forward` 尚未注册或行为不符合预期。

- [x] **Step 3: 再写 renderer 红灯测试**

新增两类测试：
1. `ChatApi.forwardMessage` 会调用 `chat.forward`
2. `mapChatMessagePayload` 能把 `forward_message` 映射为前端 `forwardInfo`

- [x] **Step 4: 运行 Bun 测试确认先失败**

Run: `bun test desktop-el/renderer/src/api/chat.test.ts`
Expected: FAIL，提示 `forwardMessage` 或 `forwardInfo` 尚未实现。

### Task 2: 实现 Go core 消息转发 RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Verify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 新增消息转发参数与 service 方法**

在 `service.go` 增加 `ForwardMessageParams` 与 `ForwardMessage(...)`，POST 到 `/rooms/{room_id}/messages/forward`，请求体只包含 `original_message_id`。

- [x] **Step 2: 注册 stdio RPC**

在 `app.go` 注册 `chat.forward`，保持参数解码、错误封装与现有 `chat.send` / `chat.delete` 一致。

- [x] **Step 3: 回跑 Go 定向测试**

Run: `go test ./internal/app -run TestAppChatForwardMessageReturnsEnvelope`
Expected: PASS

### Task 3: 实现 renderer API 与消息模型映射

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Verify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 新增 forward payload 类型与前端模型**

补 `BackendForwardMessage`、`ChatForwardInfo`、`mapForwardMessage(...)`，并把 `forward_message` 接入 `BackendMessageInfo`、`BackendPushMessage` 和 `ChatMessage`。

- [x] **Step 2: 新增 `ChatApi.forwardMessage(...)`**

renderer 通过 stdio RPC 调用 `chat.forward`，返回转发后的 `ChatMessage`，不直接走 HTTP。

- [x] **Step 3: 回跑 Bun 定向测试**

Run: `bun test desktop-el/renderer/src/api/chat.test.ts`
Expected: PASS

### Task 4: 接入 ChatPanel 最小转发 UI

**Files:**
- Create: `desktop-el/renderer/src/components/ForwardMessageModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 新增转发选择弹窗**

弹窗直接复用当前会话列表作为目标源，支持搜索，默认排除当前会话与无 `roomId` 项，只支持单选。

- [x] **Step 2: 给消息卡片增加“转发”入口**

限制为非系统消息、未删除消息，点击后打开弹窗；成功后刷新会话列表，必要时刷新当前会话消息并提示结果。

- [x] **Step 3: 展示转发来源**

当消息携带 `forwardInfo` 时，在消息卡片正文前展示“转发自 xxx”的只读来源条，避免转发消息在 UI 上与普通消息无差异。

### Task 5: 完整验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 跑最小验证集**

Run:
- `go test ./internal/app -run TestAppChatForwardMessageReturnsEnvelope`
- `bun test desktop-el/renderer/src/api/chat.test.ts`
- `bun run build`

Expected: PASS

- [x] **Step 2: 跑扩展回归**

Run:
- `go test ./...`
- `bun test`

Expected:
- `go test ./...` PASS
- `bun test` 保持既有基线，仅允许那 3 个 Electron named export mock 失败，不能新增失败项

- [x] **Step 3: 回填 backlog**

将 `P0-1` 中“转发、撤回、重发与更完整的消息操作菜单仍未迁移”更新为只剩撤回与重发未迁移，并记录本次“消息转发最小闭环”完成。

- [x] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-message-forward-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ForwardMessageModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support message forward"
git push origin codex/desktop-el
```

- [x] **Step 5: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留 `desktop-el` / `electron` / `go-core` 相关进程
