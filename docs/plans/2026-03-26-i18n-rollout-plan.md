# RedCode IM 多语言总实施计划 Implementation Plan

> **For agentic workers:** REQUIRED WORKFLOW: Use `ce:work` to execute this plan task-by-task. If execution发现需求或范围变化，先回到 `ce:brainstorm` / `ce:plan` 更新文档；变更完成后使用 `ce:review` 审查。Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按统一协议完成 `backend`、`admin`、`frontend`、`desktop` 的多语言迁移，并以 `backend` 服务端本地化为中枢完成跨端联调与验收。

**Architecture:** 本次迁移拆成 4 个独立子计划，先固定 `backend` 的 `code + message_key + message` 协议，再由 `admin`、`frontend`、`desktop` 分别接入 UI 文案与 API message 兜底策略。实施顺序严格遵守“协议先行、客户端后接、最后联调”的依赖链，避免四端产生不同的错误展示逻辑。

**Tech Stack:** Rust/Axum、Vue 3/Vue I18n、Flutter/gen_l10n、Tauri、Docker Compose、Go 1.25 测试栈

---

### Task 1: 冻结总协议与实施顺序

**Files:**
- Reference: `docs/plans/2026-03-26-i18n-architecture-design.md`
- Reference: `docs/plans/2026-03-26-i18n-backend-plan.md`
- Reference: `docs/plans/2026-03-26-i18n-admin-plan.md`
- Reference: `docs/plans/2026-03-26-i18n-frontend-plan.md`
- Reference: `docs/plans/2026-03-26-i18n-desktop-plan.md`

- [ ] **Step 1: 先确认统一协议不再变动**
  - 锁定首批语言为 `zh-CN` / `en-US`。
  - 锁定 API 错误响应结构为 `code + message_key + message + message_params + details`。

- [ ] **Step 2: 先执行 `backend` 计划**
  - 执行入口：`docs/plans/2026-03-26-i18n-backend-plan.md`
  - 目标：先让 `backend` 成为跨端唯一的本地化 API 协议源。

- [ ] **Step 3: 按客户端优先级执行 `admin -> frontend -> desktop`**
  - `admin` 先补现有半迁移状态，快速收敛共享模式。
  - `frontend` 再建立 Flutter 正式 i18n 基建。
  - `desktop` 最后接入 `vue-i18n` 并清理非组件层文案。

### Task 2: 执行 Backend 子计划

**Files:**
- Execute: `docs/plans/2026-03-26-i18n-backend-plan.md`

- [ ] **Step 1: 完成 `backend/src/i18n/` 与错误协议改造**
- [ ] **Step 2: 迁移高频业务域并补语言包**
- [ ] **Step 3: 跑通 Rust + Go 黑盒测试栈**
- [ ] **Step 4: 产出 Backend 验收文档**

### Task 3: 执行 Admin 子计划

**Files:**
- Execute: `docs/plans/2026-03-26-i18n-admin-plan.md`

- [ ] **Step 1: 完成 `admin` i18n 基础设施与 API message resolver**
- [ ] **Step 2: 补齐公共壳层与高频页面 locale**
- [ ] **Step 3: 跑通 `type:check` 与 Playwright 烟测**
- [ ] **Step 4: 产出 Admin 验收文档**

### Task 4: 执行 Frontend 子计划

**Files:**
- Execute: `docs/plans/2026-03-26-i18n-frontend-plan.md`

- [ ] **Step 1: 完成 Flutter `gen_l10n` 基础设施**
- [ ] **Step 2: 迁移高频页面与共享组件**
- [ ] **Step 3: 跑通 `flutter test` 与集成 smoke**
- [ ] **Step 4: 产出 Frontend 验收文档**

### Task 5: 执行 Desktop 子计划

**Files:**
- Execute: `docs/plans/2026-03-26-i18n-desktop-plan.md`

- [ ] **Step 1: 完成 `desktop` 的 `vue-i18n` 与全局 `t()` 基础设施**
- [ ] **Step 2: 迁移壳层、高频页面、store/api/utils 文案**
- [ ] **Step 3: 跑通 `bun run type-check`、`bun run test` 与 Tauri 手工验证**
- [ ] **Step 4: 产出 Desktop 验收文档**

### Task 6: 跨端联调与最终验收

**Files:**
- Create: `docs/reports/2026-03-26-i18n-rollout-acceptance.md`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/index.md`

- [ ] **Step 1: 联调 API 多语言协议**
  - 用同一接口分别发 `zh-CN`、`en-US`、不支持语言头请求，确认 `message` 变化、`message_key` 稳定。

- [ ] **Step 2: 联调三端展示策略**
  - 验证三端都遵守“API `message` 优先、本地 `message_key` 兜底”。
  - 验证后端缺失翻译时，三端仍不会回退成随机硬编码。

- [ ] **Step 3: 运行各模块最终验证**
  - `backend`: `./tests/run.sh`
  - `admin`: `cd admin && bun run type:check`
  - `frontend`: `cd frontend && flutter test`
  - `desktop`: `cd desktop && bun run type-check && bun run test`

- [ ] **Step 4: 输出总验收报告并提交**
  - Run: `git add docs/reports/2026-03-26-i18n-rollout-acceptance.md docs/reference/testing/README.md docs/index.md && git commit -m "docs: record i18n rollout plan and acceptance"`
