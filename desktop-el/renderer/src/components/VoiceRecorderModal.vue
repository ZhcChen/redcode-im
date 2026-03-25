<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from "vue";
import {
  buildVoiceRecordingFile,
  formatVoiceRecordingDuration,
  renameVoiceRecordingFile,
  resolvePreferredVoiceRecordingMimeType,
  type VoiceRecordingFile,
} from "@/utils/chat-voice-recording";
import {
  buildPlaceholderVoiceWaveform,
  createWaveformFromBlob,
} from "@/utils/chat-voice-waveform";

const props = defineProps<{
  visible: boolean;
  isSubmitting: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "submit", payload: { file: VoiceRecordingFile }): void;
}>();

const previewUrl = ref<string | null>(null);
const previewFile = ref<VoiceRecordingFile | null>(null);
const previewDurationMs = ref(0);
const previewFileNameDraft = ref("");
const previewWaveformBars = ref<number[]>([]);
const recordingDurationMs = ref(0);
const isRecording = ref(false);
const isPreparing = ref(false);
const errorMessage = ref<string | null>(null);

const mediaRecorderRef = ref<MediaRecorder | null>(null);
const mediaStreamRef = ref<MediaStream | null>(null);
const recordingMimeType = ref<string | null>(null);

let recordingStartedAt = 0;
let recordingTimerId: number | null = null;
let recordedChunks: BlobPart[] = [];
let discardRecordingOnStop = false;
let recordingSessionToken = 0;
let previewWaveformToken = 0;

const PREVIEW_WAVEFORM_SAMPLES = 24;

const recorderTitle = computed(() => {
  if (isRecording.value) {
    return "录音中";
  }
  if (previewFile.value) {
    return "录音预览";
  }
  return "语音消息";
});

const recorderSubtitle = computed(() => {
  if (isRecording.value) {
    return `正在采集麦克风音频 ${formatVoiceRecordingDuration(recordingDurationMs.value)}`;
  }
  if (previewFile.value) {
    return `已录制 ${formatVoiceRecordingDuration(previewDurationMs.value)}，确认后会按现有附件链路发送。`;
  }
  return "录音仅在当前窗口内采集，不额外打开本地 HTTP 端口。";
});

const primaryActionLabel = computed(() => {
  if (isPreparing.value) {
    return "准备中...";
  }
  if (isRecording.value) {
    return "停止录音";
  }
  if (previewFile.value) {
    return "重新录音";
  }
  return "开始录音";
});

const canSend = computed(
  () => Boolean(previewFile.value) && !isRecording.value && !props.isSubmitting,
);

const resetPreview = () => {
  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value);
  }
  previewUrl.value = null;
  previewFile.value = null;
  previewDurationMs.value = 0;
  previewFileNameDraft.value = "";
  previewWaveformBars.value = [];
  previewWaveformToken += 1;
};

const createPreviewWaveformPlaceholder = () =>
  buildPlaceholderVoiceWaveform(PREVIEW_WAVEFORM_SAMPLES);

const getPreviewWaveformBarStyle = (bar: number) => ({
  height: `${Math.max(12, Math.round(bar * 48))}px`,
});

const stopRecordingTimer = () => {
  if (recordingTimerId !== null) {
    window.clearInterval(recordingTimerId);
    recordingTimerId = null;
  }
};

const cleanupMediaStream = () => {
  mediaStreamRef.value?.getTracks().forEach((track) => track.stop());
  mediaStreamRef.value = null;
};

const resetRecorderState = () => {
  stopRecordingTimer();
  isPreparing.value = false;
  isRecording.value = false;
  recordingDurationMs.value = 0;
  recordingStartedAt = 0;
  recordedChunks = [];
  discardRecordingOnStop = false;
  mediaRecorderRef.value = null;
  recordingMimeType.value = null;
  cleanupMediaStream();
};

const buildRecordingId = () =>
  globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

const updatePreviewWaveform = async (file: VoiceRecordingFile) => {
  const currentToken = ++previewWaveformToken;
  previewWaveformBars.value = createPreviewWaveformPlaceholder();

  try {
    const waveform = await createWaveformFromBlob(file, PREVIEW_WAVEFORM_SAMPLES);
    if (currentToken !== previewWaveformToken) {
      return;
    }
    previewWaveformBars.value = waveform;
  } catch (error) {
    if (currentToken !== previewWaveformToken) {
      return;
    }
    previewWaveformBars.value = createPreviewWaveformPlaceholder();
    console.warn("[desktop-el-renderer] voice preview waveform failed", error);
  }
};

