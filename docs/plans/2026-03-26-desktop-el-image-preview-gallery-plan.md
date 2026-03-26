# `desktop-el` 图片连续浏览实现计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`）跟踪状态。

**目标：** 为 `desktop-el` 当前聊天图片预览层补一个“连续浏览第一刀”闭环，让用户在预览一张图片后可以切换到当前已加载消息里的上一张 / 下一张图片。

**架构：** 延续当前 `ChatPanel` 内联媒体预览弹层和 `chat-media-preview` helper，不新增 Go core RPC，不新增 Electron / Go 本地 HTTP 端口。gallery 导航信息抽成 renderer 纯 helper，当前只覆盖当前房间已加载消息里的图片，不扩到视频，不做跨分页预取。

**技术栈：** Vue 3、TypeScript、Bun test、ChatPanel、纯 renderer helper

---

### 任务 1：先写 failing tests 锁定图片 gallery 规则

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`

- [x] **Step 1: 增加图片 gallery helper 测试**

覆盖：
- 只从消息列表中提取图片 part 进入 gallery
- gallery entry 使用稳定 id 表达当前消息和 part 位置
- 给定当前 entry id 时可找到上一张 / 下一张图片

- [x] **Step 2: 跑 RED**

运行：`cd desktop-el && bun test renderer/src/utils/chat-media-preview.test.ts`
预期：FAIL，提示缺少新的 gallery/navigation helper。

### 任务 2：实现 helper 并接入 ChatPanel 图片连续浏览

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 实现 util**

新增：
- 从消息列表抽取图片 gallery entry 的 helper
- 根据当前图片 id 查找上一张 / 下一张 entry 的 helper

- [x] **Step 2: 接入 ChatPanel**

在当前图片预览弹层中补：
- 上一张 / 下一张按钮
- 当前序号提示
- 打开图片预览时记录当前 gallery item
- 切换时复用现有附件预览加载链路打开目标图片

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
- Modify: `docs/plans/2026-03-26-desktop-el-image-preview-gallery-plan.md`

- [x] **Step 1: 回填进度**

记录“更多细节交互第三刀 = 图片连续浏览（当前已加载消息范围）”已完成，剩余视频预览增强、更细缓存治理等仍待迁移。

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
        docs/plans/2026-03-26-desktop-el-image-preview-gallery-plan.md
git commit -m "feat(desktop-el): add image preview gallery navigation"
git push
```
