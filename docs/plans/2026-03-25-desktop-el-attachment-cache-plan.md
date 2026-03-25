# Desktop EL Attachment Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐宿主侧附件缓存目录能力，并让 renderer 在图片 / 视频 / 音频预览与“打开附件”链路中优先命中本地缓存，减少对短时 signed URL 的重复依赖。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 承接业务 RPC、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增本地 HTTP 端口；renderer 仍通过 backend 获取 signed URL，但会先通过 Electron file API 查询本地缓存命中，未命中时下载到宿主缓存目录并回传稳定的 `fileUrl/filePath`。

**Tech Stack:** Electron、Vue 3、TypeScript、Bun、Node `fs/promises`、`pathToFileURL`

---

### Task 1: 先用测试钉住宿主缓存 file API

**Files:**
- Modify: `desktop-el/electron/main/file.test.ts`
- Modify: `desktop-el/electron/preload/api.test.ts`
- Modify: `desktop-el/electron/main/shell-api.test.ts`
- Modify: `desktop-el/electron/preload/types.ts`

- [x] **Step 1: 为 Electron file service 缓存能力写红灯测试**

覆盖最小行为：
- `getCachedPath(relativePath)` miss 返回 `null`
- `cacheFromURL(url, relativePath)` 下载到缓存目录并返回 `filePath/fileUrl`
- 二次 `getCachedPath(relativePath)` 命中已有缓存

- [x] **Step 2: 为 preload file API 转发缓存调用写红灯测试**

覆盖最小行为：
- `desktopEl.file.getCachedPath(...)`
- `desktopEl.file.cacheFromURL(...)`

- [x] **Step 3: 跑定向测试确认先失败**

Run:
- `bun test electron/main/file.test.ts`
- `bun test electron/preload/api.test.ts`
- `bun test electron/main/shell-api.test.ts`

Expected:
- 新增缓存相关 case FAIL

### Task 2: 实现宿主缓存目录 file API

**Files:**
- Modify: `desktop-el/electron/main/file.ts`
- Modify: `desktop-el/electron/main/lifecycle.ts`
- Modify: `desktop-el/electron/preload/types.ts`
- Modify: `desktop-el/electron/preload/api.cts`

- [x] **Step 1: 在 file service 增加缓存目录读写能力**

最小新增：
- `getCachedPath({ relativePath })`
- `cacheFromURL({ url, relativePath })`

- [x] **Step 2: 让 preload 与 shell IPC 暴露新 file API**

最小要求：
- renderer 可通过 `window.desktopEl.file.*` 直接调用
- 返回结构包含 `filePath` 与 `fileUrl`

- [x] **Step 3: 回跑宿主定向测试**

Run:
- `bun test electron/main/file.test.ts`
- `bun test electron/preload/api.test.ts`
- `bun test electron/main/shell-api.test.ts`

Expected: PASS

### Task 3: 接入 renderer 附件缓存命中链路

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 为附件缓存键与缓存命中写最小 helper**

最小要求：
- 基于 attachment key / thumbnail key 构造稳定 `relativePath`
- 统一记录缓存命中的 `filePath/fileUrl`

- [x] **Step 2: 让图片 / 视频 / 音频预览优先命中缓存**

最小要求：
- 先问宿主 `getCachedPath`
- miss 时再走 signed URL + `cacheFromURL`
- 成功后复用本地 `fileUrl`

- [x] **Step 3: 让“打开附件”优先命中缓存**

最小要求：
- 已缓存则直接 `openPath`
- 未缓存则走 signed URL 下载到内部缓存目录，再 `openPath`
- 手动“下载”按钮继续保留另存为流程

### Task 4: 回归验证、更新 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-attachment-cache-plan.md`

- [x] **Step 1: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`

Expected:
- `bun test` PASS
- `bun run build` PASS

- [x] **Step 2: 回填 backlog**

将 `P0-2` 中“本地媒体缓存与更完整的预览体验仍未迁移”缩小为新的真实剩余缺口。

- [x] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-attachment-cache-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/electron/main/file.ts \
  desktop-el/electron/main/file.test.ts \
  desktop-el/electron/main/lifecycle.ts \
  desktop-el/electron/main/shell-api.test.ts \
  desktop-el/electron/preload/types.ts \
  desktop-el/electron/preload/api.cts \
  desktop-el/electron/preload/api.test.ts \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): cache attachment previews locally"
git push origin codex/desktop-el
```

- [x] **Step 4: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
