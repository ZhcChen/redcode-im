import { describe, expect, test } from "bun:test";
import {
  filterGroupMembers,
  sortGroupMembers,
  summarizeGroupMembers,
  type GroupMemberListItem,
} from "./chat-group-members";

const members: GroupMemberListItem[] = [
  {
    userId: "u-3",
    username: "charlie",
    displayName: "Charlie",
    role: "member",
    joinedAt: new Date("2026-03-25T12:30:00Z"),
  },
  {
    userId: "u-2",
    username: "bravo",
    displayName: "Bravo",
    role: "admin",
    joinedAt: new Date("2026-03-25T12:10:00Z"),
  },
  {
    userId: "u-1",
    username: "alpha",
    displayName: "Alpha",
    role: "owner",
    joinedAt: new Date("2026-03-25T12:00:00Z"),
  },
  {
    userId: "u-4",
    username: "delta",
    displayName: "Delta",
    role: "member",
    joinedAt: null,
  },
];

describe("chat group members helpers", () => {
  test("sorts group members by role first and then display name", () => {
    expect(sortGroupMembers(members).map((member) => member.userId)).toEqual([
      "u-1",
      "u-2",
      "u-3",
      "u-4",
    ]);
  });

  test("filters group members by display name, username and role label", () => {
    expect(
      filterGroupMembers(sortGroupMembers(members), "brav").map(
        (member) => member.userId,
      ),
    ).toEqual(["u-2"]);

    expect(
      filterGroupMembers(sortGroupMembers(members), "成员").map(
        (member) => member.userId,
      ),
    ).toEqual(["u-3", "u-4"]);
  });

  test("summarizes member counts by role", () => {
    expect(summarizeGroupMembers(members)).toEqual({
      total: 4,
      ownerCount: 1,
      adminCount: 1,
      memberCount: 2,
    });
  });
});
