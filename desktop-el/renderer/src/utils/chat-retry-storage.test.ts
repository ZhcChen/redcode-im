import { describe, expect, test } from "bun:test";
import type { ChatMessage } from "@/api/chat";
import {
  RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY,
  restoreRetryableLocalMessages,
  saveRetryableLocalMessages,
} from "./chat-retry-storage";
import { createLocalComposerMessage, markLocalMessageFailed } from "./chat-local-message";

const createMemoryStorage = () => {
  const store = new Map<string, string>();

  return {
    getItem(key: string) {
      return store.get(key) ?? null;
    },
    setItem(key: string, value: string) {
      store.set(key, value);
    },
    removeItem(key: string) {
      store.delete(key);
    },
  };
};

const quotedMessage = {
  id: "msg-quoted-1",
  roomId: "room-2",
  senderId: "u-2",
  senderUsername: "alice",
  senderName: "Alice",
  senderAvatarUrl: null,
  content: "quoted text",
  messageType: "text" as const,
  createdAt: new Date("2026-03-25T10:00:00Z"),
  isDeleted: false,
  parts: [
    {
      position: 0,
      partType: "text" as const,
      text: "quoted text",
      attachment: null,
    },
  ],
};

describe("chat retry storage helpers", () => {
  test("persists only failed local messages without file attachments", () => {
    const storage = createMemoryStorage();
    const retryableText = markLocalMessageFailed(
      createLocalComposerMessage({
        roomId: "room-2",
        currentUserId: "u-1",
        currentUsername: "me",
        currentDisplayName: "我",
        content: "hello retry",
        quotedMessage,
      }),
      "network timeout",
    );
    const attachmentMessage = markLocalMessageFailed(
      createLocalComposerMessage({
        roomId: "room-2",
        currentUserId: "u-1",
        currentUsername: "me",
        currentDisplayName: "我",
        attachments: [
          new File(["binary"], "report.pdf", {
            type: "application/pdf",
          }),
        ],
      }),
      "upload failed",
    );

    saveRetryableLocalMessages([retryableText, attachmentMessage], storage);

    const raw = storage.getItem(RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY);
    expect(raw).not.toBeNull();
    expect(JSON.parse(raw || "[]")).toHaveLength(1);
  });

  test("restores persisted failed text messages with dates and quoted message", () => {
    const storage = createMemoryStorage();
    const message = markLocalMessageFailed(
      createLocalComposerMessage({
        roomId: "room-2",
        currentUserId: "u-1",
        currentUsername: "me",
        currentDisplayName: "我",
        content: "hello retry",
        quotedMessage,
      }),
      "network timeout",
    );

    saveRetryableLocalMessages([message], storage);
    const restored = restoreRetryableLocalMessages(storage);

    expect(restored).toHaveLength(1);
    expect(restored[0]).toMatchObject({
      id: message.id,
      roomId: "room-2",
      content: "hello retry",
      clientStatus: "failed",
      errorMessage: "network timeout",
      retryPayload: {
        content: "hello retry",
        quotedMessageId: "msg-quoted-1",
      },
    });
    expect(restored[0].createdAt).toBeInstanceOf(Date);
    expect(restored[0].quotedMessage?.createdAt).toBeInstanceOf(Date);
  });

  test("drops corrupted storage payloads instead of throwing", () => {
    const storage = createMemoryStorage();
    storage.setItem(RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY, "{bad json");

    expect(restoreRetryableLocalMessages(storage)).toEqual([]);
  });

  test("removes storage key when there are no persistable messages", () => {
    const storage = createMemoryStorage();
    const sendingText = createLocalComposerMessage({
      roomId: "room-2",
      currentUserId: "u-1",
      currentUsername: "me",
      currentDisplayName: "我",
      content: "hello retry",
    });

    saveRetryableLocalMessages([sendingText], storage);

    expect(storage.getItem(RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY)).toBeNull();
  });
});
