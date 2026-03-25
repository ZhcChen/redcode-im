# Desktop EL Group Mutes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的现有群聊补齐“成员禁言管理”最小闭环，让群主 / 管理员可以查看当前禁言列表、禁言普通成员并解除禁言。

**Architecture:** 继续保持 Go core 承接 backend 群管理接口，renderer 只通过 stdio RPC 调用 Go core。当前切口只覆盖“列表 -> 禁言 -> 解除禁言 -> 刷新群详情 / 群设置 / 会话列表”，不扩展到更细权限矩阵、批量策略、群规联动或操作日志面板。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API

---

### Task 1: Go core 与 renderer API 禁言能力

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束禁言管理 RPC 与 renderer API**

新增测试，校验：
- Go core `chat.group.mutes.list` 调 `GET /rooms/:room_id/mutes`
- Go core `chat.group.mute.create` 调 `POST /rooms/:room_id/mutes`
- Go core `chat.group.mute.remove` 调 `DELETE /rooms/:room_id/mutes/:user_id`
- renderer `ChatApi.listGroupMutes` / `muteGroupMember` / `unmuteGroupMember` 调用上述 RPC 并映射返回值

- [x] **Step 2: 跑 targeted tests 确认先失败**

Run: `go test ./internal/app -run 'TestAppChatGroupMutesListReturnsEnvelope|TestAppChatGroupMuteCreateReturnsEnvelope|TestAppChatGroupMuteRemoveReturnsEnvelope'`
Expected: FAIL，原因是 RPC 尚未注册

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是禁言相关 API 尚未实现

- [x] **Step 3: 最小实现 RPC 与 API**

最小改动：
- Go core 增加群禁言列表 / 创建禁言 / 解除禁言 3 个 RPC
- renderer 增加 `ChatApi.listGroupMutes`、`ChatApi.muteGroupMember`、`ChatApi.unmuteGroupMember`

- [x] **Step 4: 运行 targeted tests 确认转绿**

Run: `go test ./internal/app -run 'TestAppChatGroupMutesListReturnsEnvelope|TestAppChatGroupMuteCreateReturnsEnvelope|TestAppChatGroupMuteRemoveReturnsEnvelope'`
Expected: PASS

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: ChatPanel 禁言管理弹窗与操作闭环

**Files:**
- Create: `desktop-el/renderer/src/components/ManageGroupMutesModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入禁言列表与入口**

最小行为：
- 群主 / 管理员可打开“禁言管理”弹窗
- 弹窗展示当前 active mutes、禁言原因、解禁时间
- 候选成员过滤掉群主、管理员和当前已被禁言成员

- [x] **Step 2: 接入禁言与解除禁言动作**

最小行为：
- 支持从当前群成员里多选普通成员禁言
- 先提供几个固定时长预设，并允许永久禁言
- 支持对现有禁言成员执行解除禁言
- 操作期间给出提交态，避免重复提交

- [x] **Step 3: 成功后刷新当前群上下文**

最小行为：
- 成功后刷新会话列表、群详情、群设置、禁言列表
- 保持当前 `ChatPanel` 群详情页结构不变
- notice 给出禁言 / 解除禁言结果

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-mutes-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P1-1` 中“禁言管理”的当前进度说明，并收紧剩余缺口。

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
  docs/plans/2026-03-25-desktop-el-group-mutes-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ManageGroupMutesModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support group mute management"
git push origin codex/desktop-el
```

- [x] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