const finalizeRecordedBlob = () => {
  const mimeType =
    mediaRecorderRef.value?.mimeType ||
    recordingMimeType.value ||
    "audio/webm";
  const shouldDiscard = discardRecordingOnStop;
  const durationMs = Math.max(
    recordingDurationMs.value,
    recordingStartedAt ? Date.now() - recordingStartedAt : 0,
  );
  const blob = new Blob(recordedChunks, {
    type: mimeType,
  });
  recordedChunks = [];
  resetRecorderState();

  if (shouldDiscard) {
    return;
  }

  if (!blob.size) {
    errorMessage.value = "录音未生成有效音频，请重试。";
    return;
  }

  resetPreview();
  const file = buildVoiceRecordingFile({
    blob,
    recordingId: buildRecordingId(),
    mimeType,
    durationMs,
  });
  previewFile.value = file;
  previewDurationMs.value = file.durationMs;
  previewFileNameDraft.value = file.name;
  previewUrl.value = URL.createObjectURL(file);
  errorMessage.value = null;
  void updatePreviewWaveform(file);
};

const waitForRecorderStop = () =>
  new Promise<void>((resolve) => {
    const recorder = mediaRecorderRef.value;
    if (!recorder || recorder.state === "inactive") {
      resolve();
      return;
    }

    const handleStop = () => {
      recorder.removeEventListener("stop", handleStop);
      resolve();
    };

    recorder.addEventListener("stop", handleStop);
    recorder.stop();
  });

const stopActiveRecording = async (discard = false) => {
  const recorder = mediaRecorderRef.value;
  if (!recorder || recorder.state === "inactive") {
    if (discard) {
      resetPreview();
      errorMessage.value = null;
    }
    resetRecorderState();
    return;
  }

  discardRecordingOnStop = discard;
  await waitForRecorderStop();
  if (discard) {
    resetPreview();
    errorMessage.value = null;
  }
};

const releaseResources = async () => {
  recordingSessionToken += 1;
  resetPreview();
  errorMessage.value = null;
  if (mediaRecorderRef.value && mediaRecorderRef.value.state !== "inactive") {
    await stopActiveRecording(true);
    return;
  }
  resetRecorderState();
};

const startRecording = async () => {
  if (props.isSubmitting || isPreparing.value || isRecording.value) {
    return;
  }

  if (
    typeof navigator === "undefined" ||
    !navigator.mediaDevices?.getUserMedia
  ) {
    errorMessage.value = "当前环境不支持麦克风录音。";
    return;
  }

  if (typeof MediaRecorder === "undefined") {
    errorMessage.value = "当前环境不支持 MediaRecorder。";
    return;
  }

  const preferredMimeType = resolvePreferredVoiceRecordingMimeType(MediaRecorder);
  if (!preferredMimeType) {
    errorMessage.value = "当前环境暂不支持可用的语音录音编码。";
    return;
  }

  isPreparing.value = true;
  errorMessage.value = null;
  resetPreview();
  const startToken = ++recordingSessionToken;

  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: true,
    });
    if (startToken !== recordingSessionToken || !props.visible) {
      stream.getTracks().forEach((track) => track.stop());
      isPreparing.value = false;
      return;
    }
    const recorder = new MediaRecorder(stream, {
      mimeType: preferredMimeType,
    });

    mediaStreamRef.value = stream;
    mediaRecorderRef.value = recorder;
    recordingMimeType.value = preferredMimeType;
    recordedChunks = [];
    discardRecordingOnStop = false;
    recordingStartedAt = Date.now();
    recordingDurationMs.value = 0;

    recorder.addEventListener("dataavailable", (event) => {
      if (event.data.size > 0) {
        recordedChunks.push(event.data);
      }
    });
    recorder.addEventListener("stop", () => {
      finalizeRecordedBlob();
    });
    recorder.addEventListener("error", (event) => {
      const recorderError = (event as Event & { error?: DOMException }).error;
      errorMessage.value =
        recorderError?.message || "录音过程中发生错误，请重试。";
    });

    recorder.start(250);
    isRecording.value = true;
    isPreparing.value = false;
    recordingTimerId = window.setInterval(() => {
      recordingDurationMs.value = Math.max(0, Date.now() - recordingStartedAt);
    }, 200);
  } catch (error) {
    resetRecorderState();
    errorMessage.value =
      error instanceof Error
        ? error.message
        : "无法访问麦克风，请检查权限后重试。";
  } finally {
    isPreparing.value = false;
  }
};

const handlePrimaryAction = async () => {
  if (isRecording.value) {
    await stopActiveRecording(false);
    return;
  }
  await startRecording();
};

