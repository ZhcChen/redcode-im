# Desktop EL Add Group Members Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的现有群聊补齐“添加成员”最小闭环，让群主 / 管理员可从好友列表选择用户并加入当前群。

**Architecture:** 继续保持 Go core 承接业务 RPC，renderer 不直接拼 backend 群管理请求。当前切口只覆盖“列出候选好友 -> 选择成员 -> 调用加人 RPC -> 刷新当前群上下文”，不展开到删成员、管理员管理或审批流。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API、现有好友选择 UI

---

### Task 1: Go core 与 renderer API 加人能力

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束加人 RPC 与 renderer API**

新增测试，校验：
- Go core `chat.room.members.add` 调 `POST /rooms/:room_id/members`
- 请求体透传 `user_ids`
- renderer `ChatApi.addGroupMembers` 调上述 RPC 并映射返回值

- [x] **Step 2: 跑 targeted tests 确认先失败**

Run: `go test ./internal/app -run TestAppChatRoomMembersAddReturnsEnvelope`
Expected: FAIL，原因是 RPC 尚未注册

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是 `ChatApi.addGroupMembers` 尚未实现

- [x] **Step 3: 最小实现 RPC 与 API**

最小改动：
- Go core 增加 `AddRoomMembers`
- renderer 增加 `ChatApi.addGroupMembers`

- [x] **Step 4: 运行 targeted tests 确认转绿**

Run: `go test ./internal/app -run TestAppChatRoomMembersAddReturnsEnvelope`
Expected: PASS

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: ChatPanel 添加成员弹窗与提交动作

**Files:**
- Create: `desktop-el/renderer/src/components/AddGroupMembersModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入候选好友加载与可添加成员过滤**

最小行为：
- 复用现有好友列表加载逻辑
- 过滤掉已在当前群内的成员
- 仅群主 / 管理员可打开弹窗

- [x] **Step 2: 接入成员选择弹窗与提交动作**

最小行为：
- 展示候选好友
- 允许多选
- 提交时调用 `ChatApi.addGroupMembers`

- [x] **Step 3: 成功后刷新当前群上下文**

最小行为：
- 成功后刷新会话列表、群详情、群设置
- notice 包含新增人数和跳过人数

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-member-add-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P1-1` / `P0-3` 中“群成员完整面板和管理动作”的当前进度说明。

- [x] **Step 2: 跑完整验证**

Run: `go test ./...`
Expected: PASS

Run: `bun test`
Expected: 仍然只有既有 3 个 Electron named export mock 失败

Run: `bun run build`
Expected: PASS

- [ ] **Step 3: 提交与推送**

```bash
git add docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-25-desktop-el-group-member-add-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/AddGroupMembersModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support adding group members"
git push origin codex/desktop-el
```

- [ ] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
