# Admin 鉴权韧性测试 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 补齐 Admin 登录失败、token 自动续签、续签失败回登录的 E2E 测试。

**Architecture:** 新增独立 Playwright spec，使用接口级 mock 构建可控鉴权状态机，验证登录页与受保护路由在异常情况下的行为一致性。

**Tech Stack:** Playwright Test、TypeScript、Vite Admin

---

### Task 1: 新增鉴权韧性 E2E 脚本

**Files:**
- Create: `admin/playwright-tests/specs/auth-resilience.spec.ts`

**Step 1: 写失败测试（Red）**
- 覆盖三类行为：登录失败、401+refresh 成功、401+refresh 失败。

**Step 2: 运行失败（Red）**
- `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test playwright-tests/specs/auth-resilience.spec.ts --workers=1`

**Step 3: 最小实现（Green）**
- 在新 spec 中补齐 mock 与断言。

**Step 4: 运行通过（Green）**
- 同 Step 2。

### Task 2: 文档与矩阵同步

**Files:**
- Modify: `admin/playwright-tests/README.md`
- Modify: `docs/reference/testing/matrix/admin.csv`
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

**Step 1: 更新文档口径**
- 增加鉴权韧性说明与执行入口。

**Step 2: 更新矩阵追踪**
- 新增 Admin Auth 分支条目。

### Task 3: 回归与交付

**Step 1: 执行 Admin 全量 E2E**
- `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test --workers=1`

**Step 2: 提交 + 推送**
- `git add ...`
- `git commit -m "test(admin): 增加鉴权韧性回归用例"`
- `git push`