const close = async () => {
  if (props.isSubmitting) {
    return;
  }
  await releaseResources();
  emit("update:visible", false);
};

const handleSubmit = () => {
  if (!previewFile.value || props.isSubmitting) {
    return;
  }
  emit("submit", {
    file: renameVoiceRecordingFile(previewFile.value, previewFileNameDraft.value),
  });
};

watch(
  () => props.visible,
  (visible, previousVisible) => {
    if (visible && !previousVisible) {
      resetPreview();
      errorMessage.value = null;
      return;
    }
    if (!visible && previousVisible) {
      void releaseResources();
    }
  },
);

onBeforeUnmount(() => {
  void releaseResources();
});
</script>

<template>
  <Teleport to="body">
    <div v-if="props.visible" class="voice-recorder-modal">
      <div class="voice-recorder-modal__backdrop" @click="void close()" />
      <section class="voice-recorder-modal__panel">
        <header class="voice-recorder-modal__header">
          <div>
            <p class="voice-recorder-modal__eyebrow">语音消息</p>
            <h2>{{ recorderTitle }}</h2>
            <small>{{ recorderSubtitle }}</small>
          </div>
          <button
            type="button"
            class="voice-recorder-modal__button voice-recorder-modal__button--ghost"
            :disabled="props.isSubmitting"
            @click="void close()"
          >
            关闭
          </button>
        </header>

        <div class="voice-recorder-modal__content">
          <div
            class="voice-recorder-modal__pulse"
            :class="{
              'voice-recorder-modal__pulse--active': isRecording,
              'voice-recorder-modal__pulse--ready': previewFile,
            }"
          >
            <span />
            <strong>
              {{
                isRecording
                  ? formatVoiceRecordingDuration(recordingDurationMs)
                  : previewFile
                    ? formatVoiceRecordingDuration(previewDurationMs)
                    : "00:00"
              }}
            </strong>
          </div>

          <p v-if="!previewFile" class="voice-recorder-modal__hint">
            {{
              isRecording
                ? "再次点击“停止录音”即可生成预览。"
                : "点击开始录音，停止后可先试听，再决定是否发送。"
            }}
          </p>

          <div v-if="previewUrl" class="voice-recorder-modal__preview">
            <div
              v-if="previewWaveformBars.length"
              class="voice-recorder-modal__waveform"
              aria-hidden="true"
            >
              <span
                v-for="(bar, index) in previewWaveformBars"
                :key="`preview-wave-${index}`"
                class="voice-recorder-modal__wave-bar"
                :style="getPreviewWaveformBarStyle(bar)"
              />
            </div>
            <audio
              class="voice-recorder-modal__audio"
              controls
              :src="previewUrl"
              preload="metadata"
            />
            <label class="voice-recorder-modal__field">
              <span>文件名</span>
              <input
                v-model="previewFileNameDraft"
                class="voice-recorder-modal__input"
                :disabled="props.isSubmitting"
                placeholder="请输入语音文件名"
              />
            </label>
            <small>试听无误后发送，会自动复用现有失败重试链路。</small>
          </div>

          <p
            v-if="errorMessage"
            class="voice-recorder-modal__error"
          >
            {{ errorMessage }}
          </p>
        </div>

        <footer class="voice-recorder-modal__footer">
          <button
            type="button"
            class="voice-recorder-modal__button voice-recorder-modal__button--ghost"
            :disabled="props.isSubmitting"
            @click="void close()"
          >
            取消
          </button>
          <button
            type="button"
            class="voice-recorder-modal__button voice-recorder-modal__button--secondary"
            :disabled="props.isSubmitting || isPreparing"
            @click="void handlePrimaryAction()"
          >
            {{ primaryActionLabel }}
          </button>
          <button
            type="button"
            class="voice-recorder-modal__button"
            :disabled="!canSend"
            @click="handleSubmit"
          >
            {{ props.isSubmitting ? "发送中..." : "发送语音" }}
          </button>
        </footer>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.voice-recorder-modal {
  position: fixed;
  inset: 0;
  z-index: 52;
  display: grid;
  place-items: center;
  padding: 24px;
}

.voice-recorder-modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.48);
  backdrop-filter: blur(14px);
}

.voice-recorder-modal__panel {
  position: relative;
  z-index: 1;
  width: min(560px, 100%);
  display: grid;
  gap: 20px;
  padding: 28px;
  border-radius: 28px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background:
    radial-gradient(circle at top right, rgba(0, 194, 179, 0.16), transparent 38%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.98), rgba(241, 245, 249, 0.96));
  box-shadow: 0 32px 84px rgba(15, 23, 42, 0.26);
}

