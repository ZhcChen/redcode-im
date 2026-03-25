# Desktop EL Group Avatar Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐当前群设置面板中的群头像上传写侧，并让会话列表 / 会话头部在有头像时优先展示图片。

**Architecture:** 继续保持 renderer 只通过 `http.request` 与 Go core 转发 backend API，不新增任何本地 HTTP 端口。群头像直传复用现有对象存储上传链路：请求 `/rooms/:room_id/avatar/direct-upload`，必要时直传对象存储，再提交 `/rooms/:room_id/avatar/commit`。展示层只在当前 `ChatPanel` 内补最小图片头像回显，不展开到本地缓存或更完整媒体管理。

**Tech Stack:** Vue 3、TypeScript、Bun test、Go core `http.request`、对象存储直传、现有头像校验 helper

---

### Task 1: 群头像上传 API 测试与实现

**Files:**
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束群头像上传闭环**

在 `desktop-el/renderer/src/api/chat.test.ts` 增加用例，校验：
- `ChatApi.uploadGroupAvatar` 会先请求 `/rooms/:room_id/avatar/direct-upload`
- `signature != null` 时执行对象存储直传
- 然后提交 `/rooms/:room_id/avatar/commit`
- 最终返回 `{ avatarUrl }`

- [x] **Step 2: 运行 targeted test 确认先失败**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: FAIL，原因是 `ChatApi.uploadGroupAvatar` 尚未实现

- [x] **Step 3: 最小实现 API**

复用：
- `computeFileHash`
- `uploadWithSignature`
- 现有 `http.request` 封装

- [x] **Step 4: 运行 targeted test 确认转绿**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

### Task 2: ChatPanel 群头像上传入口与图片头像显示

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入群头像上传按钮与文件选择**

最小行为：
- 仅群主 / 管理员可见“上传群头像”
- 使用隐藏文件 input
- 复用 `validateAvatarFile` 与 `AVATAR_INPUT_ACCEPT`

- [x] **Step 2: 完成上传成功后的最小本地回显**

最小行为：
- 成功后更新当前房间的 `avatarUrl`
- 刷新当前群上下文 / 会话列表
- notice 文案与上传状态一致

- [x] **Step 3: 在会话列表与会话头部优先展示图片头像**

最小行为：
- 有 `avatarUrl` 时显示 `<img>`
- 无头像时继续回退首字母占位

- [x] **Step 4: 跑 targeted 验证**

Run: `bun test renderer/src/api/chat.test.ts`
Expected: PASS

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-avatar-plan.md`

- [x] **Step 1: 回填 backlog**

更新 `P0-3` 中“群头像写侧入口仍未接回”的状态。

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
  docs/plans/2026-03-25-desktop-el-group-avatar-plan.md \
  desktop-el/renderer/src/api/chat.ts \
  desktop-el/renderer/src/api/chat.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): support group avatar upload"
git push origin codex/desktop-el
```

- [ ] **Step 4: 进程清理**

Run: `make desktop-el-down`
Expected: PASS

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无残留桌面进程
