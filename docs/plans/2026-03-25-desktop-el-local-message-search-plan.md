# Desktop EL Local Message Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐当前聊天上下文内的本地消息搜索最小闭环，让用户可以在当前会话中本地检索已加载消息、查看结果摘要并跳转定位到目标消息。

**Architecture:** 不新增 Go core 搜索 RPC，也不依赖服务端搜索。renderer 直接基于当前会话已加载的 `messages + localMessages` 做本地搜索，搜索 helper 负责提取可搜索文本、生成结果摘要与高亮片段，`ChatPanel` 负责弹层展示与滚动定位。

**Tech Stack:** Vue 3、TypeScript、Bun、现有 `ChatPanel` / `ChatMessage` 模型 / DOM 滚动定位

---

### Task 1: 先用测试钉住本地消息搜索 helper

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-message-search.ts`
- Create: `desktop-el/renderer/src/utils/chat-message-search.test.ts`

- [x] **Step 1: 为本地搜索 helper 写红灯测试**

覆盖最小行为：
- 能从文本消息、附件消息、引用消息中提取可搜索文本
- 仅返回命中当前查询词的消息，忽略已删除 / system 消息
- 搜索结果按消息时间倒序返回
- 能生成结果摘要和安全高亮片段

- [x] **Step 2: 跑定向测试确认先失败**

Run:
- `bun test renderer/src/utils/chat-message-search.test.ts`

Actual:
- `bun test renderer/src/utils/chat-message-search.test.ts` 首次失败，提示缺少 `chat-message-search.ts`

### Task 2: 接通搜索弹层与消息定位

**Files:**
- Create: `desktop-el/renderer/src/components/ChatMessageSearchModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/utils/chat-message-search.ts`
- Modify: `desktop-el/renderer/src/utils/chat-message-search.test.ts`

- [x] **Step 1: 实现本地搜索 helper**

最小要求：
- 输入 `ChatMessage[] + query` 返回本地搜索结果
- 结果包含消息 id、发送者、时间、摘要、高亮 HTML
- 查询为空时返回空结果

- [x] **Step 2: 实现搜索弹层组件**

最小要求：
- 支持输入关键词、显示命中数、列出结果
- 结果项显示发送者、时间、摘要与高亮文本
- 支持关闭和空状态

- [x] **Step 3: 在 ChatPanel 接通本地搜索**

最小要求：
- 当前聊天区域新增“搜索消息”入口
- 打开搜索弹层后仅搜索当前会话已加载消息
- 点击结果后关闭弹层、滚动到目标消息并做短暂高亮

- [x] **Step 4: 回跑定向测试**

Run:
- `bun test renderer/src/utils/chat-message-search.test.ts`

Actual:
- `bun test renderer/src/utils/chat-message-search.test.ts` PASS

### Task 3: 回填 backlog、跑回归、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-local-message-search-plan.md`

- [x] **Step 1: 回填 backlog**

最小要求：
- 将 `P1-2` 从 Go core / 服务端搜索改为“本地消息搜索”
- 将已过时的“群管理仍未迁移”“语音录制”等文案改成当前真实状态

- [x] **Step 2: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`

Actual:
- `cd desktop-el && bun test` PASS
- `cd desktop-el && bun run build` PASS

- [x] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-local-message-search-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/components/ChatMessageSearchModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue \
  desktop-el/renderer/src/utils/chat-message-search.ts \
  desktop-el/renderer/src/utils/chat-message-search.test.ts
git commit -m "feat(desktop-el): support local message search"
git push origin codex/desktop-el
```

- [x] **Step 4: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
