# Desktop EL Group Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的现有群聊补齐“群规管理”最小闭环，让群成员可查看群规，群主 / 管理员可新增、编辑和删除群规。

**Architecture:** 继续保持 Go core 承接 backend 群管理接口，renderer 只通过 stdio RPC 调用 Go core。当前切口只覆盖“列表 -> 新增 -> 编辑 -> 删除 -> 刷新群规则视图”，不扩展到拖拽排序、富文本编辑、操作日志联动或更复杂的权限矩阵。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API

---

### Task 1: Go core 与 renderer API 群规能力

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束群规 RPC 与 renderer API**

新增测试，校验：
- Go core `chat.group.rules.list` 调 `GET /rooms/:room_id/rules`
- Go core `chat.group.rule.create` 调 `POST /rooms/:room_id/rules`
- Go core `chat.group.rule.update` 调 `PATCH /rooms/:room_id/rules/:rule_id`
- Go core `chat.group.rule.delete` 调 `DELETE /rooms/:room_id/rules/:rule_id`
- renderer `ChatApi.listGroupRules` / `createGroupRule` / `updateGroupRule` / `deleteGroupRule` 调用上述 RPC 并映射返回值

- [x] **Step 2: 跑 targeted tests 确认先失败**

Run: `go test ./internal/app -run 'TestAppChatGroupRulesListReturnsEnvelope|TestAppChatGroupRuleCreateReturnsEnvelope|TestAppChatGroupRuleUpdateReturnsEnvelope|TestAppChatGroupRuleDeleteReturnsEnvelope'`
Expected: FAIL，原因是 RPC 尚未注册

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是群规相关 API 尚未实现

- [x] **Step 3: 最小实现 RPC 与 API**

最小改动：
- Go core 增加群规列表 / 创建 / 更新 / 删除 4 个 RPC
- renderer 增加 `ChatApi.listGroupRules`、`ChatApi.createGroupRule`、`ChatApi.updateGroupRule`、`ChatApi.deleteGroupRule`

- [x] **Step 4: 运行 targeted tests 确认转绿**

Run: `go test ./internal/app -run 'TestAppChatGroupRulesListReturnsEnvelope|TestAppChatGroupRuleCreateReturnsEnvelope|TestAppChatGroupRuleUpdateReturnsEnvelope|TestAppChatGroupRuleDeleteReturnsEnvelope'`
Expected: PASS

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: ChatPanel 群规弹窗与增删改闭环

**Files:**
- Create: `desktop-el/renderer/src/components/ManageGroupRulesModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入群规列表与入口**

最小行为：
- 当前群成员可打开“群规”弹窗
- 弹窗展示 active rules，并按 `orderIndex` 升序显示
- 群主 / 管理员可看到新增、编辑、删除入口

- [x] **Step 2: 接入新增 / 编辑 / 删除动作**

最小行为：
- 支持输入标题和内容创建群规
- 支持在现有群规上编辑标题和内容
- 支持删除单条群规
- 操作期间给出提交态，避免重复提交

- [x] **Step 3: 成功后刷新当前群上下文**

最小行为：
- 成功后刷新群规列表
- 不改变当前 `ChatPanel` 主布局
- notice 给出新增 / 编辑 / 删除结果

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-rules-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P1-1` 中“群规管理”的当前进度说明，并收紧剩余缺口。

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
  docs/plans/2026-03-25-desktop-el-group-rules-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ManageGroupRulesModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support group rules management"
git push origin codex/desktop-el
```

- [x] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
