# Desktop EL Group Settings Readonly Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐当前选中群聊的只读设置展示，并接入 `group_settings_updated` / `group_member_changed` 的最小实时响应。

**Architecture:** 保持 Electron 只做宿主壳，群设置读侧全部通过 Go core 调 backend `GET /rooms/:room_id/settings`，renderer 只消费 stdio RPC 和 websocket push。当前切口只补设置展示和刷新，不做设置修改、禁言写操作、成员管理或群头像上传。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group settings API、websocket push

---

### Task 1: Go Core Group Settings RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`

- [x] **Step 1: 写失败测试，约束 `chat.group.settings.get`**

在 `desktop-el/go-core/internal/app/app_test.go` 增加用例，校验：
- `chat.group.settings.get` 调 `GET /rooms/:room_id/settings`
- envelope 保留 `settings` 和 `my_mute`

- [x] **Step 2: 运行单测确认先失败**

Run: `go test ./internal/app -run TestAppChatGroupSettingsGetReturnsEnvelope`
Expected: FAIL，原因是 RPC 尚未注册

- [x] **Step 3: 最小实现 RPC**

在 `desktop-el/go-core/internal/chat/service.go` 增加 `GetGroupSettings(ctx, params)`；
在 `desktop-el/go-core/internal/app/app.go` 注册 `chat.group.settings.get`。

- [x] **Step 4: 运行单测确认转绿**

Run: `go test ./internal/app -run TestAppChatGroupSettingsGetReturnsEnvelope`
Expected: PASS

### Task 2: Renderer Group Settings API And Event Mapping

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束群设置映射与事件映射**

在 `desktop-el/renderer/src/api/chat.test.ts` 增加用例，校验：
- `ChatApi.getGroupSettings` 映射 `settings` + `my_mute`
- `mapChatRealtimeEvent` 能识别 `group_settings_updated`
- `mapChatRealtimeEvent` 能识别 `group_member_changed`

- [x] **Step 2: 运行测试确认先失败**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是 API 或 realtime 映射尚未实现

- [x] **Step 3: 最小实现 API 与事件映射**

在 `desktop-el/renderer/src/api/chat.ts` 增加：
- `ChatGroupSettings`
- `ChatGroupMyMute`
- `ChatApi.getGroupSettings`
- `group_settings_updated` / `group_member_changed` 的 realtime 类型和映射

- [x] **Step 4: 运行测试确认转绿**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 3: ChatPanel Readonly Group Settings And Realtime

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入群设置状态与加载函数**

增加：
- `groupSettings`
- `isLoadingGroupSettings`
- `loadGroupSettings(roomId)`

- [x] **Step 2: 在群详情区展示只读设置**

展示最小字段：
- 全员禁言状态
- 全员禁言原因 / 截止时间（若有）
- 入群审批
- 成员邀请权限
- 最大人数
- 当前用户个人禁言状态

- [x] **Step 3: 接入 `group_settings_updated` / `group_member_changed`**

最小行为：
- `group_settings_updated` 命中当前群时刷新 `loadGroupSettings`
- `group_member_changed` 命中当前群时刷新 `loadGroupContext`
- 若变更成员是当前用户且类型为 `muted/unmuted`，同步刷新设置并更新 notice

- [x] **Step 4: 运行 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun test renderer/src/utils/chat-group-realtime.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 4: 收尾验证与文档回填

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-settings-plan.md`

- [x] **Step 1: 回填 backlog**

把群设置只读展示和 `group_settings_updated` / `group_member_changed` 进度回填到 backlog。

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
  desktop-el/renderer/src/utils/chat-group-realtime.ts \
  desktop-el/renderer/src/utils/chat-group-realtime.test.ts \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-25-desktop-el-group-settings-plan.md
git commit -m "feat(desktop-el): show group settings"
git push origin codex/desktop-el
```

- [ ] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
