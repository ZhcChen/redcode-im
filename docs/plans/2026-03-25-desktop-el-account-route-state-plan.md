# Desktop EL Account Route State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的多账号骨架补齐每账号 `routeState` 与聊天页 `pageState.currentChatGroupId`，让账号切换与重启恢复后回到各自之前的聊天上下文。

**Architecture:** 继续保持 Electron 只做宿主壳、Go core 只承接业务会话与当前账号、renderer 在本地 session store 维护每账号页面状态。当前不引入完整 Vue Router，仅在现有 `activeView` 之上补最小 `routeState` 映射，并将聊天选中房间作为 `pageState` 保存。

**Tech Stack:** Vue 3、TypeScript、Bun test、stdio RPC、本地 session store、ChatPanel

---

### Task 1: 固定 store 的每账号 route/page state 预期

**Files:**
- Modify: `desktop-el/renderer/src/store/session.test.ts`
- Modify: `desktop-el/renderer/src/store/session.ts`

- [x] **Step 1: 写 store 失败测试**

```ts
test("persists routeState with active view per account", () => {})
test("persists currentChatGroupId per account and restores it on switch", () => {})
```

- [x] **Step 2: 运行测试确认失败**

Run: `cd desktop-el && bun test renderer/src/store/session.test.ts`
Expected: FAIL，提示缺少 `routeState` / `pageState` API。

- [x] **Step 3: 实现最小 store 扩展**

实现点：
- `SessionAccount` 补 `routeState` 与 `pageState.currentChatGroupId`
- `setActiveView` 同步更新 `routeState`
- 新增 `setCurrentChatGroupId`
- `applyCurrentAccount` 恢复当前账号对应聊天页状态

- [x] **Step 4: 运行测试确认通过**

Run: `cd desktop-el && bun test renderer/src/store/session.test.ts`
Expected: PASS

### Task 2: 抽离聊天房间恢复 helper

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-room-selection.ts`
- Create: `desktop-el/renderer/src/utils/chat-room-selection.test.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 写 helper 失败测试**

```ts
test("prefers restored room id over current room when available", () => {})
test("falls back to current room and then first room", () => {})
```

- [x] **Step 2: 运行测试确认失败**

Run: `cd desktop-el && bun test renderer/src/utils/chat-room-selection.test.ts`
Expected: FAIL，提示 helper 缺失。

- [x] **Step 3: 实现 helper 并接入 ChatPanel**

实现点：
- 抽离 `pickSelectedChatId` 为纯函数
- `ChatPanel` 增加 `restoredChatRoomId` prop
- 会话列表初次加载时优先恢复该 room
- `selectedChatId` 变化时向上层同步

- [x] **Step 4: 运行 helper 测试确认通过**

Run: `cd desktop-el && bun test renderer/src/utils/chat-room-selection.test.ts`
Expected: PASS

### Task 3: 接通 App / HomeShell 与面板重挂载恢复

**Files:**
- Modify: `desktop-el/renderer/src/App.vue`
- Modify: `desktop-el/renderer/src/components/HomeShell.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 实现上层接线**

实现点：
- `App.vue` 将当前账号 `pageState.currentChatGroupId` 传给 `HomeShell -> ChatPanel`
- `ChatPanel` 通过 emit 回写当前账号 `currentChatGroupId`
- 当前账号切换时，按 `currentUser.id` 给 `ChatPanel` / `ContactPanel` / `SettingsPanel` 加 key，避免残留旧账号本地状态

- [x] **Step 2: 运行定向验证**

Run: `cd desktop-el && bun test renderer/src/store/session.test.ts renderer/src/utils/chat-room-selection.test.ts`
Expected: PASS

- [x] **Step 3: 运行完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 4: 更新 backlog、提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-account-route-state-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/store/session.ts \
  desktop-el/renderer/src/store/session.test.ts \
  desktop-el/renderer/src/utils/chat-room-selection.ts \
  desktop-el/renderer/src/utils/chat-room-selection.test.ts \
  desktop-el/renderer/src/App.vue \
  desktop-el/renderer/src/components/HomeShell.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): persist per-account chat route state"
git push
```

### Task 4: 运行清理

**Files:**
- None

- [x] **Step 1: 停掉 desktop-el 相关进程**

Run: `make desktop-el-down`
Expected: 无残留开发实例。

- [x] **Step 2: 检查进程**

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无输出。
