# Desktop EL Chat Realtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `desktop-el` 中补齐聊天实时刷新与当前会话已读回写最小闭环，让 renderer 继续只通过 stdio RPC 使用 Go core。

**Architecture:** 继续维持 Electron 仅宿主、业务核心下沉 Go core、renderer 不直连业务 HTTP/WS。此次只做最小实时链路：Go core 读取 backend websocket 文本帧并统一转成 `ws.push` 事件，renderer 仅消费 `message` 与 `message_read` 两类事件，并在当前房间调用 `chat.read_until` 回写已读。

**Tech Stack:** Electron、Vue 3、TypeScript、Go 1.25、Gorilla WebSocket、stdio RPC、backend `/ws` 与 `/rooms/{room_id}/messages/read_until`

---

### Task 1: Go core 打通 websocket push 桥接

**Files:**
- Modify: `desktop-el/go-core/internal/ws/client.go`
- Modify: `desktop-el/go-core/internal/ws/client_test.go`
- Modify: `desktop-el/go-core/internal/ws/dispatcher.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写失败测试（Red）**
覆盖：
  - `ws.Client` 连接后可以读到后端文本帧
  - `ws.connect` 成功后，Go core 会向 stdout 发送 `ws.push`
  - `ws.push` 的 `data` 保留后端 websocket 原始 JSON 字段

- [x] **Step 2: 运行局部测试确认失败（Red）**
Run:
  - `cd desktop-el/go-core && go test ./internal/ws -run TestClientReadMessageAfterConnect -count=1`
  - `cd desktop-el/go-core && go test ./internal/app -run TestAppWSConnectEmitsPushEvent -count=1`
Expected:
  - FAIL，当前客户端没有读循环，`app` 也不会转发 `ws.push`

- [x] **Step 3: 实现最小 Go core 代码（Green）**
实现：
  - `ws.Client` 增加只读消息通道与关闭清理
  - `ws.Dispatcher` 增加统一的 push 发布能力
  - `app` 在 `ws.connect` 成功后启动读循环，把文本帧 decode 后通过 `ws.push` 发给 renderer

- [x] **Step 4: 再跑局部测试确认通过（Green）**
Run:
  - `cd desktop-el/go-core && go test ./internal/ws -run TestClientReadMessageAfterConnect -count=1`
  - `cd desktop-el/go-core && go test ./internal/app -run TestAppWSConnectEmitsPushEvent -count=1`
Expected:
  - PASS

### Task 2: Go core 补 chat.read_until RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写失败测试（Red）**
覆盖：
  - `chat.read_until` 会带 token 调用 `POST /rooms/{room_id}/messages/read_until`
  - 请求体包含 `message_id`
  - 返回 envelope 被原样透传

- [x] **Step 2: 运行局部测试确认失败（Red）**
Run: `cd desktop-el/go-core && go test ./internal/app -run TestAppChatReadUntilPostsMessageID -count=1`
Expected:
  - FAIL，当前 `chat.read_until` 尚未注册

- [x] **Step 3: 实现最小 Go core 代码（Green）**
在 `chat.Service` 中新增：
  - `MarkReadUntilParams`
  - `MarkReadUntil`
并在 `app.RegisterRPC()` 注册 `chat.read_until`。

- [x] **Step 4: 再跑局部测试确认通过（Green）**
Run: `cd desktop-el/go-core && go test ./internal/app -run TestAppChatReadUntilPostsMessageID -count=1`
Expected:
  - PASS

### Task 3: Renderer 接通最小实时聊天闭环

**Files:**
- Modify: `desktop-el/renderer/src/App.vue`
- Modify: `desktop-el/renderer/src/components/HomeShell.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/websocket.ts`

- [x] **Step 1: 扩展 renderer 事件模型**
在 `App.vue` 中保存最近一次 `ws.push`，并透传给 `HomeShell` / `ChatPanel`。

- [x] **Step 2: 扩展聊天 API**
在 `chat.ts` 中新增：
  - websocket push 类型
  - `chat.readUntil`
  - 必要的消息映射辅助函数，避免 UI 直接解析原始后端字段

- [x] **Step 3: 接通 ChatPanel 的最小实时逻辑**
实现：
  - 当前房间收到 `message` 时刷新消息列表与会话摘要
  - 非当前房间收到 `message` 时只刷新会话摘要
  - 当前房间加载消息后、收到新消息后调用 `chat.read_until`
  - 收到 `message_read` 时刷新当前会话摘要，并尽量保持当前消息状态新鲜

### Task 4: 全量验证、清理与提交

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-chat-realtime-plan.md`

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
  - 验证 Go core、Electron、renderer 正常启动，聊天页实时事件链路可用
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el && make desktop-el-down`
  - `screen -ls || true`
  - `pgrep -fl '/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/node_modules/.bin/electron|/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron|desktop-el-core' || true`
Expected:
  - 前台启动正常
  - 收尾后无 `desktop-el` 残留进程

- [x] **Step 5: 提交并推送**
Run:
```bash
git add desktop-el/go-core/internal/ws/client.go desktop-el/go-core/internal/ws/client_test.go desktop-el/go-core/internal/ws/dispatcher.go desktop-el/go-core/internal/app/app.go desktop-el/go-core/internal/app/app_test.go desktop-el/go-core/internal/chat/service.go desktop-el/renderer/src/App.vue desktop-el/renderer/src/components/HomeShell.vue desktop-el/renderer/src/components/ChatPanel.vue desktop-el/renderer/src/api/chat.ts desktop-el/renderer/src/api/websocket.ts docs/plans/2026-03-24-desktop-el-chat-realtime-plan.md
git commit -m "feat(desktop-el): support realtime chat sync"
git push origin codex/desktop-el
```
