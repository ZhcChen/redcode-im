import { describe, expect, test } from "bun:test";
import type { ChatRealtimeEvent } from "@/api/chat";
import { getGroupRealtimePlan } from "./chat-group-realtime";

describe("chat group realtime helpers", () => {
  test("reloads active group settings after settings update", () => {
    const event: ChatRealtimeEvent = {
      type: "group_settings_updated",
      roomId: "room-group-1",
      globalMuteEnabled: true,
      globalMuteReason: "会议中",
      globalMuteUntil: new Date("2026-03-26T12:00:00Z"),
      globalMuteSetBy: "u-1",
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: false,
      shouldReloadGroupSettings: true,
      notice: null,
    });
  });

  test("reloads active group context and shows mute notice for current user", () => {
    const event: ChatRealtimeEvent = {
      type: "group_member_changed",
      roomId: "room-group-1",
      memberId: "u-2",
      changeType: "muted",
      newRole: null,
      operatorId: "u-1",
      reason: "刷屏",
      until: new Date("2026-03-25T13:10:00Z"),
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: true,
      shouldReloadGroupSettings: true,
      notice: "你已在当前群被禁言",
    });
  });

  test("reloads chats but skips active panel refresh for inactive groups", () => {
    const event: ChatRealtimeEvent = {
      type: "group_member_changed",
      roomId: "room-group-2",
      memberId: "u-3",
      changeType: "joined",
      newRole: "member",
      operatorId: "u-1",
      reason: null,
      until: null,
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: false,
      shouldReloadGroupSettings: false,
      notice: null,
    });
  });

  test("shows unmute notice when current user is restored in active group", () => {
    const event: ChatRealtimeEvent = {
      type: "group_member_changed",
      roomId: "room-group-1",
      memberId: "u-2",
      changeType: "unmuted",
      newRole: null,
      operatorId: "u-1",
      reason: null,
      until: null,
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: true,
      shouldReloadGroupSettings: true,
      notice: "你已在当前群解除禁言",
    });
  });

  test("shows admin promote notice when current user role changes in active group", () => {
    const event: ChatRealtimeEvent = {
      type: "group_member_changed",
      roomId: "room-group-1",
      memberId: "u-2",
      changeType: "role_changed",
      newRole: "admin",
      operatorId: "u-1",
      reason: null,
      until: null,
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: true,
      shouldReloadGroupSettings: true,
      notice: "你已成为当前群管理员",
    });
  });

  test("shows admin demote notice when current user loses admin role in active group", () => {
    const event: ChatRealtimeEvent = {
      type: "group_member_changed",
      roomId: "room-group-1",
      memberId: "u-2",
      changeType: "role_changed",
      newRole: "member",
      operatorId: "u-1",
      reason: null,
      until: null,
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: true,
      shouldReloadGroupSettings: true,
      notice: "你已不再是当前群管理员",
    });
  });

  test("reloads chats and shows dissolve notice for active group", () => {
    const event: ChatRealtimeEvent = {
      type: "group_dissolved",
      roomId: "room-group-1",
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: false,
      shouldReloadGroupSettings: false,
      notice: "当前群聊已解散",
    });
  });

  test("reloads active group data and shows notice when current user becomes owner", () => {
    const event: ChatRealtimeEvent = {
      type: "group_owner_transferred",
      roomId: "room-group-1",
      oldOwnerId: "u-9",
      newOwnerId: "u-2",
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: true,
      shouldReloadGroupSettings: true,
      notice: "你已成为当前群的新群主",
    });
  });

  test("reloads active group data and shows notice when current user is no longer owner", () => {
    const event: ChatRealtimeEvent = {
      type: "group_owner_transferred",
      roomId: "room-group-1",
      oldOwnerId: "u-2",
      newOwnerId: "u-9",
    };

    expect(
      getGroupRealtimePlan({
        event,
        activeRoomId: "room-group-1",
        currentUserId: "u-2",
      }),
    ).toEqual({
      shouldReloadChats: true,
      shouldReloadGroupContext: true,
      shouldReloadGroupSettings: true,
      notice: "当前群群主已转让给其他成员",
    });
  });
});
