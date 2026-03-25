# Desktop EL Renderer Smoke Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 增加独立的 renderer 级 smoke 验证，覆盖“宿主启动初始化 -> 登录 -> 进入 HomeShell”的最小浏览器闭环。

**Architecture:** 使用 Playwright 跑浏览器级 smoke，目标页面来自 `bun run build` 后的 `vite preview`，并在页面脚本执行前通过 `addInitScript` 注入最小 `window.desktopEl` mock。该 smoke 保持独立入口，不并入当前 `desktop-el-verify`，避免把 Playwright 浏览器依赖强耦合进默认快速验收链路。

**Tech Stack:** Playwright Test、Vite preview、Vue 3、TypeScript、Bun、Makefile

---

### Task 1: 落计划与 smoke 入口边界

**Files:**
- Create: `docs/plans/2026-03-26-desktop-el-renderer-smoke-plan.md`
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 明确 smoke 目标**

仅覆盖最小主链路：
1. 页面启动时识别 `window.desktopEl`
2. 完成 `core.bootstrap.get` / `core.config.get` / `app.getVersion` 初始化
3. 在登录页输入账号密码并触发登录
4. 进入 `HomeShell` 并断言主导航文案

- [x] **Step 2: 约束运行方式**

保持为独立入口：
- `bun run smoke`
- `make desktop-el-smoke`

- [x] **Step 3: 回填 backlog**

把 `P2-3 renderer 级 smoke / e2e 方案` 标记为进行中，并引用新增计划文档。

### Task 2: 先写 failing smoke 测试

**Files:**
- Create: `desktop-el/playwright.config.ts`
- Create: `desktop-el/smoke/app-smoke.spec.ts`
- Create: `desktop-el/smoke/support/mock-desktop-el.ts`
- Modify: `desktop-el/package.json`

- [x] **Step 1: 安装测试依赖并声明脚本**

新增 `@playwright/test` 依赖与 `smoke` 脚本，脚本负责执行单独的 Playwright 配置。

- [x] **Step 2: 写最小 failing smoke**

在 `app-smoke.spec.ts` 中定义一个测试：
- 打开 `/`
- 断言初始登录页文案
- 输入账号密码并点击“登录账号”
- 断言 `HomeShell` 导航文案出现

mock 中先只提供最小 `window.desktopEl` 能力，故意让关键调用未满足或返回值不完整，让测试先失败。

- [x] **Step 3: 跑 smoke 验证 RED**

Run: `cd desktop-el && bun run smoke`
Expected: FAIL，失败原因应指向缺失的宿主 mock 或初始化返回值不符合 renderer 预期。

### Task 3: 实现最小宿主 mock 让 smoke 通过

**Files:**
- Modify: `desktop-el/smoke/support/mock-desktop-el.ts`
- Modify: `desktop-el/smoke/app-smoke.spec.ts`

- [x] **Step 1: 完整补齐初始化依赖**

在 mock 中补齐以下最小能力：
- `rpc.invoke`
- `rpc.onEvent`
- `app.getVersion`
- `window.setTitle/hide/focus/show/requestAttention`
- `dialog.open/save`
- `notification.isSupported/show`
- `file.saveFromURL/getCachedPath/cacheFromURL/openPath`

- [x] **Step 2: 补齐登录链路返回值**

为以下调用返回稳定数据：
- `core.bootstrap.get`
- `core.config.get`
- 登录相关 RPC
- websocket connect/status

- [x] **Step 3: 跑 smoke 验证 GREEN**

Run: `cd desktop-el && bun run smoke`
Expected: PASS，且能稳定进入 `HomeShell`。

### Task 4: 接入文档与根命令入口

**Files:**
- Modify: `desktop-el/README.md`
- Modify: `Makefile`

- [x] **Step 1: 更新 README**

补充 smoke 依赖、命令与适用场景说明，强调其为独立浏览器级验收，不替代 `bun run verify`。

- [x] **Step 2: 更新根 Makefile**

新增 `desktop-el-smoke` 目标，并在注释中说明用途。

- [x] **Step 3: 验证命令入口**

Run: `make desktop-el-smoke`
Expected: PASS

### Task 5: 完成回填、验证与提交

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 更新 backlog**

将 `P2-3 renderer 级 smoke / e2e 方案` 标记为已完成，并补充当前采用 Playwright smoke 的说明。

- [x] **Step 2: 跑固定验收**

Run:
- `cd desktop-el && bun run smoke`
- `cd desktop-el && bun run verify`

Expected:
- smoke PASS
- 既有 verify PASS

- [x] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-26-desktop-el-renderer-smoke-plan.md \
        docs/plans/2026-03-24-desktop-el-migration-backlog.md \
        Makefile \
        desktop-el/README.md \
        desktop-el/package.json \
        desktop-el/playwright.config.ts \
        desktop-el/smoke/app-smoke.spec.ts \
        desktop-el/smoke/support/mock-desktop-el.ts
git commit -m "test(desktop-el): add renderer smoke coverage"
git push
```
