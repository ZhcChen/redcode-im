# Desktop EL Remaining Group Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐当前群设置面板里剩余的 3 个写侧能力：`member_can_add_friends`、`require_admin_to_add_friends` 与 `max_members`。

**Architecture:** 继续保持 Go core 代理 backend `PATCH /rooms/:room_id/settings`，renderer 只消费 stdio RPC 与现有 websocket push。当前切口仅在现有群设置卡片原位扩展，不新增桌面业务 HTTP 端口，不引入新的群设置弹窗或抽屉。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API、websocket push

---

### Task 1: 补齐 API 与输入校验测试

**Files:**
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`
- Create: `desktop-el/renderer/src/utils/chat-group-settings.ts`
- Create: `desktop-el/renderer/src/utils/chat-group-settings.test.ts`

- [x] **Step 1: 写失败测试，约束 Go core PATCH 透传剩余字段**

在 `desktop-el/go-core/internal/app/app_test.go` 增加用例，校验：
- `chat.group.settings.update` 可透传 `member_can_add_friends`
- `chat.group.settings.update` 可透传 `require_admin_to_add_friends`
- `chat.group.settings.update` 可透传 `max_members`
- 请求体只包含本次提交的字段

- [x] **Step 2: 写失败测试，约束 renderer API 与最大人数输入校验**

在 `desktop-el/renderer/src/api/chat.test.ts` 增加用例，校验：
- `ChatApi.updateGroupSettings` 可透传上述 3 个字段
- 返回值继续映射为 `ChatGroupSettings`

在 `desktop-el/renderer/src/utils/chat-group-settings.test.ts` 增加用例，校验：
- 最大人数输入必须为正整数
- 与当前值相同时返回“不需要提交”
- 去掉首尾空白后可正常解析

- [x] **Step 3: 跑 targeted tests 确认先失败**

Run: `go test ./internal/app -run 'TestAppChatGroupSettingsUpdate'`
Expected: PASS，说明 Go core 现有 `chat.group.settings.update` 已可复用，新增测试只是在补覆盖面

Run: `bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-group-settings.test.ts`
Expected: FAIL，原因是 `chat-group-settings` util 尚未实现

- [x] **Step 4: 最小实现让测试转绿**

最小改动范围：
- 只补现有 API 测试覆盖，不新增新的 RPC 名称
- 新建一个聚焦最大人数解析的 util，避免把校验散落在 `ChatPanel.vue`

### Task 2: 在 ChatPanel 原位补齐剩余群设置写侧

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/utils/chat-group-settings.ts`

- [x] **Step 1: 扩展群设置面板展示**

补充只读展示项：
- `member_can_add_friends`
- `require_admin_to_add_friends`

并在当前卡片中增加：
- 最大人数输入框
- 保存按钮

- [x] **Step 2: 接入 2 个开关动作与 1 个数值保存动作**

最小行为：
- 群主 / 管理员可切换“群内加好友”
- 群主 / 管理员可切换“加好友需管理员审批”
- 群主 / 管理员可提交新的最大人数
- 提交中显示对应 loading 态

- [x] **Step 3: 成功后更新本地状态，失败时回退**

最小行为：
- 成功后直接更新 `groupSettings`
- `max_members` 成功后同步刷新输入框草稿
- 失败时调用 `loadGroupSettings(roomId)` 回拉
- notice 文案与动作结果一致

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts renderer/src/utils/chat-group-settings.test.ts`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-settings-remaining-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P0-3` 当前进度与缺口描述，标记：
- `member_can_add_friends`
- `require_admin_to_add_friends`
- `max_members`

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
  docs/plans/2026-03-25-desktop-el-group-settings-remaining-plan.md \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue \
  desktop-el/renderer/src/utils/chat-group-settings.ts \
  desktop-el/renderer/src/utils/chat-group-settings.test.ts
git commit -m "feat(desktop-el): complete group settings actions"
git push origin codex/desktop-el
```

- [ ] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
