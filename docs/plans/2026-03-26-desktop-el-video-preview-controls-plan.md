# `desktop-el` 视频预览控制增强实现计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`）跟踪状态。

**目标：** 为 `desktop-el` 当前媒体预览层补一个“视频预览增强第一刀”闭环，让用户在打开视频预览后拥有基本可控的播放体验，包括播放/暂停、快进/快退、时间进度感知与键盘快捷操作。

**架构：** 继续沿用 `ChatPanel` 当前媒体预览弹层，不新增 Go core RPC，不新增 Electron / Go 本地 HTTP 端口，也不单独开本地服务。视频控制规则先抽成 renderer 纯 helper，再由 `ChatPanel` 绑定现有 `<video>` 元素与预览状态。当前保持原生 `<video>` 播放内核，只补一层轻量控制条，不整搬旧端自定义播放器。

**技术栈：** Vue 3、TypeScript、Bun test、ChatPanel、纯 renderer helper、浏览器 `HTMLVideoElement`

---

### 任务 1：先写 failing tests 锁定视频预览 helper 规则

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`

- [x] **Step 1: 增加 video preview helper 测试**

覆盖：
- 视频预览时间格式化
- 视频播放时间进度百分比计算
- 视频快进 / 快退 seek 目标的边界收敛
- 视频预览打开时，`Space` / 左右方向键映射到播放控制动作

- [x] **Step 2: 跑 RED**

运行：`cd desktop-el && bun test renderer/src/utils/chat-media-preview.test.ts`
预期：FAIL，提示缺少新的 video preview helper。

### 任务 2：实现 helper 并接入 ChatPanel 视频预览控制

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 实现 util**

新增：
- 视频预览时间格式化 helper
- 视频 seek 目标计算 helper
- 视频当前播放进度百分比 helper
- 视频预览键盘动作扩展

- [x] **Step 2: 接入 ChatPanel**

在当前视频预览弹层中补：
- 播放 / 暂停、后退 / 前进操作按钮
- 当前时间 / 总时长展示
- 进度条展示
- `Space`、`ArrowLeft`、`ArrowRight` 键盘快捷操作
- 关闭预览时暂停视频并重置预览状态

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
- Modify: `docs/plans/2026-03-26-desktop-el-video-preview-controls-plan.md`

- [x] **Step 1: 回填进度**

记录“更多细节交互下一刀 = 视频预览控制增强”已完成，剩余语音录制增强、更细缓存治理等仍待迁移。

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
        docs/plans/2026-03-26-desktop-el-video-preview-controls-plan.md
git commit -m "feat(desktop-el): add video preview controls"
git push
```
