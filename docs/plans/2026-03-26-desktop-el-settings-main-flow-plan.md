# Desktop EL Settings Main Flow Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 设置页主流程补齐独立计划文档，沉淀已完成的头像、账号安全、反馈与版本更新迁移切口。

**Architecture:** 设置页由 `SettingsPanel` 聚合用户资料、账号安全、反馈与版本信息等分区；头像、密码、反馈和版本下载分别走 renderer API 与 Electron shell 能力，不新增桌面本地 HTTP 端口。

**Tech Stack:** Vue 3、TypeScript、Bun、Electron shell、backend HTTP / version API

---

### Task 1: 设置页基础骨架与资料编辑

**Files:**
- Modify: `desktop-el/renderer/src/components/SettingsPanel.vue`
- Modify: `desktop-el/renderer/src/api/user.ts`
- Verify: `desktop-el/renderer/src/utils/user-avatar-upload.test.ts`
- Verify: `desktop-el/renderer/src/api/user.test.ts`

- [x] **Step 1: 迁移设置页骨架与昵称编辑**

代表提交：
- `675587dd feat(desktop-el): port settings panel`
- `5a12f210 feat(desktop-el): support nickname update`

- [x] **Step 2: 接通头像上传直传链路**

代表验证：
- `renderer/src/utils/user-avatar-upload.test.ts`
- `renderer/src/api/user.test.ts`

### Task 2: 账号安全、反馈与版本更新

**Files:**
- Modify: `desktop-el/renderer/src/components/SettingsPanel.vue`
- Modify: `desktop-el/renderer/src/api/user.ts`
- Modify: `desktop-el/renderer/src/api/feedback.ts`
- Modify: `desktop-el/renderer/src/api/version.ts`
- Verify: `desktop-el/renderer/src/api/feedback.test.ts`
- Verify: `desktop-el/renderer/src/api/version.test.ts`

- [x] **Step 1: 接通修改密码与反馈提交**

代表提交：
- `cd8800d8 feat(desktop-el): complete settings workflows`

- [x] **Step 2: 接通版本检查、下载与安装包打开**

代表验证：
- `renderer/src/api/version.test.ts`
- `renderer/src/components/SettingsPanel.vue`

- [x] **Step 3: 回填 backlog 对齐设置页主流程已完成状态**

对应 backlog：
- `P0-5 设置页主流程补齐`
