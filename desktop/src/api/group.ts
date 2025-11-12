import { get, post, del } from "./http";
import type { ApiResponse } from "./http";
import type {
  Chat,
  RoomMember,
  RoomMemberRole,
  EnsureChatResult,
} from "@/types/models";
import { ChatType } from "@/types/models";

type BackendRoomType = "private" | "group" | "public" | "favorite";

interface BackendChatMessagePreview {
  id: string;
  content: string;
  message_type: string;
  created_at: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
}

interface BackendChatSummary {
  room_id: string;
  name: string;
  room_type: BackendRoomType;
  avatar_url?: string | null;
  description?: string | null;
  unread_count: number;
  last_message?: BackendChatMessagePreview | null;
  last_message_at?: string | null;
  is_pinned?: boolean;
  is_muted?: boolean;
  extra?: Record<string, unknown> | null;
}

interface BackendRoomInfo {
  id: string;
  name: string;
  description?: string | null;
  avatar_url?: string | null;
  room_type: BackendRoomType;
  owner_id: string;
  created_at: string;
  is_pinned?: boolean;
  is_muted?: boolean;
  extra?: Record<string, unknown> | null;
}

interface BackendRoomMember {
  user_id: string;
  username: string;
  nickname?: string | null;
  avatar_url?: string | null;
  role: "owner" | "admin" | "member";
  joined_at?: string | null;
}

interface BackendEnsureChatResponse {
  room_id: string;
  room_name: string;
  room_type: string;
  friend_id: string;
  friend_name: string;
  friend_avatar?: string | null;
  friend_avatar_object_key?: string | null;
}

interface CreateGroupResponse {
  room: BackendRoomInfo;
}

const parseRoomType = (value: BackendRoomType): ChatType => {
  switch (value) {
    case "group":
      return ChatType.GROUP;
    case "favorite":
      return ChatType.FAVORITE;
    case "private":
    case "public":
    default:
      return ChatType.SINGLE;
  }
};

const parseTimestamp = (value?: string | null): Date => {
  if (!value) {
    return new Date();
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return new Date();
  }
  return parsed;
};

const mapChatSummary = (summary: BackendChatSummary): Chat => {
  const lastMessage = summary.last_message;
  const lastTimestamp =
    summary.last_message_at ??
    summary.last_message?.created_at ??
    new Date().toISOString();

  const summaryExtra = summary.extra as Record<string, unknown> | null;
  const memberCountRaw = summaryExtra
    ? summaryExtra["member_count"]
    : undefined;
  const memberCount =
    typeof memberCountRaw === "number" ? memberCountRaw : undefined;

  return {
    id: summary.room_id,
    roomId: summary.room_id,
    name: summary.name,
    avatar: summary.avatar_url ?? null,
    type: parseRoomType(summary.room_type),
    lastMessage: lastMessage?.content ?? "",
    lastMessageTime: parseTimestamp(lastTimestamp),
    lastMessageId: lastMessage?.id,
    unreadCount: summary.unread_count ?? 0,
    isPinned: Boolean(summary.is_pinned),
    isMuted: Boolean(summary.is_muted),
    memberCount,
    extra:
      summary.extra ??
      (summary.description ? { description: summary.description } : null),
  };
};

const mapRoomInfo = (room: BackendRoomInfo): Chat => {
  const roomExtra = room.extra as Record<string, unknown> | null;
  const memberCountRaw = roomExtra ? roomExtra["member_count"] : undefined;
  const memberCount =
    typeof memberCountRaw === "number" ? memberCountRaw : undefined;

  return {
    id: room.id,
    roomId: room.id,
    name: room.name,
    avatar: room.avatar_url ?? null,
    type: parseRoomType(room.room_type),
    lastMessage: "",
    lastMessageTime: parseTimestamp(room.created_at),
    lastMessageId: undefined,
    unreadCount: 0,
    isPinned: Boolean(room.is_pinned),
    isMuted: Boolean(room.is_muted),
    memberCount,
    extra:
      room.extra ??
      (room.description ? { description: room.description } : null),
  };
};

