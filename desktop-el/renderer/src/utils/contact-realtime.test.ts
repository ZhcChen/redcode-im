import { describe, expect, test } from "bun:test";
import { mapContactRealtimeEvent } from "./contact-realtime";

describe("contact realtime helpers", () => {
  test("maps supported contact websocket pushes", () => {
    expect(
      mapContactRealtimeEvent({
        type: "friend_request_update",
        pending_count: 3
      })
    ).toEqual({
      type: "friend_request_update",
      pendingCount: 3
    });

    expect(
      mapContactRealtimeEvent({
        type: "friendship_deleted",
        user_id: "u-2"
      })
    ).toEqual({
      type: "friendship_deleted",
      userId: "u-2"
    });

    expect(
      mapContactRealtimeEvent({
        type: "friend_profile_updated",
        user_id: "u-2",
        nickname: "Alice"
      })
    ).toEqual({
      type: "friend_profile_updated",
      userId: "u-2"
    });
  });

  test("ignores unrelated websocket pushes", () => {
    expect(mapContactRealtimeEvent({ type: "message", room_id: "room-1" })).toBeNull();
    expect(mapContactRealtimeEvent({ type: "friendship_deleted" })).toBeNull();
    expect(mapContactRealtimeEvent(null)).toBeNull();
  });
});