.voice-recorder-modal__header,
.voice-recorder-modal__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.voice-recorder-modal__header {
  align-items: flex-start;
}

.voice-recorder-modal__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: rgba(15, 23, 42, 0.55);
}

.voice-recorder-modal__header h2 {
  margin: 0;
  font-size: 24px;
  color: var(--text-primary);
}

.voice-recorder-modal__header small {
  color: var(--text-secondary);
}

.voice-recorder-modal__content {
  display: grid;
  gap: 18px;
}

.voice-recorder-modal__pulse {
  display: grid;
  place-items: center;
  gap: 14px;
  min-height: 200px;
  padding: 24px;
  border-radius: 24px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background:
    radial-gradient(circle, rgba(15, 23, 42, 0.04), transparent 70%),
    rgba(255, 255, 255, 0.84);
}

.voice-recorder-modal__pulse span {
  width: 84px;
  height: 84px;
  border-radius: 999px;
  background: linear-gradient(135deg, #ff7a59, #ff4d6d);
  box-shadow: 0 18px 44px rgba(255, 77, 109, 0.28);
}

.voice-recorder-modal__pulse strong {
  font-size: 36px;
  font-variant-numeric: tabular-nums;
  color: var(--text-primary);
}

.voice-recorder-modal__pulse--active span {
  animation: voice-recorder-pulse 1.25s ease-in-out infinite;
}

.voice-recorder-modal__pulse--ready span {
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  box-shadow: 0 18px 44px rgba(0, 194, 179, 0.24);
}

.voice-recorder-modal__hint,
.voice-recorder-modal__preview small {
  margin: 0;
  color: var(--text-secondary);
}

.voice-recorder-modal__preview {
  display: grid;
  gap: 12px;
  padding: 14px 16px;
  border-radius: 22px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.76);
}

.voice-recorder-modal__field {
  display: grid;
  gap: 8px;
}

.voice-recorder-modal__field span {
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(15, 23, 42, 0.54);
}

.voice-recorder-modal__input {
  width: 100%;
  padding: 12px 14px;
  border-radius: 14px;
  border: 1px solid rgba(148, 163, 184, 0.36);
  background: rgba(255, 255, 255, 0.92);
  color: #0f172a;
  font-size: 14px;
  line-height: 1.4;
}

.voice-recorder-modal__input:focus {
  outline: 2px solid rgba(0, 194, 179, 0.18);
  border-color: rgba(0, 194, 179, 0.48);
}

.voice-recorder-modal__input:disabled {
  cursor: not-allowed;
  background: rgba(226, 232, 240, 0.68);
}

.voice-recorder-modal__waveform {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 4px;
  min-height: 56px;
}

.voice-recorder-modal__wave-bar {
  flex: 1 1 0;
  min-width: 4px;
  border-radius: 999px;
  background: linear-gradient(180deg, rgba(0, 194, 179, 0.9), rgba(15, 118, 110, 0.55));
  box-shadow: 0 10px 24px rgba(0, 194, 179, 0.14);
}

.voice-recorder-modal__audio {
  width: 100%;
}

.voice-recorder-modal__error {
  margin: 0;
  padding: 12px 14px;
  border-radius: 16px;
  background: rgba(248, 113, 113, 0.12);
  color: #b91c1c;
}

.voice-recorder-modal__button {
  height: 42px;
  padding: 0 18px;
  border: 1px solid transparent;
  border-radius: 999px;
  background: linear-gradient(135deg, rgba(0, 194, 179, 0.24), rgba(0, 155, 143, 0.22));
  color: var(--primary-color-strong);
  cursor: pointer;
}

.voice-recorder-modal__button--ghost {
  background: rgba(15, 23, 42, 0.04);
  color: var(--text-primary);
}

.voice-recorder-modal__button--secondary {
  background: rgba(255, 122, 89, 0.14);
  color: #c2410c;
}

.voice-recorder-modal__button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

@keyframes voice-recorder-pulse {
  0%,
  100% {
    transform: scale(0.92);
    opacity: 0.84;
  }

  50% {
    transform: scale(1.06);
    opacity: 1;
  }
}

@media (max-width: 720px) {
  .voice-recorder-modal {
    padding: 16px;
  }

  .voice-recorder-modal__panel {
    padding: 22px;
  }

  .voice-recorder-modal__footer {
    flex-wrap: wrap;
    justify-content: flex-end;
  }

  .voice-recorder-modal__button {
    flex: 1 1 140px;
  }
}
</style>
