# Desktop EL Voice Waveform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的语音录音预览补齐最小波形展示，让用户在发送前能看到录音振幅概览，同时不改变现有附件上传与发送链路。

**Architecture:** 保持 renderer 本地处理录音预览，不新增 Go core RPC，不新增 Electron/Go 本地 HTTP 端口。波形计算抽成纯工具函数，优先复用旧端 Web Audio 解码思路，并在 `VoiceRecorderModal` 中异步生成预览数据；失败时静默降级为占位波形，不阻断发送。

**Tech Stack:** Vue 3、TypeScript、Bun test、Web Audio API、MediaRecorder、现有 `VoiceRecorderModal`

---

### Task 1: 固定波形 helper 的纯函数行为

**Files:**
- Create: `desktop-el/renderer/src/utils/chat-voice-waveform.ts`
- Create: `desktop-el/renderer/src/utils/chat-voice-waveform.test.ts`

- [x] **Step 1: 写 helper 失败测试**

```ts
test("creates normalized waveform bars from channel data", () => {})
test("returns placeholder bars when channel data is empty", () => {})
test("clamps waveform bars into the visible range", () => {})
```

- [x] **Step 2: 运行测试确认失败**

Run: `cd desktop-el && bun test renderer/src/utils/chat-voice-waveform.test.ts`
Expected: FAIL，提示缺少 `chat-voice-waveform` helper。

- [x] **Step 3: 实现最小 helper**

实现点：
- 从单声道采样数据生成固定数量的 `0-1` 归一化 bars
- 提供占位波形与 clamp/normalize 能力
- 提供 `Blob -> AudioBuffer -> waveform` 的异步入口

- [x] **Step 4: 运行 helper 测试确认通过**

Run: `cd desktop-el && bun test renderer/src/utils/chat-voice-waveform.test.ts`
Expected: PASS

### Task 2: 接入录音预览波形展示

**Files:**
- Modify: `desktop-el/renderer/src/components/VoiceRecorderModal.vue`

- [x] **Step 1: 在预览态接入异步波形生成**

实现点：
- 录音停止并生成 `previewFile` 后异步计算 waveform
- 关闭弹层 / 重录时正确取消过期结果
- 波形生成失败时保留音频预览与发送能力

- [x] **Step 2: 增加预览区波形 UI**

实现点：
- 在 `<audio>` 上方展示波形 bars
- 视觉上区分默认占位与真实振幅
- 保持移动端布局不回退

### Task 3: 验证、回填 backlog、提交推送与清理

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-voice-waveform-plan.md`

- [x] **Step 1: 运行定向验证**

Run: `cd desktop-el && bun test renderer/src/utils/chat-voice-waveform.test.ts`
Expected: PASS

- [x] **Step 2: 运行完整验证**

Run: `cd desktop-el && bun test`
Expected: PASS

Run: `cd desktop-el && bun run build`
Expected: PASS

- [x] **Step 3: 更新 backlog、提交并推送**

```bash
git add docs/plans/2026-03-26-desktop-el-voice-waveform-plan.md \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  desktop-el/renderer/src/utils/chat-voice-waveform.ts \
  desktop-el/renderer/src/utils/chat-voice-waveform.test.ts \
  desktop-el/renderer/src/components/VoiceRecorderModal.vue
git commit -m "feat(desktop-el): add voice recording waveform preview"
git push
```

- [x] **Step 4: 运行清理**

Run: `make desktop-el-down`
Expected: 无残留开发实例。

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无输出。
