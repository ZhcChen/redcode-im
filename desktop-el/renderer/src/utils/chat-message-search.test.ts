import { describe, expect, test } from "bun:test";
import type { ChatMessage } from "@/api/chat";
import {
  buildLocalMessageSearchText,
  highlightLocalMessageSearchSnippet,
  searchLocalChatMessages,
} from "./chat-message-search";

const createRemoteMessage = (
  overrides: Partial<ChatMessage> = {},
): ChatMessage => ({
  id: "msg-1",
  roomId: "room-1",
  senderId: "u-1",
  senderUsername: "alice",
  senderName: "Alice",
  senderAvatarUrl: null,
  content: "hello world",
  preview: "hello world",
  messageType: "text",
  deliveryStatus: "sent",
  createdAt: new Date("2026-03-25T12:00:00Z"),
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
      text: "hello world",
      attachment: null,
    },
  ],
  clientStatus: null,
  retryPayload: null,
  errorMessage: null,
  ...overrides,
});

describe("chat local message search helpers", () => {
  test("builds searchable text from text, attachments and quoted message", () => {
    const message = createRemoteMessage({
      id: "msg-rich",
      content: "",
      preview: "[文件] spec.pdf",
      parts: [
        {
          position: 0,
          partType: "text",
          text: "发布说明",
          attachment: null,
        },
        {
          position: 1,
          partType: "file",
          text: null,
          attachment: {
            key: "files/spec.pdf",
            name: "spec.pdf",
            mime: "application/pdf",
            size: 1024,
            width: null,
            height: null,
            durationMs: null,
            thumbnailKey: null,
          },
        },
      ],
      quotedMessage: {
        id: "msg-quoted-1",
        roomId: "room-1",
        senderId: "u-2",
        senderUsername: "bob",
        senderName: "Bob",
        senderAvatarUrl: null,
        content: "旧版本说明",
        messageType: "text",
        createdAt: new Date("2026-03-25T11:59:00Z"),
        isDeleted: false,
        parts: [
          {
            position: 0,
            partType: "text",
            text: "旧版本说明",
            attachment: null,
          },
        ],
      },
    });

    expect(buildLocalMessageSearchText(message)).toContain("发布说明");
    expect(buildLocalMessageSearchText(message)).toContain("spec.pdf");
    expect(buildLocalMessageSearchText(message)).toContain("Bob");
    expect(buildLocalMessageSearchText(message)).toContain("旧版本说明");
  });

  test("returns matched messages in reverse chronological order and ignores deleted/system messages", () => {
    const oldest = createRemoteMessage({
      id: "msg-oldest",
      content: "alpha hello",
      preview: "alpha hello",
      createdAt: new Date("2026-03-25T10:00:00Z"),
    });
    const newest = createRemoteMessage({
      id: "msg-newest",
      content: "latest hello",
      preview: "latest hello",
      createdAt: new Date("2026-03-25T13:00:00Z"),
    });
    const system = createRemoteMessage({
      id: "msg-system",
      content: "hello from system",
      preview: "hello from system",
      messageType: "system",
      isSelf: false,
      parts: [],
    });
    const deleted = createRemoteMessage({
      id: "msg-deleted",
      content: "hello deleted",
      preview: "hello deleted",
      isDeleted: true,
      parts: [],
    });

    const results = searchLocalChatMessages(
      [oldest, newest, system, deleted],
      "hello",
    );

    expect(results.map((item) => item.messageId)).toEqual([
      "msg-newest",
      "msg-oldest",
    ]);
    expect(results[0]?.senderName).toBe("Alice");
  });

  test("matches attachment names and returns highlighted snippets", () => {
    const attachmentMessage = createRemoteMessage({
      id: "msg-file",
      content: "",
      preview: "[文件] roadmap-final.pdf",
      messageType: "file",
      parts: [
        {
          position: 0,
          partType: "file",
          text: null,
          attachment: {
            key: "files/roadmap-final.pdf",
            name: "roadmap-final.pdf",
            mime: "application/pdf",
            size: 2048,
            width: null,
            height: null,
            durationMs: null,
            thumbnailKey: null,
          },
        },
      ],
    });

    const [result] = searchLocalChatMessages([attachmentMessage], "roadmap");

    expect(result?.summaryText).toContain("roadmap-final.pdf");
    expect(result?.highlightedHtml).toContain("<mark>roadmap</mark>");
  });

  test("escapes html before highlighting snippets", () => {
    expect(
      highlightLocalMessageSearchSnippet("prefix <b>hello</b> suffix", "hello"),
    ).toContain("&lt;b&gt;<mark>hello</mark>&lt;/b&gt;");
  });
});
