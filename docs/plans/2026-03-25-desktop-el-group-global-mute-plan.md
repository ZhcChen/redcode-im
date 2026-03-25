# Desktop EL Group Global Mute Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐“全员禁言写侧 + 群聊输入区禁用态”最小闭环，让群主/管理员可以直接在当前群设置面板里开启或解除全员禁言，并让当前用户的输入框状态随群禁言和个人禁言实时变化。

**Architecture:** 继续保持 Electron 只做宿主壳、Go core 负责所有业务 HTTP 代理、renderer 只通过 stdio RPC 和 websocket push 交互。当前切口只补 `POST /rooms/:room_id/mutes/global` 的写侧能力，以及基于现有 `groupSettings` / `groupMembers` 的本地权限与输入态推导；不扩到群设置 PATCH、管理员列表、转让群主或解散群。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API、websocket push

---

### Task 1: Go Core Global Mute Update RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写失败测试，约束 `chat.group.settings.global_mute.update`**

在 `desktop-el/go-core/internal/app/app_test.go` 增加用例，校验：
- `chat.group.settings.global_mute.update` 调 `POST /rooms/:room_id/mutes/global`
- 请求体包含 `enabled`
- backend 返回的 envelope 保留 `settings` 和 `my_mute`

- [x] **Step 2: 运行单测确认先失败**

Run: `go test ./internal/app -run TestAppChatGroupGlobalMuteUpdateReturnsEnvelope`
Expected: FAIL，原因是 RPC 尚未注册

- [x] **Step 3: 最小实现 RPC**

在 `desktop-el/go-core/internal/chat/service.go` 增加：
- `UpdateGlobalMuteParams`
- `UpdateGroupGlobalMute(ctx, params)`

在 `desktop-el/go-core/internal/app/app.go` 注册：
- `chat.group.settings.global_mute.update`

- [x] **Step 4: 运行单测确认转绿**

Run: `go test ./internal/app -run TestAppChatGroupGlobalMuteUpdateReturnsEnvelope`
Expected: PASS

### Task 2: Renderer API And Group Permission Helpers

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`
- Create: `desktop-el/renderer/src/utils/chat-group-permissions.ts`
- Create: `desktop-el/renderer/src/utils/chat-group-permissions.test.ts`

- [x] **Step 1: 写失败测试，约束全员禁言更新 API 与输入态推导**

在 `desktop-el/renderer/src/api/chat.test.ts` 增加用例，校验：
- `ChatApi.updateGroupGlobalMute` 调 `chat.group.settings.global_mute.update`
- 返回值映射为 `ChatGroupSettings`

在 `desktop-el/renderer/src/utils/chat-group-permissions.test.ts` 增加用例，校验：
- 当前用户是 `owner/admin` 时可管理群
- 当前用户被个人禁言时输入框禁用
- 全员禁言开启且当前用户不是管理者时输入框禁用
- 管理者在全员禁言时仍可发送消息

- [x] **Step 2: 运行测试确认先失败**

Run: `bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-group-permissions.test.ts`
Expected: FAIL，原因是 API 或 helper 尚未实现

- [x] **Step 3: 最小实现 API 与 helper**

在 `desktop-el/renderer/src/api/chat.ts` 增加：
- `ChatApi.updateGroupGlobalMute(params)`

在 `desktop-el/renderer/src/utils/chat-group-permissions.ts` 增加：
- `resolveGroupManageState(...)`
- `resolveGroupComposerState(...)`

- [x] **Step 4: 运行测试确认转绿**

Run: `bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-group-permissions.test.ts`
Expected: PASS

### Task 3: ChatPanel Global Mute Action And Composer State

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入群管理权限与输入态计算**

增加：
- 当前用户是否可管理群的 computed
- 输入框是否禁用的 computed
- 输入框 placeholder / 禁用提示文本

- [x] **Step 2: 在群设置面板接入全员禁言按钮**

最小行为：
- 群主或管理员显示“开启全员禁言 / 解除全员禁言”按钮
- 提交中展示 loading 态
- 成功后直接更新 `groupSettings`
- 成功后刷新会话列表并给出 notice

- [x] **Step 3: 把输入区与附件操作接入禁用态**

最小行为：
- `textarea`、附件选择、发送按钮接入禁用态
- `handleSend` / `handlePickAttachment` 对禁用态做兜底
- 当前用户被个人禁言或群全员禁言命中时，显示明确提示

- [x] **Step 4: 运行 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-group-permissions.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 4: 收尾验证与文档回填

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-global-mute-plan.md`

- [x] **Step 1: 回填 backlog**

把全员禁言写侧和群输入区禁用态的进度回填到 backlog。

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
  desktop-el/renderer/src/utils/chat-group-permissions.ts \
  desktop-el/renderer/src/utils/chat-group-permissions.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-25-desktop-el-group-global-mute-plan.md
git commit -m "feat(desktop-el): support group global mute"
git push origin codex/desktop-el
```

- [ ] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
