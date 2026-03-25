# Desktop EL Account Panel State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的多账号能力补齐联系人页与设置页的更深页面子状态恢复，让账号切换与重启恢复后回到各自之前的联系人/设置上下文。

**Architecture:** 继续保持 renderer session store 维护每账号页面状态，Electron 不承接业务状态，Go core 不增加额外 RPC。联系人页恢复模式、搜索关键词、选中项和搜人上下文；设置页只恢复安全可持久化的本地编辑上下文，如昵称草稿和反馈草稿，不持久化密码草稿。

**Tech Stack:** Vue 3、TypeScript、Bun test、本地 session store、ContactPanel、SettingsPanel

---

### Task 1: 扩展 session store 的每账号联系人/设置页面状态

**Files:**
- Modify: `desktop-el/renderer/src/store/session.ts`
- Modify: `desktop-el/renderer/src/store/session.test.ts`

- [x] **Step 1: 写 store 失败测试**

```ts
test("restores per-account contact page state when switching accounts", () => {})
test("restores persisted contact and settings page state", () => {})
```

- [x] **Step 2: 运行测试确认失败**

Run: `cd desktop-el && bun test renderer/src/store/session.test.ts`
Expected: FAIL，提示缺少联系人/设置页面状态字段或 setter。

- [x] **Step 3: 实现最小 store 扩展**

实现点：
- `SessionPageState` 补 `contact` 与 `settings` 子状态
- 增加当前账号 `contact/settings` 状态的 setter
- `applyCurrentAccount` / persisted restore 同步当前账号对应子状态
- 明确不把密码草稿放进持久化 state

- [x] **Step 4: 运行 store 测试确认通过**

Run: `cd desktop-el && bun test renderer/src/store/session.test.ts`
Expected: PASS

### Task 2: 接通 ContactPanel 的按账号页面状态恢复

**Files:**
- Modify: `desktop-el/renderer/src/components/ContactPanel.vue`
- Modify: `desktop-el/renderer/src/components/HomeShell.vue`
- Modify: `desktop-el/renderer/src/App.vue`

- [x] **Step 1: 接入联系人页 restore props 与 emit**

实现点：
- `ContactPanel` 接受 restore state prop，并在关键本地状态变化时 emit
- 恢复 `mode`、联系人搜索词、搜人关键词、选中联系人/申请/搜索结果、好友申请留言
- 仅在需要时重跑 discover 搜索，不为聊天/设置页引入额外耦合

- [x] **Step 2: 保持旧账号状态不会泄漏到新账号**

实现点：
- 仍保留按 `currentUser.id` 的组件 key
- 切账号时恢复当前账号自己的联系人上下文
- 对不该恢复的瞬时 loading / notice 状态继续重置

### Task 3: 接通 SettingsPanel 的按账号安全页面状态恢复

**Files:**
- Modify: `desktop-el/renderer/src/components/SettingsPanel.vue`
- Modify: `desktop-el/renderer/src/components/HomeShell.vue`
- Modify: `desktop-el/renderer/src/App.vue`

- [x] **Step 1: 接入设置页 restore props 与 emit**

实现点：
- 恢复昵称编辑开关与昵称草稿
- 恢复反馈内容草稿与联系方式草稿
- 文档弹层、更新下载状态、密码草稿与密码编辑态不做持久化

- [x] **Step 2: 确保安全边界**

实现点：
- 不把旧账号密码输入留到新账号
- 反馈/昵称草稿只跟随各自账号
- 运行时 notice 与更新检查状态保持本地瞬态

### Task 4: 验证、回填 backlog、提交推送与清理

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-account-panel-state-plan.md`

- [x] **Step 1: 运行定向验证**

Run: `cd desktop-el && bun test renderer/src/store/session.test.ts`
Expected: PASS

- [x] **Step 2: 运行完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 3: 更新 backlog、提交并推送**

```bash
git add docs/plans/2026-03-26-desktop-el-account-panel-state-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/store/session.ts \
  desktop-el/renderer/src/store/session.test.ts \
  desktop-el/renderer/src/components/ContactPanel.vue \
  desktop-el/renderer/src/components/SettingsPanel.vue \
  desktop-el/renderer/src/components/HomeShell.vue \
  desktop-el/renderer/src/App.vue
git commit -m "feat(desktop-el): restore account panel state"
git push
```

- [x] **Step 4: 运行清理**

Run: `make desktop-el-down`
Expected: 无残留开发实例。

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无输出。
