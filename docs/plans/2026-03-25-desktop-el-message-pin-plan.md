# Desktop EL Message Pin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐消息 `置顶/取消置顶` 的最小闭环，让 renderer 通过 stdio RPC 调用 Go core，并接上 `pin_update` 实时同步和消息卡片置顶标识。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务核心、renderer 只通过 stdio RPC 与 Go core 交互。此批次只做消息级 pin 能力，不把旧桌面端的 pinned messages drawer、reaction、typing 一并迁入。消息状态更新优先复用 backend 已有 `pin_update` 推送，renderer 只做当前会话的最小局部更新。

**Tech Stack:** Go 1.25、TypeScript、Vue 3、Bun、stdio RPC、现有 backend `/rooms/{room_id}/messages/{message_id}/pin`

---

### Task 1: 补计划与红灯测试

**Files:**
- Create: `docs/plans/2026-03-25-desktop-el-message-pin-plan.md`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写 Go core pin/unpin 红灯测试**

新增：
- `TestAppChatPinMessageReturnsEnvelope`
- `TestAppChatUnpinMessageReturnsEnvelope`

验证 `chat.pin` / `chat.unpin` 分别命中 backend 对应路径。

- [x] **Step 2: 运行 Go 定向测试确认先失败**

Run:
- `go test ./internal/app -run 'TestAppChat(Pin|Unpin)MessageReturnsEnvelope'`

Expected: FAIL，提示 `chat.pin` / `chat.unpin` 尚未注册或行为不符。

- [x] **Step 3: 写 renderer 红灯测试**

新增：
- `ChatApi.pinMessage(...)`
- `ChatApi.unpinMessage(...)`
- `mapChatMessagePayload` 映射 `is_pinned/pinned_at/pinned_by`
- `mapChatRealtimeEvent` 映射 `pin_update`

- [x] **Step 4: 运行 Bun 定向测试确认先失败**

Run: `bun test desktop-el/renderer/src/api/chat.test.ts`
Expected: FAIL，提示 pin API、消息映射或事件映射未实现。

### Task 2: 实现 Go core message pin RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Verify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 新增 pin/unpin 参数与 service 方法**

在 `service.go` 增加消息 pin 参数结构与 `PinMessage(...)` / `UnpinMessage(...)`，分别调用：
- `POST /rooms/{room_id}/messages/{message_id}/pin`
- `DELETE /rooms/{room_id}/messages/{message_id}/pin`

- [x] **Step 2: 注册 stdio RPC**

在 `app.go` 注册：
- `chat.pin`
- `chat.unpin`

- [x] **Step 3: 回跑 Go 定向测试**

Run:
- `go test ./internal/app -run 'TestAppChat(Pin|Unpin)MessageReturnsEnvelope'`

Expected: PASS

### Task 3: 实现 renderer API、消息模型和 realtime 事件

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Verify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 补消息 pin 字段与响应映射**

为 `BackendMessageInfo` / `ChatMessage` 增加：
- `pinnedAt`
- `pinnedBy`

并新增 `BackendPinResponse`、`PinMessageData` 的映射。

- [x] **Step 2: 接入 `pin_update` 推送类型**

扩展 `ChatWebSocketPush` / `ChatRealtimeEvent`，让 renderer 能识别 `pin_update`。

- [x] **Step 3: 新增 `ChatApi.pinMessage` / `ChatApi.unpinMessage`**

renderer 通过 stdio RPC 调 Go core，不直接调用 HTTP。

- [x] **Step 4: 回跑 Bun 定向测试**

Run: `bun test desktop-el/renderer/src/api/chat.test.ts`
Expected: PASS

### Task 4: 接入 ChatPanel 最小 pin UI

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 给消息卡片增加置顶/取消置顶按钮**

限制为非系统、未删除消息；按钮文案随当前 pinned 状态变化。

- [x] **Step 2: 展示最小置顶标识**

消息已置顶时在卡片上显示显式标识，避免用户无法判断当前状态。

- [x] **Step 3: 处理 `pin_update` 当前会话局部更新**

当前房间收到 `pin_update` 时，局部更新对应消息的 `pinnedAt/pinnedBy`，不额外 reload 全量会话。

### Task 5: 验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 跑最小验证集**

Run:
- `go test ./internal/app -run 'TestAppChat(Pin|Unpin)MessageReturnsEnvelope'`
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

将 `P0-1` 中 `pin_update` 从当前缺口里移除，并记录“消息置顶最小闭环”完成。

- [ ] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-message-pin-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support message pin"
git push origin codex/desktop-el
```

- [ ] **Step 5: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
