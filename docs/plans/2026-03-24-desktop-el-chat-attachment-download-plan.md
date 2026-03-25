# Desktop EL Chat Attachment Download Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 聊天模块补齐附件消息读侧最小闭环，支持附件消息渲染、下载到本地并打开文件。

**Architecture:** 继续坚持 Electron 仅作为宿主壳，renderer 不直接请求 backend，也不暴露本地 HTTP 服务；附件下载 URL 先由 Go core 通过 stdio RPC 向 backend 获取，renderer 再通过 Electron 宿主能力完成“选择保存路径 -> 下载到本地 -> 打开文件”。这一刀只做读侧最小闭环，不碰上传、分片和发送附件。

**Tech Stack:** Electron、Vue 3、TypeScript、Go 1.25、stdio RPC、backend HTTP API、Bun test/build

---

### Task 1: 补 Go core 附件下载 RPC

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/docs/rpc-contract.md`

- [x] **Step 1: 先写失败测试，覆盖 `chat.attachment.download_url` 的调用路径**

在 `app_test.go` 增加集成测试，验证：
- Go core 会调用 `GET /rooms/{room_id}/messages/attachments/download`
- 查询参数至少包含 `key`
- 可选透传 `expires_in_seconds`
- RPC 返回 backend 原始 envelope

- [x] **Step 2: 运行单测确认失败**

Run: `go test ./internal/app -run TestAppChatAttachmentDownloadURLReturnsEnvelope`
Expected: FAIL，提示方法未注册或请求未发出

- [x] **Step 3: 实现最小代码让测试通过**

新增：
- `chat.AttachmentDownloadURLParams`
- `(*chat.Service).GetAttachmentDownloadURL(...)`
- `app.RegisterRPC()` 中的 `chat.attachment.download_url`

- [x] **Step 4: 再跑单测确认通过**

Run: `go test ./internal/app -run TestAppChatAttachmentDownloadURLReturnsEnvelope`
Expected: PASS

- [x] **Step 5: 同步 RPC 文档**

在 `desktop-el/docs/rpc-contract.md` 补充方法名、参数与返回约定。

### Task 2: 扩展 renderer 消息模型与附件 API

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`

- [x] **Step 1: 先补类型测试思路并确定映射边界**

确认 `ChatMessage` 需要显式暴露：
- `parts`
- 附件元信息（`key/name/mime/size/thumbnailKey`）
- 下载 URL 响应结构

- [x] **Step 2: 实现最小映射**

在 `chat.ts` 中：
- 将 `BackendMessagePart` / `BackendMessageAttachment` 映射成 UI 可消费结构
- 保持现有 `preview` 逻辑不回退
- 新增 `ChatApi.getAttachmentDownloadUrl(...)`

- [x] **Step 3: 做一次 type-check**

Run: `bun run type-check`
Expected: PASS

### Task 3: 补 Electron 宿主文件能力

**Files:**
- Modify: `desktop-el/electron/preload/types.ts`
- Modify: `desktop-el/electron/preload/api.cts`
- Add: `desktop-el/electron/main/file.ts`
- Modify: `desktop-el/electron/main/shell-api.ts`
- Modify: `desktop-el/electron/main/shell-api.test.ts`
- Modify: `desktop-el/electron/main/lifecycle.ts`

- [x] **Step 1: 先写 main 层测试，约束新 namespace 分发**

测试覆盖：
- `file.saveFromURL`
- `file.openPath`
- `shell-api` 可识别 `file` namespace

- [x] **Step 2: 运行测试确认失败**

Run: `bun test electron/main/shell-api.test.ts`
Expected: FAIL，提示 namespace 未支持

- [x] **Step 3: 实现最小宿主能力**

新增 `file` service：
- `saveFromURL({ url, filePath })` 使用 Electron/Node 原生能力下载到目标路径
- `openPath(path)` 打开本地文件

并通过 preload 暴露给 renderer。

- [x] **Step 4: 重新运行 main 层测试**

Run: `bun test electron/main/shell-api.test.ts`
Expected: PASS

### Task 4: 完成 ChatPanel 附件消息读侧交互

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 先补最小交互状态**

增加：
- 下载中状态
- 每条消息的附件块渲染
- 下载/打开按钮

- [x] **Step 2: 实现附件消息 UI**

最小支持：
- `image` 显示缩略信息和“下载”
- `video` / `audio` / `file` 显示文件名、类型、大小和操作按钮
- 已删除消息保持现有展示

- [x] **Step 3: 实现下载闭环**

流程固定为：
1. `ChatApi.getAttachmentDownloadUrl`
2. `window.desktopEl.dialog.save`
3. `window.desktopEl.file.saveFromURL`
4. `window.desktopEl.file.openPath`

- [x] **Step 4: 重新做 type-check 和 build**

Run: `bun run type-check`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 5: 验证、清理、提交

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`

- [x] **Step 1: 回填 backlog**

将 `P0-2` 中“附件消息读侧闭环”记入当前进度，避免后续重复分析。

- [x] **Step 2: 运行完整验证**

Run: `go test ./...`
Expected: PASS

Run: `bun test electron/main/shell-api.test.ts`
Expected: PASS

Run: `bun run type-check`
Expected: PASS

Run: `bun run build`
Expected: PASS

- [x] **Step 3: 清理残留进程**

Run: `make desktop-el-down`

Run: `screen -ls || true`

Run: `pgrep -fl \"desktop-el|electron|go-core\" || true`

Expected: 没有本轮遗留的 `desktop-el` / Electron / Go core 进程

- [x] **Step 4: 提交并推送**

```bash
git add docs/plans/2026-03-24-desktop-el-chat-attachment-download-plan.md \
  desktop-el/go-core/internal/chat/service.go \
  desktop-el/go-core/internal/app/app.go \
  desktop-el/go-core/internal/app/app_test.go \
  desktop-el/docs/rpc-contract.md \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/components/ChatPanel.vue \
  desktop-el/electron/preload/types.ts \
  desktop-el/electron/preload/api.cts \
  desktop-el/electron/main/file.ts \
  desktop-el/electron/main/shell-api.ts \
  desktop-el/electron/main/shell-api.test.ts \
  desktop-el/electron/main/lifecycle.ts \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md
git commit -m "feat(desktop-el): support attachment message downloads"
git push
```
