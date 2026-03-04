# 跨模块测试扩展 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成 Frontend 深化、Desktop、Website 三模块测试扩展并通过全量回归。

**Architecture:** 采用“按模块独立 TDD + 统一回归”的执行方式：每个模块先写失败测试，再做最小修复，最后汇总三模块回归结果并更新矩阵和验收报告。

**Tech Stack:** Flutter Test、Vitest、TypeScript、Dart

---

### Task 1: Frontend 配置服务测试补齐

**Files:**
- Create: `frontend/test/core/settings_service_test.dart`
- Modify: `docs/reference/testing/matrix/frontend.csv`

**Step 1: 写失败测试（Red）**
- 覆盖：`fetchAppName` 成功/失败回退、`fetchPrivacyPolicy` 数据格式异常。

**Step 2: 运行失败测试（Red）**
- Run: `cd frontend && flutter test test/core/settings_service_test.dart`

**Step 3: 最小实现（Green）**
- 尽量仅新增测试，不改生产逻辑。

**Step 4: 运行通过（Green）**
- Run 同 Step 2。

### Task 2: Desktop 高价值链路测试补齐

**Files:**
- Create: `desktop/test/store/accounts.actions.test.ts`
- Create: `desktop/test/utils/cache.test.ts`
- Create: `desktop/test/api/message.transform-and-send.test.ts`
- Modify: `desktop/test/api/message-search.test.ts`
- Modify: `docs/reference/testing/matrix/desktop.csv`

**Step 1: 写失败测试（Red）**
- accounts actions、cache 回退、message 映射/发送异常、message-search 异常分支。

**Step 2: 运行失败测试（Red）**
- Run: `cd desktop && bun run test`

**Step 3: 最小实现（Green）**
- 优先不改生产代码；如发现真实缺陷再最小修复。

**Step 4: 运行通过（Green）**
- Run 同 Step 2。

### Task 3: Website 下载工具边界测试补齐

**Files:**
- Modify: `website/test/download-utils.test.ts`
- Modify: `docs/reference/testing/matrix/website.csv`

**Step 1: 写失败测试（Red）**
- 覆盖 store/package 边界、payload fallback、平台识别边界。

**Step 2: 运行失败测试（Red）**
- Run: `cd website && bun run test`

**Step 3: 最小实现（Green）**
- 优先仅补测试，不引入额外依赖。

**Step 4: 运行通过（Green）**
- Run 同 Step 2。

### Task 4: 三模块统一回归与交付

**Files:**
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

**Step 1: 统一回归执行**
- `cd frontend && flutter test`
- `cd desktop && bun run test`
- `cd website && bun run test`

**Step 2: 更新文档**
- 记录新增链路、命令、结果、风险。

**Step 3: 提交与推送**
- `git add ...`
- `git commit -m "test: 扩展前端/桌面/网站测试链路"`
- `git push`
