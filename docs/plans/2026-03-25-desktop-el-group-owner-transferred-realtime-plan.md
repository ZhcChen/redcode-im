# Desktop EL 群主转让事件收敛 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐 `group_owner_transferred` websocket 事件映射与当前群聊刷新闭环。

**Architecture:** 继续由 Go core 统一透传 websocket 事件，renderer 只在 `ChatApi` 做事件映射，在 `chat-group-realtime` 计算刷新计划，在 `ChatPanel` 按统一 realtime 收敛链路刷新群详情 / 群设置 / 管理面板，不新增本地 HTTP 端口。

**Tech Stack:** Electron、Vue 3、TypeScript、stdio RPC、backend websocket、bun test、bun build

---

### Task 1: 映射 `group_owner_transferred` 事件

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Test: `desktop-el/renderer/src/api/chat.test.ts`

- [ ] **Step 1: 写失败测试**

覆盖 `mapChatRealtimeEvent` 对 `group_owner_transferred` 的映射，断言包含：
- `roomId`
- `oldOwnerId`
- `newOwnerId`

- [ ] **Step 2: 跑测试确认红灯**

Run: `cd desktop-el && bun test renderer/src/api/chat.test.ts`
Expected: FAIL，提示事件未映射。

- [ ] **Step 3: 写最小实现**

在 `chat.ts` 中补：
- backend push 类型
- type guard
- `ChatRealtimeEvent` union
- `mapChatRealtimeEvent` 分支

- [ ] **Step 4: 跑测试确认转绿**

Run: `cd desktop-el && bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: realtime 收敛与当前群刷新

**Files:**
- Modify: `desktop-el/renderer/src/utils/chat-group-realtime.ts`
- Test: `desktop-el/renderer/src/utils/chat-group-realtime.test.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Reference: `desktop/src/views/Chat.vue`

- [ ] **Step 1: 写失败测试**

补 `getGroupRealtimePlan` 测试，断言：
- 命中当前群时刷新 chats / groupContext / groupSettings
- 当前用户成为新群主时给 notice
- 当前用户失去群主身份时给 notice

- [ ] **Step 2: 跑测试确认红灯**

Run: `cd desktop-el && bun test renderer/src/utils/chat-group-realtime.test.ts`
Expected: FAIL

- [ ] **Step 3: 写最小实现**

在 `chat-group-realtime.ts` 中补 `group_owner_transferred` 刷新策略；在 `ChatPanel.vue` 沿用现有 group realtime 收敛链路刷新群详情、群设置和相关管理数据。

- [ ] **Step 4: 完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [ ] **Step 5: 回填 backlog + 提交**

```bash
git add desktop-el/renderer/src/api/chat.ts desktop-el/renderer/src/api/chat.test.ts desktop-el/renderer/src/utils/chat-group-realtime.ts desktop-el/renderer/src/utils/chat-group-realtime.test.ts desktop-el/renderer/src/components/ChatPanel.vue docs/plans/2026-03-24-desktop-el-migration-backlog.md docs/plans/2026-03-25-desktop-el-group-owner-transferred-realtime-plan.md
git commit -m "feat(desktop-el): sync group owner transfer events"
git push
```