const mapRoomMemberRole = (role: string): RoomMemberRole => {
  switch (role) {
    case "owner":
      return "owner";
    case "admin":
      return "admin";
    default:
      return "member";
  }
};

const mapRoomMember = (member: BackendRoomMember): RoomMember => ({
  userId: member.user_id,
  username: member.username,
  nickname: member.nickname ?? null,
  avatarUrl: member.avatar_url ?? null,
  role: mapRoomMemberRole(member.role),
  joinedAt: member.joined_at ? parseTimestamp(member.joined_at) : null,
});

export class GroupApi {
  static async getMyChatGroupList(): Promise<ApiResponse<Chat[]>> {
    const response = await get<BackendChatSummary[]>("/chats");
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.map(mapChatSummary),
    };
  }

  static async getMyJoinChatGroupList(): Promise<ApiResponse<Chat[]>> {
    const response = await get<BackendRoomInfo[]>("/rooms");
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.map(mapRoomInfo),
    };
  }

  static async getChatGroupInfo(params: {
    chatGroupId: string;
  }): Promise<ApiResponse<Chat>> {
    const response = await get<BackendRoomInfo>(`/rooms/${params.chatGroupId}`);
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapRoomInfo(response.data),
    };
  }

  static async getChatGroupMembers(params: {
    chatGroupId: string;
  }): Promise<ApiResponse<RoomMember[]>> {
    const response = await get<BackendRoomMember[]>(
      `/rooms/${params.chatGroupId}/members`,
    );
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.map(mapRoomMember),
    };
  }

  static async createSingleChat(params: {
    friendId: string;
  }): Promise<ApiResponse<EnsureChatResult>> {
    const response = await post<BackendEnsureChatResponse>(
      `/friends/${params.friendId}/chat`,
      {},
    );
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        roomId: response.data.room_id,
        roomName: response.data.room_name,
        roomType: response.data.room_type,
        friendId: response.data.friend_id,
        friendName: response.data.friend_name,
        friendAvatar: response.data.friend_avatar ?? null,
        friendAvatarObjectKey: response.data.friend_avatar_object_key ?? null,
      },
    };
  }

  static async launchChatGroup(params: {
    name: string;
    memberIds: string[];
    description?: string;
    avatarUrl?: string;
  }): Promise<ApiResponse<{ roomId: string }>> {
    const payload: Record<string, unknown> = {
      name: params.name,
      member_ids: params.memberIds,
    };

    if (params.description) {
      payload.description = params.description;
    }
    if (params.avatarUrl) {
      payload.avatar_url = params.avatarUrl;
    }

    const response = await post<CreateGroupResponse>("/rooms", payload);
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        roomId: response.data.room.id,
      },
    };
  }

  static async updateGroupInfo(): Promise<ApiResponse<null>> {
    return {
      code: 501,
      success: false,
      message: "当前后端暂未提供群设置更新能力",
      data: null,
    };
  }

  static async pinChat(params: {
    roomId: string;
  }): Promise<ApiResponse<{ isPinned: boolean }>> {
    const response = await post<{ is_pinned: boolean }>(
      `/rooms/${params.roomId}/pin`,
      {},
    );

    if (!response.success || response.data === null || response.data === undefined) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        isPinned: Boolean(response.data.is_pinned),
      },
    };
  }

  static async unpinChat(params: {
    roomId: string;
  }): Promise<ApiResponse<{ isPinned: boolean }>> {
    const response = await del<{ is_pinned: boolean }>(
      `/rooms/${params.roomId}/pin`,
    );

    if (!response.success || response.data === null || response.data === undefined) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        isPinned: Boolean(response.data.is_pinned),
      },
    };
  }

  static async deleteChat(params: {
    roomId: string;
  }): Promise<ApiResponse<null>> {
    const response = await del<null>(`/chats/${params.roomId}`);
    return response;
  }
}
