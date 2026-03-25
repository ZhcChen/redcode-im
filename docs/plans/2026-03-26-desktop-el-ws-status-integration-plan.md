# Desktop EL Go Core WS Status Integration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 扩充 `desktop-el` Go core 的 app-level 集成测试，确保 websocket 远端掉线后 renderer 能收到 `ws.status.updated(disconnected)`。

**Architecture:** 直接在 `internal/app/app_test.go` 走真实 `RegisterRPC()`、本地 `httptest` websocket server 与 `rpc.Encoder` 输出，覆盖 `ws.connect -> startWSPump -> 远端断开 -> status event` 整条链路。若测试暴露缺口，只在 `App.startWSPump()` 这一层做最小修复，不改 renderer 协议面。

**Tech Stack:** Go 1.25、httptest、Gorilla WebSocket、stdio RPC encoder

---

### Task 1: 写掉线状态 failing integration test

**Files:**
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写最小 failing test**

新增 app-level 集成测试，覆盖：
- 建立本地 websocket server
- 通过 `ws.connect` 接通 Go core
- 等待 `ws.status.updated(authenticated)`
- 让 server 主动关闭连接
- 期待后续出现 `ws.status.updated(disconnected)` 与 `ws.status.get=disconnected`

- [x] **Step 2: 跑 RED**

Run: `cd desktop-el/go-core && go test ./internal/app -run TestAppWSPumpEmitsDisconnectedStatusWhenServerClosesConnection -count=1`
Expected: FAIL，暴露当前只有 `authenticated` 事件、缺少 `disconnected` 事件。

### Task 2: 最小修复 websocket 掉线事件透传

**Files:**
- Modify: `desktop-el/go-core/internal/app/app.go`

- [x] **Step 1: 补齐掉线状态事件**

在 `startWSPump()` 的 `ReadMessage` 错误分支里追加 `ws.status.updated` 发射，让 renderer 在远端主动断开时也能收到掉线事件。

- [x] **Step 2: 跑 GREEN**

Run:
- `cd desktop-el/go-core && go test ./internal/app -run TestAppWSPumpEmitsDisconnectedStatusWhenServerClosesConnection -count=1`
- `cd desktop-el/go-core && go test ./internal/app -run 'TestApp(ReceivesWebSocketPushEvent|WSJoinAndLeaveWriteWebSocketEvents|ChatTypingSendWritesWebSocketEvent)' -count=1`

Expected:
- 新增掉线状态测试 PASS
- 既有 websocket app-level 集成测试 PASS

### Task 3: 回填文档并固定验收

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Create: `docs/plans/2026-03-26-desktop-el-ws-status-integration-plan.md`

- [x] **Step 1: 回填 backlog**

记录本次补齐 websocket 掉线状态透传的 integration test 与修复。

- [x] **Step 2: 跑固定验收**

Run: `make desktop-el-verify`
Expected: PASS

- [ ] **Step 3: 提交并推送**

```bash
git add desktop-el/go-core/internal/app/app.go \
        desktop-el/go-core/internal/app/app_test.go \
        docs/plans/2026-03-24-desktop-el-migration-backlog.md \
        docs/plans/2026-03-26-desktop-el-ws-status-integration-plan.md
git commit -m "test(desktop-el): cover ws disconnect status updates"
git push
```
