# Desktop EL Failed Text Resend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐文本 / 引用文本消息发送失败后的本地失败态与手动重发最小闭环。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务核心、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增 backend / Go core 新接口，直接复用已有 `chat.send` / `chat.sendTextMessage`；renderer 只补本地临时消息模型、失败态展示与手动重投，不迁移附件重发、自动重试队列或本地持久化失败箱。

**Tech Stack:** Vue 3、TypeScript、Bun、stdio RPC、现有 `ChatPanel` / `ChatApi`

---

### Task 1: 为本地失败消息 helper 写红灯测试

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-local-message.test.ts`
- Create: `desktop-el/renderer/src/utils/chat-local-message.ts`
- Modify: `desktop-el/renderer/src/api/chat.ts`

- [x] **Step 1: 写 helper 红灯测试**

覆盖最小行为：
- 创建本地发送中文本消息
- 将本地消息标记为失败
- 判断消息是否允许手动重发
- 用服务端返回消息替换本地消息

- [x] **Step 2: 跑定向测试确认先失败**

Run:
- `bun test desktop-el/renderer/src/utils/chat-local-message.test.ts`

Expected: FAIL，提示 helper 尚未实现或 `ChatMessage` 本地字段缺失。

### Task 2: 实现本地文本消息 helper

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.ts`
- Verify: `desktop-el/renderer/src/utils/chat-local-message.test.ts`

- [x] **Step 1: 扩展 `ChatMessage` 本地状态字段**

最小增加：
- `clientStatus?: "sending" | "failed" | null`
- `retryPayload?: { content: string; quotedMessageId?: string | null } | null`
- `errorMessage?: string | null`

- [x] **Step 2: 实现 helper**

最小提供：
- `createLocalTextMessage(...)`
- `markLocalMessageFailed(...)`
- `markLocalMessageSending(...)`
- `replaceLocalMessage(...)`
- `canResendLocalMessage(...)`

- [x] **Step 3: 回跑 helper 定向测试**

Run:
- `bun test desktop-el/renderer/src/utils/chat-local-message.test.ts`

Expected: PASS

### Task 3: 接入 `ChatPanel` 发送失败态与手动重发

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 发送文本前插入本地 sending 气泡**

范围仅限：
- 纯文本
- 引用文本

附件发送仍沿用当前行为，不进入本地失败气泡体系。

- [x] **Step 2: 发送成功后替换本地气泡**

复用服务端返回的消息体替换本地消息；若消息已经被 `loadChats()` 刷新冲掉，则静默跳过。

- [x] **Step 3: 发送失败后保留 failed 气泡**

失败时：
- 不清空输入框原有回显逻辑以外的现有 UX
- 将本地消息转为 `failed`
- 在消息卡片展示“发送失败”与“重发”入口

- [x] **Step 4: 接入手动重发**

仅支持：
- 文本消息
- 引用文本消息

不支持：
- 附件消息
- 自动重试
- 本地持久化 pending queue

### Task 4: 验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-failed-text-resend-plan.md`

- [x] **Step 1: 跑定向验证**

Run:
- `bun test desktop-el/renderer/src/utils/chat-local-message.test.ts`

Expected: PASS

- [x] **Step 2: 跑回归验证**

Run:
- `bun run build`
- `bun test`
- `go test ./...`

Expected:
- `bun run build` PASS
- `bun test` PASS
- `go test ./...` PASS

- [x] **Step 3: 回填 backlog**

将 `P0-1` 中“重发”从当前缺口缩小为仅剩“撤回与更完整消息操作菜单”。

- [x] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-failed-text-resend-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/utils/chat-local-message.ts \
  desktop-el/renderer/src/utils/chat-local-message.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support failed text resend"
git push origin codex/desktop-el
```

- [x] **Step 5: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
