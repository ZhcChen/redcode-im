# `desktop-el` 视频预览进度跳转实现计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`）跟踪状态。

**目标：** 为 `desktop-el` 当前视频预览层补一个“可点击进度条跳转”闭环，让用户点击预览层进度条时可以直接跳到目标时间点。

**架构：** 继续沿用 `ChatPanel` 当前视频预览状态与 `chat-media-preview` helper，不新增 Go core RPC，不新增 Electron / Go 本地 HTTP 端口。跳转比例计算先抽成 renderer 纯 helper，再由 `ChatPanel` 根据进度条容器的相对点击位置驱动 `HTMLVideoElement.currentTime`。

**技术栈：** Vue 3、TypeScript、Bun test、ChatPanel、纯 renderer helper

---

### 任务 1：先写 failing tests 锁定进度条跳转规则

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`

- [x] **Step 1: 增加 progress seek helper 测试**

覆盖：
- 进度条 ratio 会被限制在 `0 ~ 1`
- 给定视频总时长和 ratio 时，可换算为目标播放时间
- 非法时长或 ratio 会安全回落

- [x] **Step 2: 跑 RED**

运行：`cd desktop-el && bun test renderer/src/utils/chat-media-preview.test.ts`
预期：FAIL，提示缺少新的 progress seek helper。

### 任务 2：实现 helper 并接入 ChatPanel 视频进度条点击跳转

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 实现 util**

新增：
- 进度条 ratio clamp helper
- 由 duration + ratio 推导目标播放时间 helper

- [x] **Step 2: 接入 ChatPanel**

在当前视频预览弹层中补：
- 进度条点击事件
- 点击后根据相对位置直接设置视频当前时间
- 状态条与时间展示随跳转即时刷新

- [x] **Step 3: 跑 GREEN**

运行：
- `cd desktop-el && bun test renderer/src/utils/chat-media-preview.test.ts`
- `cd desktop-el && bun run type-check`

预期：
- util 测试 PASS
- ChatPanel 接入后类型检查 PASS

### 任务 3：回填 backlog / 进度文档并做固定验收

**涉及文件：**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-migration-progress-table.md`
- Modify: `docs/plans/2026-03-26-desktop-el-video-preview-seek-plan.md`

- [x] **Step 1: 回填进度**

记录“更多细节交互下一刀 = 视频预览进度跳转”已完成，剩余语音录制增强、更细视频预览与缓存治理仍待迁移。

- [x] **Step 2: 跑固定验收**

运行：`make desktop-el-verify`
预期：PASS

- [x] **Step 3: 提交并推送**

```bash
git add desktop-el/renderer/src/utils/chat-media-preview.ts \
        desktop-el/renderer/src/utils/chat-media-preview.test.ts \
        desktop-el/renderer/src/components/ChatPanel.vue \
        docs/plans/2026-03-24-desktop-el-migration-backlog.md \
        docs/plans/2026-03-26-desktop-el-migration-progress-table.md \
        docs/plans/2026-03-26-desktop-el-video-preview-seek-plan.md
git commit -m "feat(desktop-el): add video preview seek bar"
git push
```
