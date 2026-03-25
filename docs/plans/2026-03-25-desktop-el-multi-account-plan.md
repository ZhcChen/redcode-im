# Desktop EL Multi-Account Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 打通“多账号登录并存 + 当前账号切换 + 当前账号登出后自动切到剩余账号 + 每账号独立基础视图状态”的最小闭环。

**Architecture:** 保持 Electron 只做宿主壳、Go core 承接登录态与当前激活账号、renderer 通过 stdio RPC 管理账号切换。当前只做“每账号 token / user / activeView / ws 重连”的最小骨架，不额外引入本地 HTTP 端口，也不提前做未读数汇总和复杂路由恢复。

**Tech Stack:** Vue 3、TypeScript、Bun test、Go 1.25、stdio RPC、Electron preload、Go core session/bootstrap

---

### Task 1: 固定 renderer 多账号 store 预期

**Files:**
- Create: `desktop-el/renderer/src/store/session.test.ts`
- Modify: `desktop-el/renderer/src/store/session.ts`
- Modify: `desktop-el/renderer/src/types/bootstrap.ts`

- [x] **Step 1: 写 renderer store 失败测试**

```ts
test("adds accounts and switches current account with per-account active view", () => {
  // 登录两个账号后，切换账号时应恢复该账号自己的 activeView。
})

test("hydrates accounts from bootstrap snapshot without losing current access token", () => {
  // bootstrap 返回账号快照后，应同步账号列表和当前账号用户信息。
})
```

- [x] **Step 2: 运行 store 测试确认失败**

Run: `cd desktop-el && bun test renderer/src/store/session.test.ts`
Expected: FAIL，提示缺少多账号 state / API。

- [x] **Step 3: 实现 store 多账号骨架**

```ts
interface SessionAccount {
  id: string
  token: string | null
  user: LegacyUserInfo
  activeView: HomeView
}

interface SessionState {
  accounts: SessionAccount[]
  currentAccountId: string | null
}
```

实现点：
- `setAuthenticated` 改为“upsert 当前账号并激活”
- `setActiveView` 改为保存到当前账号，而不是全局单值
- `switchAccount`、`removeAccount`、`hydrateFromBootstrap` 补齐
- bootstrap `accounts` 类型补到当前最小字段，供主壳切换器展示

- [x] **Step 4: 运行 store 测试确认通过**

Run: `cd desktop-el && bun test renderer/src/store/session.test.ts`
Expected: PASS

- [x] **Step 5: 提交当前子闭环**

```bash
git add desktop-el/renderer/src/store/session.ts \
  desktop-el/renderer/src/store/session.test.ts \
  desktop-el/renderer/src/types/bootstrap.ts
git commit -m "feat(desktop-el): add multi-account renderer store"
```

### Task 2: 固定 Go core 多账号 session / bootstrap / switch RPC

**Files:**
- Modify: `desktop-el/go-core/internal/session/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写 Go core 失败测试**

```go
func TestAppBootstrapIncludesAccountsAndCurrentUser(t *testing.T) {}
func TestAppAuthSwitchAccountActivatesStoredSession(t *testing.T) {}
func TestAppAuthLogoutFallsBackToRemainingAccount(t *testing.T) {}
```

- [x] **Step 2: 运行 Go 测试确认失败**

Run: `cd desktop-el/go-core && go test ./internal/app`
Expected: FAIL，提示缺少多账号 session / switch 行为。

- [x] **Step 3: 实现 Go core 多账号状态**

```go
type AccountSession struct {
  UserID       string
  AccessToken  string
  RefreshToken string
  CurrentUser  *state.UserSnapshot
}
```

实现点：
- session service 支持 `UpsertAndActivate`、`Switch`、`RemoveCurrentOrSwitch`、`AccountsSnapshot`
- `auth.login` / `auth.login.sms` 登录成功时写入账号表并激活
- 新增 `auth.account.switch` RPC，切换 Go core 当前账号和 HTTP token
- `auth.logout` 改为移除当前账号；若还有剩余账号，则自动切到第一个剩余账号；若没有，则清空
- bootstrap 快照返回 `accounts` 与当前 `auth`

- [x] **Step 4: 运行 Go 测试确认通过**

Run: `cd desktop-el/go-core && go test ./internal/app`
Expected: PASS

- [x] **Step 5: 提交当前子闭环**

```bash
git add desktop-el/go-core/internal/session/service.go \
  desktop-el/go-core/internal/auth/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/state/snapshot.go \
  desktop-el/go-core/internal/app/app_test.go
git commit -m "feat(desktop-el): add multi-account core session"
```

### Task 3: 接通主壳账号切换 UI 与 ws 重连

**Files:**
- Modify: `desktop-el/renderer/src/App.vue`
- Modify: `desktop-el/renderer/src/components/HomeShell.vue`
- Modify: `desktop-el/renderer/src/components/LoginScreen.vue`
- Modify: `desktop-el/renderer/src/api/system.ts`
- Create: `desktop-el/renderer/src/utils/session-account-switch.ts`
- Create: `desktop-el/renderer/src/utils/session-account-switch.test.ts`

- [x] **Step 1: 写账号切换 helper 失败测试**

```ts
test("builds reconnect plan for switching to another stored account", () => {})
test("builds logout fallback plan when another account remains", () => {})
```

- [x] **Step 2: 运行 helper 测试确认失败**

Run: `cd desktop-el && bun test renderer/src/utils/session-account-switch.test.ts`
Expected: FAIL，提示 helper 缺失。

- [x] **Step 3: 实现 App / HomeShell 多账号闭环**

实现点：
- `HomeShell` 增加最小账号切换器，展示当前账号与其他已登录账号
- 登录成功后，账号进入列表，不再覆盖清空旧账号
- 点击切换账号时先调用 `auth.account.switch`，再断开并重连 ws，最后刷新 bootstrap
- 当前账号登出后，若还有剩余账号，则自动切到剩余账号并重连 ws；否则回到登录页
- 所有 ws 连接仍只保持一个活动实例，避免多开

- [x] **Step 4: 运行 renderer 定向测试**

Run: `cd desktop-el && bun test renderer/src/utils/session-account-switch.test.ts renderer/src/store/session.test.ts renderer/src/api/websocket.test.ts`
Expected: PASS

- [x] **Step 5: 运行完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

Run: `cd desktop-el/go-core && go test ./...`
Expected: PASS

- [x] **Step 6: 更新 backlog / 计划状态并提交**

```bash
git add docs/plans/2026-03-25-desktop-el-multi-account-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/App.vue \
  desktop-el/renderer/src/components/HomeShell.vue \
  desktop-el/renderer/src/api/system.ts \
  desktop-el/renderer/src/api/websocket.ts \
  desktop-el/renderer/src/utils/session-account-switch.ts \
  desktop-el/renderer/src/utils/session-account-switch.test.ts
git commit -m "feat(desktop-el): support multi-account switching"
git push
```

### Task 4: 收尾与运行清理

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 关闭 desktop-el 相关进程**

Run: `make desktop-el-down`
Expected: 停止已有开发中的 Electron / Go core 进程。

- [x] **Step 2: 验证没有残留进程**

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无输出。

- [x] **Step 3: 推进 backlog 状态**

将 `P2-1` 已完成项回填到 backlog，保留仍未迁移的更深项：
- 每账号更深 route/pageState
- 未读数 / 好友请求数聚合
- 跨重启更强持久化
