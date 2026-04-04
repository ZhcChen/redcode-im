# Admin 多语言迁移 Implementation Plan

> **For agentic workers:** REQUIRED WORKFLOW: Use `ce:work` to execute this plan task-by-task. If execution发现需求或范围变化，先回到 `ce:brainstorm` / `ce:plan` 更新文档；变更完成后使用 `ce:review` 审查。Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 `vue-i18n` 基础上补齐 `admin` 多语言覆盖，统一 UI 文案与 API 错误展示策略，并完成中英文对齐。

**Architecture:** 保留 [admin/src/locale/index.ts](/Users/chen/code/redcode-im/admin/src/locale/index.ts) 作为全局入口，新增长尾共享文案与 API message 解析辅助层，优先迁移公共壳层与高频页面，再补缺失的 locale 文件。运行验证采用 `vue-tsc` + Playwright 路由烟测。

**Tech Stack:** Vue 3、Vue I18n、TypeScript、Arco Design、Playwright

---

### Task 1: 收口 Admin i18n 基础设施与 API message 解析

**Files:**
- Create: `admin/src/locale/common/errors.ts`
- Create: `admin/src/locale/common/index.ts`
- Create: `admin/src/utils/i18n.ts`
- Modify: `admin/src/locale/index.ts`
- Modify: `admin/src/hooks/locale.ts`
- Modify: `admin/src/api/interceptor.ts`

- [ ] **Step 1: 先写失败测试或断言脚本**
  - 为 `admin/src/utils/i18n.ts` 设计最小单元验证，确认 `message` 优先、`message_key` 本地兜底、最终再兜底默认错误文案。
  - 在 `interceptor.ts` 中先补一处失败断言，确保没有 `message` 时不会直接退回英文硬编码 `Error`。

- [ ] **Step 2: 新增 API message 解析辅助**
  - 抽出统一解析函数，支持后端返回 `message`、`message_key`、`message_params`。
  - 在 `axios` 响应拦截器中改用统一解析，不再散落中文/英文硬编码错误提示。

- [ ] **Step 3: 规范化 locale 入口**
  - 将公共错误文案和共享动作文案合并到 `admin/src/locale/common/`。
  - 保持 `zh-CN` / `en-US` 为首批唯二语言，统一 fallback 口径。

- [ ] **Step 4: 运行类型检查**
  - Run: `cd admin && bun run type:check`
  - Expected: `vue-tsc` 通过，`interceptor` 与 locale 入口无类型错误。

- [ ] **Step 5: 提交基础设施改动**
  - Run: `git add admin/src/locale admin/src/utils/i18n.ts admin/src/api/interceptor.ts admin/src/hooks/locale.ts && git commit -m "feat(admin): add i18n message resolver"`

### Task 2: 迁移公共壳层与共享组件硬编码文案

**Files:**
- Modify: `admin/src/App.vue`
- Modify: `admin/src/layout/default-layout.vue`
- Modify: `admin/src/layout/page-layout.vue`
- Modify: `admin/src/components/navbar/index.vue`
- Modify: `admin/src/components/breadcrumb/index.vue`
- Modify: `admin/src/components/footer/index.vue`
- Modify: `admin/src/components/message-box/index.vue`
- Modify: `admin/src/components/message-box/list.vue`
- Modify: `admin/src/components/message-box/locale/zh-CN.ts`
- Modify: `admin/src/components/message-box/locale/en-US.ts`

- [ ] **Step 1: 扫描公共壳层硬编码文案**
  - 用 `rg '[一-龥]' admin/src/App.vue admin/src/layout admin/src/components` 收口待迁移文案。
  - 标记哪些已经有现成 key，哪些需要新增共享 key。

- [ ] **Step 2: 用共享 key 替换硬编码**
  - 页面壳层、导航、消息盒子全部改为 `$t(...)` 或组合式 `t(...)`。
  - 不在模板里保留中文/英文字面量。

- [ ] **Step 3: 补齐 `zh-CN` / `en-US` 共享文案**
  - 新增的公共 key 必须两份语言同时补齐。
  - 保持 key 命名与 backend 协议的错误 key 区分，避免混用。

- [ ] **Step 4: 运行类型检查与最小页面验证**
  - Run: `cd admin && bun run type:check`
  - Expected: 壳层组件与共享 locale 引用全部通过。

- [ ] **Step 5: 提交公共壳层改动**
  - Run: `git add admin/src/App.vue admin/src/layout admin/src/components admin/src/locale && git commit -m "feat(admin): localize shared layout and components"`

### Task 3: 迁移高频页面一：登录、聊天记录、举报与反馈

**Files:**
- Modify: `admin/src/views/login/index.vue`
- Modify: `admin/src/views/login/components/login-form.vue`
- Modify: `admin/src/views/login/components/banner.vue`
- Modify: `admin/src/views/login/locale/zh-CN.ts`
- Modify: `admin/src/views/login/locale/en-US.ts`
- Modify: `admin/src/views/chat-history/list/index.vue`
- Create: `admin/src/views/chat-history/locale/en-US.ts`
- Modify: `admin/src/views/chat-history/locale/zh-CN.ts`
- Modify: `admin/src/views/report/list/index.vue`
- Create: `admin/src/views/report/list/locale/en-US.ts`
- Modify: `admin/src/views/report/list/locale/zh-CN.ts`
- Modify: `admin/src/views/feedback/list/index.vue`
- Modify: `admin/src/views/feedback/list/locale/zh-CN.ts`
- Modify: `admin/src/views/feedback/list/locale/en-US.ts`

