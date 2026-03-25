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

  test("leaves group through go-core rpc and maps success payload", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "已退出群聊",
              data: {
                ok: true,
              },
            };
          },
        },
      },
    } as Window;

    const leaveGroup = (
      ChatApi as unknown as {
        leaveGroup?: (params: { roomId: string }) => Promise<unknown>;
      }
    ).leaveGroup;

    expect(typeof leaveGroup).toBe("function");
    if (!leaveGroup) {
      return;
    }

    const response = (await leaveGroup({
      roomId: "room-group-1",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.group.leave",
        params: {
          room_id: "room-group-1",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "已退出群聊",
      data: {
        success: true,
        message: "已退出群聊",
      },
    });
  });

  test("dissolves group through go-core rpc and maps success payload", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "群聊已解散",
              data: {
                success: true,
              },
            };
          },
        },
      },
    } as Window;

    const dissolveGroup = (
      ChatApi as unknown as {
        dissolveGroup?: (params: { roomId: string }) => Promise<unknown>;
      }
    ).dissolveGroup;

    expect(typeof dissolveGroup).toBe("function");
    if (!dissolveGroup) {
      return;
    }

    const response = (await dissolveGroup({
      roomId: "room-group-1",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.group.dissolve",
        params: {
          room_id: "room-group-1",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "群聊已解散",
      data: {
        success: true,
        message: "群聊已解散",
      },
    });
  });

  test("forwards message through go-core rpc and maps forwarded payload", async () => {
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
                message: {
                  id: "msg-forward-1",
                  room_id: "room-target-1",
                  sender_id: "u-1",
                  sender_username: "alice",
                  sender_nickname: "Alice",
                  content: "转发后的消息",
                  message_type: "text",
                  status: "sent",
                  created_at: "2026-03-25T18:00:00Z",
                  forward_message: {
                    message_id: "msg-origin-1",
                    room_id: "room-origin-1",
                    sender_id: "u-9",
                    sender_username: "bob",
                    sender_nickname: "Bob",
                    source_type: "group",
                    source_id: "room-origin-1",
                    source_name: "产品群",
                    source_avatar: "https://example.com/group.png",
                  },
                },
              },
            };
          },
        },
      },
    } as Window;

    const forwardMessage = (
      ChatApi as unknown as {
        forwardMessage?: (params: {
          roomId: string;
          originalMessageId: string;
          currentUserId?: string;
        }) => Promise<unknown>;
      }
    ).forwardMessage;

    expect(typeof forwardMessage).toBe("function");
    if (!forwardMessage) {
      return;
    }

    const response = (await forwardMessage({
      roomId: "room-target-1",
      originalMessageId: "msg-origin-1",
      currentUserId: "u-1",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.forward",
        params: {
          room_id: "room-target-1",
          original_message_id: "msg-origin-1",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        id: "msg-forward-1",
        roomId: "room-target-1",
        senderId: "u-1",
        senderUsername: "alice",
        senderName: "Alice",
        senderAvatarUrl: null,
        content: "转发后的消息",
        preview: "转发后的消息",
        messageType: "text",
        deliveryStatus: "sent",
        createdAt: new Date("2026-03-25T18:00:00Z"),
        isDeleted: false,
        isEdited: false,
        isSelf: true,
        pinnedAt: null,
        pinnedBy: null,
        forwardInfo: {
          sourceType: "group",
          sourceId: "room-origin-1",
          sourceName: "产品群",
          sourceAvatar: "https://example.com/group.png",
          originMessageId: "msg-origin-1",
          originRoomId: "room-origin-1",
          originSenderId: "u-9",
          originSenderName: "Bob",
        },
        quotedMessage: null,
        parts: [],
        clientStatus: null,
        retryPayload: null,
        errorMessage: null,
      },
    });
  });

  test("pins message through go-core rpc and maps pinned payload", async () => {
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
                room_id: "room-1",
                is_pinned: true,
                message: {
                  id: "msg-15",
                  room_id: "room-1",
                  sender_id: "u-1",
                  sender_username: "alice",
                  sender_nickname: "Alice",
                  content: "要置顶的消息",
                  message_type: "text",
                  status: "sent",
                  created_at: "2026-03-25T19:00:00Z",
                  is_pinned: true,
                  pinned_at: "2026-03-25T19:05:00Z",
                  pinned_by: "u-9",
                },
                pinned_at: "2026-03-25T19:05:00Z",
                pinned_by: "u-9",
              },
            };
          },
        },
      },
    } as Window;

    const pinMessage = (
      ChatApi as unknown as {
        pinMessage?: (params: {
          roomId: string;
          messageId: string;
          currentUserId?: string;
        }) => Promise<unknown>;
      }
    ).pinMessage;

    expect(typeof pinMessage).toBe("function");
    if (!pinMessage) {
      return;
    }

    const response = (await pinMessage({
      roomId: "room-1",
      messageId: "msg-15",
      currentUserId: "u-1",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.pin",
        params: {
          room_id: "room-1",
          message_id: "msg-15",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        message: {
          id: "msg-15",
          roomId: "room-1",
          senderId: "u-1",
          senderUsername: "alice",
          senderName: "Alice",
          senderAvatarUrl: null,
          content: "要置顶的消息",
          preview: "要置顶的消息",
          messageType: "text",
          deliveryStatus: "sent",
          createdAt: new Date("2026-03-25T19:00:00Z"),
          isDeleted: false,
          isEdited: false,
          isSelf: true,
          pinnedAt: new Date("2026-03-25T19:05:00Z"),
          pinnedBy: "u-9",
          forwardInfo: null,
          quotedMessage: null,
          parts: [],
          clientStatus: null,
          retryPayload: null,
          errorMessage: null,
        },
        isPinned: true,
        pinnedAt: new Date("2026-03-25T19:05:00Z"),
        pinnedBy: "u-9",
      },
    });
  });

  test("unpines message through go-core rpc and maps result", async () => {
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
                room_id: "room-1",
                is_pinned: false,
                message: null,
                pinned_at: null,
                pinned_by: null,
              },
            };
          },
        },
      },
    } as Window;

    const unpinMessage = (
      ChatApi as unknown as {
        unpinMessage?: (params: {
          roomId: string;
          messageId: string;
        }) => Promise<unknown>;
      }
    ).unpinMessage;

    expect(typeof unpinMessage).toBe("function");
    if (!unpinMessage) {
      return;
    }

    const response = (await unpinMessage({
      roomId: "room-1",
      messageId: "msg-15",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.unpin",
        params: {
          room_id: "room-1",
          message_id: "msg-15",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        message: null,
        isPinned: false,
        pinnedAt: null,
        pinnedBy: null,
      },
    });
  });

  test("loads message readers through go-core rpc and maps reader payload", async () => {
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
                  user_id: "u-8",
                  username: "bob",
                  nickname: "Bob",
                  avatar_url: "https://example.com/avatar-bob.png",
                  read_at: "2026-03-25T19:06:00Z",
                },
                {
                  user_id: "u-9",
                  username: "carol",
                  nickname: null,
                  avatar_url: null,
                  read_at: "2026-03-25T19:07:00Z",
                },
              ],
            };
          },
        },
      },
    } as Window;

    const getMessageReaders = (
      ChatApi as unknown as {
        getMessageReaders?: (params: {
          roomId: string;
          messageId: string;
        }) => Promise<unknown>;
      }
    ).getMessageReaders;

    expect(typeof getMessageReaders).toBe("function");
    if (!getMessageReaders) {
      return;
    }

    const response = (await getMessageReaders({
      roomId: "room-2",
      messageId: "msg-15",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.message.readers.list",
        params: {
          room_id: "room-2",
          message_id: "msg-15",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: [
        {
          userId: "u-8",
          username: "bob",
          nickname: "Bob",
          avatarUrl: "https://example.com/avatar-bob.png",
          readAt: new Date("2026-03-25T19:06:00Z"),
        },
        {
          userId: "u-9",
          username: "carol",
          nickname: null,
          avatarUrl: null,
          readAt: new Date("2026-03-25T19:07:00Z"),
        },
      ],
    });
  });

  test("sends typing state through go-core rpc", async () => {
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

    const sendTyping = (
      ChatApi as unknown as {
        sendTyping?: (params: {
          roomId: string;
          isTyping: boolean;
        }) => Promise<unknown>;
      }
    ).sendTyping;

    expect(typeof sendTyping).toBe("function");
    if (!sendTyping) {
      return;
    }

    const response = (await sendTyping({
      roomId: "room-2",
      isTyping: true,
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.typing.send",
        params: {
          room_id: "room-2",
          is_typing: true,
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: null,
    });
  });

  test("adds reaction through go-core rpc and maps summaries", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "反应已添加",
              data: {
                success: true,
                message: "反应已添加",
                summaries: [
                  {
                    reaction_key: "👍",
                    count: 2,
                    user_ids: ["u-1", "u-2"],
                    has_self: true,
                  },
                ],
              },
            };
          },
        },
      },
    } as Window;

    const addReaction = (
      ChatApi as unknown as {
        addReaction?: (params: {
          roomId: string;
          messageId: string;
          reactionKey: string;
        }) => Promise<unknown>;
      }
    ).addReaction;

    expect(typeof addReaction).toBe("function");
    if (!addReaction) {
      return;
    }

    const response = (await addReaction({
      roomId: "room-1",
      messageId: "msg-15",
      reactionKey: "👍",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.reactions.add",
        params: {
          room_id: "room-1",
          message_id: "msg-15",
          reaction_key: "👍",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "反应已添加",
      data: {
        summaries: [
          {
            reactionKey: "👍",
            count: 2,
            userIds: ["u-1", "u-2"],
            hasSelf: true,
          },
        ],
      },
    });
  });

  test("edits message through go-core rpc and maps edited payload", async () => {
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
                id: "msg-15",
                room_id: "room-1",
                sender_id: "u-1",
                sender_username: "alice",
                sender_nickname: "Alice",
                content: "编辑后的消息",
                message_type: "text",
                status: "sent",
                created_at: "2026-03-25T19:00:00Z",
                is_edited: true,
                edited_at: "2026-03-25T19:06:00Z",
                parts: [],
              },
            };
          },
        },
      },
    } as Window;

    const editMessage = (
      ChatApi as unknown as {
        editMessage?: (params: {
          roomId: string;
          messageId: string;
          content: string;
          currentUserId?: string;
        }) => Promise<unknown>;
      }
    ).editMessage;

    expect(typeof editMessage).toBe("function");
    if (!editMessage) {
      return;
    }

    const response = (await editMessage({
      roomId: "room-1",
      messageId: "msg-15",
      content: "编辑后的消息",
      currentUserId: "u-1",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.edit",
        params: {
          room_id: "room-1",
          message_id: "msg-15",
          content: "编辑后的消息",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        id: "msg-15",
        roomId: "room-1",
        senderId: "u-1",
        senderUsername: "alice",
        senderName: "Alice",
        senderAvatarUrl: null,
        content: "编辑后的消息",
        preview: "编辑后的消息",
        messageType: "text",
        deliveryStatus: "sent",
        createdAt: new Date("2026-03-25T19:00:00Z"),
        isDeleted: false,
        isEdited: true,
        isSelf: true,
        pinnedAt: null,
        pinnedBy: null,
        forwardInfo: null,
        quotedMessage: null,
        parts: [],
        clientStatus: null,
        retryPayload: null,
        errorMessage: null,
      },
    });
  });

  test("removes reaction through go-core rpc and maps summaries", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "反应已删除",
              data: {
                success: true,
                message: "反应已删除",
                summaries: [
                  {
                    reaction_key: "👍",
                    count: 1,
                    user_ids: ["u-2"],
                    has_self: false,
                  },
                ],
              },
            };
          },
        },
      },
    } as Window;

    const removeReaction = (
      ChatApi as unknown as {
        removeReaction?: (params: {
          roomId: string;
          messageId: string;
          reactionKey: string;
        }) => Promise<unknown>;
      }
    ).removeReaction;

    expect(typeof removeReaction).toBe("function");
    if (!removeReaction) {
      return;
    }

    const response = (await removeReaction({
      roomId: "room-1",
      messageId: "msg-15",
      reactionKey: "👍",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.reactions.remove",
        params: {
          room_id: "room-1",
          message_id: "msg-15",
          reaction_key: "👍",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "反应已删除",
      data: {
        summaries: [
          {
            reactionKey: "👍",
            count: 1,
            userIds: ["u-2"],
            hasSelf: false,
          },
        ],
      },
    });
  });

  test("loads reactions through go-core rpc and maps summaries", async () => {
    globalThis.window = {
      desktopEl: {
        rpc: {
          invoke: async (method: string, params?: Record<string, unknown>) => {
            calls.push({ method, params });
            return {
              code: 200,
              success: true,
              message: "获取成功",
              data: {
                success: true,
                message: "获取成功",
                summaries: [
                  {
                    reaction_key: "🎉",
                    count: 3,
                    user_ids: ["u-1", "u-2", "u-3"],
                    has_self: true,
                  },
                ],
              },
            };
          },
        },
      },
    } as Window;

    const getReactions = (
      ChatApi as unknown as {
        getReactions?: (params: {
          roomId: string;
          messageId: string;
        }) => Promise<unknown>;
      }
    ).getReactions;

    expect(typeof getReactions).toBe("function");
    if (!getReactions) {
      return;
    }

    const response = (await getReactions({
      roomId: "room-1",
      messageId: "msg-15",
    })) as Record<string, unknown>;

    expect(calls).toEqual([
      {
        method: "chat.reactions.list",
        params: {
          room_id: "room-1",
          message_id: "msg-15",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "获取成功",
      data: {
        summaries: [
          {
            reactionKey: "🎉",
            count: 3,
            userIds: ["u-1", "u-2", "u-3"],
            hasSelf: true,
          },
        ],
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

  test("transfers group owner through go-core rpc and maps payload", async () => {
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
                room_id: "room-group-1",
                owner_id: "u-2",
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.transferGroupOwner({
      roomId: "room-group-1",
      newOwnerId: "u-2",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.owner.transfer",
        params: {
          room_id: "room-group-1",
          new_owner_id: "u-2",
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        roomId: "room-group-1",
        ownerId: "u-2",
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

  test("loads group rules through go-core rpc and maps payload", async () => {
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
                rules: [
                  {
                    id: "group-rule-1",
                    room_id: "room-group-1",
                    title: "文明发言",
                    content: "禁止刷屏和辱骂",
                    creator_id: "u-1",
                    order_index: 0,
                    is_active: true,
                    created_at: "2026-03-25T15:00:00Z",
                    updated_at: "2026-03-25T15:00:00Z",
                  },
                  {
                    id: "group-rule-2",
                    room_id: "room-group-1",
                    title: "资料安全",
                    content: "禁止泄露项目信息",
                    creator_id: "u-2",
                    order_index: 1,
                    is_active: true,
                    created_at: "2026-03-25T15:10:00Z",
                    updated_at: "2026-03-25T15:20:00Z",
                  },
                ],
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.listGroupRules({
      roomId: "room-group-1",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.rules.list",
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
          id: "group-rule-1",
          roomId: "room-group-1",
          title: "文明发言",
          content: "禁止刷屏和辱骂",
          creatorId: "u-1",
          orderIndex: 0,
          isActive: true,
          createdAt: new Date("2026-03-25T15:00:00Z"),
          updatedAt: new Date("2026-03-25T15:00:00Z"),
        },
        {
          id: "group-rule-2",
          roomId: "room-group-1",
          title: "资料安全",
          content: "禁止泄露项目信息",
          creatorId: "u-2",
          orderIndex: 1,
          isActive: true,
          createdAt: new Date("2026-03-25T15:10:00Z"),
          updatedAt: new Date("2026-03-25T15:20:00Z"),
        },
      ],
    });
  });

  test("creates group rule through go-core rpc and maps payload", async () => {
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
                rule: {
                  id: "group-rule-1",
                  room_id: "room-group-1",
                  title: "文明发言",
                  content: "禁止刷屏和辱骂",
                  creator_id: "u-1",
                  order_index: 0,
                  is_active: true,
                  created_at: "2026-03-25T15:00:00Z",
                  updated_at: "2026-03-25T15:00:00Z",
                },
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.createGroupRule({
      roomId: "room-group-1",
      title: "文明发言",
      content: "禁止刷屏和辱骂",
      orderIndex: 0,
    });

    expect(calls).toEqual([
      {
        method: "chat.group.rule.create",
        params: {
          room_id: "room-group-1",
          title: "文明发言",
          content: "禁止刷屏和辱骂",
          order_index: 0,
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        id: "group-rule-1",
        roomId: "room-group-1",
        title: "文明发言",
        content: "禁止刷屏和辱骂",
        creatorId: "u-1",
        orderIndex: 0,
        isActive: true,
        createdAt: new Date("2026-03-25T15:00:00Z"),
        updatedAt: new Date("2026-03-25T15:00:00Z"),
      },
    });
  });

  test("updates group rule through go-core rpc and maps payload", async () => {
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
                rule: {
                  id: "group-rule-1",
                  room_id: "room-group-1",
                  title: "文明发言 2.0",
                  content: "禁止刷屏、辱骂和广告",
                  creator_id: "u-1",
                  order_index: 0,
                  is_active: true,
                  created_at: "2026-03-25T15:00:00Z",
                  updated_at: "2026-03-25T16:00:00Z",
                },
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.updateGroupRule({
      roomId: "room-group-1",
      ruleId: "group-rule-1",
      title: "文明发言 2.0",
      content: "禁止刷屏、辱骂和广告",
      isActive: true,
    });

    expect(calls).toEqual([
      {
        method: "chat.group.rule.update",
        params: {
          room_id: "room-group-1",
          rule_id: "group-rule-1",
          title: "文明发言 2.0",
          content: "禁止刷屏、辱骂和广告",
          is_active: true,
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        id: "group-rule-1",
        roomId: "room-group-1",
        title: "文明发言 2.0",
        content: "禁止刷屏、辱骂和广告",
        creatorId: "u-1",
        orderIndex: 0,
        isActive: true,
        createdAt: new Date("2026-03-25T15:00:00Z"),
        updatedAt: new Date("2026-03-25T16:00:00Z"),
      },
    });
  });

  test("deletes group rule through go-core rpc and maps success result", async () => {
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

    const response = await ChatApi.deleteGroupRule({
      roomId: "room-group-1",
      ruleId: "group-rule-1",
    });

    expect(calls).toEqual([
      {
        method: "chat.group.rule.delete",
        params: {
          room_id: "room-group-1",
          rule_id: "group-rule-1",
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

  test("loads group operation logs through go-core rpc and maps payload", async () => {
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
                logs: [
                  {
                    id: "group-log-1",
                    room_id: "room-group-1",
                    operator_id: "u-1",
                    target_user_id: "u-9",
                    operation_type: "mute_user",
                    operation_data: {
                      duration_hours: 24,
                    },
                    created_at: "2026-03-25T16:30:00Z",
                  },
                  {
                    id: "group-log-2",
                    room_id: "room-group-1",
                    operator_id: "u-2",
                    target_user_id: null,
                    operation_type: "update_group_settings",
                    operation_data: null,
                    created_at: "2026-03-25T16:20:00Z",
                  },
                ],
                total: 88,
              },
            };
          },
        },
      },
    } as Window;

    const response = await ChatApi.listGroupOperationLogs({
      roomId: "room-group-1",
      limit: 20,
      offset: 40,
    });

    expect(calls).toEqual([
      {
        method: "chat.group.operation_logs.list",
        params: {
          room_id: "room-group-1",
          limit: 20,
          offset: 40,
        },
      },
    ]);
    expect(response).toEqual({
      code: 200,
      success: true,
      message: "ok",
      data: {
        logs: [
          {
            id: "group-log-1",
            roomId: "room-group-1",
            operatorId: "u-1",
            targetUserId: "u-9",
            operationType: "mute_user",
            operationData: {
              duration_hours: 24,
            },
            createdAt: new Date("2026-03-25T16:30:00Z"),
          },
          {
            id: "group-log-2",
            roomId: "room-group-1",
            operatorId: "u-2",
            targetUserId: null,
            operationType: "update_group_settings",
            operationData: null,
            createdAt: new Date("2026-03-25T16:20:00Z"),
          },
        ],
        total: 88,
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

  test("maps pinned fields into chat message model", () => {
    const mapped = mapChatMessagePayload({
      id: "msg-pin-1",
      room_id: "room-1",
      sender_id: "user-1",
      sender_username: "alice",
      sender_nickname: "Alice",
      content: "pinned payload",
      message_type: "text",
      status: "sent",
      created_at: "2026-03-25T11:00:00Z",
      is_pinned: true,
      pinned_at: "2026-03-25T11:05:00Z",
      pinned_by: "user-9",
      parts: [],
    } as Parameters<typeof mapChatMessagePayload>[0]);

    expect(mapped).toMatchObject({
      pinnedAt: new Date("2026-03-25T11:05:00Z"),
      pinnedBy: "user-9",
    });
  });

  test("maps forward_message payload into chat message model", () => {
    const mapped = mapChatMessagePayload({
      id: "msg-forward-2",
      room_id: "room-9",
      sender_id: "user-2",
      sender_username: "bob",
      sender_nickname: "Bob",
      content: "这是转发内容",
      message_type: "text",
      status: "sent",
      created_at: "2026-03-25T10:05:00Z",
      forward_message: {
        message_id: "msg-origin-2",
        room_id: "room-3",
        sender_id: "user-1",
        sender_username: "alice",
        sender_nickname: "Alice",
        source_type: "group",
        source_id: "room-3",
        source_name: "架构讨论群",
        source_avatar: "https://example.com/source.png",
      },
      parts: [],
    } as Parameters<typeof mapChatMessagePayload>[0]);

    expect(mapped).toMatchObject({
      forwardInfo: {
        sourceType: "group",
        sourceId: "room-3",
        sourceName: "架构讨论群",
        sourceAvatar: "https://example.com/source.png",
        originMessageId: "msg-origin-2",
        originRoomId: "room-3",
        originSenderId: "user-1",
        originSenderName: "Alice",
      },
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

  test("maps group_dissolved payload into realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "group_dissolved",
      room_id: "room-group-1",
    });

    expect(mapped).toEqual({
      type: "group_dissolved",
      roomId: "room-group-1",
    });
  });

  test("maps group_owner_transferred payload into realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "group_owner_transferred",
      room_id: "room-group-1",
      old_owner_id: "u-1",
      new_owner_id: "u-2",
    });

    expect(mapped).toEqual({
      type: "group_owner_transferred",
      roomId: "room-group-1",
      oldOwnerId: "u-1",
      newOwnerId: "u-2",
    });
  });

  test("maps pin_update payload into realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "pin_update",
      room_id: "room-1",
      message_id: "msg-15",
      is_pinned: true,
      pinned_at: "2026-03-25T19:05:00Z",
      pinned_by: "u-9",
    });

    expect(mapped).toEqual({
      type: "pin_update",
      roomId: "room-1",
      messageId: "msg-15",
      isPinned: true,
      pinnedAt: new Date("2026-03-25T19:05:00Z"),
      pinnedBy: "u-9",
    });
  });

  test("maps edited message_update payload into realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "message_update",
      room_id: "room-1",
      message_id: "msg-15",
      is_deleted: false,
      deleted_at: null,
      edited_at: "2026-03-25T19:06:00Z",
      content: "编辑后的消息",
    });

    expect(mapped).toEqual({
      type: "message_update",
      roomId: "room-1",
      messageId: "msg-15",
      isDeleted: false,
      deletedAt: null,
      editedAt: new Date("2026-03-25T19:06:00Z"),
      content: "编辑后的消息",
    });
  });

  test("maps reaction_update payload into realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "reaction_update",
      room_id: "room-1",
      message_id: "msg-15",
      reaction_key: "🎉",
      user_id: "u-3",
      action: "add",
    });

    expect(mapped).toEqual({
      type: "reaction_update",
      roomId: "room-1",
      messageId: "msg-15",
      reactionKey: "🎉",
      userId: "u-3",
      action: "add",
    });
  });

  test("maps typing_update payload into realtime event", () => {
    const mapped = mapChatRealtimeEvent({
      type: "typing_update",
      room_id: "room-1",
      user_id: "u-3",
      is_typing: true,
      expires_in_ms: 6000,
    });

    expect(mapped).toEqual({
      type: "typing_update",
      roomId: "room-1",
      userId: "u-3",
      isTyping: true,
      expiresInMs: 6000,
    });
  });
});
