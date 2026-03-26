# `desktop-el` ws.connect 失败状态事件实现计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`）跟踪状态。

**目标：** 补齐 `desktop-el` Go core app-level 集成测试与实现缺口，确保 `ws.connect` 失败时 renderer 仍能收到 `ws.status.updated(disconnected)`，避免桌面端停留在旧 websocket 状态。

**架构：** 保持现有 Electron/renderer 通过 stdio RPC 感知 websocket 状态的模式不变，不新增本地 HTTP 端口，不改 renderer 协议。只在 Go core `app.go` 的 `ws.connect` 失败路径补状态事件发射，并用 `internal/app/app_test.go` 的 app-level 集成测试锁住行为。

**技术栈：** Go 1.25、`httptest`、Gorilla WebSocket、Go core app-level 集成测试

---

### 任务 1：先写 failing test 锁定失败路径状态事件

**涉及文件：**
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/go-core/internal/app/app.go`

- [x] **Step 1: 增加 ws.connect 失败状态事件测试**

覆盖：
- `ws.connect` 握手失败时返回 RPC error
- 同时 stdout 会发出 `ws.status.updated(disconnected)`
- `ws.status.get` 仍保持 `disconnected`

- [x] **Step 2: 跑 RED**

运行：`cd desktop-el/go-core && go test ./internal/app -run TestAppWSConnectEmitsDisconnectedStatusWhenConnectFails`
预期：FAIL，提示没有等到 `ws.status.updated(disconnected)`。

### 任务 2：实现失败路径状态发射并让测试转绿

**涉及文件：**
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 调整 ws.connect 失败路径**

在 `a.wsClient.Connect(...)` 返回 error 时：
- 继续返回 RPC error
- 但先向 renderer 发出当前 websocket 状态事件

- [x] **Step 2: 跑 GREEN**

运行：`cd desktop-el/go-core && go test ./internal/app -run TestAppWSConnectEmitsDisconnectedStatusWhenConnectFails`
预期：PASS

### 任务 3：回填进度文档并跑固定验收

**涉及文件：**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-migration-progress-table.md`
- Modify: `docs/plans/2026-03-26-desktop-el-ws-connect-failure-status-plan.md`

- [x] **Step 1: 回填 `P2-3` 进度**

记录“Go core app-level 集成测试继续扩充”新增一刀，当前已覆盖 `ws.connect` 失败状态事件。

- [x] **Step 2: 跑固定验收**

运行：`make desktop-el-verify`
预期：PASS

- [x] **Step 3: 提交并推送**

```bash
git add desktop-el/go-core/internal/app/app.go \
        desktop-el/go-core/internal/app/app_test.go \
        docs/plans/2026-03-24-desktop-el-migration-backlog.md \
        docs/plans/2026-03-26-desktop-el-migration-progress-table.md \
        docs/plans/2026-03-26-desktop-el-ws-connect-failure-status-plan.md
git commit -m "test(desktop-el): cover ws connect failure status events"
git push
```
