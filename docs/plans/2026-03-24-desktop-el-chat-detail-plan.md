# Desktop EL Chat Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `desktop-el` 中打通“联系人发起私聊 -> 切到聊天页 -> 拉取历史消息列表”的最小业务闭环。

**Architecture:** 继续坚持 Electron 只做宿主壳，所有聊天业务通过 Go core 暴露 stdio RPC 给 renderer。此次只补齐会话发起与历史消息读取，不接发送、已读、Reaction、附件等重交互，保证迁移切口小而闭环完整。

**Tech Stack:** Electron、Vue 3、TypeScript、Go 1.25、stdio RPC、backend `/friends/{friend_user_id}/chat` 与 `/rooms/{room_id}/messages`

---

### Task 1: Go core 补齐聊天详情 RPC

**Files:**
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/go-core/internal/chat/service.go`

- [x] **Step 1: 写失败测试（Red）**
覆盖：
  - `chat.private.ensure` 会携带 token `POST /friends/{friend_id}/chat`
  - `chat.messages.list` 会携带 token `GET /rooms/{room_id}/messages?limit=50`

- [x] **Step 2: 运行局部测试确认失败（Red）**
Run: `cd desktop-el/go-core && go test ./internal/app -run 'TestAppChat(EnsurePrivate|MessagesList)' -count=1`
Expected: FAIL，当前 RPC 尚未注册。

- [x] **Step 3: 实现最小 Go core 代码（Green）**
在 `chat.Service` 中新增：
  - `EnsurePrivateChat`
  - `ListMessages`
并在 `app.RegisterRPC()` 注册：
  - `chat.private.ensure`
  - `chat.messages.list`

- [x] **Step 4: 再跑局部测试确认通过（Green）**
Run: `cd desktop-el/go-core && go test ./internal/app -run 'TestAppChat(EnsurePrivate|MessagesList)' -count=1`
Expected: PASS

### Task 2: Renderer 接通聊天详情最小闭环

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/components/ContactPanel.vue`
- Modify: `desktop-el/renderer/src/components/HomeShell.vue`

- [x] **Step 1: 扩展聊天 API 封装**
在 `chat.ts` 中新增：
  - 私聊房间确保接口
  - 消息列表接口
  - 最小消息类型映射（文本 / 系统 / 图片 / 语音 / 视频 / 文件预览）

- [x] **Step 2: 让 ContactPanel 发起聊天**
补 `open-chat` 事件与“发消息”按钮，点击后把好友用户 ID 抛给 `HomeShell`。

- [x] **Step 3: 让 HomeShell 承接聊天意图**
在 `HomeShell` 中维护一次性的 open-chat request：
  - Contact 发起时切到 `chat`
  - 把好友 ID 透传给 `ChatPanel`

- [x] **Step 4: 让 ChatPanel 接历史消息**
在 `ChatPanel` 中实现：
  - 默认选中会话时加载消息
  - 收到联系人发起聊天请求时先 ensure room，再刷新会话列表并加载消息
  - 详情区用最小样式渲染消息时间、发送者、消息预览

### Task 3: 全量验证与提交

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-chat-detail-plan.md`

- [x] **Step 1: 运行 Go 全量测试**
Run: `cd desktop-el/go-core && go test ./...`
Expected: PASS

- [x] **Step 2: 运行类型检查**
Run: `cd desktop-el && bun run type-check`
Expected: PASS

- [x] **Step 3: 运行构建**
Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 4: 运行启动烟测并清理**
Run:
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el && make desktop-el-down`
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el && bun run dev`
  - 验证 Electron / Go core 正常启动
  - `cd /Users/chen/code/redcode-im/.worktrees/desktop-el && make desktop-el-down`
  - `screen -ls || true`
  - `pgrep -fl '/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/node_modules/.bin/electron|/Users/chen/code/redcode-im/.worktrees/desktop-el/desktop-el/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron|desktop-el-core' || true`
Expected:
  - 前台启动可见 Go core ready 与 renderer 初始化日志
  - 收尾后无 `desktop-el` 残留进程

- [x] **Step 5: 提交并推送**
Run:
```bash
git add desktop-el/go-core/internal/app/app.go desktop-el/go-core/internal/app/app_test.go desktop-el/go-core/internal/chat/service.go desktop-el/renderer/src/api/chat.ts desktop-el/renderer/src/components/ChatPanel.vue desktop-el/renderer/src/components/ContactPanel.vue desktop-el/renderer/src/components/HomeShell.vue docs/plans/2026-03-24-desktop-el-chat-detail-plan.md
git commit -m "feat(desktop-el): port chat detail flow"
git push origin codex/desktop-el
```
