import { describe, expect, test } from "bun:test";
import type { ChatMessage } from "@/api/chat";
import {
  canResendLocalMessage,
  createLocalTextMessage,
  mergeRemoteAndLocalMessages,
  markLocalMessageFailed,
  markLocalMessageSending,
  replaceLocalMessage,
} from "./chat-local-message";

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

const remoteMessage: ChatMessage = {
  id: "msg-remote-1",
  roomId: "room-2",
  senderId: "u-1",
  senderUsername: "me",
  senderName: "我",
  senderAvatarUrl: null,
  content: "hello desktop-el",
  preview: "hello desktop-el",
  messageType: "text",
  deliveryStatus: "sent",
  createdAt: new Date("2026-03-25T10:01:00Z"),
  isDeleted: false,
  isEdited: false,
  isSelf: true,
  pinnedAt: null,
  pinnedBy: null,
  forwardInfo: null,
  quotedMessage: null,
  parts: [
    {
      position: 0,
      partType: "text",
      text: "hello desktop-el",
      attachment: null,
    },
  ],
  clientStatus: null,
  retryPayload: null,
  errorMessage: null,
};

describe("chat local message helpers", () => {
  test("creates local sending text message with retry payload", () => {
    const message = createLocalTextMessage({
      roomId: "room-2",
      currentUserId: "u-1",
      currentUsername: "me",
      currentDisplayName: "我",
      content: "  hello desktop-el  ",
      quotedMessage,
    });

    expect(message.id.startsWith("local-message-")).toBeTrue();
    expect(message.roomId).toBe("room-2");
    expect(message.content).toBe("hello desktop-el");
    expect(message.preview).toBe("hello desktop-el");
    expect(message.messageType).toBe("text");
    expect(message.isSelf).toBeTrue();
    expect(message.clientStatus).toBe("sending");
    expect(message.retryPayload).toEqual({
      content: "hello desktop-el",
      quotedMessageId: "msg-quoted-1",
    });
    expect(message.quotedMessage).toEqual(quotedMessage);
    expect(message.parts).toEqual([
      {
        position: 0,
        partType: "text",
        text: "hello desktop-el",
        attachment: null,
      },
    ]);
    expect(message.createdAt).toBeInstanceOf(Date);
  });

  test("marks local message as failed and clears stale sending state", () => {
    const localMessage = createLocalTextMessage({
      roomId: "room-2",
      currentUserId: "u-1",
      currentUsername: "me",
      currentDisplayName: "我",
      content: "hello desktop-el",
    });

    expect(
      markLocalMessageFailed(localMessage, "network timeout"),
    ).toMatchObject({
      id: localMessage.id,
      clientStatus: "failed",
      errorMessage: "network timeout",
      retryPayload: {
        content: "hello desktop-el",
        quotedMessageId: null,
      },
    });
  });

  test("switches failed local message back to sending for retry", () => {
    const failedMessage = markLocalMessageFailed(
      createLocalTextMessage({
        roomId: "room-2",
        currentUserId: "u-1",
        currentUsername: "me",
        currentDisplayName: "我",
        content: "hello desktop-el",
      }),
      "network timeout",
    );

    expect(markLocalMessageSending(failedMessage)).toMatchObject({
      id: failedMessage.id,
      clientStatus: "sending",
      errorMessage: null,
    });
  });

  test("detects whether local message can be resent", () => {
    const resendable = markLocalMessageFailed(
      createLocalTextMessage({
        roomId: "room-2",
        currentUserId: "u-1",
        currentUsername: "me",
        currentDisplayName: "我",
        content: "hello desktop-el",
      }),
      "network timeout",
    );

    expect(canResendLocalMessage(resendable)).toBeTrue();
    expect(canResendLocalMessage(markLocalMessageSending(resendable))).toBeFalse();
    expect(
      canResendLocalMessage({
        ...resendable,
        parts: [
          {
            position: 0,
            partType: "file",
            text: null,
            attachment: {
              key: "attachments/demo.pdf",
              name: "demo.pdf",
              mime: "application/pdf",
              size: 1024,
              width: null,
              height: null,
              durationMs: null,
              thumbnailKey: null,
            },
          },
        ],
      }),
    ).toBeFalse();
  });

  test("replaces local message with remote message in place", () => {
    const localMessage = createLocalTextMessage({
      roomId: "room-2",
      currentUserId: "u-1",
      currentUsername: "me",
      currentDisplayName: "我",
      content: "hello desktop-el",
    });

    const messages = [
      {
        ...remoteMessage,
        id: "msg-remote-0",
      },
      localMessage,
    ];

    expect(
      replaceLocalMessage(messages, localMessage.id, remoteMessage),
    ).toEqual([
      {
        ...remoteMessage,
        id: "msg-remote-0",
      },
      remoteMessage,
    ]);
  });

  test("keeps local failed messages appended after remote history", () => {
    const failedLocalMessage = markLocalMessageFailed(
      createLocalTextMessage({
        roomId: "room-2",
        currentUserId: "u-1",
        currentUsername: "me",
        currentDisplayName: "我",
        content: "failed local message",
      }),
      "network timeout",
    );

    expect(
      mergeRemoteAndLocalMessages(
        [
          {
            ...remoteMessage,
            id: "msg-remote-0",
            createdAt: new Date("2026-03-25T10:00:00Z"),
          },
          remoteMessage,
        ],
        [failedLocalMessage],
      ),
    ).toEqual([
      {
        ...remoteMessage,
        id: "msg-remote-0",
        createdAt: new Date("2026-03-25T10:00:00Z"),
      },
      remoteMessage,
      failedLocalMessage,
    ]);
  });
});
