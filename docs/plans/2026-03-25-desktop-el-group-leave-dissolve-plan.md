# Desktop EL 群退出与解散 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐“退出群聊 / 解散群聊 + group_dissolved 事件收敛”的最小可用闭环。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务 RPC、renderer 仅通过 stdio RPC 与 Go core 交互。群退出与解散分别落到 Go core `chat.group.leave` / `chat.group.dissolve`，renderer 统一通过 `ChatApi` 调用，并在 `group_dissolved` / 当前用户被移出群时触发会话与面板收口。

**Tech Stack:** Electron、Vue 3、TypeScript、Go 1.25、stdio RPC、backend HTTP/WS、bun test、bun build

---

### Task 1: Go core 群退出 / 解散 RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Test: `desktop-el/go-core/internal/app/app_test.go`

- [ ] **Step 1: 写失败测试**

为 `chat.group.leave` / `chat.group.dissolve` 增加 RPC 测试，断言：
- `chat.group.leave` 调 backend `POST /rooms/{room_id}/leave`
- `chat.group.dissolve` 调 backend `DELETE /rooms/{room_id}`
- RPC 结果保持 backend envelope，不在 renderer 直接拼 HTTP

- [ ] **Step 2: 跑测试确认红灯**

Run: `cd desktop-el/go-core && go test ./internal/app -run 'TestAppChatGroup(Leave|Dissolve)'`
Expected: FAIL，提示 RPC 未注册或 handler 缺失。

- [ ] **Step 3: 写最小实现**

在 `service.go` 新增：
- `LeaveGroup(ctx, RoomParams)`
- `DissolveGroup(ctx, RoomParams)`

在 `app.go` 注册：
- `chat.group.leave`
- `chat.group.dissolve`

- [ ] **Step 4: 跑测试确认转绿**

Run: `cd desktop-el/go-core && go test ./internal/app -run 'TestAppChatGroup(Leave|Dissolve)'`
Expected: PASS

- [ ] **Step 5: 小提交**

```bash
git add desktop-el/go-core/internal/chat/service.go desktop-el/go-core/internal/app/app.go desktop-el/go-core/internal/app/app_test.go
git commit -m "feat(desktop-el): add group leave and dissolve rpc"
git push
```

### Task 2: renderer API 与 realtime 事件映射

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Test: `desktop-el/renderer/src/api/chat.test.ts`
- Test: `desktop-el/renderer/src/utils/chat-group-realtime.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-group-realtime.ts`

- [ ] **Step 1: 写失败测试**

补测试覆盖：
- `ChatApi.leaveGroup`
- `ChatApi.dissolveGroup`
- `mapChatRealtimeEvent` 映射 `group_dissolved`
- `getGroupRealtimePlan` 对 `group_dissolved` 返回 reload 策略和提示

- [ ] **Step 2: 跑测试确认红灯**

Run: `cd desktop-el && bun test desktop-el/renderer/src/api/chat.test.ts desktop-el/renderer/src/utils/chat-group-realtime.test.ts`
Expected: FAIL，提示方法不存在或事件未映射。

- [ ] **Step 3: 写最小实现**

在 `chat.ts`：
- 扩充 `ChatRealtimeEvent` 与 `ChatWebSocketPush`
- 新增 `ChatApi.leaveGroup`
- 新增 `ChatApi.dissolveGroup`
- `mapChatRealtimeEvent` 增加 `group_dissolved`

在 `chat-group-realtime.ts`：
- 为 `group_dissolved` 产出 `shouldReloadChats: true`
- 命中当前房间时触发上下文收口与 notice

- [ ] **Step 4: 跑测试确认转绿**

Run: `cd desktop-el && bun test desktop-el/renderer/src/api/chat.test.ts desktop-el/renderer/src/utils/chat-group-realtime.test.ts`
Expected: PASS

- [ ] **Step 5: 小提交**

```bash
git add desktop-el/renderer/src/api/chat.ts desktop-el/renderer/src/api/chat.test.ts desktop-el/renderer/src/utils/chat-group-realtime.ts desktop-el/renderer/src/utils/chat-group-realtime.test.ts
git commit -m "feat(desktop-el): wire group dissolve realtime event"
git push
```

### Task 3: ChatPanel 交互与当前会话收口

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Reference: `desktop/src/views/Chat.vue`
- Reference: `desktop/src/components/GroupSettingsDrawer.vue`

- [ ] **Step 1: 先补失败测试或最小可验证行为点**

如果当前组件测试成本过高，则以已有 API / util 测试为回归基础，手工验证以下行为：
- 群主显示“解散群聊”
- 非群主显示“退出群聊”
- 成功后清空当前群上下文并刷新会话列表
- 收到 `group_dissolved` 命中当前房间后自动收口并提示

- [ ] **Step 2: 写最小实现**

在 `ChatPanel.vue`：
- 增加 “退出群聊 / 解散群聊” 动作
- 统一成功后的当前房间收口 helper
- 接入 `group_dissolved` 与当前用户被移出群的 notice / reload 行为

- [ ] **Step 3: 跑前端验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [ ] **Step 4: 回填 backlog 并提交**

```bash
git add desktop-el/renderer/src/components/ChatPanel.vue docs/plans/2026-03-24-desktop-el-migration-backlog.md docs/plans/2026-03-25-desktop-el-group-leave-dissolve-plan.md
git commit -m "feat(desktop-el): support leaving and dissolving groups"
git push
```

### Task 4: 固定收尾

**Files:**
- None

- [ ] **Step 1: 清理桌面进程**

Run: `make desktop-el-down`

- [ ] **Step 2: 核对残留进程**

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 没有遗留客户端 / go-core 业务进程；若有，继续清理。

- [ ] **Step 3: 核对工作区**

Run: `git status --short --branch`
Expected: 干净，且分支领先远端已推送。
