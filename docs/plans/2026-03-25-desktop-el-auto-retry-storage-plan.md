# Desktop EL Auto Retry Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐消息自动重试和本地持久化失败箱最小闭环，让失败文本消息在重启后仍能恢复并继续自动重试，同时保留附件消息的会话内自动重试能力。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 只承接业务 RPC、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增本地 HTTP 端口，也不改附件选择链路；由于当前附件 retry payload 基于浏览器 `File` 对象，跨重启持久化只覆盖可序列化的文本 / 引用文本失败消息，附件与 mixed message 继续只支持当前会话内自动重试和手动重发。

**Tech Stack:** Vue 3、TypeScript、Bun、现有 `ChatPanel` / `chat-local-message` / `chat-message-retry`

---

### Task 1: 先用测试钉住失败消息持久化规则

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-retry-storage.ts`
- Create: `desktop-el/renderer/src/utils/chat-retry-storage.test.ts`

- [x] **Step 1: 为失败消息存储 helper 写红灯测试**

覆盖最小行为：
- 只序列化失败且可重试的本地消息
- 只持久化不带附件文件的 retry payload
- 反序列化后恢复 `ChatMessage` 基本字段、`createdAt` 和 `quotedMessage`

- [x] **Step 2: 跑定向测试确认先失败**

Run:
- `bun test renderer/src/utils/chat-retry-storage.test.ts`

Expected: FAIL，提示 storage helper 尚未实现

### Task 2: 接通 ChatPanel 自动重试与持久化恢复

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/utils/chat-message-retry.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-retry-storage.ts`
- Modify: `desktop-el/renderer/src/utils/chat-retry-storage.test.ts`

- [x] **Step 1: 实现 storage helper**

最小要求：
- 提供 `save / restore / clear` 或等价 API
- 对不可持久化的附件 retry payload 自动跳过
- 容错处理损坏的 localStorage 数据

- [x] **Step 2: 在 ChatPanel 接通自动重试队列**

最小要求：
- 本地消息发送失败后 3 秒自动重试
- 手动重发前取消已有自动重试 timer
- 自动重试成功后移除本地消息与持久化记录
- 自动重试失败后继续调度下一次重试

- [x] **Step 3: 在 ChatPanel 接通持久化恢复**

最小要求：
- `onMounted` 先恢复持久化失败消息，再加载聊天列表
- 恢复后的失败消息进入 `localMessagesByRoom`
- 恢复后的文本失败消息会自动继续重试

- [x] **Step 4: 回跑定向测试**

Run:
- `bun test renderer/src/utils/chat-retry-storage.test.ts`
- `bun test renderer/src/utils/chat-local-message.test.ts`

Expected: PASS

### Task 3: 回归验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-auto-retry-storage-plan.md`

- [x] **Step 1: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`

Expected:
- `bun test` PASS
- `bun run build` PASS

- [x] **Step 2: 回填 backlog**

将 `P0-1` 中“自动重试、本地持久化失败箱”标记为已完成；若附件跨重启失败箱仍受 `File` 持久化限制，需要在说明里明确该限制归属于更深消息管理体验，而不是主链路阻塞。

- [x] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-auto-retry-storage-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/components/ChatPanel.vue \
  desktop-el/renderer/src/utils/chat-local-message.ts \
  desktop-el/renderer/src/utils/chat-local-message.test.ts \
  desktop-el/renderer/src/utils/chat-message-retry.ts \
  desktop-el/renderer/src/utils/chat-retry-storage.ts \
  desktop-el/renderer/src/utils/chat-retry-storage.test.ts
git commit -m "feat(desktop-el): persist retryable local messages"
git push origin codex/desktop-el
```

- [x] **Step 4: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
