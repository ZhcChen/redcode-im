# Desktop EL Group Join Requests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的现有群聊补齐“入群申请管理”最小闭环，让群主 / 管理员可以查看待审核申请，并执行通过或拒绝。

**Architecture:** 继续保持 Go core 承接 backend 群管理接口，renderer 只通过 stdio RPC 调用 Go core。当前切口只覆盖“列表 -> 审核通过 / 拒绝 -> 刷新群详情 / 群设置 / 会话列表”，不扩展到申请发起侧、批量审核、操作日志联动或更深群审批流。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API

---

### Task 1: Go core 与 renderer API 入群申请能力

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束入群申请 RPC 与 renderer API**

新增测试，校验：
- Go core `chat.group.join_requests.list` 调 `GET /rooms/:room_id/join-requests`
- Go core `chat.group.join_request.review` 调 `PATCH /rooms/:room_id/join-requests/:request_id/review`
- renderer `ChatApi.listGroupJoinRequests` / `reviewGroupJoinRequest` 调用上述 RPC 并映射返回值

- [x] **Step 2: 跑 targeted tests 确认先失败**

Run: `go test ./internal/app -run 'TestAppChatGroupJoinRequestsListReturnsEnvelope|TestAppChatGroupJoinRequestReviewReturnsEnvelope'`
Expected: FAIL，原因是 RPC 尚未注册

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是入群申请相关 API 尚未实现

- [x] **Step 3: 最小实现 RPC 与 API**

最小改动：
- Go core 增加入群申请列表 / 审核 2 个 RPC
- renderer 增加 `ChatApi.listGroupJoinRequests`、`ChatApi.reviewGroupJoinRequest`

- [x] **Step 4: 运行 targeted tests 确认转绿**

Run: `go test ./internal/app -run 'TestAppChatGroupJoinRequestsListReturnsEnvelope|TestAppChatGroupJoinRequestReviewReturnsEnvelope'`
Expected: PASS

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: ChatPanel 入群审核弹窗与审批动作闭环

**Files:**
- Create: `desktop-el/renderer/src/components/ManageGroupJoinRequestsModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入申请列表与入口**

最小行为：
- 群主 / 管理员可打开“入群审核”弹窗
- 弹窗展示申请人、申请理由、申请时间、当前状态
- pending 申请优先展示

- [x] **Step 2: 接入通过 / 拒绝动作**

最小行为：
- 允许对 pending 申请执行通过或拒绝
- 操作期间给出提交态，避免重复提交
- 审核后刷新当前申请列表

- [x] **Step 3: 成功后刷新当前群上下文**

最小行为：
- 成功后刷新会话列表、群详情、群设置
- 如果通过申请导致成员变化，成员数和成员列表同步刷新
- notice 给出审核结果

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-join-requests-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P1-1` 中“入群申请管理”的当前进度说明，并收紧剩余缺口。

- [x] **Step 2: 跑完整验证**

Run: `go test ./...`
Expected: PASS

Run: `bun test`
Expected: 仍然只有既有 3 个 Electron named export mock 失败，且不新增失败项

Run: `bun run build`
Expected: PASS

- [x] **Step 3: 提交与推送**

```bash
git add docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-25-desktop-el-group-join-requests-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ManageGroupJoinRequestsModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support group join requests"
git push origin codex/desktop-el
```

- [x] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
