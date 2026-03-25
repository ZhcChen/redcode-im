# Desktop EL Contact Main Flow Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 联系人主流程补齐独立计划文档，沉淀已经完成的联系人迁移切口与对应提交。

**Architecture:** 联系人页延续 `renderer -> stdio RPC -> Go core` 的统一架构，联系人面板负责展示与交互，好友搜索 / 申请 / 备注 / 删除通过 renderer API 调用 Go core，实时刷新继续复用 websocket push 到 renderer 的收敛链路。

**Tech Stack:** Vue 3、TypeScript、Go 1.25、stdio RPC、联系人实时事件

---

### Task 1: 联系人面板与好友申请基础闭环

**Files:**
- Modify: `desktop-el/renderer/src/components/ContactPanel.vue`
- Modify: `desktop-el/renderer/src/api/user.ts`
- Modify: `desktop-el/renderer/src/api/friend.ts`
- Verify: `desktop-el/renderer/src/api/user.test.ts`
- Verify: `desktop-el/renderer/src/api/friend.test.ts`
- Verify: `desktop-el/renderer/src/utils/contact-discovery.test.ts`

- [x] **Step 1: 迁移联系人面板骨架与申请列表**

代表提交：
- `ea0cc417 feat(desktop-el): port contact panel`
- `ccbec915 feat(desktop-el): handle friend requests`

- [x] **Step 2: 接通搜人和发送好友申请**

代表提交：
- `c32d07ab feat(desktop-el): support friend search and requests`

- [x] **Step 3: 补齐关系态识别与测试**

代表验证：
- `renderer/src/utils/contact-discovery.test.ts`
- `renderer/src/api/user.test.ts`
- `renderer/src/api/friend.test.ts`

### Task 2: 联系人编辑与实时刷新

**Files:**
- Modify: `desktop-el/renderer/src/components/ContactPanel.vue`
- Modify: `desktop-el/renderer/src/api/friend.ts`
- Create: `desktop-el/renderer/src/utils/contact-realtime.ts`
- Verify: `desktop-el/renderer/src/utils/contact-realtime.test.ts`

- [x] **Step 1: 接通备注编辑与删除好友**

代表提交：
- `677cb9b6 feat(desktop-el): support contact remark and deletion`

- [x] **Step 2: 接通联系人实时刷新**

覆盖事件：
- `friend_request_update`
- `friend_profile_updated`
- `friendship_deleted`

代表提交：
- `4685e1cc feat(desktop-el): refresh contacts on realtime events`

- [x] **Step 3: 回填 backlog 对齐联系人主流程已完成状态**

对应 backlog：
- `P0-4 联系人主流程补齐`
