# Desktop EL Chat Message Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `desktop-el` 中补齐“删除自己发送的消息 + 接收 `message_update` 实时事件并刷新聊天上下文”的最小闭环。

**Architecture:** 继续维持 Electron 仅宿主、Go core 承接业务、renderer 只通过 stdio RPC 使用 Go core。此次不做复杂的前端本地消息 patch，而是走更稳的策略：Go core 暴露 `chat.delete`，renderer 触发删除后刷新；收到后端 websocket `message_update` 时，当前会话刷新消息列表和会话摘要，非当前会话只刷新摘要。

**Tech Stack:** Electron、Vue 3、TypeScript、Go 1.25、stdio RPC、backend `DELETE /rooms/{room_id}/messages/{message_id}`、websocket `message_update`

---

### Task 1: Go core 补齐 chat.delete RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写失败测试（Red）**
覆盖：
  - `chat.delete` 会携带 token 调用 `DELETE /rooms/{room_id}/messages/{message_id}`
  - 返回 envelope 被原样透传

- [x] **Step 2: 运行局部测试确认失败（Red）**
Run: `cd desktop-el/go-core && go test ./internal/app -run TestAppChatDeleteDeletesMessage -count=1`
Expected:
  - FAIL，当前 `chat.delete` 尚未注册

- [x] **Step 3: 实现最小 Go core 代码（Green）**
在 `chat.Service` 中新增：
  - `DeleteMessageParams`
  - `DeleteMessage`
并在 `app.RegisterRPC()` 注册 `chat.delete`。

- [x] **Step 4: 再跑局部测试确认通过（Green）**
Run: `cd desktop-el/go-core && go test ./internal/app -run TestAppChatDeleteDeletesMessage -count=1`
Expected:
  - PASS

### Task 2: Renderer 接通 message_update 与删除入口

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 扩展聊天 API**
在 `chat.ts` 中新增：
  - `chat.deleteMessage`
  - `message_update` realtime 事件映射

- [x] **Step 2: 在 ChatPanel 增加最小删除入口**
仅对自己发送的消息展示“删除”按钮：
  - 点击后调用 `chat.delete`
  - 删除中禁用重复触发
  - 成功后刷新当前消息列表与会话摘要

- [x] **Step 3: 接通 message_update 事件处理**
在 `ChatPanel` 中实现：
  - 当前会话收到 `message_update` 时刷新消息列表与会话摘要
  - 非当前会话收到 `message_update` 时只刷新会话摘要
  - 保持当前选中会话不丢失

### Task 3: 全量验证与提交

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-chat-message-update-plan.md`

- [x] **Step 1: 运行 Go 全量测试**
Run: `cd desktop-el/go-core && go test ./...`
Expected: PASS

- [x] **Step 2: 运行类型检查**
Run: `cd desktop-el && bun run type-check`
Expected: PASS

- [x] **Step 3: 运行构建**
Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 4: 前台烟测并清理**
Run:
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el && make desktop-el-down`
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el && bun run dev`
  - 验证 Go core、Electron、renderer 正常启动，删除消息后列表与实时刷新行为正常
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el && make desktop-el-down`
  - `screen -ls || true`
  - `pgrep -fl '/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/node_modules/.bin/electron|/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron|desktop-el-core' || true`
Expected:
  - 前台启动正常
  - 收尾后无 `desktop-el` 残留进程

- [x] **Step 5: 提交并推送**
Run:
```bash
git add desktop-el/go-core/internal/chat/service.go desktop-el/go-core/internal/app/app.go desktop-el/go-core/internal/app/app_test.go desktop-el/renderer/src/api/chat.ts desktop-el/renderer/src/components/ChatPanel.vue docs/plans/2026-03-24-desktop-el-chat-message-update-plan.md
git commit -m "feat(desktop-el): support message update sync"
git push origin codex/desktop-el
```
