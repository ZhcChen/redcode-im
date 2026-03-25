# Desktop EL 快捷键 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `desktop-el` 具备旧桌面端已存在的最小快捷键能力，优先补全导航拦截和聊天区高频热键。

**Architecture:** 不引入新的宿主层全局快捷键注册，也不把 Electron main 变成热键业务中心。renderer 内部通过纯函数判断键位，再由 `main.ts` 与 `ChatPanel.vue` 分别接通全局导航拦截和聊天区快捷键。

**Tech Stack:** Vue 3、TypeScript、bun test、vite build

---

### Task 1: 快捷键 pure helper

**Files:**
- Create: `desktop-el/renderer/src/utils/navigation-shortcuts.ts`
- Create: `desktop-el/renderer/src/utils/navigation-shortcuts.test.ts`
- Create: `desktop-el/renderer/src/utils/chat-shortcuts.ts`
- Create: `desktop-el/renderer/src/utils/chat-shortcuts.test.ts`

- [ ] **Step 1: 写失败测试**

覆盖：
- 阻断浏览器前进后退的键盘导航判断
- `Cmd/Ctrl+F` 打开当前会话搜索
- `Cmd/Ctrl+Enter` 提交编辑消息

- [ ] **Step 2: 跑测试确认红灯**

Run: `cd desktop-el && bun test renderer/src/utils/navigation-shortcuts.test.ts renderer/src/utils/chat-shortcuts.test.ts`
Expected: FAIL

- [ ] **Step 3: 写最小实现**

补齐：
- 导航快捷键判断与启停函数
- 聊天快捷键判断 helper

- [ ] **Step 4: 跑测试确认转绿**

Run: `cd desktop-el && bun test renderer/src/utils/navigation-shortcuts.test.ts renderer/src/utils/chat-shortcuts.test.ts`
Expected: PASS

### Task 2: main.ts + ChatPanel 接入

**Files:**
- Modify: `desktop-el/renderer/src/main.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [ ] **Step 1: 写最小实现**

接入：
- renderer 启动时启用导航快捷键拦截
- `ChatPanel` 支持 `Cmd/Ctrl+F` 打开搜索消息
- 编辑消息弹层支持 `Cmd/Ctrl+Enter` 提交
- 保持现有 `Enter` 发送和 `Escape` 退出逻辑

- [ ] **Step 2: 完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [ ] **Step 3: 提交**

```bash
git add desktop-el/renderer/src/utils/navigation-shortcuts.ts desktop-el/renderer/src/utils/navigation-shortcuts.test.ts desktop-el/renderer/src/utils/chat-shortcuts.ts desktop-el/renderer/src/utils/chat-shortcuts.test.ts desktop-el/renderer/src/main.ts desktop-el/renderer/src/components/ChatPanel.vue docs/plans/2026-03-25-desktop-el-shortcuts-plan.md docs/plans/2026-03-24-desktop-el-migration-backlog.md
git commit -m "feat(desktop-el): support keyboard shortcuts"
git push
```
