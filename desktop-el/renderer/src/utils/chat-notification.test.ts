import { describe, expect, test } from "bun:test";
import type { ChatWebSocketPush } from "@/api/chat";
import { getChatNotificationPlan } from "./chat-notification";

const createMessagePush = (
  overrides: Partial<Extract<ChatWebSocketPush, { type: "message" }>> = {},
): Extract<ChatWebSocketPush, { type: "message" }> => ({
  type: "message",
  id: "msg-1",
  message_id: "msg-1",
  room_id: "room-1",
  sender_id: "user-2",
  sender_username: "linyi",
  sender_nickname: "林一",
  sender_avatar_url: null,
  content: "  你好\n  desktop-el  ",
  message_type: "text",
  timestamp: "2026-03-25T09:00:00Z",
  quoted_message: null,
  forward_message: null,
  parts: [],
  ...overrides,
});

describe("chat notification helpers", () => {
  test("ignores self-sent messages", () => {
    expect(
      getChatNotificationPlan({
        push: createMessagePush({ sender_id: "user-1" }),
        currentUserId: "user-1",
        activeView: "contact",
        isWindowFocused: false,
      }),
    ).toEqual({
      shouldNotify: false,
      payload: null,
    });
  });

  test("ignores system messages", () => {
    expect(
      getChatNotificationPlan({
        push: createMessagePush({
          message_type: "system",
          content: "系统维护通知",
        }),
        currentUserId: "user-1",
        activeView: "contact",
        isWindowFocused: false,
      }),
    ).toEqual({
      shouldNotify: false,
      payload: null,
    });
  });

  test("skips system notification while chat view is focused", () => {
    expect(
      getChatNotificationPlan({
        push: createMessagePush(),
        currentUserId: "user-1",
        activeView: "chat",
        isWindowFocused: true,
      }),
    ).toEqual({
      shouldNotify: false,
      payload: null,
    });
  });

  test("builds notification title and body for background text messages", () => {
    expect(
      getChatNotificationPlan({
        push: createMessagePush(),
        currentUserId: "user-1",
        activeView: "contact",
        isWindowFocused: true,
      }),
    ).toEqual({
      shouldNotify: true,
      payload: {
        title: "林一",
        body: "你好 desktop-el",
      },
    });
  });

  test("falls back to message-type preview when content is empty", () => {
    expect(
      getChatNotificationPlan({
        push: createMessagePush({
          content: "   ",
          message_type: "image",
        }),
        currentUserId: "user-1",
        activeView: "settings",
        isWindowFocused: false,
      }),
    ).toEqual({
      shouldNotify: true,
      payload: {
        title: "林一",
        body: "[图片]",
      },
    });
  });
});
