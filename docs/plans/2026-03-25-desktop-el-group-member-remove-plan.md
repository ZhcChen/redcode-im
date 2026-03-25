# Desktop EL Remove Group Members Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的现有群聊补齐“删除成员”最小闭环，让群主 / 管理员可在当前群中选择并移除成员。

**Architecture:** 继续保持 Go core 承接业务 RPC，renderer 只消费 stdio RPC。当前切口只覆盖“选择可移除成员 -> 调用移除 RPC -> 刷新群上下文”，不展开到管理员角色调整、禁言管理或更深群管理抽屉。

**Tech Stack:** Go 1.25、Vue 3、TypeScript、Bun test、stdio RPC、backend group management API

---

### Task 1: Go core 与 renderer API 移除成员能力

**Files:**
- Modify: `desktop-el/go-core/internal/chat/service.go`
- Modify: `desktop-el/go-core/internal/app/app.go`
- Modify: `desktop-el/go-core/internal/app/app_test.go`
- Modify: `desktop-el/renderer/src/api/chat.ts`
- Modify: `desktop-el/renderer/src/api/chat.test.ts`

- [x] **Step 1: 写失败测试，约束删成员 RPC 与 renderer API**
- [x] **Step 2: 跑 targeted tests 确认先失败**
- [x] **Step 3: 最小实现 RPC 与 API**
- [x] **Step 4: 运行 targeted tests 确认转绿**

### Task 2: ChatPanel 删除成员弹窗与批量移除动作

**Files:**
- Create: `desktop-el/renderer/src/components/RemoveGroupMembersModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`

- [x] **Step 1: 过滤可移除成员**
- [x] **Step 2: 接入删除成员弹窗与批量移除动作**
- [x] **Step 3: 成功后刷新群上下文并给出统计 notice**
- [x] **Step 4: 跑 targeted 验证**

### Task 3: 回填 backlog、完整验证与收尾

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-group-member-remove-plan.md`

- [x] **Step 1: 回填 backlog**
- [x] **Step 2: 跑完整验证**
- [ ] **Step 3: 提交与推送**
- [ ] **Step 4: 进程清理**
