import { describe, expect, test } from "bun:test";
import { mapChatMessagePayload } from "./chat";

describe("chat api message mapping", () => {
  test("maps quoted_message payload into chat message model", () => {
    const mapped = mapChatMessagePayload(
      {
        id: "msg-2",
        room_id: "room-1",
        sender_id: "user-2",
        sender_username: "bob",
        sender_nickname: "Bob",
        content: "reply payload",
        message_type: "text",
        status: "sent",
        created_at: "2026-03-25T10:00:00Z",
        quoted_message: {
          id: "msg-1",
          room_id: "room-1",
          sender_id: "user-1",
          sender_username: "alice",
          sender_nickname: "Alice",
          content: "",
          message_type: "mixed",
          created_at: "2026-03-25T09:59:00Z",
          is_deleted: false,
          parts: [
            {
              position: 0,
              part_type: "text",
              text: "quoted text",
              attachment: null
            },
            {
              position: 1,
              part_type: "image",
              attachment: {
                key: "messages/room-1/demo.png",
                name: "demo.png",
                mime: "image/png",
                size: 1024,
                width: 320,
                height: 200
              }
            }
          ]
        },
        parts: [
          {
            position: 0,
            part_type: "text",
            text: "reply payload",
            attachment: null
          }
        ]
      },
      "user-2"
    );

    expect(mapped.isSelf).toBe(true);
    expect(mapped.quotedMessage).toEqual({
      id: "msg-1",
      roomId: "room-1",
      senderId: "user-1",
      senderUsername: "alice",
      senderName: "Alice",
      senderAvatarUrl: null,
      content: "",
      messageType: "mixed",
      createdAt: new Date("2026-03-25T09:59:00Z"),
      isDeleted: false,
      parts: [
        {
          position: 0,
          partType: "text",
          text: "quoted text",
          attachment: null
        },
        {
          position: 1,
          partType: "image",
          text: null,
          attachment: {
            key: "messages/room-1/demo.png",
            name: "demo.png",
            mime: "image/png",
            size: 1024,
            width: 320,
            height: 200,
            durationMs: null,
            thumbnailKey: null
          }
        }
      ]
    });
  });
});
