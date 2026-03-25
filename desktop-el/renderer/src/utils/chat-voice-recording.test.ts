import { describe, expect, test } from "bun:test";
import {
  buildVoiceRecordingFile,
  formatVoiceRecordingDuration,
  getVoiceRecordingBlockedReason,
  renameVoiceRecordingFile,
  resolvePreferredVoiceRecordingMimeType,
} from "./chat-voice-recording";

describe("chat voice recording helpers", () => {
  test("prefers opus webm when supported", () => {
    const mimeType = resolvePreferredVoiceRecordingMimeType({
      isTypeSupported(candidate) {
        return candidate === "audio/webm;codecs=opus";
      },
    });

    expect(mimeType).toBe("audio/webm;codecs=opus");
  });

  test("falls back to another supported recording mime type", () => {
    const mimeType = resolvePreferredVoiceRecordingMimeType({
      isTypeSupported(candidate) {
        return candidate === "audio/mp4";
      },
    });

    expect(mimeType).toBe("audio/mp4");
  });

  test("reports why voice recording cannot start", () => {
    expect(
      getVoiceRecordingBlockedReason({
        roomId: null,
        isSending: false,
        composerDisabled: false,
        hasDraftText: false,
        hasPendingAttachments: false,
      }),
    ).toBe("请先选择一个会话。");

    expect(
      getVoiceRecordingBlockedReason({
        roomId: "room-1",
        isSending: true,
        composerDisabled: false,
        hasDraftText: false,
        hasPendingAttachments: false,
      }),
    ).toBe("当前仍有消息发送中，请稍后再试。");

    expect(
      getVoiceRecordingBlockedReason({
        roomId: "room-1",
        isSending: false,
        composerDisabled: true,
        hasDraftText: false,
        hasPendingAttachments: false,
      }),
    ).toBe("当前会话暂时不能发送语音消息。");

    expect(
      getVoiceRecordingBlockedReason({
        roomId: "room-1",
        isSending: false,
        composerDisabled: false,
        hasDraftText: true,
        hasPendingAttachments: false,
      }),
    ).toBe("语音消息暂不支持和文本混发，请先发送或清空输入框。");

    expect(
      getVoiceRecordingBlockedReason({
        roomId: "room-1",
        isSending: false,
        composerDisabled: false,
        hasDraftText: false,
        hasPendingAttachments: true,
      }),
    ).toBe("语音消息暂不支持和其他附件混发，请先发送或移除附件。");
  });

  test("creates an uploadable recording file with duration metadata", () => {
    const blob = new Blob(["voice-demo"], {
      type: "audio/webm",
    });

    const file = buildVoiceRecordingFile({
      blob,
      recordingId: "rec-123",
      mimeType: "audio/webm",
      durationMs: 4200,
    });

    expect(file.name).toBe("voice_rec-123.webm");
    expect(file.type).toBe("audio/webm");
    expect(file.durationMs).toBe(4200);
  });

  test("renames recorded file while keeping extension and duration metadata", async () => {
    const file = buildVoiceRecordingFile({
      blob: new Blob(["voice-demo"], {
        type: "audio/webm",
      }),
      recordingId: "rec-123",
      mimeType: "audio/webm",
      durationMs: 4200,
    });

    const renamed = renameVoiceRecordingFile(file, "  team-sync-summary  ");

    expect(renamed.name).toBe("team-sync-summary.webm");
    expect(renamed.type).toBe("audio/webm");
    expect(renamed.durationMs).toBe(4200);
    expect(await renamed.text()).toBe("voice-demo");
  });

  test("keeps original file name when edited draft is empty", () => {
    const file = buildVoiceRecordingFile({
      blob: new Blob(["voice-demo"], {
        type: "audio/webm",
      }),
      recordingId: "rec-123",
      mimeType: "audio/webm",
      durationMs: 4200,
    });

    const renamed = renameVoiceRecordingFile(file, "   ");

    expect(renamed.name).toBe(file.name);
    expect(renamed.durationMs).toBe(4200);
  });

  test("formats recording duration for recorder status and preview", () => {
    expect(formatVoiceRecordingDuration(0)).toBe("00:00");
    expect(formatVoiceRecordingDuration(12_300)).toBe("00:12");
    expect(formatVoiceRecordingDuration(125_000)).toBe("02:05");
  });
});
