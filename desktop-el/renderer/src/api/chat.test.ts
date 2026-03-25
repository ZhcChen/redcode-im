import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { ChatApi, mapChatMessagePayload, mapChatRealtimeEvent } from "./chat";

class MockXMLHttpRequest {
  static instances: MockXMLHttpRequest[] = [];

  method = "";
  url = "";
  headers: Record<string, string> = {};
  body: BodyInit | null = null;
  status = 200;
  upload = {
    onprogress: null as ((event: ProgressEvent<EventTarget>) => void) | null,
  };
  onerror: (() => void) | null = null;
  onabort: (() => void) | null = null;
  onload: (() => void) | null = null;

  constructor() {
    MockXMLHttpRequest.instances.push(this);
  }

  open(method: string, url: string) {
    this.method = method;
    this.url = url;
  }

  setRequestHeader(headerKey: string, headerValue: string) {
    this.headers[headerKey] = headerValue;
  }

  send(body: BodyInit | null) {
    this.body = body;
    this.onload?.();
  }
}

describe("chat api", () => {
  const originalWindow = globalThis.window;
  const originalXMLHttpRequest = globalThis.XMLHttpRequest;
  let calls: Array<{
    method: string;
    params: Record<string, unknown> | undefined;
  }> = [];

  beforeEach(() => {
    calls = [];
    MockXMLHttpRequest.instances = [];
  });

  afterEach(() => {
    globalThis.XMLHttpRequest = originalXMLHttpRequest;
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

  test("updates group global mute through go-core rpc and maps settings payload", async () => {
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
                  global_mute_until: null,
                  global_mute_reason: null,
                  global_mute_set_by: "u-1",
                  created_at: "2026-03-25T12:00:00Z",
                  updated_at: "2026-03-25T12:45:00Z",
                },
                my_mute: null,
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.updateGroupGlobalMute({
      roomId: "room-group-1",
      enabled: true,
    });

    expect(calls).toEqual([
      {
        method: "chat.group.settings.global_mute.update",
        params: {
          room_id: "room-group-1",
          enabled: true,
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
        globalMuteUntil: null,
        globalMuteReason: null,
        globalMuteSetBy: "u-1",
        createdAt: new Date("2026-03-25T12:00:00Z"),
        updatedAt: new Date("2026-03-25T12:45:00Z"),
        myMute: null,
      },
    });
  });

  test("updates group settings through go-core rpc and maps settings payload", async () => {
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
                  global_mute_until: null,
                  global_mute_reason: null,
                  global_mute_set_by: "u-1",
                  created_at: "2026-03-25T12:00:00Z",
                  updated_at: "2026-03-25T13:10:00Z",
                },
                my_mute: null,
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.updateGroupSettings({
      roomId: "room-group-1",
      joinApprovalRequired: true,
    });

    expect(calls).toEqual([
      {
        method: "chat.group.settings.update",
        params: {
          room_id: "room-group-1",
          join_approval_required: true,
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
        globalMuteUntil: null,
        globalMuteReason: null,
        globalMuteSetBy: "u-1",
        createdAt: new Date("2026-03-25T12:00:00Z"),
        updatedAt: new Date("2026-03-25T13:10:00Z"),
        myMute: null,
      },
    });
  });

  test("updates remaining group settings fields through go-core rpc", async () => {
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
                  member_can_add_friends: false,
                  require_admin_to_add_friends: true,
                  max_members: 256,
                  global_mute_enabled: false,
                  global_mute_until: null,
                  global_mute_reason: null,
                  global_mute_set_by: null,
                  created_at: "2026-03-25T12:00:00Z",
                  updated_at: "2026-03-25T13:20:00Z",
                },
                my_mute: null,
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.updateGroupSettings({
      roomId: "room-group-1",
      memberCanAddFriends: false,
      requireAdminToAddFriends: true,
      maxMembers: 256,
    });

    expect(calls).toEqual([
      {
        method: "chat.group.settings.update",
        params: {
          room_id: "room-group-1",
          member_can_add_friends: false,
          require_admin_to_add_friends: true,
          max_members: 256,
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
        memberCanAddFriends: false,
        requireAdminToAddFriends: true,
        maxMembers: 256,
        globalMuteEnabled: false,
        globalMuteUntil: null,
        globalMuteReason: null,
        globalMuteSetBy: null,
        createdAt: new Date("2026-03-25T12:00:00Z"),
        updatedAt: new Date("2026-03-25T13:20:00Z"),
        myMute: null,
      },
    });
  });

  test("uploads group avatar through direct upload, commits it, and returns avatar url", async () => {
    globalThis.XMLHttpRequest =
      MockXMLHttpRequest as unknown as typeof XMLHttpRequest;
    const file = new File(["group-avatar"], "group-avatar.png", {
      type: "image/png",
    });

    globalThis.window = {
      crypto: {
        subtle: {
          digest: async () => new Uint8Array([0, 1, 255]).buffer,
        },
      },
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            const path = params?.path;

            if (
              method === "http.request" &&
              path === "/rooms/room-group-1/avatar/direct-upload"
            ) {
              return {
                code: 200,
                success: true,
                message: "ok",
                data: {
                  success: true,
                  message: "signature ready",
                  key: "room_avatars/room-group-1/avatar.png",
                  signature: {
                    url: "https://upload.example.com/group-avatar",
                    method: "PUT",
                    headers: {
                      Authorization: "signed-token",
                      Host: "upload.example.com",
                    },
                    key: "room_avatars/room-group-1/avatar.png",
                  },
                },
              };
            }

            if (
              method === "http.request" &&
              path === "/rooms/room-group-1/avatar/commit"
            ) {
              return {
                code: 200,
                success: true,
                message: "ok",
                data: {
                  success: true,
                  message: "avatar committed",
                  avatar_url: "https://static.example.com/group-avatar.png",
                },
              };
            }

            throw new Error(`unexpected rpc call: ${method} ${path ?? ""}`);
          },
        },
      },
    } as unknown as Window;

    const response = await ChatApi.uploadGroupAvatar({
      roomId: "room-group-1",
      file,
    });

    expect(calls).toEqual([
      {
        method: "http.request",
        params: {
          method: "POST",
          path: "/rooms/room-group-1/avatar/direct-upload",
          headers: undefined,
          body: {
            content_type: "image/png",
            filename: "group-avatar.png",
            file_size: file.size,
            hash_value: "0001ff",
            hash_alg: 2,
          },
          query_params: undefined,
          inject_token: undefined,
        },
      },
      {
        method: "http.request",
        params: {
          method: "POST",
          path: "/rooms/room-group-1/avatar/commit",
          headers: undefined,
          body: {
            key: "room_avatars/room-group-1/avatar.png",
          },
          query_params: undefined,
          inject_token: undefined,
        },
      },
    ]);
    expect(MockXMLHttpRequest.instances).toHaveLength(1);
    expect(MockXMLHttpRequest.instances[0]).toMatchObject({
      method: "PUT",
      url: "https://upload.example.com/group-avatar",
      headers: {
        Authorization: "signed-token",
        "Content-Type": "image/png",
      },
      body: file,
    });
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "avatar committed",
      data: {
        avatarUrl: "https://static.example.com/group-avatar.png",
      },
    });
  });

  test("adds group members through go-core rpc and maps result", async () => {
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
                added_user_ids: ["u-2"],
                skipped_user_ids: ["u-3"],
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.addGroupMembers({
      roomId: "room-group-1",
      userIds: ["u-2", "u-3"],
    });

    expect(calls).toEqual([
      {
        method: "chat.room.members.add",
        params: {
          room_id: "room-group-1",
          user_ids: ["u-2", "u-3"],
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        success: true,
        addedUserIds: ["u-2"],
        skippedUserIds: ["u-3"],
      },
    });
  });

  test("removes group member through go-core rpc and maps result", async () => {
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
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.removeGroupMember({
      roomId: "room-group-1",
      userId: "u-2",
    });

    expect(calls).toEqual([
      {
        method: "chat.room.member.remove",
        params: {
          room_id: "room-group-1",
          user_id: "u-2",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        success: true,
      },
    });
  });

  test("loads group admins through go-core rpc and maps admin payload", async () => {
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
                admins: [
                  {
                    id: "group-admin-1",
                    room_id: "room-group-1",
                    admin_id: "u-2",
                    appointed_by: "u-1",
                    role: "admin",
                    permissions: ["invite_member"],
                    appointed_at: "2026-03-25T13:30:00Z",
                  },
                ],
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.listGroupAdmins({
      roomId: "room-group-1",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.admins.list",
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
          id: "group-admin-1",
          roomId: "room-group-1",
          adminId: "u-2",
          appointedBy: "u-1",
          role: "admin",
          permissions: ["invite_member"],
          appointedAt: new Date("2026-03-25T13:30:00Z"),
        },
      ],
    });
  });

  test("appoints group admin through go-core rpc and maps admin payload", async () => {
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
                admin: {
                  id: "group-admin-1",
                  room_id: "room-group-1",
                  admin_id: "u-2",
                  appointed_by: "u-1",
                  role: "admin",
                  permissions: ["invite_member"],
                  appointed_at: "2026-03-25T13:30:00Z",
                },
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.appointGroupAdmin({
      roomId: "room-group-1",
      userId: "u-2",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.admin.appoint",
        params: {
          room_id: "room-group-1",
          user_id: "u-2",
          role: "admin",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        id: "group-admin-1",
        roomId: "room-group-1",
        adminId: "u-2",
        appointedBy: "u-1",
        role: "admin",
        permissions: ["invite_member"],
        appointedAt: new Date("2026-03-25T13:30:00Z"),
      },
    });
  });

  test("removes group admin through go-core rpc and maps success result", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 204,
              success: true,
              message: "No Content",
              data: null,
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.removeGroupAdmin({
      roomId: "room-group-1",
      adminId: "u-2",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.admin.remove",
        params: {
          room_id: "room-group-1",
          admin_id: "u-2",
        },
      },
    ]);
    expect(response).toEqual({
      code: 204,
      success: true,
      message: "No Content",
      data: {
        success: true,
        message: "No Content",
      },
    });
  });

  test("loads group join requests through go-core rpc and maps payload", async () => {
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
                requests: [
                  {
                    id: "join-request-1",
                    room_id: "room-group-1",
                    applicant_id: "u-9",
                    message: "想加入项目群",
                    status: 0,
                    reviewer_id: null,
                    review_message: null,
                    created_at: "2026-03-25T14:00:00Z",
                    reviewed_at: null,
                  },
                  {
                    id: "join-request-2",
                    room_id: "room-group-1",
                    applicant_id: "u-8",
                    message: null,
                    status: 1,
                    reviewer_id: "u-1",
                    review_message: "欢迎加入",
                    created_at: "2026-03-25T13:00:00Z",
                    reviewed_at: "2026-03-25T13:10:00Z",
                  },
                ],
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.listGroupJoinRequests({
      roomId: "room-group-1",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.join_requests.list",
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
          id: "join-request-1",
          roomId: "room-group-1",
          applicantId: "u-9",
          message: "想加入项目群",
          status: "pending",
          reviewerId: null,
          reviewMessage: null,
          createdAt: new Date("2026-03-25T14:00:00Z"),
          reviewedAt: null,
        },
        {
          id: "join-request-2",
          roomId: "room-group-1",
          applicantId: "u-8",
          message: null,
          status: "approved",
          reviewerId: "u-1",
          reviewMessage: "欢迎加入",
          createdAt: new Date("2026-03-25T13:00:00Z"),
          reviewedAt: new Date("2026-03-25T13:10:00Z"),
        },
      ],
    });
  });

  test("reviews group join request through go-core rpc and maps payload", async () => {
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
                request: {
                  id: "join-request-1",
                  room_id: "room-group-1",
                  applicant_id: "u-9",
                  message: "想加入项目群",
                  status: 2,
                  reviewer_id: "u-1",
                  review_message: "暂不符合要求",
                  created_at: "2026-03-25T14:00:00Z",
                  reviewed_at: "2026-03-25T14:05:00Z",
                },
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.reviewGroupJoinRequest({
      roomId: "room-group-1",
      requestId: "join-request-1",
      status: "rejected",
      reviewMessage: "暂不符合要求",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.join_request.review",
        params: {
          room_id: "room-group-1",
          request_id: "join-request-1",
          status: "rejected",
          review_message: "暂不符合要求",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        id: "join-request-1",
        roomId: "room-group-1",
        applicantId: "u-9",
        message: "想加入项目群",
        status: "rejected",
        reviewerId: "u-1",
        reviewMessage: "暂不符合要求",
        createdAt: new Date("2026-03-25T14:00:00Z"),
        reviewedAt: new Date("2026-03-25T14:05:00Z"),
      },
    });
  });

  test("loads group mutes through go-core rpc and maps payload", async () => {
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
                mutes: [
                  {
                    id: "group-mute-1",
                    room_id: "room-group-1",
                    user_id: "u-9",
                    muted_by: "u-1",
                    reason: "刷屏",
                    mute_duration_hours: 24,
                    muted_at: "2026-03-25T14:00:00Z",
                    unmuted_at: null,
                    is_active: true,
                  },
                  {
                    id: "group-mute-2",
                    room_id: "room-group-1",
                    user_id: "u-8",
                    muted_by: "u-1",
                    reason: null,
                    mute_duration_hours: 0,
                    muted_at: "2026-03-25T13:00:00Z",
                    unmuted_at: null,
                    is_active: true,
                  },
                ],
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.listGroupMutes({
      roomId: "room-group-1",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.mutes.list",
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
          id: "group-mute-1",
          roomId: "room-group-1",
          userId: "u-9",
          mutedBy: "u-1",
          reason: "刷屏",
          muteDurationHours: 24,
          mutedAt: new Date("2026-03-25T14:00:00Z"),
          unmutedAt: null,
          isActive: true,
          muteUntil: new Date("2026-03-26T14:00:00Z"),
        },
        {
          id: "group-mute-2",
          roomId: "room-group-1",
          userId: "u-8",
          mutedBy: "u-1",
          reason: null,
          muteDurationHours: 0,
          mutedAt: new Date("2026-03-25T13:00:00Z"),
          unmutedAt: null,
          isActive: true,
          muteUntil: null,
        },
      ],
    });
  });

  test("creates group mute through go-core rpc and maps payload", async () => {
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
                mute: {
                  id: "group-mute-1",
                  room_id: "room-group-1",
                  user_id: "u-9",
                  muted_by: "u-1",
                  reason: "刷屏",
                  mute_duration_hours: 24,
                  muted_at: "2026-03-25T14:00:00Z",
                  unmuted_at: null,
                  is_active: true,
                },
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.muteGroupMember({
      roomId: "room-group-1",
      userId: "u-9",
      durationHours: 24,
      reason: "刷屏",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.mute.create",
        params: {
          room_id: "room-group-1",
          user_id: "u-9",
          duration_hours: 24,
          reason: "刷屏",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        id: "group-mute-1",
        roomId: "room-group-1",
        userId: "u-9",
        mutedBy: "u-1",
        reason: "刷屏",
        muteDurationHours: 24,
        mutedAt: new Date("2026-03-25T14:00:00Z"),
        unmutedAt: null,
        isActive: true,
        muteUntil: new Date("2026-03-26T14:00:00Z"),
      },
    });
  });

  test("removes group mute through go-core rpc and maps success result", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 204,
              success: true,
              message: "No Content",
              data: null,
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.unmuteGroupMember({
      roomId: "room-group-1",
      userId: "u-9",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.mute.remove",
        params: {
          room_id: "room-group-1",
          user_id: "u-9",
        },
      },
    ]);
    expect(response).toEqual({
      code: 204,
      success: true,
      message: "No Content",
      data: {
        success: true,
        message: "No Content",
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
