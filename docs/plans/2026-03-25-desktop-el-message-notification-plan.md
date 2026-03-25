# Desktop EL Message Notification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 接通消息到达通知最小闭环，让新消息在不打断当前聊天操作的前提下触发 Electron 系统通知。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务 RPC、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增本地 HTTP 端口；通知策略放在 renderer helper 中做纯函数判断，`HomeShell` 只负责监听 `lastWsPush` 并调用现有 `window.desktopEl.notification.show(...)`。

**Tech Stack:** Vue 3、TypeScript、Bun、Electron Notification、现有 `HomeShell` / `ChatApi`

---

### Task 1: 先用测试钉住消息通知策略

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-notification.ts`
- Create: `desktop-el/renderer/src/utils/chat-notification.test.ts`

- [x] **Step 1: 为消息通知 helper 写红灯测试**

覆盖最小行为：
- 忽略自己发送的消息
- 忽略系统消息
- 当前处于聊天视图且窗口聚焦时不弹系统通知
- 其他情况下构造 `title/body`

- [x] **Step 2: 跑定向测试确认先失败**

Run:
- `bun test renderer/src/utils/chat-notification.test.ts`

Expected: FAIL，提示 helper 尚未实现

### Task 2: 实现 helper 并接到 HomeShell

**Files:**
- Modify: `desktop-el/renderer/src/components/HomeShell.vue`
- Modify: `desktop-el/renderer/src/utils/chat-notification.ts`
- Modify: `desktop-el/renderer/src/utils/chat-notification.test.ts`

- [x] **Step 1: 实现通知策略 helper**

最小要求：
- 输入 `lastWsPush/currentUserId/activeView/isWindowFocused`
- 返回是否应通知与通知文案

- [x] **Step 2: 在 HomeShell 监听 `lastWsPush`**

最小要求：
- 只处理 `type === "message"`
- 满足 helper 条件时调用 `window.desktopEl.notification.show(...)`
- 调用失败只告警，不中断 UI

- [x] **Step 3: 回跑定向测试**

Run:
- `bun test renderer/src/utils/chat-notification.test.ts`

Expected: PASS

### Task 3: 回归验证、更新 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-notification-plan.md`

- [x] **Step 1: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`

Expected:
- `bun test` PASS
- `bun run build` PASS

- [x] **Step 2: 回填 backlog**

将 `P1-3` 中“消息到达通知”标记为已完成，并缩小剩余宿主业务接通缺口。

- [x] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-message-notification-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/components/HomeShell.vue \
  desktop-el/renderer/src/utils/chat-notification.ts \
  desktop-el/renderer/src/utils/chat-notification.test.ts
git commit -m "feat(desktop-el): support message notifications"
git push origin codex/desktop-el
```

- [x] **Step 4: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
