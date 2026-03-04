# Admin 全可达冒烟（含 4xx/5xx）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 Admin Playwright 从 5 条主链路扩展为“全路由可达 + 关键交互 + 4xx/5xx 异常”可复用测试架构，覆盖 default 与 data-cleanup 两套可达范围。

**Architecture:** 采用“路由用例清单 + 统一 Mock 夹具 + 数据驱动执行器”模式。测试按路由清单逐条运行：先验证可达与主交互，再对主接口注入 4xx/5xx 并校验页面可恢复。通过环境变量切换 default/data-cleanup 配置，复用同一套脚本。

**Tech Stack:** Playwright Test、TypeScript、Vite Admin、Arco Design

---

### Task 1: 路由清单与覆盖矩阵建模

**Files:**
- Create: `admin/playwright-tests/support/route-cases.ts`
- Modify: `docs/reference/testing/matrix/admin.csv`
- Modify: `docs/reference/testing/README.md`

**Step 1: 写路由清单测试（Red）**
- 新增用例，断言 route case 至少覆盖：
  - default 可达路由全集
  - data-cleanup 可达路由全集（含 `operations/data-cleanup`）

**Step 2: 运行测试确认失败（Red）**
- Run: `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --grep "route catalog" --workers=1`
- Expected: FAIL（route 清单未实现）

**Step 3: 实现最小清单（Green）**
- 在 `route-cases.ts` 定义：
  - `id/path/anchor/primaryEndpoint/profile/interactionHint`
  - dynamic 路由实化（roomId/userId）

**Step 4: 运行测试确认通过（Green）**
- Run 同 Step 2
- Expected: PASS

**Step 5: Commit**
```bash
git add admin/playwright-tests/support/route-cases.ts docs/reference/testing/matrix/admin.csv docs/reference/testing/README.md
git commit -m "test(admin): 建立全路由冒烟覆盖清单"
```

### Task 2: 统一 Mock 夹具（成功态 + 异常注入）

**Files:**
- Create: `admin/playwright-tests/support/mock-server.ts`
- Create: `admin/playwright-tests/support/test-context.ts`
- Modify: `admin/playwright-tests/specs/core-flows.spec.ts`

**Step 1: 写失败测试（Red）**
- 在新 spec 中新增“注入 403/500 后页面不崩溃”的最小断言。

**Step 2: 运行确认失败（Red）**
- Run: `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --grep "error branch" --workers=1`
- Expected: FAIL（缺少统一注入能力）

**Step 3: 实现最小 Mock 夹具（Green）**
- 统一提供：
  - 登录态注入（token/refresh_token + `/auth/admin/me`）
  - API 成功响应基线（覆盖全路由首屏请求）
  - 按 endpoint 注入一次 4xx/5xx
  - 外部地图资源兜底（防止第三方 GeoJSON 波动）

**Step 4: 运行确认通过（Green）**
- Run 同 Step 2
- Expected: PASS

**Step 5: Commit**
```bash
git add admin/playwright-tests/support/mock-server.ts admin/playwright-tests/support/test-context.ts admin/playwright-tests/specs/core-flows.spec.ts
git commit -m "test(admin): 抽离可复用 mock 夹具并支持异常注入"
```

### Task 3: 全路由可达 + 关键交互 + 4xx/5xx 脚本

**Files:**
- Create: `admin/playwright-tests/specs/route-smoke.spec.ts`
- Modify: `admin/package.json`

**Step 1: 写失败测试（Red）**
- 新建数据驱动 spec，先只接一条路由，断言：
  - 可达
  - 至少 1 个关键交互
  - 403/500 注入后仍可恢复

**Step 2: 运行确认失败（Red）**
- Run: `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1`
- Expected: FAIL

**Step 3: 实现最小可用脚本（Green）**
- 扩展到全量路由（按 profile 过滤）
- 每条路由执行：
  - success smoke（可达 + anchor + interaction）
  - error smoke（403 + 500）

**Step 4: 运行确认通过（Green）**
- Run 同 Step 2
- Expected: PASS

**Step 5: Commit**
```bash
git add admin/playwright-tests/specs/route-smoke.spec.ts admin/package.json
git commit -m "test(admin): 新增全路由冒烟与异常分支脚本"
```

### Task 4: 文档与验收入口收敛

**Files:**
- Modify: `admin/playwright-tests/README.md`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reference/testing/matrix/admin.csv`

**Step 1: 写失败检查（Red）**
- 增加“文档与命令一致性”检查（人工核对清单）。

**Step 2: 更新文档（Green）**
- 给出两套执行方式：
  - default（不含 data-cleanup 路由）
  - data-cleanup（含 data-cleanup 路由）
- 给出发布前推荐命令与最小验收标准。

**Step 3: 验证（Green）**
- Run:
  - `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 ADMIN_ROUTE_PROFILE=default pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1`
  - `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 ADMIN_ROUTE_PROFILE=data-cleanup pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1`
- Expected: 两套 profile 均 PASS

**Step 4: Commit**
```bash
git add admin/playwright-tests/README.md docs/reference/testing/README.md docs/reference/testing/matrix/admin.csv docs/plans/2026-03-05-admin-full-route-smoke-plan.md
git commit -m "docs(testing): 补充 admin 全路由冒烟执行与验收标准"
```

### Task 5: 最终回归与交付

**Files:**
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`（追加 Admin 新回归记录）

**Step 1: 全量验证**
- Run: `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test --workers=1`
- Run: `cd tests/go && go test ./backend/admin -v`

**Step 2: 记录结果**
- 写入通过率、失败修复、残余风险（若有）。

**Step 3: Commit + Push**
```bash
git add docs/reports/2026-03-04-full-module-regression-acceptance.md
git commit -m "test(admin): 完成全可达冒烟与异常分支验收"
git push
```