- [ ] **Step 1: 先为缺失 locale 的页面补英文文件**
  - `chat-history` 与 `report` 当前只有中文，先补 `en-US.ts` 骨架，避免迁移过程中 key 漂移。

- [ ] **Step 2: 替换高频页面中的硬编码**
  - 登录、聊天记录、举报、反馈页中的表头、按钮、弹窗标题、状态文案全部替换为 `$t(...)`。
  - 特别处理弹窗、预览框和表格列标题中的漏网硬编码。

- [ ] **Step 3: 接入 API 错误解析**
  - 对依赖 backend 错误提示的操作页，统一走 `interceptor`/`resolveApiMessage`。
  - 确保后端返回 `message_key` 时，页面仍能通过本地文案兜底。

- [ ] **Step 4: 运行类型检查与定向路由烟测**
  - Run: `cd admin && bun run type:check`
  - Run: `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://127.0.0.1:5173 bun run test:e2e:routes`
  - Expected: 类型检查通过；在本地 admin dev server 已启动时，路由烟测通过。

- [ ] **Step 5: 提交高频页面一改动**
  - Run: `git add admin/src/views/login admin/src/views/chat-history admin/src/views/report admin/src/views/feedback && git commit -m "feat(admin): localize login and audit views"`

### Task 4: 迁移高频页面二：用户、设置、仪表盘

**Files:**
- Modify: `admin/src/views/user-management/list/index.vue`
- Modify: `admin/src/views/user-management/list/locale/zh-CN.ts`
- Modify: `admin/src/views/user-management/list/locale/en-US.ts`
- Modify: `admin/src/views/settings/captcha/index.vue`
- Modify: `admin/src/views/settings/captcha/locale/zh-CN.ts`
- Modify: `admin/src/views/settings/captcha/locale/en-US.ts`
- Modify: `admin/src/views/settings/ipinfo-token/index.vue`
- Modify: `admin/src/views/settings/ipinfo-token/locale/zh-CN.ts`
- Modify: `admin/src/views/settings/ipinfo-token/locale/en-US.ts`
- Modify: `admin/src/views/dashboard/workplace/index.vue`
- Modify: `admin/src/views/dashboard/workplace/locale/zh-CN.ts`
- Modify: `admin/src/views/dashboard/workplace/locale/en-US.ts`
- Modify: `admin/src/views/dashboard/monitor/index.vue`
- Modify: `admin/src/views/dashboard/monitor/locale/zh-CN.ts`
- Modify: `admin/src/views/dashboard/monitor/locale/en-US.ts`

- [ ] **Step 1: 清点剩余高频视图硬编码**
  - 用 `rg -l '[一-龥]' admin/src/views --glob '!**/locale/**'` 收口仍未迁移的视图。
  - 先覆盖后台常用入口：用户管理、系统设置、仪表盘。

- [ ] **Step 2: 逐页替换并补齐 locale**
  - 保持现有 `meta.locale` 路由策略不变。
  - 页面内部操作按钮、状态标签、表格文案与空态文案全部走 locale。

- [ ] **Step 3: 验证切换语言后的 UI 一致性**
  - 手工检查顶部语言切换后，目标页面主文案是否同步刷新。
  - 若发现局部缓存未更新，补必要响应式修正。

- [ ] **Step 4: 运行完整 Admin 验证**
  - Run: `cd admin && bun run type:check`
  - Run: `cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://127.0.0.1:5173 bun run test:e2e`
  - Expected: 类型检查通过；在本地 admin dev server 已启动时，E2E 不因 i18n 改造出现新增回归。

- [ ] **Step 5: 提交高频页面二改动**
  - Run: `git add admin/src/views admin/src/locale admin/src/router && git commit -m "feat(admin): localize dashboard user and settings views"`

### Task 5: 文档、迁移清单与验收

**Files:**
- Create: `docs/reports/2026-03-26-admin-i18n-acceptance.md`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/index.md`

- [ ] **Step 1: 记录 Admin 多语言覆盖范围**
  - 在验收文档中列出已迁移页面、未覆盖长尾页面与剩余硬编码扫描结果。

- [ ] **Step 2: 更新测试与文档入口**
  - 在测试总览中记录 Admin i18n 的验证命令和前置条件。
  - 如有必要，在 `docs/index.md` 补计划/验收文档索引。

- [ ] **Step 3: 运行最终验证**
  - Run: `cd admin && bun run type:check`
  - Expected: 最终交付前类型检查保持全绿。

- [ ] **Step 4: 提交文档**
  - Run: `git add docs/reports/2026-03-26-admin-i18n-acceptance.md docs/reference/testing/README.md docs/index.md && git commit -m "docs(admin): record i18n rollout acceptance"`
