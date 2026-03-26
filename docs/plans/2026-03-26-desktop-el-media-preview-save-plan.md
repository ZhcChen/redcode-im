# `desktop-el` 媒体预览保存动作实现计划

> **给代理执行者：** 必须配合 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐步落地，并使用 checkbox（`- [ ]`) 跟踪状态。

**Goal:** 为 `desktop-el` 当前媒体预览层补一个“保存当前媒体”闭环，让用户在预览图片或视频时可直接触发现有附件保存链路。

**Architecture:** 继续复用 `ChatPanel` 当前附件下载保存流程，不新增 Go core RPC，不新增 Electron / Go 本地 HTTP 端口。只在预览态记录当前 source message/part，并通过纯 renderer helper 解析 source，对接已有 `handleDownloadAttachment()`。当前不做图片复制、右键菜单或系统剪贴板增强。

**Tech Stack:** Vue 3、TypeScript、Bun test、ChatPanel、纯 renderer helper

---

### 任务 1：先写 failing tests 锁定预览 source 解析

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`

- [x] **Step 1: 增加 source resolve helper 测试**

覆盖：
- 能根据 `messageId + partPosition` 找到当前预览 source
- source 不存在时返回 `null`

- [x] **Step 2: 跑 RED**

运行：`cd desktop-el && bun test renderer/src/utils/chat-media-preview.test.ts`
预期：FAIL，提示缺少新的 source resolve helper。

### 任务 2：实现 helper 并接入 ChatPanel 预览保存按钮

**涉及文件：**
- Modify: `desktop-el/renderer/src/utils/chat-media-preview.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 实现 util**

新增：
- 根据 source id 解析消息与 part 的 helper

- [x] **Step 2: 接入 ChatPanel**

在当前媒体预览弹层中补：
- 记录当前预览 source message/part
- “保存”按钮
- 点击后复用现有 `handleDownloadAttachment()`，而不是新写一套保存逻辑

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
- Modify: `docs/plans/2026-03-26-desktop-el-media-preview-save-plan.md`

- [x] **Step 1: 回填进度**

记录“更多细节交互第五刀 = 媒体预览内保存当前媒体”已完成，剩余视频预览增强、更细缓存治理等仍待迁移。

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
        docs/plans/2026-03-26-desktop-el-media-preview-save-plan.md
git commit -m "feat(desktop-el): add media preview save action"
git push
```
