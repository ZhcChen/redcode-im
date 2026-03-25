import { describe, expect, test } from "bun:test";
import {
  findCreatedGroupChat,
  validateGroupCreatePayload,
} from "./chat-group-create";

describe("chat group create helpers", () => {
  test("rejects empty group name", () => {
    expect(
      validateGroupCreatePayload({
        name: "   ",
        memberUserIds: ["u-2"],
      }),
    ).toBe("请输入群聊名称");
  });

  test("rejects group name longer than 20 characters", () => {
    expect(
      validateGroupCreatePayload({
        name: "123456789012345678901",
        memberUserIds: ["u-2"],
      }),
    ).toBe("群聊名称不能超过 20 个字符");
  });

  test("rejects creating group without members", () => {
    expect(
      validateGroupCreatePayload({
        name: "项目组",
        memberUserIds: [],
      }),
    ).toBe("请至少选择一位好友");
  });

  test("returns null for valid payload", () => {
    expect(
      validateGroupCreatePayload({
        name: "项目组",
        memberUserIds: ["u-2", "u-3"],
      }),
    ).toBeNull();
  });

  test("finds created group by room id first", () => {
    const matched = findCreatedGroupChat(
      [
        {
          id: "room-1",
          roomId: "room-1",
          title: "旧会话",
        },
        {
          id: "room-group-1",
          roomId: "room-group-1",
          title: "项目组",
        },
      ],
      {
        roomId: "room-group-1",
        roomName: "项目组",
      },
    );

    expect(matched).toEqual({
      id: "room-group-1",
      roomId: "room-group-1",
      title: "项目组",
    });
  });

  test("falls back to room name when room id is not found", () => {
    const matched = findCreatedGroupChat(
      [
        {
          id: "room-3",
          roomId: "room-3",
          title: "项目组",
        },
      ],
      {
        roomId: "room-group-missing",
        roomName: "项目组",
      },
    );

    expect(matched).toEqual({
      id: "room-3",
      roomId: "room-3",
      title: "项目组",
    });
  });
});
