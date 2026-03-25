# Desktop EL Typing Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐 `typing_update` 最小闭环，让 renderer 通过 stdio RPC 驱动 Go core 向 backend websocket 发送 typing 事件，并在当前会话展示输入中提示。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务核心、renderer 只通过 stdio RPC 与 Go core 交互，不新增本地 HTTP 服务端口。本批次只补当前会话的 typing 读写闭环，不顺带迁移撤回、重发或复杂消息状态面板；由于 backend typing 依赖 websocket 房间订阅，本批次会一并补最小 `ws.join/ws.leave`，发送策略沿用旧端的最小节流和停止输入清理规则。

**Tech Stack:** Go 1.25、TypeScript、Vue 3、Bun、stdio RPC、Gorilla WebSocket、现有 backend `typing_update`

---

### Task 1: 补计划与红灯测试

**Files:**
- Create: `docs/plans/2026-03-25-desktop-el-typing-update-plan.md`
- Modify: `desktop-el/go-core/internal/ws/client_test.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`
- Create: `desktop-el/renderer/src/api/websocket.test.ts`

- [x] **Step 1: 写 Go core typing 红灯测试**

新增：
- `TestClientWriteJSONAfterConnect`
- `TestAppWSJoinAndLeaveWriteWebSocketEvents`
- `TestAppChatTypingSendWritesWebSocketEvent`

- [x] **Step 2: 运行 Go 定向测试确认先失败**

Run:
- `go test ./internal/ws ./internal/app -run 'Test(ClientWriteJSONAfterConnect|AppChatTypingSendWritesWebSocketEvent)'`

Expected: FAIL，提示 websocket 写侧能力或 typing RPC 尚未实现。

- [x] **Step 3: 写 renderer 红灯测试**

新增：
- `ChatApi.sendTyping(...)`
- `mapChatRealtimeEvent` 映射 `typing_update`
- `WebSocketApi.joinRoom(...)`
- `WebSocketApi.leaveRoom(...)`

- [x] **Step 4: 运行 Bun 定向测试确认先失败**

Run:
- `bun test desktop-el/renderer/src/api/chat.test.ts`

Expected: FAIL，提示 typing API 或 `typing_update` 映射尚未实现。

### Task 2: 实现 Go core websocket 写侧、房间订阅与 typing RPC

**Files:**
- Modify: `desktop-el/go-core/internal/ws/client.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Verify: `desktop-el/go-core/internal/ws/client_test.go`
- Verify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 补 websocket JSON 写侧能力**

新增 `WriteJSON` 或等价方法，复用现有连接状态管理，不另起端口。

- [x] **Step 2: 注册 stdio RPC**

在 `app.go` 注册：
- `ws.join`
- `ws.leave`
- `chat.typing.send`

请求体最小包含：
- `room_id`
- `is_typing`

- [x] **Step 3: 回跑 Go 定向测试**

Run:
- `go test ./internal/ws ./internal/app -run 'Test(ClientWriteJSONAfterConnect|AppChatTypingSendWritesWebSocketEvent)'`

Expected: PASS

### Task 3: 实现 renderer typing API、房间订阅与 realtime 映射

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/websocket.ts`
- Verify: `desktop-el/renderer/src/api/chat.test.ts`
- Verify: `desktop-el/renderer/src/api/websocket.test.ts`

- [x] **Step 1: 新增 `ChatApi.sendTyping`**

renderer 通过 stdio RPC 调 Go core，不直接操作 websocket 或 HTTP。

- [x] **Step 2: 新增 `WebSocketApi.joinRoom/leaveRoom`**

在切换当前会话时维护 backend 所需的最小房间订阅。

- [x] **Step 3: 接入 `typing_update` 推送类型**

扩展 `ChatWebSocketPush` / `ChatRealtimeEvent` 映射：
- `roomId`
- `userId`
- `isTyping`
- `expiresInMs`

- [x] **Step 4: 回跑 Bun 定向测试**

Run:
- `bun test desktop-el/renderer/src/api/chat.test.ts`

Expected: PASS

### Task 4: 接入 ChatPanel 最小 typing UI

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 增加 typing 本地状态与提示文案**

复用旧端策略：
- 单聊显示“对方正在输入...”
- 群聊显示“某人正在输入...”或“某人等 N 人正在输入...”

- [x] **Step 2: 切换会话时维护最小 `join/leave`**

进入当前会话时 `join`，离开旧会话时 `leave`，避免 backend 返回 `not subscribed`，也避免收到旧房间的 typing 噪音。

- [x] **Step 3: 发送 typing 事件**

在输入有内容时节流发送 `is_typing=true`，在空闲、blur、发消息、切会话或输入被禁用时发送 `false`。

- [x] **Step 4: 接收 `typing_update` 并局部更新**

只处理当前会话、只展示他人、按 `expires_in_ms` 自动过期，不做跨会话全局缓存。

### Task 5: 验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 跑最小验证集**

Run:
- `go test ./internal/ws ./internal/app -run 'Test(ClientWriteJSONAfterConnect|AppChatTypingSendWritesWebSocketEvent)'`
- `bun test desktop-el/renderer/src/api/chat.test.ts`
- `bun test desktop-el/renderer/src/api/websocket.test.ts`
- `bun run build`

Expected: PASS

- [x] **Step 2: 跑扩展回归**

Run:
- `go test ./...`
- `bun test`

Expected:
- `go test ./...` PASS
- `bun run build` PASS
- `bun test`（renderer 目录）PASS
- `bun test`（`desktop-el` 根目录）仍只剩既有 3 个 Electron mock export 错误

- [x] **Step 3: 回填 backlog**

将 `P0-1` 中 `typing_update` 从当前缺口里移除，并记录“typing_update 最小闭环”完成。

- [x] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-typing-update-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/go-core/internal/ws/client.go \
  desktop-el/go-core/internal/ws/client_test.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/api/websocket.ts \
  desktop-el/renderer/src/api/websocket.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support typing update"
git push origin codex/desktop-el
```

- [x] **Step 5: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
