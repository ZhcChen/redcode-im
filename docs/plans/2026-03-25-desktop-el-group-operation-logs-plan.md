# Desktop EL Group Operation Logs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的现有群聊补齐“群操作日志”最小闭环，让群主 / 管理员可以查看最近群管理操作并继续分页加载。

**Architecture:** 继续保持 Go core 承接 backend 群管理接口，renderer 只通过 stdio RPC 调用 Go core。当前切口只覆盖“列表 -> 加载更多 -> 本地展示操作文案”，不扩展到筛选、搜索、导出、日志详情或复杂审计能力。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API

---

### Task 1: Go core 与 renderer API 操作日志能力

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束操作日志 RPC 与 renderer API**

新增测试，校验：
- Go core `chat.group.operation_logs.list` 调 `GET /rooms/:room_id/operation-logs?limit=&offset=`
- renderer `ChatApi.listGroupOperationLogs` 调用上述 RPC 并映射 `logs + total`

- [x] **Step 2: 跑 targeted tests 确认先失败**

Run: `go test ./internal/app -run 'TestAppChatGroupOperationLogsListReturnsEnvelope'`
Expected: FAIL，原因是 RPC 尚未注册

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是操作日志 API 尚未实现

- [x] **Step 3: 最小实现 RPC 与 API**

最小改动：
- Go core 增加群操作日志列表 RPC
- renderer 增加 `ChatApi.listGroupOperationLogs`

- [x] **Step 4: 运行 targeted tests 确认转绿**

Run: `go test ./internal/app -run 'TestAppChatGroupOperationLogsListReturnsEnvelope'`
Expected: PASS

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: ChatPanel 操作日志弹窗与分页闭环

**Files:**
- Create: `desktop-el/renderer/src/components/ManageGroupOperationLogsModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入操作日志入口与首屏列表**

最小行为：
- 仅群主 / 管理员可打开“操作日志”弹窗
- 弹窗展示时间、操作人、操作内容和目标成员
- 首屏按 backend 返回顺序展示最近一批日志

- [x] **Step 2: 接入加载更多**

最小行为：
- 支持继续请求下一页日志
- 通过 `limit + offset` 累加已加载列表
- 没有更多数据时隐藏“加载更多”

- [x] **Step 3: 成功后刷新当前日志视图**

最小行为：
- 弹窗打开时自动加载首屏
- 加载更多只追加日志列表，不影响当前群主面板其他状态
- notice 给出加载失败结果

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-operation-logs-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P1-1` 中“群操作日志”的当前进度说明，并收紧剩余缺口。

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
  docs/plans/2026-03-25-desktop-el-group-operation-logs-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ManageGroupOperationLogsModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support group operation logs"
git push origin codex/desktop-el
```

- [x] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
