import { describe, expect, test } from "bun:test";
import { buildDefaultFriendRequestMessage, resolveRelationshipState } from "./contact-discovery";

describe("contact discovery helpers", () => {
  test("resolves self, friend, pending and addable states", () => {
    expect(
      resolveRelationshipState({
        candidateId: "u-1",
        currentUserId: "u-1",
        friendUserIds: ["u-2"],
        pendingTargetUserIds: ["u-3"]
      })
    ).toBe("self");

    expect(
      resolveRelationshipState({
        candidateId: "u-2",
        currentUserId: "u-1",
        friendUserIds: ["u-2"],
        pendingTargetUserIds: ["u-3"]
      })
    ).toBe("friend");

    expect(
      resolveRelationshipState({
        candidateId: "u-3",
        currentUserId: "u-1",
        friendUserIds: ["u-2"],
        pendingTargetUserIds: ["u-3"]
      })
    ).toBe("pending");

    expect(
      resolveRelationshipState({
        candidateId: "u-4",
        currentUserId: "u-1",
        friendUserIds: ["u-2"],
        pendingTargetUserIds: ["u-3"]
      })
    ).toBe("addable");
  });

  test("builds default friend request message from nickname or username", () => {
    expect(
      buildDefaultFriendRequestMessage({
        username: "alice",
        nickname: "Alice"
      })
    ).toBe("我是Alice");

    expect(
      buildDefaultFriendRequestMessage({
        username: "alice",
        nickname: null
      })
    ).toBe("我是alice");

    expect(buildDefaultFriendRequestMessage(null)).toBe("你好，很高兴认识你");
  });
});
