# Desktop EL Chat Send Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `desktop-el` 中补齐聊天文本发送最小闭环，让用户能在聊天页输入文本并通过 Go core 发送到 backend。

**Architecture:** 继续维持 Electron 仅宿主、Go core 承接业务、renderer 只走 stdio RPC。此次只支持文本发送，发送成功后刷新当前会话消息列表与会话摘要；不引入附件、引用、Reaction、已读等额外交互。

**Tech Stack:** Electron、Vue 3、TypeScript、Go 1.25、stdio RPC、backend `/rooms/{room_id}/messages`

---

### Task 1: Go core 补齐 chat.send RPC

**Files:**
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/go-core/internal/chat/service.go`

- [x] **Step 1: 写失败测试（Red）**
覆盖：
  - `chat.send` 会带 token `POST /rooms/{room_id}/messages`
  - 请求体包含 `content`
  - 返回消息对象会被完整包进统一响应 envelope

- [x] **Step 2: 运行局部测试确认失败（Red）**
Run: `cd desktop-el/go-core && go test ./internal/app -run TestAppChatSendPostsMessagePayload -count=1`
Expected: FAIL，当前 `chat.send` 尚未注册。

- [x] **Step 3: 实现最小 Go core 代码（Green）**
在 `chat.Service` 中新增：
  - `SendMessageParams`
  - `SendMessage`
并在 `app.RegisterRPC()` 注册 `chat.send`。

- [x] **Step 4: 再跑局部测试确认通过（Green）**
Run: `cd desktop-el/go-core && go test ./internal/app -run TestAppChatSendPostsMessagePayload -count=1`
Expected: PASS

### Task 2: Renderer 接通文本发送

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 扩展聊天 API**
在 `chat.ts` 中新增文本发送接口，复用现有消息映射结构。

- [x] **Step 2: 补输入框与发送按钮**
在 `ChatPanel` 中加入：
  - 文本输入框
  - 发送按钮
  - `Enter` 发送、`Shift+Enter` 换行
  - 发送中禁用态

- [x] **Step 3: 发送成功后刷新当前上下文**
发送成功后：
  - 刷新当前会话消息列表
  - 刷新会话摘要列表
  - 保持当前选中会话不丢失

### Task 3: 全量验证与提交

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-chat-send-plan.md`

- [x] **Step 1: 运行 Go 全量测试**
Run: `cd desktop-el/go-core && go test ./...`
Expected: PASS

- [x] **Step 2: 运行类型检查**
Run: `cd desktop-el && bun run type-check`
Expected: PASS

- [x] **Step 3: 运行构建**
Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 4: 前台烟测并清理**
Run:
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el && make desktop-el-down`
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el && bun run dev`
  - 验证 Electron / renderer / Go core 正常启动
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el && make desktop-el-down`
  - `screen -ls || true`
  - `pgrep -fl '/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/node_modules/.bin/electron|/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron|desktop-el-core' || true`
Expected:
  - 前台启动正常
  - 收尾后无 `desktop-el` 残留进程

- [x] **Step 5: 提交并推送**
Run:
```bash
git add desktop-el/go-core/internal/app/app.go desktop-el/go-core/internal/app/app_test.go desktop-el/go-core/internal/chat/service.go desktop-el/renderer/src/api/chat.ts desktop-el/renderer/src/components/ChatPanel.vue docs/plans/2026-03-24-desktop-el-chat-send-plan.md
git commit -m "feat(desktop-el): support text message sending"
git push origin codex/desktop-el
```
