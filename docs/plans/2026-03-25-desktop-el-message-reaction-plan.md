# Desktop EL Message Reaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐消息 reaction 的最小闭环，让 renderer 通过 stdio RPC 调用 Go core，支持添加/移除 reaction、展示 reaction 标签，并接上 `reaction_update` 当前会话同步。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务核心、renderer 只通过 stdio RPC 与 Go core 交互。此批次只做消息级 reaction，不顺带迁移 typing、复杂表情弹层或 pinned drawer；`reaction_update` 到达时只同步当前会话的目标消息。

**Tech Stack:** Go 1.25、TypeScript、Vue 3、Bun、stdio RPC、现有 backend `/rooms/{room_id}/messages/{message_id}/reactions`

---

### Task 1: 补计划与红灯测试

**Files:**
- Create: `docs/plans/2026-03-25-desktop-el-message-reaction-plan.md`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写 Go core reaction 红灯测试**

新增：
- `TestAppChatAddReactionReturnsEnvelope`
- `TestAppChatRemoveReactionReturnsEnvelope`
- `TestAppChatListReactionsReturnsEnvelope`

- [x] **Step 2: 运行 Go 定向测试确认先失败**

Run:
- `go test ./internal/app -run 'TestAppChat(Add|Remove|List)Reaction(s)?ReturnsEnvelope'`

Expected: FAIL，提示 reaction RPC 尚未注册或行为不符。

- [x] **Step 3: 写 renderer 红灯测试**

新增：
- `ChatApi.addReaction(...)`
- `ChatApi.removeReaction(...)`
- `ChatApi.getReactions(...)`
- `mapChatRealtimeEvent` 映射 `reaction_update`

- [x] **Step 4: 运行 Bun 定向测试确认先失败**

Run: `bun test desktop-el/renderer/src/api/chat.test.ts`
Expected: FAIL，提示 reaction API 或 `reaction_update` 尚未实现。

### Task 2: 实现 Go core reaction RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Verify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 新增 add/remove/list reaction 参数与 service 方法**

分别调用：
- `POST /rooms/{room_id}/messages/{message_id}/reactions`
- `DELETE /rooms/{room_id}/messages/{message_id}/reactions?reaction_key=...`
- `GET /rooms/{room_id}/messages/{message_id}/reactions`

- [x] **Step 2: 注册 stdio RPC**

在 `app.go` 注册：
- `chat.reactions.add`
- `chat.reactions.remove`
- `chat.reactions.list`

- [x] **Step 3: 回跑 Go 定向测试**

Run:
- `go test ./internal/app -run 'TestAppChat(Add|Remove|List)Reaction(s)?ReturnsEnvelope'`

Expected: PASS

### Task 3: 实现 renderer API 与 realtime 映射

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Verify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 补 reaction summary 类型与映射**

新增 `ChatMessageReactionSummary` 与通用 reaction response mapper。

- [x] **Step 2: 接入 `reaction_update` 推送类型**

扩展 `ChatWebSocketPush` / `ChatRealtimeEvent`，让 renderer 能识别 reaction 更新。

- [x] **Step 3: 新增 `ChatApi.addReaction/removeReaction/getReactions`**

renderer 通过 stdio RPC 调 Go core，不直接走 HTTP。

- [x] **Step 4: 回跑 Bun 定向测试**

Run: `bun test desktop-el/renderer/src/api/chat.test.ts`
Expected: PASS

### Task 4: 接入 ChatPanel 最小 reaction UI

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 给消息卡片增加最小 reaction 入口**

提供一个简化版 emoji picker，只支持固定的 6 个 reaction。

- [x] **Step 2: 展示 reaction 标签并支持点击切换**

当消息已有 reaction 汇总时，显示 `emoji + count` 标签；若当前用户已参与则给出高亮态。

- [x] **Step 3: 处理 `reaction_update` 当前会话同步**

当前会话收到 `reaction_update` 时，对目标消息重新拉取 reaction summaries 并局部刷新。

### Task 5: 验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 跑最小验证集**

Run:
- `go test ./internal/app -run 'TestAppChat(Add|Remove|List)Reaction(s)?ReturnsEnvelope'`
- `bun test desktop-el/renderer/src/api/chat.test.ts`
- `bun run build`

Expected: PASS

- [x] **Step 2: 跑扩展回归**

Run:
- `go test ./...`
- `bun test`

Expected:
- `go test ./...` PASS
- `bun test` 仍只允许既有 3 个 Electron mock 失败

- [x] **Step 3: 回填 backlog**

将 `P0-1` 中 `reaction_update` 从当前缺口里移除，并记录“消息 reaction 最小闭环”完成。

- [x] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-message-reaction-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support message reactions"
git push origin codex/desktop-el
```

- [x] **Step 5: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
