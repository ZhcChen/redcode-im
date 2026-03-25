export interface VoiceRecordingGateInput {
  roomId: string | null;
  isSending: boolean;
  composerDisabled: boolean;
  hasDraftText: boolean;
  hasPendingAttachments: boolean;
}

export interface VoiceRecordingFile extends File {
  durationMs: number;
}

const VOICE_RECORDING_MIME_CANDIDATES = [
  "audio/webm;codecs=opus",
  "audio/webm",
  "audio/mp4",
  "audio/ogg;codecs=opus",
  "audio/ogg",
] as const;

const getVoiceRecordingFileExtension = (mimeType: string) => {
  const normalizedMimeType = mimeType.trim().toLowerCase();
  if (normalizedMimeType.includes("audio/mp4")) {
    return "m4a";
  }
  if (normalizedMimeType.includes("audio/ogg")) {
    return "ogg";
  }
  if (normalizedMimeType.includes("audio/wav")) {
    return "wav";
  }
  return "webm";
};

export const resolvePreferredVoiceRecordingMimeType = (
  mediaRecorderLike:
    | {
        isTypeSupported?: (mimeType: string) => boolean;
      }
    | null
    | undefined = typeof MediaRecorder === "undefined" ? null : MediaRecorder,
) => {
  const isTypeSupported = mediaRecorderLike?.isTypeSupported;
  if (typeof isTypeSupported !== "function") {
    return null;
  }

  return (
    VOICE_RECORDING_MIME_CANDIDATES.find((candidate) =>
      isTypeSupported(candidate),
    ) ?? null
  );
};

export const getVoiceRecordingBlockedReason = (
  input: VoiceRecordingGateInput,
) => {
  if (!input.roomId) {
    return "请先选择一个会话。";
  }
  if (input.isSending) {
    return "当前仍有消息发送中，请稍后再试。";
  }
  if (input.composerDisabled) {
    return "当前会话暂时不能发送语音消息。";
  }
  if (input.hasDraftText) {
    return "语音消息暂不支持和文本混发，请先发送或清空输入框。";
  }
  if (input.hasPendingAttachments) {
    return "语音消息暂不支持和其他附件混发，请先发送或移除附件。";
  }

  return null;
};

export const buildVoiceRecordingFile = (options: {
  blob: Blob;
  recordingId: string;
  mimeType: string;
  durationMs: number;
}) => {
  const normalizedMimeType = options.mimeType.trim().toLowerCase() || "audio/webm";
  const extension = getVoiceRecordingFileExtension(normalizedMimeType);
  const file = new File(
    [options.blob],
    `voice_${options.recordingId}.${extension}`,
    {
      type: normalizedMimeType,
      lastModified: Date.now(),
    },
  ) as VoiceRecordingFile;
  file.durationMs = Math.max(0, Math.round(options.durationMs));
  return file;
};

export const formatVoiceRecordingDuration = (durationMs: number) => {
  const totalSeconds = Math.max(
    0,
    Math.floor(
      Number.isFinite(durationMs) ? Math.max(0, durationMs) / 1000 : 0,
    ),
  );
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
};
