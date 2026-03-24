import { describe, expect, test } from "bun:test";
import { formatQuotedMessagePreview, getQuotedSenderDisplayName } from "./chat-quoted-message";

describe("chat quoted message helpers", () => {
  test("prefers senderName over username when building quoted display name", () => {
    expect(
      getQuotedSenderDisplayName({
        senderName: "Alice",
        senderUsername: "alice",
        senderId: "user-1"
      })
    ).toBe("Alice");
  });

  test("formats text, attachment and deleted quoted messages into compact preview copy", () => {
    expect(
      formatQuotedMessagePreview({
        content: "",
        isDeleted: false,
        parts: [
          {
            position: 0,
            partType: "text",
            text: "quoted text",
            attachment: null
          }
        ]
      })
    ).toBe("quoted text");

    expect(
      formatQuotedMessagePreview({
        content: "",
        isDeleted: false,
        parts: [
          {
            position: 0,
            partType: "video",
            text: null,
            attachment: null
          }
        ]
      })
    ).toBe("[视频]");

    expect(
      formatQuotedMessagePreview({
        content: "legacy text",
        isDeleted: true,
        parts: []
      })
    ).toBe("[消息已删除]");
  });
});
