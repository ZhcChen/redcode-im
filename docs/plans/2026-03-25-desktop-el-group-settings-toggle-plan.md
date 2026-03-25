# Desktop EL Group Settings Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐当前群设置面板中的“入群审批”和“成员邀请”两个写侧开关，让群主/管理员可以直接修改这两个群设置项。

**Architecture:** 继续保持 Go core 代理 backend `PATCH /rooms/:room_id/settings`，renderer 只消费 stdio RPC 与现有 websocket push。当前切口只覆盖 `join_approval_required` 和 `member_can_invite` 两个布尔开关，不扩到 `max_members`、群头像、管理员列表或群成员管理。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API、websocket push

---

### Task 1: Go Core Group Settings Patch RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写失败测试，约束 `chat.group.settings.update`**

在 `desktop-el/go-core/internal/app/app_test.go` 增加用例，校验：
- `chat.group.settings.update` 调 `PATCH /rooms/:room_id/settings`
- 请求体仅带已传入字段
- 返回 envelope 保留 `settings` 和 `my_mute`

- [x] **Step 2: 运行单测确认先失败**

Run: `go test ./internal/app -run TestAppChatGroupSettingsUpdateReturnsEnvelope`
Expected: FAIL，原因是 RPC 尚未注册

- [x] **Step 3: 最小实现 RPC**

在 `desktop-el/go-core/internal/chat/service.go` 增加：
- `UpdateGroupSettingsParams`
- `UpdateGroupSettings(ctx, params)`

在 `desktop-el/go-core/internal/app/app.go` 注册：
- `chat.group.settings.update`

- [x] **Step 4: 运行单测确认转绿**

Run: `go test ./internal/app -run TestAppChatGroupSettingsUpdateReturnsEnvelope`
Expected: PASS

### Task 2: Renderer Group Settings Update API

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束群设置更新 API**

在 `desktop-el/renderer/src/api/chat.test.ts` 增加用例，校验：
- `ChatApi.updateGroupSettings` 调 `chat.group.settings.update`
- 仅透传传入字段
- 返回值映射为 `ChatGroupSettings`

- [x] **Step 2: 运行测试确认先失败**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是 API 尚未实现

- [x] **Step 3: 最小实现 API**

在 `desktop-el/renderer/src/api/chat.ts` 增加：
- `ChatApi.updateGroupSettings(params)`

- [x] **Step 4: 运行测试确认转绿**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 3: ChatPanel Settings Toggle Actions

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入设置更新动作状态**

增加：
- 当前正在更新的设置项状态
- 通用的群设置 patch 提交函数

- [x] **Step 2: 在群设置区接入两个动作按钮**

最小行为：
- 群主或管理员可见“开启 / 关闭入群审批”
- 群主或管理员可见“开启 / 关闭成员邀请”
- 提交中显示 loading 态

- [x] **Step 3: 成功后本地刷新设置并给出 notice**

最小行为：
- 成功后更新 `groupSettings`
- 失败时回退到 `loadGroupSettings(roomId)`
- notice 文案与当前动作一致

- [x] **Step 4: 运行 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 4: 收尾验证与文档回填

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-settings-toggle-plan.md`

- [x] **Step 1: 回填 backlog**

把入群审批 / 成员邀请两个设置开关的进度回填到 backlog。

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
  docs/plans/2026-03-25-desktop-el-group-settings-toggle-plan.md
git commit -m "feat(desktop-el): support group settings toggles"
git push origin codex/desktop-el
```

- [ ] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
