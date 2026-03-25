# Desktop EL Group Admin Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的现有群聊补齐“群管理员管理”最小闭环，让群主可以查看当前管理员、任命管理员并撤销管理员。

**Architecture:** 继续保持 Go core 承接 backend 群管理接口，renderer 只通过 stdio RPC 调用 Go core。当前切口只覆盖“列表 -> 任命 -> 撤销 -> 刷新群详情 / 群设置 / 会话列表”，不扩展到更细权限矩阵、审批流、禁言流或操作日志。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API

---

### Task 1: Go core 与 renderer API 管理员能力

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束管理员管理 RPC 与 renderer API**

新增测试，校验：
- Go core `chat.group.admins.list` 调 `GET /rooms/:room_id/admins`
- Go core `chat.group.admin.appoint` 调 `POST /rooms/:room_id/admins`
- Go core `chat.group.admin.remove` 调 `DELETE /rooms/:room_id/admins/:admin_id`
- renderer `ChatApi.listGroupAdmins` / `appointGroupAdmin` / `removeGroupAdmin` 调用上述 RPC 并映射返回值

- [x] **Step 2: 跑 targeted tests 确认先失败**

Run: `go test ./internal/app -run 'TestAppChatGroupAdminsListReturnsEnvelope|TestAppChatGroupAdminAppointReturnsEnvelope|TestAppChatGroupAdminRemoveReturnsEnvelope'`
Expected: FAIL，原因是 RPC 尚未注册

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是管理员相关 API 尚未实现

- [x] **Step 3: 最小实现 RPC 与 API**

最小改动：
- Go core 增加群管理员列表 / 任命 / 撤销 3 个 RPC
- renderer 增加 `ChatApi.listGroupAdmins`、`ChatApi.appointGroupAdmin`、`ChatApi.removeGroupAdmin`

- [x] **Step 4: 运行 targeted tests 确认转绿**

Run: `go test ./internal/app -run 'TestAppChatGroupAdminsListReturnsEnvelope|TestAppChatGroupAdminAppointReturnsEnvelope|TestAppChatGroupAdminRemoveReturnsEnvelope'`
Expected: PASS

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: ChatPanel 管理员弹窗与操作闭环

**Files:**
- Create: `desktop-el/renderer/src/components/ManageGroupAdminsModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入当前管理员列表与可任命成员过滤**

最小行为：
- 仅群主允许打开管理员管理弹窗
- 弹窗展示当前管理员列表
- 候选成员过滤掉群主、当前已是管理员的成员

- [x] **Step 2: 接入任命与撤销动作**

最小行为：
- 允许从当前群成员中多选任命管理员
- 允许对现有管理员执行撤销
- 操作期间给出提交态，避免重复提交

- [x] **Step 3: 成功后刷新当前群上下文**

最小行为：
- 成功后刷新会话列表、群详情、群设置
- 视图内成员角色标签同步更新
- notice 给出任命 / 撤销结果

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-admin-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P1-1` 中“群管理员管理”的当前进度说明，并收紧剩余缺口。

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
  docs/plans/2026-03-25-desktop-el-group-admin-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ManageGroupAdminsModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support group admin management"
git push origin codex/desktop-el
```

- [x] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
