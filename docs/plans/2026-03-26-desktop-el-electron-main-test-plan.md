# Desktop EL Electron Main Test Expansion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的 Electron main 层补齐 `dialog` 与 `notification` 的自动化测试，扩展现有 host 能力测试覆盖。

**Architecture:** 保持现有 main service 设计不变，只扩充 `electron/test-support` mock 能力并新增 `bun test` 用例。当前不引入 Playwright/e2e，不改 renderer 与 Go core 通信方式。

**Tech Stack:** Bun test、TypeScript、Electron mock、dialog service、notification service

---

### Task 1: 固定 dialog / notification 的测试预期

**Files:**
- Create: `desktop-el/electron/main/dialog.test.ts`
- Create: `desktop-el/electron/main/notification.test.ts`

- [x] **Step 1: 写失败测试**

```ts
test("dialog service forwards open and save options to electron dialog", async () => {})
test("notification service only creates notifications when host support is available", async () => {})
```

- [x] **Step 2: 运行测试确认失败**

Run: `cd desktop-el && bun test electron/main/dialog.test.ts electron/main/notification.test.ts`
Expected: FAIL，提示当前 `electron` mock 缺少 `dialog` / `Notification` 支撑。

### Task 2: 扩展 electron mock 并让测试转绿

**Files:**
- Modify: `desktop-el/electron/test-support/electron-mock.ts`
- Modify: `desktop-el/electron/main/dialog.test.ts`
- Modify: `desktop-el/electron/main/notification.test.ts`

- [x] **Step 1: 实现最小 mock 能力**

实现点：
- `dialog.showOpenDialog` / `dialog.showSaveDialog` 记录入参并返回可控结果
- `Notification.isSupported` 可在测试中切换
- Notification 实例记录构造入参与 `show()` 调用

- [x] **Step 2: 运行定向测试确认通过**

Run: `cd desktop-el && bun test electron/main/dialog.test.ts electron/main/notification.test.ts`
Expected: PASS

### Task 3: 完整验证、回填 backlog、提交推送与清理

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-electron-main-test-plan.md`

- [x] **Step 1: 运行完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 2: 更新 backlog、提交并推送**

```bash
git add docs/plans/2026-03-26-desktop-el-electron-main-test-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/electron/test-support/electron-mock.ts \
  desktop-el/electron/main/dialog.test.ts \
  desktop-el/electron/main/notification.test.ts
git commit -m "test(desktop-el): cover dialog and notification services"
git push
```

- [x] **Step 3: 运行清理**

Run: `make desktop-el-down`
Expected: 无残留开发实例。

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无输出。
