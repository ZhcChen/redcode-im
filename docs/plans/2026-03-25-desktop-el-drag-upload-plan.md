# Desktop EL 拖拽上传 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 `desktop-el` 聊天面板支持把本地文件直接拖进当前会话，复用现有待发送附件队列与上传链路。

**Architecture:** 不新增任何后端接口，也不改现有 direct upload / multipart upload。renderer 只补拖拽识别、待发送附件入队和界面提示，实际发送仍走已有 `pendingAttachments -> handleSend -> uploadAttachmentsAndBuildParts` 链路。

**Tech Stack:** Vue 3、TypeScript、bun test、vite build

---

### Task 1: 拖拽附件 helper

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-composer-attachments.ts`
- Create: `desktop-el/renderer/src/utils/chat-composer-attachments.test.ts`

- [x] **Step 1: 写失败测试**

覆盖：
- 识别 `DataTransfer.types` 是否包含文件
- 为拖入文件生成稳定的 pending attachment id
- 生成“添加附件 / 通过拖拽添加附件”的提示文案

- [x] **Step 2: 跑测试确认红灯**

Run: `cd desktop-el && bun test renderer/src/utils/chat-composer-attachments.test.ts`
Expected: FAIL

- [x] **Step 3: 写最小实现**

补 helper：
- `hasFileTransfer`
- `buildPendingComposerAttachments`
- `buildPendingAttachmentNotice`

- [x] **Step 4: 跑测试确认转绿**

Run: `cd desktop-el && bun test renderer/src/utils/chat-composer-attachments.test.ts`
Expected: PASS

### Task 2: ChatPanel 拖拽上传交互

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 写最小实现**

接入：
- chat panel 根节点 dragenter / dragover / dragleave / drop
- 仅当拖入文件且当前会话允许发送时显示 overlay
- drop 后把文件并入现有 `pendingAttachments`
- 若未选中会话 / 当前禁发 / 正在发送，则给出 notice 并拒绝入队

- [x] **Step 2: 完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 3: 回填 backlog + 提交**

```bash
git add desktop-el/renderer/src/utils/chat-composer-attachments.ts desktop-el/renderer/src/utils/chat-composer-attachments.test.ts desktop-el/renderer/src/components/ChatPanel.vue docs/plans/2026-03-25-desktop-el-drag-upload-plan.md docs/plans/2026-03-24-desktop-el-migration-backlog.md
git commit -m "feat(desktop-el): support drag attachment upload"
git push
```
