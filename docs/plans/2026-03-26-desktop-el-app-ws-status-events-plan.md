# `desktop-el` Go core 账号链路 websocket 状态事件测试计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`）跟踪状态。

**目标：** 扩充 `desktop-el` Go core `internal/app` 的 app-level 集成测试，覆盖账号恢复、账号切换与登出三条主链路在主动断开 websocket 时都会向 renderer 发出 `ws.status.updated(disconnected)`。

**架构：** 不改 renderer，不改 Electron，不改 Go core RPC 契约；只在 `internal/app/app_test.go` 增加 app-level 断言，直接验证 stdio 事件输出。当前只补账号链路断开态，不扩展到更细 websocket 重连策略。

**技术栈：** Go 1.25、testing、`internal/app`、stdio RPC event encoder

---

### 任务 1：补账号链路断开态集成测试

**涉及文件：**
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 新增 restore / switch / logout 的状态事件测试**

覆盖：
- `auth.accounts.restore` 触发主动断开后会输出 `ws.status.updated(disconnected)`
- `auth.account.switch` 触发主动断开后会输出 `ws.status.updated(disconnected)`
- `auth.logout` 触发主动断开后会输出 `ws.status.updated(disconnected)`

- [x] **Step 2: 跑定向验证**

运行：`cd desktop-el/go-core && go test ./internal/app -run TestAppAuth.*WSStatusUpdated`
预期：PASS

### 任务 2：回填进度并做固定验收

**涉及文件：**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-migration-progress-table.md`
- Modify: `docs/plans/2026-03-26-desktop-el-app-ws-status-events-plan.md`

- [x] **Step 1: 回填进度**

记录 `P2-3` 已补账号恢复 / 切换 / 登出的 websocket 断开态 app-level 集成测试。

- [x] **Step 2: 跑固定验收**

运行：`make desktop-el-verify`
预期：PASS

- [x] **Step 3: 提交并推送**

```bash
git add desktop-el/go-core/internal/app/app_test.go \
        docs/plans/2026-03-24-desktop-el-migration-backlog.md \
        docs/plans/2026-03-26-desktop-el-migration-progress-table.md \
        docs/plans/2026-03-26-desktop-el-app-ws-status-events-plan.md
git commit -m "test(desktop-el): cover account ws status events"
git push
```
