import { describe, expect, test } from "bun:test";
import type { ChatMessage } from "@/api/chat";
import { createLocalComposerMessage, markLocalMessageFailed } from "./chat-local-message";
import {
  buildDragSelectedMessageIds,
  buildForwardSourceSummary,
  canDeleteMessage,
  canDeleteSelectedMessages,
  canForwardMessage,
  canForwardSelectedMessages,
  canSelectMessageForMultiSelect,
} from "./chat-message-actions";

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

describe("chat message action helpers", () => {
  test("allows regular remote self messages to participate in batch forward and delete", () => {
    const first = createRemoteMessage({
      id: "msg-1",
      content: "first",
      preview: "first",
    });
    const second = createRemoteMessage({
      id: "msg-2",
      content: "second",
      preview: "second",
    });

    expect(canSelectMessageForMultiSelect(first)).toBe(true);
    expect(canForwardMessage(first)).toBe(true);
    expect(canDeleteMessage(first)).toBe(true);
    expect(canForwardSelectedMessages([first, second])).toBe(true);
    expect(canDeleteSelectedMessages([first, second])).toBe(true);
  });

  test("blocks batch forward for local retry messages but still allows deleting own failed local message", () => {
    const failedLocalMessage = markLocalMessageFailed(
      createLocalComposerMessage({
        roomId: "room-1",
        currentUserId: "u-1",
        currentUsername: "alice",
        currentDisplayName: "Alice",
        content: "retry me",
      }),
      "network timeout",
    );

    expect(canSelectMessageForMultiSelect(failedLocalMessage)).toBe(true);
    expect(canForwardMessage(failedLocalMessage)).toBe(false);
    expect(canDeleteMessage(failedLocalMessage)).toBe(true);
    expect(canForwardSelectedMessages([failedLocalMessage])).toBe(false);
    expect(canDeleteSelectedMessages([failedLocalMessage])).toBe(true);
  });

  test("prevents system messages from entering multi select", () => {
    const systemMessage = createRemoteMessage({
      id: "msg-system",
      messageType: "system",
      content: "",
      preview: "系统消息",
      isSelf: false,
      parts: [],
    });

    expect(canSelectMessageForMultiSelect(systemMessage)).toBe(false);
  });

  test("requires every selected message to satisfy delete rules", () => {
    const selfMessage = createRemoteMessage({
      id: "msg-self",
    });
    const peerMessage = createRemoteMessage({
      id: "msg-peer",
      isSelf: false,
      senderId: "u-2",
      senderUsername: "bob",
      senderName: "Bob",
    });

    expect(canDeleteSelectedMessages([selfMessage, peerMessage])).toBe(false);
  });

  test("builds forward summary for single and multiple selected messages", () => {
    const single = createRemoteMessage({
      id: "msg-single",
      content: "summary text",
      preview: "summary text",
    });
    const second = createRemoteMessage({
      id: "msg-2",
      content: "second",
      preview: "second",
    });

    expect(buildForwardSourceSummary([])).toBeNull();
    expect(buildForwardSourceSummary([single])).toBe("summary text");
    expect(buildForwardSourceSummary([single, second])).toBe("已选择 2 条消息");
  });

  test("builds drag-selected message ids for a forward range", () => {
    const first = createRemoteMessage({ id: "msg-1" });
    const second = createRemoteMessage({ id: "msg-2" });
    const third = createRemoteMessage({ id: "msg-3" });

    expect(
      buildDragSelectedMessageIds(
        [first, second, third],
        "msg-1",
        "msg-3",
      ),
    ).toEqual(["msg-1", "msg-2", "msg-3"]);
  });

  test("builds drag-selected message ids for a reverse range and skips system messages", () => {
    const first = createRemoteMessage({ id: "msg-1" });
    const system = createRemoteMessage({
      id: "msg-system",
      messageType: "system",
      content: "",
      preview: "系统消息",
      isSelf: false,
      parts: [],
    });
    const third = createRemoteMessage({ id: "msg-3" });

    expect(
      buildDragSelectedMessageIds(
        [first, system, third],
        "msg-3",
        "msg-1",
      ),
    ).toEqual(["msg-1", "msg-3"]);
  });

  test("returns an empty selection when drag anchor or current message is missing", () => {
    const first = createRemoteMessage({ id: "msg-1" });
    const second = createRemoteMessage({ id: "msg-2" });

    expect(
      buildDragSelectedMessageIds([first, second], "missing", "msg-2"),
    ).toEqual([]);
    expect(
      buildDragSelectedMessageIds([first, second], "msg-1", "missing"),
    ).toEqual([]);
  });
});
