# Desktop EL Docs Closeout Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收口 `desktop-el` 迁移文档，补齐缺失的主切口计划文档、统一回填旧聊天计划状态，并形成可快速浏览的迁移进度总表。

**Architecture:** 本轮只改文档，不改业务代码，不新增运行入口。文档收口基于已合入的 `desktop-el` 提交序列、现有 backlog 状态与已有计划文档覆盖面，确保“进度、计划、提交”三者一致。

**Tech Stack:** Markdown、Git 历史、迁移 backlog、现有计划文档

---

### Task 1: 补齐缺失的主切口计划文档

**Files:**
- Create: `docs/plans/2026-03-26-desktop-el-contact-main-flow-plan.md`
- Create: `docs/plans/2026-03-26-desktop-el-settings-main-flow-plan.md`

- [x] **Step 1: 为联系人主流程补 retro plan**

实现点：
- 覆盖联系人面板、好友申请、全局搜人、备注编辑、删除好友、联系人实时刷新
- 标注对应代表提交

- [x] **Step 2: 为设置页主流程补 retro plan**

实现点：
- 覆盖头像上传、昵称更新、修改密码、反馈提交、版本检查与安装包下载
- 标注对应代表提交

### Task 2: 形成迁移总表并回填旧聊天计划

**Files:**
- Create: `docs/plans/2026-03-26-desktop-el-migration-progress-table.md`
- Modify: `docs/plans/2026-03-24-desktop-el-chat-attachment-download-plan.md`
- Modify: `docs/plans/2026-03-24-desktop-el-chat-attachment-upload-plan.md`
- Modify: `docs/plans/2026-03-24-desktop-el-chat-detail-plan.md`
- Modify: `docs/plans/2026-03-24-desktop-el-chat-message-update-plan.md`
- Modify: `docs/plans/2026-03-24-desktop-el-chat-realtime-plan.md`
- Modify: `docs/plans/2026-03-24-desktop-el-chat-send-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-attachment-cache-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-attachment-resend-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-auto-retry-storage-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-context-menu-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-drag-upload-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-local-message-search-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-drag-select-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-edit-menu-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-forward-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-multi-select-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-pin-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-reaction-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-message-readers-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-shortcuts-plan.md`
- Modify: `docs/plans/2026-03-25-desktop-el-voice-message-plan.md`
- Modify: `docs/plans/2026-03-26-desktop-el-voice-waveform-plan.md`

- [x] **Step 1: 生成迁移总表**

实现点：
- 覆盖 `P0` ~ `P2`
- 区分已完成、部分完成与剩余缺口
- 链接代表计划文档与代表提交

- [x] **Step 2: 回填旧聊天计划状态**

实现点：
- 仅回填已落地特性的旧计划文档
- 把未勾选但已完成的步骤统一更新为已完成

### Task 3: 更新 backlog、校验与提交

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-docs-closeout-plan.md`

- [x] **Step 1: 回填 backlog**

实现点：
- `P2-4` 三项全部对齐实际状态
- 增加文档收口进度说明

- [x] **Step 2: 做文档校验**

Run: `rg -n "^- \\[ \\]" docs/plans/2026-03-24-desktop-el-chat-*.md docs/plans/2026-03-25-desktop-el-message-*.md docs/plans/2026-03-25-desktop-el-context-menu-plan.md docs/plans/2026-03-25-desktop-el-drag-upload-plan.md docs/plans/2026-03-25-desktop-el-shortcuts-plan.md docs/plans/2026-03-25-desktop-el-voice-message-plan.md docs/plans/2026-03-26-desktop-el-voice-waveform-plan.md`
Expected: 不再出现已完成旧聊天计划的未勾选步骤。

- [x] **Step 3: 提交、推送与清理**

```bash
git add docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-26-desktop-el-docs-closeout-plan.md \
  docs/plans/2026-03-26-desktop-el-contact-main-flow-plan.md \
  docs/plans/2026-03-26-desktop-el-settings-main-flow-plan.md \
  docs/plans/2026-03-26-desktop-el-migration-progress-table.md
git commit -m "docs(desktop-el): close out migration planning docs"
git push
make desktop-el-down
pgrep -fl "desktop-el|electron|go-core" || true
```
