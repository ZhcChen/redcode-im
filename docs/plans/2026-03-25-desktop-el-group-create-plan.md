# Desktop EL Group Create Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐“创建群聊并自动进入新群”的最小闭环。

**Architecture:** 保持 Electron 只做宿主壳，群创建业务通过 Go core 新增 `chat.group.create` RPC 调 backend `POST /rooms`。renderer 侧只负责群创建表单、成员选择、调用 RPC、刷新会话列表并切换到新房间，不新增本地 HTTP 端口或绕过 Go core 直接拼业务请求。

**Tech Stack:** Vue 3、TypeScript、Bun test、Go 1.25、Go core stdio RPC、backend room API

---

### Task 1: Go Core Group Create RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写失败测试，约束 `chat.group.create` RPC**

在 `desktop-el/go-core/internal/app/app_test.go` 增加用例，校验：
- RPC 方法名为 `chat.group.create`
- Go core 向 backend 发起 `POST /rooms`
- body 至少包含 `name` 与 `member_ids`
- 返回 envelope 中可读取新群 `room.id` / `room.name` / `room.room_type`

- [x] **Step 2: 运行单测确认先失败**

Run: `go test ./internal/app -run TestAppChatCreateGroupPostsRooms`
Expected: FAIL，原因是 `chat.group.create` 尚未注册或 service 方法不存在

- [x] **Step 3: 最小实现 `chat.group.create`**

在 `desktop-el/go-core/internal/chat/service.go` 新增 `CreateGroupParams` 与 `CreateGroup`；
在 `desktop-el/go-core/internal/app/app.go` 注册 `chat.group.create`，走 Go core -> backend `/rooms`。

- [x] **Step 4: 运行单测确认转绿**

Run: `go test ./internal/app -run TestAppChatCreateGroupPostsRooms`
Expected: PASS

### Task 2: Renderer Chat API Group Create

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束 `ChatApi.createGroup` 映射**

在 `desktop-el/renderer/src/api/chat.test.ts` 增加用例，校验：
- renderer 调 `chat.group.create`
- 参数含 `name` 与 `member_user_ids`
- 成功后映射出 `roomId`、`roomName`、`roomType`

- [x] **Step 2: 运行测试确认先失败**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是 `ChatApi.createGroup` 尚未实现

- [x] **Step 3: 最小实现 `ChatApi.createGroup`**

在 `desktop-el/renderer/src/api/chat.ts` 增加 backend payload 类型与 `createGroup` 方法，保持字段映射与现有 `ensurePrivateChat` 风格一致。

- [x] **Step 4: 运行测试确认转绿**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 3: Group Create UI Helper

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-group-create.ts`
- Create: `desktop-el/renderer/src/utils/chat-group-create.test.ts`

- [x] **Step 1: 写失败测试，约束群创建表单最小规则**

在 `desktop-el/renderer/src/utils/chat-group-create.test.ts` 增加用例，覆盖：
- 群名不能为空、长度不能超过 20
- 至少选择一位好友
- 创建成功后能按 `roomId` 优先从会话列表中定位新群

- [x] **Step 2: 运行测试确认先失败**

Run: `bun test renderer/src/utils/chat-group-create.test.ts`
Expected: FAIL，原因是 helper 尚未存在

- [x] **Step 3: 最小实现 helper**

在 `desktop-el/renderer/src/utils/chat-group-create.ts` 实现：
- `validateGroupCreatePayload`
- `findCreatedGroupChat`

- [x] **Step 4: 运行测试确认转绿**

Run: `bun test renderer/src/utils/chat-group-create.test.ts`
Expected: PASS

### Task 4: ChatPanel Create Group Modal

**Files:**
- Create: `desktop-el/renderer/src/components/CreateGroupModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/api/friend.ts`（仅当需要更明确的成员展示字段时）

- [x] **Step 1: 接入创建群聊入口**

在 `ChatPanel` 侧栏头部增加“创建群聊”按钮，打开新 modal。

- [x] **Step 2: 接入好友列表选择**

modal 内复用 `FriendApi.getMyFriendList()` 拉好友列表，支持关键字过滤与多选，表单仅保留：
- 群聊名称
- 成员选择

- [x] **Step 3: 接入创建成功后的自动切群**

提交后调用 `ChatApi.createGroup`，然后 `loadChats({ preferredRoomId })`，并用 `findCreatedGroupChat` 兜底查找，最后 `selectChat(newRoomId)`。

- [x] **Step 4: 保持 notice 与 loading 状态**

创建中、失败、成功都更新 `notice`，避免 silent failure。

- [x] **Step 5: 运行 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-group-create.test.ts`
Expected: PASS

### Task 5: 收尾验证与文档回填

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 回填 backlog**

把 `P0-3` 的“先补建群与基础群房间进入”标为已完成或补充当前进度描述。

- [x] **Step 2: 跑 Go / renderer 验证**

Run: `go test ./...`
Expected: PASS

Run: `bun test`
Expected: 仍然只有既有 3 个 Electron mock 失败，无新增失败

Run: `bun run build`
Expected: PASS

- [ ] **Step 3: 提交与推送**

```bash
git add desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/utils/chat-group-create.ts \
  desktop-el/renderer/src/utils/chat-group-create.test.ts \
  desktop-el/renderer/src/components/CreateGroupModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-25-desktop-el-group-create-plan.md
git commit -m "feat(desktop-el): support group creation"
git push origin codex/desktop-el
```

- [ ] **Step 4: 进程清理**

## Verification Notes

- `bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-group-create.test.ts`
- `go test ./...`
- `bun run build`
- `bun test` 结果仍旧只有既有 3 个 Electron named export mock 失败：
  - `electron/main/file.test.ts`
  - `electron/main/rpc.test.ts`
  - `electron/preload/api.test.ts`

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
