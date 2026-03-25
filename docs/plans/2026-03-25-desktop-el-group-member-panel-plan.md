# Desktop EL Group Member Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的当前群详情补齐“完整成员面板”最小闭环，让用户能在桌面端查看全量成员、搜索成员、识别角色分布，并从成员面板进入现有群管理动作。

**Architecture:** 延续 `ChatPanel` 作为群详情主容器，新增独立成员面板 modal，不重写已有成员增删 / 管理员 / 转让群主逻辑。成员面板只负责展示与入口路由，具体管理动作继续复用现有 modal 与 handler。

**Tech Stack:** Vue 3、TypeScript、Bun test、Bun build、现有群聊 renderer 组件体系

---

### Task 1: 成员面板数据 helper

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-group-members.ts`
- Create: `desktop-el/renderer/src/utils/chat-group-members.test.ts`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 先写 helper 失败测试**

测试覆盖：
- 成员排序仍保持 owner > admin > member，再按显示名排序
- 成员搜索同时匹配昵称 / 用户名 / 角色标签
- 角色统计返回 owner/admin/member/total 数量

- [x] **Step 2: 跑 targeted tests 确认先失败**

Run: `bun test renderer/src/utils/chat-group-members.test.ts`
Expected: FAIL，原因是 helper 尚未实现

- [x] **Step 3: 实现 helper 并接入 ChatPanel**

- [x] **Step 4: targeted tests 转绿**

Run: `bun test renderer/src/utils/chat-group-members.test.ts`
Expected: PASS

### Task 2: 完整成员面板 modal

**Files:**
- Create: `desktop-el/renderer/src/components/ViewGroupMembersModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 接入成员面板入口**

最小行为：
- 群详情成员区增加“查看全部成员”入口
- 打开后展示全量成员列表、搜索框、角色统计
- 每个成员展示头像占位、显示名、用户名、角色、入群时间

- [x] **Step 2: 在成员面板内衔接现有管理动作**

最小行为：
- owner/admin 可从成员面板进入“添加成员” / “删除成员”
- owner 可从成员面板进入“管理员设置” / “转让群主”
- 仅展示入口，不重写已有管理逻辑

- [x] **Step 3: 跑 targeted 构建验证**

Run: `bun run build`
Expected: PASS

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-member-panel-plan.md`

- [x] **Step 1: 回填 backlog**

若成员面板完成，则把 `P1-1` 的“群成员管理”剩余项改为完成，仅保留更后续的增强项。

- [x] **Step 2: 跑完整验证**

Run: `bun test`
Expected: 仍然只有既有 3 个 Electron named export mock 失败，且不新增失败项

Run: `bun run build`
Expected: PASS

- [x] **Step 3: 提交 / 推送 / 清进程**

```bash
git add docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-25-desktop-el-group-member-panel-plan.md \
  desktop-el/renderer/src/utils/chat-group-members.ts \
  desktop-el/renderer/src/utils/chat-group-members.test.ts \
  desktop-el/renderer/src/components/ViewGroupMembersModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue
git commit -m "feat(desktop-el): add full group member panel"
git push origin codex/desktop-el
make desktop-el-down
pgrep -fl "desktop-el|electron|go-core" || true
```
