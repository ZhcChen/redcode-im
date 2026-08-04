---
status: archived
archived_at: 2026-08-04
archived_reason: 2.0 主线未包含多语言需求，本计划无活跃执行方
---

# Desktop 多语言迁移 Implementation Plan

> **For agentic workers:** REQUIRED WORKFLOW: Use `ce:work` to execute this plan task-by-task. If execution发现需求或范围变化，先回到 `ce:brainstorm` / `ce:plan` 更新文档；变更完成后使用 `ce:review` 审查。Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有 `desktop` Tauri 模块接入 `vue-i18n`，补齐高频 UI 与非组件层文本，并实现 backend `message/message_key` 的统一消费策略。

**Architecture:** 以 [desktop/src/main.ts](/Users/chen/code/redcode-im/desktop/src/main.ts) 为接入点新增 `vue-i18n`，把 locale 状态与全局 `t()` 能力下沉到独立模块，使组件、`store`、`api`、`utils` 都能访问统一翻译入口。优先迁移应用壳层、登录/主页/设置，再迁移消息、联系人与工具层提示。

**Tech Stack:** Vue 3、Vue I18n、TypeScript、Vuex、Vitest、Tauri

---

### Task 1: 建立 Desktop i18n 基础设施与全局 `t()` 入口

**Files:**
- Create: `desktop/src/i18n/index.ts`
- Create: `desktop/src/i18n/messages/zh-CN/common.ts`
- Create: `desktop/src/i18n/messages/en-US/common.ts`
- Create: `desktop/src/i18n/messages/zh-CN/errors.ts`
- Create: `desktop/src/i18n/messages/en-US/errors.ts`
- Create: `desktop/src/utils/i18n.ts`
- Modify: `desktop/package.json`
- Modify: `desktop/src/main.ts`
- Modify: `desktop/src/store/index.ts`

- [ ] **Step 1: 先写失败测试**
  - 为 `desktop/src/utils/i18n.ts` 写最小测试，验证在非组件层可以通过统一入口取文案。
  - 为应用入口写一条失败断言，确认 `main.ts` 尚未注入 i18n plugin。

- [ ] **Step 2: 引入 `vue-i18n` 并创建消息入口**
  - 在 `desktop/package.json` 中增加 `vue-i18n`。
  - 新建 `desktop/src/i18n/index.ts` 与中英文共享文案文件。

- [ ] **Step 3: 在应用入口与 store 层接线**
  - 在 `main.ts` 中 `app.use(i18n)`。
  - 在 `store/index.ts` 中把明显的中文时间/状态文本改为通过统一 `t()` 访问。

- [ ] **Step 4: 运行类型检查与单测**
  - Run: `cd desktop && bun install`
  - Run: `cd desktop && bun run type-check`
  - Run: `cd desktop && bun run test`
  - Expected: i18n 基础设施接入后，类型检查与 Vitest 通过。

- [ ] **Step 5: 提交基础设施改动**
  - Run: `git add desktop/package.json desktop/src/i18n desktop/src/utils/i18n.ts desktop/src/main.ts desktop/src/store/index.ts && git commit -m "feat(desktop): add vue i18n foundation"`

### Task 2: 统一 API 错误展示与 backend `message_key` 兜底

**Files:**
- Create: `desktop/src/api/message-resolver.ts`
- Modify: `desktop/src/api/http.ts`
- Modify: `desktop/src/api/user.ts`
- Modify: `desktop/src/api/friend.ts`
- Modify: `desktop/src/api/group.ts`
- Modify: `desktop/src/api/message.ts`
- Modify: `desktop/src/api/search.ts`
- Modify: `desktop/src/api/settings.ts`
- Modify: `desktop/src/utils/toast.ts`

- [ ] **Step 1: 先定义 message 解析规则**
  - 统一抽象 `message` 优先、本地 `message_key` + `params` 兜底、最后兜底默认错误文案。
  - 不允许各个 API 文件继续各自拼装中文提示。

- [ ] **Step 2: 在 HTTP 层接入解析器**
  - `desktop/src/api/http.ts` 统一处理后端错误响应。
  - `toast` 层只负责显示，不再决定具体文案来源。

- [ ] **Step 3: 替换主要 API 模块中的自由字符串**
  - 用户、好友、群组、消息、搜索、设置域逐步改用统一解析器。
  - 避免再在 API 层直接写中文/英文错误提示。

- [ ] **Step 4: 运行类型检查**
  - Run: `cd desktop && bun run type-check`
  - Expected: API 层与 toast 层无类型错误。

- [ ] **Step 5: 提交 API/message resolver 改动**
  - Run: `git add desktop/src/api desktop/src/utils/toast.ts && git commit -m "feat(desktop): localize api error handling"`

### Task 3: 迁移高频壳层与页面：登录、首页、设置

