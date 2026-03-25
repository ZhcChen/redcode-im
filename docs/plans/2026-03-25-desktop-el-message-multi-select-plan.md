# Desktop EL Message Multi Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐聊天消息多选模式最小闭环，让当前会话支持进入多选、选择多条消息、批量转发、批量删除，以及通过 `Esc` 或显式按钮退出多选模式。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 只承接业务 RPC、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增本地 HTTP 端口，也不新增 Go core RPC；批量转发继续复用现有 `chat.forward` 单条转发接口顺序执行，批量删除继续复用现有 `chat.delete` 与本地失败消息移除逻辑。

**Tech Stack:** Vue 3、TypeScript、Bun、现有 `ChatPanel` / `ForwardMessageModal` / `ChatApi`

---

### Task 1: 先用测试钉住消息多选动作规则

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-message-actions.ts`
- Create: `desktop-el/renderer/src/utils/chat-message-actions.test.ts`

- [x] **Step 1: 为消息动作 helper 写红灯测试**

覆盖最小行为：
- 远端普通消息可被纳入多选，并且能计算“全部可批量转发 / 删除”的状态
- 本地 sending / failed 消息不允许批量转发，但自己的本地失败消息仍允许批量删除
- 系统消息不能进入多选，批量转发摘要在单条 / 多条场景下输出正确文案

- [x] **Step 2: 跑定向测试确认先失败**

Run:
- `bun test renderer/src/utils/chat-message-actions.test.ts`

Expected: FAIL，提示 helper 尚未实现

### Task 2: 接通 ChatPanel 多选模式与批量动作

**Files:**
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/components/ForwardMessageModal.vue`
- Modify: `desktop-el/renderer/src/utils/chat-message-actions.ts`
- Modify: `desktop-el/renderer/src/utils/chat-message-actions.test.ts`

- [x] **Step 1: 实现消息动作 helper**

最小要求：
- 提供单条消息 action capability 判断
- 提供批量多选的可选性、批量转发/删除可执行性判断
- 提供批量转发摘要文案 helper

- [x] **Step 2: 在 ChatPanel 接通多选模式**

最小要求：
- 通过消息“更多”菜单进入多选，并默认选中当前消息
- 多选模式下展示已选数量、批量转发、批量删除、退出多选
- 房间切换、消息列表变化或 `Esc` 时能正确退出 / 收口多选状态

- [x] **Step 3: 接通批量转发与批量删除**

最小要求：
- 批量转发复用现有转发弹窗，支持把当前已选消息顺序转发到单个目标会话
- 批量删除顺序处理当前已选消息；远端消息走 `chat.delete`，本地失败消息走本地移除
- 成功后清空多选状态并刷新会话列表 / 当前消息区

- [x] **Step 4: 回跑定向测试**

Run:
- `bun test renderer/src/utils/chat-message-actions.test.ts`

Expected: PASS

### Task 3: 回归验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-multi-select-plan.md`

- [x] **Step 1: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`

Expected:
- `bun test` PASS
- `bun run build` PASS

- [x] **Step 2: 回填 backlog**

将 `P0-1` 中“更深消息管理体验仍未迁移”更新为“拖拽框选等更深消息管理体验仍未迁移”，明确消息多选 / 批量转发 / 批量删除已完成最小闭环。

- [ ] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-message-multi-select-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/components/ChatPanel.vue \
  desktop-el/renderer/src/components/ForwardMessageModal.vue \
  desktop-el/renderer/src/utils/chat-message-actions.ts \
  desktop-el/renderer/src/utils/chat-message-actions.test.ts
git commit -m "feat(desktop-el): support message multi select"
git push origin codex/desktop-el
```

- [ ] **Step 4: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
