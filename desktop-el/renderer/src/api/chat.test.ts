import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { ChatApi, mapChatMessagePayload, mapChatRealtimeEvent } from "./chat";

describe("chat api", () => {
  const originalWindow = globalThis.window;
  let calls: Array<{
    method: string;
    params: Record<string, unknown> | undefined;
  }> = [];

  beforeEach(() => {
    calls = [];
  });

  afterEach(() => {
    if (originalWindow) {
      globalThis.window = originalWindow;
      return;
    }
    Reflect.deleteProperty(globalThis, "window");
  });

  test("creates group through go-core rpc and maps created room", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "ok",
              data: {
                room: {
                  id: "room-group-1",
                  name: "项目组",
                  room_type: "group",
                },
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.createGroup({
      name: "项目组",
      memberUserIds: ["u-2", "u-3"],
    });

    expect(calls).toEqual([
      {
        method: "chat.group.create",
        params: {
          name: "项目组",
          member_user_ids: ["u-2", "u-3"],
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        roomId: "room-group-1",
        roomName: "项目组",
        roomType: "group",
      },
    });
  });

  test("loads room detail through go-core rpc and maps room payload", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "ok",
              data: {
                success: true,
                room: {
                  id: "room-group-1",
                  name: "项目组",
                  description: "项目群",
                  avatar_url: null,
                  avatar_object_key: "rooms/project/avatar.png",
                  room_type: "group",
                  owner_id: "u-1",
                  created_at: "2026-03-25T12:00:00Z",
                  updated_at: "2026-03-25T12:30:00Z",
                  deleted_at: null,
                },
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.getRoom({ roomId: "room-group-1" });

    expect(calls).toEqual([
      {
        method: "chat.room.get",
        params: {
          room_id: "room-group-1",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        roomId: "room-group-1",
        roomName: "项目组",
        roomType: "group",
        description: "项目群",
        avatarUrl: null,
        avatarObjectKey: "rooms/project/avatar.png",
        ownerId: "u-1",
        createdAt: new Date("2026-03-25T12:00:00Z"),
        updatedAt: new Date("2026-03-25T12:30:00Z"),
      },
    });
  });

  test("loads room members through go-core rpc and maps member payload", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "ok",
              data: [
                {
                  user_id: "u-1",
                  username: "alice",
                  nickname: "Alice",
                  avatar_url: null,
                  avatar_object_key: "avatars/u-1.png",
                  role: "owner",
                  joined_at: "2026-03-25T12:00:00Z",
                },
                {
                  user_id: "u-2",
                  username: "bob",
                  nickname: "Bob",
                  avatar_url: "https://example.com/bob.png",
                  avatar_object_key: null,
                  role: "member",
                  joined_at: null,
                },
              ],
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.listRoomMembers({ roomId: "room-group-1" });

    expect(calls).toEqual([
      {
        method: "chat.room.members.list",
        params: {
          room_id: "room-group-1",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: [
        {
          userId: "u-1",
          username: "alice",
          nickname: "Alice",
          avatarUrl: null,
          avatarObjectKey: "avatars/u-1.png",
          role: "owner",
          joinedAt: new Date("2026-03-25T12:00:00Z"),
        },
        {
          userId: "u-2",
          username: "bob",
          nickname: "Bob",
          avatarUrl: "https://example.com/bob.png",
          avatarObjectKey: null,
          role: "member",
          joinedAt: null,
        },
      ],
    });
  });

  test("loads group settings through go-core rpc and maps settings payload", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "ok",
              data: {
                settings: {
                  id: "settings-1",
                  room_id: "room-group-1",
                  join_approval_required: true,
                  member_can_invite: false,
                  member_can_add_friends: true,
                  require_admin_to_add_friends: false,
                  max_members: 500,
                  global_mute_enabled: true,
                  global_mute_until: "2026-03-26T12:00:00Z",
                  global_mute_reason: "会议中",
                  global_mute_set_by: "u-1",
                  created_at: "2026-03-25T12:00:00Z",
                  updated_at: "2026-03-25T12:30:00Z",
                },
                my_mute: {
                  is_muted: true,
                  reason: "临时禁言",
                  muted_at: "2026-03-25T12:10:00Z",
                  mute_until: "2026-03-25T13:10:00Z",
                },
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.getGroupSettings({ roomId: "room-group-1" });

    expect(calls).toEqual([
      {
        method: "chat.group.settings.get",
        params: {
          room_id: "room-group-1",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        roomId: "room-group-1",
        joinApprovalRequired: true,
        memberCanInvite: false,
        memberCanAddFriends: true,
        requireAdminToAddFriends: false,
        maxMembers: 500,
        globalMuteEnabled: true,
        globalMuteUntil: new Date("2026-03-26T12:00:00Z"),
        globalMuteReason: "会议中",
        globalMuteSetBy: "u-1",
        createdAt: new Date("2026-03-25T12:00:00Z"),
        updatedAt: new Date("2026-03-25T12:30:00Z"),
        myMute: {
          isMuted: true,
          reason: "临时禁言",
          mutedAt: new Date("2026-03-25T12:10:00Z"),
          muteUntil: new Date("2026-03-25T13:10:00Z"),
        },
      },
    });
  });
});

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
              attachment: null,
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
                height: 200,
              },
            },
          ],
        },
        parts: [
          {
            position: 0,
            part_type: "text",
            text: "reply payload",
            attachment: null,
          },
        ],
      },
      "user-2",
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
          attachment: null,
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
            thumbnailKey: null,
          },
        },
      ],
    });
  });

  test("maps room_created payload into room realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "room_created",
      room_id: "room-group-1",
      room_name: "项目组",
      room_type: "group",
      initiator_id: "u-1",
      owner_id: "u-1",
      description: "项目群",
      avatar_url: "https://example.com/group.png",
      created_at: "2026-03-25T12:00:00Z",
    });

    expect(mapped).toEqual({
      type: "room_created",
      roomId: "room-group-1",
      roomName: "项目组",
      roomType: "group",
      initiatorId: "u-1",
      ownerId: "u-1",
      description: "项目群",
      avatarUrl: "https://example.com/group.png",
      avatarObjectKey: null,
      createdAt: new Date("2026-03-25T12:00:00Z"),
    });
  });

  test("maps room_updated payload into room realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "room_updated",
      room_id: "room-group-1",
      room_name: "项目组-新",
      room_type: "group",
      avatar_url: null,
      avatar_object_key: "rooms/project/new-avatar.png",
      description: "新的群简介",
    });

    expect(mapped).toEqual({
      type: "room_updated",
      roomId: "room-group-1",
      roomName: "项目组-新",
      roomType: "group",
      avatarUrl: null,
      avatarObjectKey: "rooms/project/new-avatar.png",
      description: "新的群简介",
    });
  });

  test("maps group_settings_updated payload into realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "group_settings_updated",
      room_id: "room-group-1",
      global_mute_enabled: true,
      global_mute_reason: "会议中",
      global_mute_until: "2026-03-26T12:00:00Z",
      global_mute_set_by: "u-1",
    });

    expect(mapped).toEqual({
      type: "group_settings_updated",
      roomId: "room-group-1",
      globalMuteEnabled: true,
      globalMuteReason: "会议中",
      globalMuteUntil: new Date("2026-03-26T12:00:00Z"),
      globalMuteSetBy: "u-1",
    });
  });

  test("maps group_member_changed payload into realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "group_member_changed",
      room_id: "room-group-1",
      member_id: "u-2",
      change_type: "muted",
      new_role: null,
      operator_id: "u-1",
      reason: "广告",
      until: "2026-03-25T14:00:00Z",
    });

    expect(mapped).toEqual({
      type: "group_member_changed",
      roomId: "room-group-1",
      memberId: "u-2",
      changeType: "muted",
      newRole: null,
      operatorId: "u-1",
      reason: "广告",
      until: new Date("2026-03-25T14:00:00Z"),
    });
  });
});
