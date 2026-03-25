# Desktop EL 上下文菜单 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `desktop-el` 支持旧桌面端同类的最小上下文菜单能力，包括会话列表右键菜单与消息右键菜单。

**Architecture:** 保持 Electron 只做宿主壳，不新增任何本地端口。会话菜单直接走现有 backend 能力（`pin room`、`notification settings`、`delete chat`），消息菜单只作为现有 renderer 行为的右键入口，不复制第二套业务逻辑。

**Tech Stack:** Vue 3、TypeScript、bun test、vite build、stdio RPC、Go core

---

### Task 1: 会话菜单 API 与纯函数能力

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`
- Create: `desktop-el/renderer/src/utils/chat-context-menu.ts`
- Create: `desktop-el/renderer/src/utils/chat-context-menu.test.ts`

- [x] **Step 1: 写失败测试**

覆盖：
- `ChatApi.pinChat`
- `ChatApi.unpinChat`
- `ChatApi.updateNotificationSettings`
- `ChatApi.deleteChat`
- 会话菜单项根据 `isPinned` / `isMuted` 输出正确 label

- [x] **Step 2: 跑测试确认红灯**

Run: `cd desktop-el && bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-context-menu.test.ts`
Expected: FAIL

- [x] **Step 3: 写最小实现**

补齐：
- `chat.room.pin` / `chat.room.unpin` / `chat.room.notification.update` / `chat.room.delete`
- 会话菜单 helper（会话菜单 label、消息菜单可见项、菜单位置裁剪）

- [x] **Step 4: 跑测试确认转绿**

Run: `cd desktop-el && bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-context-menu.test.ts`
Expected: PASS

### Task 2: 上下文菜单组件与 ChatPanel 接入

**Files:**
- Create: `desktop-el/renderer/src/components/ChatListContextMenu.vue`
- Create: `desktop-el/renderer/src/components/MessageContextMenu.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 写最小实现**

接入：
- 会话列表项右键弹出 `置顶 / 消息免打扰 / 删除对话`
- 消息卡片右键弹出当前已支持动作入口
- 保持现有 message action handler 作为唯一业务实现
- 当前会话被删除后自动清空当前上下文

- [x] **Step 2: 完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 3: 回填 backlog + 提交**

```bash
git add desktop-el/renderer/src/api/chat.ts desktop-el/renderer/src/api/chat.test.ts desktop-el/renderer/src/utils/chat-context-menu.ts desktop-el/renderer/src/utils/chat-context-menu.test.ts desktop-el/renderer/src/components/ChatListContextMenu.vue desktop-el/renderer/src/components/MessageContextMenu.vue desktop-el/renderer/src/components/ChatPanel.vue docs/plans/2026-03-25-desktop-el-context-menu-plan.md docs/plans/2026-03-24-desktop-el-migration-backlog.md
git commit -m "feat(desktop-el): support chat context menus"
git push
```
