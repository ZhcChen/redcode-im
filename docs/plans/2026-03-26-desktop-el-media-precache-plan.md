# `desktop-el` 媒体预缓存实现计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`）跟踪状态。

**目标：** 为 `desktop-el` 聊天面板补浏览器层媒体预缓存第一刀，优先预加载最近消息里的图片与视频缩略图，降低首屏缩略图闪烁与预览等待。

**架构：** 复用现有 `ensureAttachmentPreviewUrl()` 和 Electron 文件缓存目录能力，只新增一个 renderer 侧图片预加载 store，用 `Image` 对象对已经解析出的 preview URL 做去重预载。当前只覆盖图片与视频缩略图，不预载音频 playable URL，也不改 Go core 协议。

**技术栈：** Vue 3、TypeScript、Bun test、ChatPanel、attachment preview helpers

---

### 任务 1：先写 failing util tests 锁定预缓存行为

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-attachment-preview.test.ts`

- [x] **Step 1: 增加浏览器预缓存判定与 store 测试**

覆盖：
- 只有图片 / 视频缩略图参与浏览器层预加载
- 并发预加载同一 URL 时只创建一个 `Image`
- 失败后会清掉 inflight，后续可以重试

- [x] **Step 2: 跑 RED**

运行：`cd desktop-el && bun test renderer/src/utils/chat-attachment-preview.test.ts`
预期：FAIL，提示新的预缓存 helper 尚不存在。

### 任务 2：实现图片预缓存 store 并接入 ChatPanel

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-attachment-preview.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 实现 util**

新增：
- 图片/视频缩略图是否需要浏览器预缓存的判定
- `Image` 级 preload store（成功缓存、并发去重、失败可重试、可清理）

- [x] **Step 2: 接入 ChatPanel**

在 `ensureAttachmentPreviewUrl()` 成功拿到 preview URL 后，对图片 / 视频缩略图做后台预加载；组件卸载时清理 preload store 引用。

- [x] **Step 3: 跑 GREEN**

运行：
- `cd desktop-el && bun test renderer/src/utils/chat-attachment-preview.test.ts`
- `cd desktop-el && bun run type-check`

预期：
- util 测试 PASS
- ChatPanel 接入后类型检查 PASS

### 任务 3：回填 backlog 并做固定验收

**涉及文件：**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Create: `docs/plans/2026-03-26-desktop-el-media-precache-plan.md`

- [x] **Step 1: 回填 backlog**

记录“媒体预缓存第一刀 = 图片 / 视频缩略图浏览器级预加载”已完成。

- [x] **Step 2: 跑固定验收**

Run: `make desktop-el-verify`
Expected: PASS

- [x] **Step 3: 提交并推送**

```bash
git add desktop-el/renderer/src/components/ChatPanel.vue \
        desktop-el/renderer/src/utils/chat-attachment-preview.ts \
        desktop-el/renderer/src/utils/chat-attachment-preview.test.ts \
        docs/plans/2026-03-24-desktop-el-migration-backlog.md \
        docs/plans/2026-03-26-desktop-el-media-precache-plan.md
git commit -m "feat(desktop-el): preload media previews"
git push
```
