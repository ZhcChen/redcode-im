# Desktop EL Message Drag Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐消息拖拽框选最小闭环，让当前会话支持按旧端习惯从一条消息拖到另一条消息，自动进入多选模式并选中区间消息。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 只承接业务 RPC、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增任何 Go core RPC；拖拽框选仅发生在 renderer 本地状态层，直接复用上一刀已经落地的多选、批量转发、批量删除能力。

**Tech Stack:** Vue 3、TypeScript、Bun、现有 `ChatPanel` / `chat-message-actions`

---

### Task 1: 先用测试钉住拖拽范围选择规则

**Files:**
- Modify: `desktop-el/renderer/src/utils/chat-message-actions.ts`
- Modify: `desktop-el/renderer/src/utils/chat-message-actions.test.ts`

- [x] **Step 1: 为拖拽选区 helper 写红灯测试**

覆盖最小行为：
- 给定锚点消息和当前悬停消息，能按消息顺序返回闭区间内的消息 ID
- 支持从下往上拖拽
- 自动跳过系统消息等不可纳入多选的消息
- 锚点 / 当前消息不存在时返回空结果

- [x] **Step 2: 跑定向测试确认先失败**

Run:
- `bun test renderer/src/utils/chat-message-actions.test.ts`

Expected: FAIL，提示拖拽选区 helper 尚未实现

### Task 2: 接通 ChatPanel 拖拽框选

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/utils/chat-message-actions.ts`
- Modify: `desktop-el/renderer/src/utils/chat-message-actions.test.ts`

- [x] **Step 1: 实现拖拽选区 helper**

最小要求：
- 提供根据消息列表、锚点 ID、当前 ID 计算拖拽选区的 API
- 只返回允许进入多选的消息 ID

- [x] **Step 2: 在 ChatPanel 接通拖拽进入多选**

最小要求：
- 在消息列表按下左键记录锚点与起始坐标
- 鼠标移动超过阈值后进入拖拽态
- 首次跨到另一条消息时自动进入多选模式并按范围选中消息

- [x] **Step 3: 补齐拖拽收口**

最小要求：
- 鼠标抬起、离开消息区域或切换房间后清理拖拽状态
- 拖拽时清理浏览器文本选中，避免和消息内容选中冲突
- 点击按钮、输入框、音视频控件等交互元素时不触发拖拽框选

- [x] **Step 4: 回跑定向测试**

Run:
- `bun test renderer/src/utils/chat-message-actions.test.ts`

Expected: PASS

### Task 3: 回归验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-drag-select-plan.md`

- [x] **Step 1: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`

Expected:
- `bun test` PASS
- `bun run build` PASS

- [x] **Step 2: 回填 backlog**

将 `P0-1` 中“拖拽框选等更深消息管理体验仍未迁移”更新为只剩更深增强项，明确拖拽框选也已落地。

- [x] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-message-drag-select-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/components/ChatPanel.vue \
  desktop-el/renderer/src/utils/chat-message-actions.ts \
  desktop-el/renderer/src/utils/chat-message-actions.test.ts
git commit -m "feat(desktop-el): support message drag select"
git push origin codex/desktop-el
```

- [x] **Step 4: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
