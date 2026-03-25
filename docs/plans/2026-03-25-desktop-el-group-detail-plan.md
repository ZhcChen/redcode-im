# Desktop EL Group Detail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐当前选中群聊的基础详情展示，并接入 `room_created` / `room_updated` 的最小实时刷新。

**Architecture:** 保持 Electron 只做宿主壳，群详情读侧全部走 Go core RPC，renderer 不直接请求 backend。当前切口只补“房间详情 + 成员列表 + room 级 websocket 刷新”，不扩展到群设置写操作、群头像上传或管理员逻辑。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend room API、websocket push

---

### Task 1: Go Core Room Detail RPC

**Files:**

- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写失败测试，约束 `chat.room.get` 与 `chat.room.members.list`**

在 `desktop-el/go-core/internal/app/app_test.go` 增加用例，校验：

- `chat.room.get` 调 `GET /rooms/:room_id`
- `chat.room.members.list` 调 `GET /rooms/:room_id/members`
- envelope 数据保持 backend 响应结构

- [x] **Step 2: 运行单测确认先失败**

Run: `go test ./internal/app -run 'TestAppChatRoom(GetReturnsEnvelope|MembersListReturnsEnvelope)'`
Expected: FAIL，原因是 RPC 尚未注册

- [x] **Step 3: 最小实现 RPC**

在 `desktop-el/go-core/internal/chat/service.go` 增加：

- `GetRoom(ctx, params)`
- `ListRoomMembers(ctx, params)`

在 `desktop-el/go-core/internal/app/app.go` 注册：

- `chat.room.get`
- `chat.room.members.list`

- [x] **Step 4: 运行单测确认转绿**

Run: `go test ./internal/app -run 'TestAppChatRoom(GetReturnsEnvelope|MembersListReturnsEnvelope)'`
Expected: PASS

### Task 2: Renderer Chat API And Realtime Mapping

**Files:**

- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束群详情 API 与 room 级事件映射**

在 `desktop-el/renderer/src/api/chat.test.ts` 增加用例，校验：

- `ChatApi.getRoom` 映射 `room`
- `ChatApi.listRoomMembers` 映射成员列表
- `mapChatRealtimeEvent` 能识别 `room_created`
- `mapChatRealtimeEvent` 能识别 `room_updated`

- [x] **Step 2: 运行测试确认先失败**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是 API 或 event mapping 尚未实现

- [x] **Step 3: 最小实现 API 与 event mapping**

在 `desktop-el/renderer/src/api/chat.ts` 增加：

- `ChatRoomDetail`
- `ChatRoomMember`
- `ChatApi.getRoom`
- `ChatApi.listRoomMembers`
- `room_created` / `room_updated` 的 realtime 类型和映射

- [x] **Step 4: 运行测试确认转绿**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 3: ChatPanel Group Detail UI

**Files:**

- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入群详情状态与加载函数**

在 `ChatPanel` 增加：

- `groupDetail`
- `groupMembers`
- `isLoadingGroupDetail`
- `loadGroupContext(roomId)`
- 非群聊时清空群详情状态

- [x] **Step 2: 在选中群聊时展示基础详情**

展示最小字段：

- 群名
- 群简介
- 群主
- 成员数量
- 创建时间
- 成员列表（最小展示）

- [x] **Step 3: 接入 `room_created` / `room_updated` 刷新**

在 `handleRealtimeEvent` 中：

- 房间创建时刷新会话列表
- 房间更新时刷新会话列表
- 若事件命中当前选中群，则额外刷新 `loadGroupContext`

- [x] **Step 4: 运行 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 4: 收尾验证与文档回填

**Files:**

- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-detail-plan.md`

- [x] **Step 1: 回填 backlog**

把 `P0-3` 的“群详情基础展示”和 `room_created` / `room_updated` 最小刷新进度回填到 backlog。

- [x] **Step 2: 跑完整验证**

Run: `go test ./...`
Expected: PASS

Run: `bun test`
Expected: 仍然只有既有 3 个 Electron named export mock 失败

Run: `bun run build`
Expected: PASS

- [ ] **Step 3: 提交与推送**

```bash
git add desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-25-desktop-el-group-detail-plan.md
git commit -m "feat(desktop-el): show group detail"
git push origin codex/desktop-el
```

- [ ] **Step 4: 进程清理**

## Verification Notes

- `go test ./internal/app -run 'TestAppChatRoom(GetReturnsEnvelope|MembersListReturnsEnvelope)'`
- `bun test renderer/src/api/chat.test.ts`
- `go test ./...`
- `bun run build`
- `bun test` 仍然只有既有 3 个 Electron named export mock 失败：
  - `electron/main/file.test.ts`
  - `electron/main/rpc.test.ts`
  - `electron/preload/api.test.ts`

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
