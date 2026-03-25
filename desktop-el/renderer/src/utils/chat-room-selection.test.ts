import { describe, expect, test } from "bun:test";
import { pickSelectedChatRoomId } from "./chat-room-selection";

describe("chat room selection helpers", () => {
  const chats = [
    { roomId: "room-1" },
    { roomId: "room-2" },
    { roomId: "room-3" },
  ];

  test("prefers restored room id over current room when available", () => {
    expect(
      pickSelectedChatRoomId({
        chats,
        restoredRoomId: "room-2",
        currentRoomId: "room-1",
      }),
    ).toBe("room-2");
  });

  test("falls back to current room and then first room", () => {
    expect(
      pickSelectedChatRoomId({
        chats,
        restoredRoomId: "room-missing",
        currentRoomId: "room-3",
      }),
    ).toBe("room-3");

    expect(
      pickSelectedChatRoomId({
        chats,
        restoredRoomId: null,
        currentRoomId: "room-missing",
      }),
    ).toBe("room-1");
  });

  test("returns null when fallback is disabled or the list is empty", () => {
    expect(
      pickSelectedChatRoomId({
        chats,
        restoredRoomId: null,
        currentRoomId: null,
        fallbackToFirst: false,
      }),
    ).toBeNull();

    expect(
      pickSelectedChatRoomId({
        chats: [],
        restoredRoomId: "room-1",
        currentRoomId: "room-1",
      }),
    ).toBeNull();
  });
});
