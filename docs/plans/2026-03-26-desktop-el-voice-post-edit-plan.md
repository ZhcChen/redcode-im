# Desktop EL Voice Post-Edit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 语音录音弹层补一个最小“录后编辑”闭环，允许用户在预览态修改语音文件名后再发送。

**Architecture:** 保持现有 `VoiceRecorderModal -> ChatPanel -> 附件上传/失败重试` 链路不变，只新增一个纯前端文件名重命名 helper，并在预览态提交前应用到 `VoiceRecordingFile`。不新增 Go core RPC，也不改附件消息结构。

**Tech Stack:** Vue 3、TypeScript、Bun test、VoiceRecorderModal、MediaRecorder

---

### Task 1: 先写 failing test 锁定文件名重命名规则

**Files:**
- Modify: `desktop-el/renderer/src/utils/chat-voice-recording.test.ts`

- [x] **Step 1: 增加重命名测试**

覆盖：
- 修改语音文件名时保留原扩展名
- 保留 `durationMs`
- 空白输入时保持原文件名

- [x] **Step 2: 跑 RED**

Run: `cd desktop-el && bun test renderer/src/utils/chat-voice-recording.test.ts`
Expected: FAIL，提示 `renameVoiceRecordingFile` 尚不存在。

### Task 2: 实现最小录后编辑 helper 与预览输入框

**Files:**
- Modify: `desktop-el/renderer/src/utils/chat-voice-recording.ts`
- Modify: `desktop-el/renderer/src/components/VoiceRecorderModal.vue`

- [x] **Step 1: 实现 helper**

新增 `renameVoiceRecordingFile()`，在发送前按输入草稿重命名 `VoiceRecordingFile`，保留扩展名与 `durationMs`。

- [x] **Step 2: 接入 VoiceRecorderModal**

在录音预览态增加文件名输入框，默认回填当前录音文件名；点击“发送语音”时应用 helper。

- [x] **Step 3: 跑 GREEN**

Run:
- `cd desktop-el && bun test renderer/src/utils/chat-voice-recording.test.ts`
- `cd desktop-el && bun run type-check`

Expected:
- 新增 util 测试 PASS
- 组件接入后类型检查 PASS

### Task 3: 回填 backlog 并做固定验收

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Create: `docs/plans/2026-03-26-desktop-el-voice-post-edit-plan.md`

- [x] **Step 1: 回填 backlog**

记录“录后编辑第一刀 = 预览态可改语音文件名”已完成。

- [x] **Step 2: 跑固定验收**

Run: `make desktop-el-verify`
Expected: PASS

- [ ] **Step 3: 提交并推送**

```bash
git add desktop-el/renderer/src/components/VoiceRecorderModal.vue \
        desktop-el/renderer/src/utils/chat-voice-recording.ts \
        desktop-el/renderer/src/utils/chat-voice-recording.test.ts \
        docs/plans/2026-03-24-desktop-el-migration-backlog.md \
        docs/plans/2026-03-26-desktop-el-voice-post-edit-plan.md
git commit -m "feat(desktop-el): support voice post-edit naming"
git push
```
