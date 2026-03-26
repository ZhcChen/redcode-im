# `desktop-el` 媒体预览键盘操作实现计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`）跟踪状态。

**目标：** 为 `desktop-el` 当前媒体预览层补一个“键盘操作第一刀”闭环，让用户在预览打开时可用 `Escape` 关闭预览，并在图片预览中用左右方向键切换上一张 / 下一张。

**Architecture:** 继续沿用 `ChatPanel` 当前媒体预览状态与 `chat-media-preview` helper，不新增 Go core RPC，不新增 Electron / Go 本地 HTTP 端口。键盘意图先抽成 renderer 纯 helper，再由 `ChatPanel` 的全局 `keydown` 入口统一分发。当前只覆盖 `Escape` / `ArrowLeft` / `ArrowRight`，不扩到视频播放器快捷键。

**Tech Stack:** Vue 3、TypeScript、Bun test、ChatPanel、纯 renderer helper

---

### 任务 1：先写 failing tests 锁定键盘动作映射

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`

- [x] **Step 1: 增加 keyboard action helper 测试**

覆盖：
- 图片预览打开时，`Escape` 返回 `close`
- 图片预览打开时，`ArrowLeft` / `ArrowRight` 分别返回 `previous` / `next`
- 视频预览打开时，仅 `Escape` 生效，左右键不产生 gallery 动作

- [x] **Step 2: 跑 RED**

运行：`cd desktop-el && bun test renderer/src/utils/chat-media-preview.test.ts`
预期：FAIL，提示缺少新的 keyboard action helper。

### 任务 2：实现 helper 并接入 ChatPanel 全局按键

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 实现 util**

新增：
- 媒体预览键盘动作 helper
- 只在预览打开且 key 命中时返回明确动作

- [x] **Step 2: 接入 ChatPanel**

在现有 `handleGlobalKeydown()` 中补：
- 预览打开时优先消费 `Escape`
- 图片预览打开时消费 `ArrowLeft` / `ArrowRight`
- 继续复用现有上一张 / 下一张与关闭预览入口

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
- Modify: `docs/plans/2026-03-26-desktop-el-media-preview-keyboard-plan.md`

- [x] **Step 1: 回填进度**

记录“更多细节交互第四刀 = 媒体预览键盘操作”已完成，剩余视频预览增强、更细缓存治理等仍待迁移。

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
        docs/plans/2026-03-26-desktop-el-media-preview-keyboard-plan.md
git commit -m "feat(desktop-el): add media preview keyboard controls"
git push
```
