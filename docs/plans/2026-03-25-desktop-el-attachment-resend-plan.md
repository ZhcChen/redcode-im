# Desktop EL Attachment Resend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐附件消息与 mixed message 的本地失败态和手动重发最小闭环，让附件发送失败后仍保留在当前会话并可重新上传发送。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 只承接业务 RPC、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增本地 HTTP 端口，也不补“失败箱持久化”或自动重试；本地失败消息继续只存活在 renderer 内存里，附件重发时重新走现有 upload signature / multipart / `chat.send(parts)` 链路。

**Tech Stack:** Vue 3、TypeScript、Bun、现有 `ChatPanel` / `chat-local-message` / `chat-message-compose`

---

### Task 1: 先用测试钉住本地附件失败消息模型

**Files:**
- Modify: `desktop-el/renderer/src/utils/chat-local-message.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.test.ts`
- Modify: `desktop-el/renderer/src/api/chat.ts`

- [x] **Step 1: 为本地附件 / mixed message helper 写红灯测试**

覆盖最小行为：
- 创建本地 sending 附件消息时保留 `File[]` 级 retry payload
- 本地消息 parts 能带出附件名、大小、mime 和 partType
- `canResendLocalMessage` 对失败附件消息和 mixed message 返回 `true`

- [x] **Step 2: 跑定向测试确认先失败**

Run:
- `bun test renderer/src/utils/chat-local-message.test.ts`

Expected: FAIL，提示 retry payload / resend 判定尚未支持附件消息

### Task 2: 为附件重发抽最小 helper，并接回 ChatPanel

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-message-retry.ts`
- Create: `desktop-el/renderer/src/utils/chat-message-retry.test.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.test.ts`
- Modify: `desktop-el/renderer/src/api/chat.ts`

- [x] **Step 1: 为附件 / mixed message 重发 helper 写红灯测试**

覆盖最小行为：
- 文本重发继续走 `sendTextMessage`
- 附件 / mixed message 重发重新调用 `uploadAttachmentsAndBuildParts`，再走 `sendMessage`
- 上传后的 parts 与文本拼装顺序保持 `text first, attachments after`

- [x] **Step 2: 跑定向测试确认先失败**

Run:
- `bun test renderer/src/utils/chat-message-retry.test.ts`

Expected: FAIL，提示 resend helper 尚未实现

- [x] **Step 3: 实现本地附件消息 helper 与重发 helper**

最小要求：
- `retryPayload` 扩展到 `content + quotedMessageId + attachments`
- 本地附件消息可带临时附件元信息并进入会话列表
- 重发 helper 能根据 payload 自动选择 `sendTextMessage` 或 `sendMessage`

- [x] **Step 4: 在 ChatPanel 接通本地附件失败态与手动重发**

最小要求：
- 发送附件 / mixed message 前先创建本地 sending 消息并清空 composer
- 上传 / 发送失败时将本地消息标记为 failed，而不是只弹 notice
- 上传 / 发送成功时用远端消息替换本地消息
- 本地附件消息只显示卡片和重发，不提供打开 / 下载 / 预览动作

- [x] **Step 5: 回跑定向测试**

Run:
- `bun test renderer/src/utils/chat-local-message.test.ts`
- `bun test renderer/src/utils/chat-message-retry.test.ts`

Expected: PASS

### Task 3: 回归验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-attachment-resend-plan.md`

- [x] **Step 1: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`

Expected:
- `bun test` PASS
- `bun run build` PASS

- [x] **Step 2: 回填 backlog**

将 `P0-1` 中“附件重发”最小闭环标记为已完成，只保留自动重试、本地持久化失败箱和更深消息管理体验缺口。

- [x] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-attachment-resend-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/components/ChatPanel.vue \
  desktop-el/renderer/src/utils/chat-local-message.ts \
  desktop-el/renderer/src/utils/chat-local-message.test.ts \
  desktop-el/renderer/src/utils/chat-message-retry.ts \
  desktop-el/renderer/src/utils/chat-message-retry.test.ts
git commit -m "feat(desktop-el): support attachment resend"
git push origin codex/desktop-el
```

- [x] **Step 4: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
