# `desktop-el` 图片预览缩放实现计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`）跟踪状态。

**目标：** 为 `desktop-el` 当前聊天图片预览层补一个“缩放第一刀”闭环，让用户在大图预览态可以做基础放大/缩小与重置，降低图片细节查看门槛。

**架构：** 保持现有 `ChatPanel` 内联媒体预览弹层结构，不新增 Go core RPC，不新增 Electron / Go 本地 HTTP 端口。将缩放边界与滚轮步进抽成 renderer 纯 helper，`ChatPanel` 只负责状态持有与交互绑定。当前只覆盖图片预览，不改视频预览，不做连续浏览、旋转与复杂手势。

**技术栈：** Vue 3、TypeScript、Bun test、ChatPanel、纯 renderer helper

---

### 任务 1：先写 failing tests 锁定缩放规则

**涉及文件：**
- Create: `desktop-el/renderer/src/utils/chat-media-preview.test.ts`
- Create: `desktop-el/renderer/src/utils/chat-media-preview.ts`

- [x] **Step 1: 增加缩放 helper 测试**

覆盖：
- 统一 clamp 图片缩放范围
- 滚轮向上 / 向下时按固定步进缩放
- 超过上下界时会被截断

- [x] **Step 2: 跑 RED**

运行：`cd desktop-el && bun test renderer/src/utils/chat-media-preview.test.ts`
预期：FAIL，提示缺少新的 media preview helper。

### 任务 2：实现 helper 并接入 ChatPanel 图片预览

**涉及文件：**
- Create: `desktop-el/renderer/src/utils/chat-media-preview.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 实现 util**

新增：
- 图片预览缩放边界常量
- 滚轮缩放计算 helper
- 缩放值 clamp helper

- [x] **Step 2: 接入 ChatPanel**

在当前图片预览弹层中补：
- 图片滚轮缩放
- 基础放大 / 缩小 / 重置按钮
- 打开新图片或关闭预览时重置缩放

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
- Modify: `docs/plans/2026-03-26-desktop-el-image-preview-zoom-plan.md`

- [x] **Step 1: 回填进度**

记录“更多细节交互第一刀 = 图片预览缩放”已完成，剩余连续浏览、视频预览增强等仍待迁移。

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
        docs/plans/2026-03-26-desktop-el-image-preview-zoom-plan.md
git commit -m "feat(desktop-el): add image preview zoom"
git push
```