**Files:**
- Modify: `desktop/src/App.vue`
- Modify: `desktop/src/views/Login.vue`
- Modify: `desktop/src/views/Home.vue`
- Modify: `desktop/src/views/Settings.vue`
- Modify: `desktop/src/views/GeneralSettings.vue`
- Modify: `desktop/src/views/Privacy.vue`
- Modify: `desktop/src/components/SideMenu.vue`
- Modify: `desktop/src/components/AccountLoginModal.vue`
- Modify: `desktop/src/components/AccountHome.vue`
- Modify: `desktop/src/components/ConfirmDialog.vue`
- Modify: `desktop/src/components/Dialog.vue`
- Modify: `desktop/src/components/Toast.vue`
- Modify: `desktop/src/i18n/messages/zh-CN/common.ts`
- Modify: `desktop/src/i18n/messages/en-US/common.ts`

- [ ] **Step 1: 收口高频页面与壳层硬编码**
  - 用 `rg '[一-龥]' desktop/src/{App.vue,views,components}` 先清出登录、首页、设置、公共弹窗中的硬编码。
  - 将共用动作文案沉到 `common.*`。

- [ ] **Step 2: 逐文件替换为 `$t` / `t()`**
  - 组件模板内使用 `$t` 或 `useI18n`。
  - 非模板逻辑中的文案改用统一 `t()` helper。

- [ ] **Step 3: 验证语言切换刷新**
  - 若桌面端当前无语言切换入口，可先在 store/localStorage 中引入默认语言状态。
  - 确保窗口重新加载后仍保持语言偏好。

- [ ] **Step 4: 运行类型检查与单测**
  - Run: `cd desktop && bun run type-check`
  - Run: `cd desktop && bun run test`
  - Expected: 高频页面与共享组件不因 i18n 改造产生新增测试失败。

- [ ] **Step 5: 提交壳层与高频页面改动**
  - Run: `git add desktop/src/App.vue desktop/src/views desktop/src/components desktop/src/i18n && git commit -m "feat(desktop): localize shell login and settings views"`

### Task 4: 迁移消息、联系人、搜索与 store/utils 文案

**Files:**
- Modify: `desktop/src/views/Chat.vue`
- Modify: `desktop/src/views/Contact.vue`
- Modify: `desktop/src/components/MessageBubble.vue`
- Modify: `desktop/src/components/MessageSearch.vue`
- Modify: `desktop/src/components/SearchDialog.vue`
- Modify: `desktop/src/components/CreateGroupDialog.vue`
- Modify: `desktop/src/components/GroupSettingsDrawer.vue`
- Modify: `desktop/src/components/GroupJoinRequestsDialog.vue`
- Modify: `desktop/src/components/GroupOperationLogsDialog.vue`
- Modify: `desktop/src/components/GroupMuteDialog.vue`
- Modify: `desktop/src/components/ReportDialog.vue`
- Modify: `desktop/src/store/index.ts`
- Modify: `desktop/src/services/messageSearchService.ts`
- Modify: `desktop/src/utils/keyboardShortcuts.ts`
- Modify: `desktop/src/utils/loading.ts`
- Modify: `desktop/src/utils/window.ts`
- Modify: `desktop/src/utils/accountMigration.ts`

- [ ] **Step 1: 清点非组件层文案**
  - 特别关注 `store/index.ts` 中的时间格式、状态值、全局错误提示。
  - 检查 `services` 和 `utils` 中是否仍有用户可见文案。

- [ ] **Step 2: 迁移消息/联系人/搜索域**
  - 聊天气泡、搜索对话框、群组相关弹窗、联系人提示全部改为 i18n key。
  - 统一处理本地搜索相关提示，保持“消息搜索直接本地搜索”的既有原则不变。

- [ ] **Step 3: 补齐中英文语言文件**
  - 消息状态、联系人动作、群组管理与搜索空态同步补到 `zh-CN` / `en-US`。
  - 不要在多个文件复制相同文案。

- [ ] **Step 4: 运行验证**
  - Run: `cd desktop && bun run type-check`
  - Run: `cd desktop && bun run test`
  - Expected: store、components、utils 的文案访问全部可解析，Vitest 无新增回归。

- [ ] **Step 5: 提交消息与工具层改动**
  - Run: `git add desktop/src/views/Chat.vue desktop/src/views/Contact.vue desktop/src/components desktop/src/store/index.ts desktop/src/services desktop/src/utils desktop/src/i18n && git commit -m "feat(desktop): localize chat contact and utility flows"`

### Task 5: 文档、验收与运行口径

**Files:**
- Modify: `desktop/README.md`
- Modify: `docs/reference/testing/README.md`
- Create: `docs/reports/2026-03-26-desktop-i18n-acceptance.md`

- [ ] **Step 1: 补桌面端多语言运行说明**
  - 记录 `bun run type-check`、`bun run test`、`bun run tauri:dev` 下的验证方式。
  - 明确 `desktop` 当前仍为 Tauri 模块，与 `desktop-el` 分离。

- [ ] **Step 2: 运行最终验证**
  - Run: `cd desktop && bun run type-check`
  - Run: `cd desktop && bun run test`
  - Run: `cd desktop && bun run tauri:dev`
  - Expected: 类型检查与测试通过；本地手工验证登录/首页/设置/聊天关键页面文案能正确切换。

- [ ] **Step 3: 记录验收结果并提交**
  - Run: `git add desktop/README.md docs/reference/testing/README.md docs/reports/2026-03-26-desktop-i18n-acceptance.md && git commit -m "docs(desktop): record i18n rollout acceptance"`
