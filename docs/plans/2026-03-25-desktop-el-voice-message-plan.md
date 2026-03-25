# Desktop EL Voice Message Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 补齐录音发送最小闭环，让当前会话支持在 renderer 中录制音频、预览、发送语音消息，并继续复用现有附件上传、失败重试与消息展示链路。

**Architecture:** 继续坚持 Electron 只做宿主壳、Go core 只承接业务 RPC、renderer 只通过 stdio RPC 与 Go core 交互。本批次不新增本地 HTTP 端口，也不新增 Go core RPC；录音完全使用浏览器 `MediaRecorder` 在 renderer 采集，生成带 `durationMs` 扩展属性的 `File`，再走现有 `uploadAttachmentAndBuildPart -> chat.send(parts)` 链路。

**Tech Stack:** Vue 3、TypeScript、Bun、浏览器 `MediaRecorder`、现有 `ChatPanel` / `chat-attachment-upload` / `chat-message-retry`

---

### Task 1: 先用测试钉住录音 helper 与音频时长透传规则

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-voice-recording.ts`
- Create: `desktop-el/renderer/src/utils/chat-voice-recording.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-attachment-upload.ts`
- Modify: `desktop-el/renderer/src/utils/chat-attachment-upload.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.test.ts`

- [x] **Step 1: 为录音 helper 写红灯测试**

覆盖最小行为：
- 选择受支持的录音 MIME type，优先 `audio/webm;codecs=opus`
- 录音文件名会按 MIME type 生成合适扩展名
- 录音按钮开启条件会拦截“无会话 / 正在发送 / 已有文本 / 已有附件 / 被禁言”
- 生成的录音 `File` 会携带 `durationMs` 扩展属性

- [x] **Step 2: 为音频时长透传写红灯测试**

覆盖最小行为：
- `determineAttachmentMeta` 遇到带 `durationMs` 扩展属性的音频 `File` 时，会把该值带到返回 metadata
- `createLocalComposerMessage` 遇到带 `durationMs` 的语音 `File` 时，会把时长保留到本地 sending / failed 消息附件 metadata

- [x] **Step 3: 跑定向测试确认先失败**

Run:
- `bun test renderer/src/utils/chat-voice-recording.test.ts`
- `bun test renderer/src/utils/chat-attachment-upload.test.ts`

Actual:
- `bun test renderer/src/utils/chat-voice-recording.test.ts` 首次失败，提示缺少 `formatVoiceRecordingDuration` 导出
- `bun test renderer/src/utils/chat-local-message.test.ts` 首次失败，提示本地语音消息未保留 `durationMs`

### Task 2: 接通录音弹层与语音消息发送

**Files:**
- Create: `desktop-el/renderer/src/components/VoiceRecorderModal.vue`
- Modify: `desktop-el/renderer/src/components/ChatPanel.vue`
- Modify: `desktop-el/renderer/src/utils/chat-voice-recording.ts`
- Modify: `desktop-el/renderer/src/utils/chat-voice-recording.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-attachment-upload.ts`
- Modify: `desktop-el/renderer/src/utils/chat-attachment-upload.test.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.ts`
- Modify: `desktop-el/renderer/src/utils/chat-local-message.test.ts`

- [x] **Step 1: 实现录音 helper 与时长透传**

最小要求：
- 提供 MIME type 选择、文件名扩展名映射、录音按钮可用性判断
- 提供把 `Blob + durationMs` 转成可上传 `File` 的 helper
- `determineAttachmentMeta` 对录音文件上的 `durationMs` 扩展属性生效

- [x] **Step 2: 实现录音弹层组件**

最小要求：
- 支持开始录音、停止录音、试听、发送、取消
- 录音中展示进行态和时长
- 关闭或销毁时释放 `MediaStream`、`MediaRecorder`、预览 URL

- [x] **Step 3: 在 ChatPanel 接通语音发送**

最小要求：
- composer 增加“录音”入口
- 点击后在符合条件时打开录音弹层，不符合条件时给出明确 notice
- 发送录音时复用现有本地 sending/failed 消息、自动重试与手动重发链路
- 语音消息不与文本/其他附件混发，发送成功后刷新当前会话

- [x] **Step 4: 回跑定向测试**

Run:
- `bun test renderer/src/utils/chat-voice-recording.test.ts`
- `bun test renderer/src/utils/chat-attachment-upload.test.ts`

Actual:
- `bun test renderer/src/utils/chat-voice-recording.test.ts` PASS
- `bun test renderer/src/utils/chat-local-message.test.ts` PASS
- `bun test renderer/src/utils/chat-attachment-upload.test.ts` PASS

### Task 3: 回归验证、回填 backlog、提交推送

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-25-desktop-el-voice-message-plan.md`

- [x] **Step 1: 跑回归验证**

Run:
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`

Actual:
- `cd desktop-el && bun test` PASS
- `cd desktop-el && bun run build` PASS

- [x] **Step 2: 回填 backlog**

将 `P0-2` 中“录音发送与更深媒体体验仍未迁移”更新为只剩更深媒体体验与预览增强，明确录音发送已完成最小闭环。

- [x] **Step 3: 提交并推送**

```bash
git add docs/plans/2026-03-25-desktop-el-voice-message-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/components/VoiceRecorderModal.vue \
  desktop-el/renderer/src/components/ChatPanel.vue \
  desktop-el/renderer/src/utils/chat-voice-recording.ts \
  desktop-el/renderer/src/utils/chat-voice-recording.test.ts \
  desktop-el/renderer/src/utils/chat-attachment-upload.ts \
  desktop-el/renderer/src/utils/chat-attachment-upload.test.ts \
  desktop-el/renderer/src/utils/chat-local-message.ts \
  desktop-el/renderer/src/utils/chat-local-message.test.ts
git commit -m "feat(desktop-el): support voice message recording"
git push origin codex/desktop-el
```

- [x] **Step 4: 收尾清理桌面进程**

Run:
- `make desktop-el-down`
- `pgrep -fl "desktop-el|electron|go-core" || true`

Expected: 无残留相关进程
