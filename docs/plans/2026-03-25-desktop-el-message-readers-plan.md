# Desktop EL Message Readers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐消息已读成员列表的最小闭环，让 renderer 通过 stdio RPC 调用 Go core 拉取指定消息的已读成员，并在消息卡片中提供查看入口。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务核心、renderer 只通过 stdio RPC 与 Go core 交互。此批次只补读侧链路，不顺带迁移 `typing_update`、撤回、重发或更复杂的消息状态面板；已读成员列表直接复用 backend 现有 `/rooms/{room_id}/messages/{message_id}/reads` HTTP 接口。

**Tech Stack:** Go 1.25、TypeScript、Vue 3、Bun、stdio RPC、现有 backend 消息已读查询接口

---

### Task 1: 补计划与红灯测试

**Files:**
- Create: `docs/plans/2026-03-25-desktop-el-message-readers-plan.md`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写 Go core readers 红灯测试**

新增：
- `TestAppChatMessageReadersListReturnsEnvelope`

- [x] **Step 2: 运行 Go 定向测试确认先失败**

Run:
- `go test ./internal/app -run TestAppChatMessageReadersListReturnsEnvelope`

Expected: FAIL，提示消息已读成员 RPC 尚未注册或返回不符。

- [x] **Step 3: 写 renderer 红灯测试**

新增：
- `ChatApi.getMessageReaders(...)`

- [x] **Step 4: 运行 Bun 定向测试确认先失败**

Run:
- `bun test desktop-el/renderer/src/api/chat.test.ts`

Expected: FAIL，提示消息已读成员 API 尚未实现。

### Task 2: 实现 Go core message readers RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Verify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 新增 message readers 参数与 service 方法**

调用：
- `GET /rooms/{room_id}/messages/{message_id}/reads`

- [x] **Step 2: 注册 stdio RPC**

在 `app.go` 注册：
- `chat.message.readers.list`

- [x] **Step 3: 回跑 Go 定向测试**

Run:
- `go test ./internal/app -run TestAppChatMessageReadersListReturnsEnvelope`

Expected: PASS

### Task 3: 实现 renderer API 映射

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Verify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 补消息已读成员类型与映射**

新增 `ChatMessageReader` 与 reader mapper。

- [x] **Step 2: 新增 `ChatApi.getMessageReaders`**

renderer 通过 stdio RPC 调 Go core，不直接走 HTTP。

- [x] **Step 3: 回跑 Bun 定向测试**

Run:
- `bun test desktop-el/renderer/src/api/chat.test.ts`

Expected: PASS

### Task 4: 接入 ChatPanel 最小已读成员弹窗

**Files:**
- Create: `desktop-el/renderer/src/components/MessageReadersModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 给消息卡片增加“已读成员”入口**

仅在当前消息不是系统消息时展示，优先支持自己发送的消息查看。

- [x] **Step 2: 提供最小弹窗展示 readers 列表**

展示昵称/账号、已读时间和基础空态、加载态。

- [x] **Step 3: 保持局部状态更新**

只在打开弹窗时拉取数据，不额外引入全量消息刷新。

### Task 5: 验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 跑最小验证集**

Run:
- `go test ./internal/app -run TestAppChatMessageReadersListReturnsEnvelope`
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

将 `P0-1` 中“已读成员列表”从当前缺口里移除，并记录“消息已读成员列表最小闭环”完成。

- [ ] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-message-readers-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/MessageReadersModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support message readers"
git push origin codex/desktop-el
```

- [ ] **Step 5: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
