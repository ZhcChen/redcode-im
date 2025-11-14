import { get, post, del, patch } from "./http";
import type { ApiResponse } from "./http";
import { rustHttp } from "./rust-http";
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
  room_avatar_object_key?: string | null;
  description?: string | null;
  unread_count: number;
  last_message?: BackendChatMessagePreview | null;
  last_message_at?: string | null;
  is_pinned?: boolean;
  is_muted?: boolean;
  extra?: Record<string, unknown> | null;
  friend_user_id?: string | null;
  friend_nickname?: string | null;
  friend_username?: string | null;
  friend_remark?: string | null;
  friend_avatar_object_key?: string | null;
}

interface BackendRoomInfo {
  id: string;
  name: string;
  description?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
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
  avatar_object_key?: string | null;
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

  // 构建 extra 对象，合并后端的 extra 和好友信息
  const extra: Record<string, unknown> = {
    ...(summaryExtra || {}),
  };

  // 添加好友相关信息到 extra
  if (summary.friend_user_id) {
    extra.friend_id = summary.friend_user_id;
    extra.friendId = summary.friend_user_id;
    extra.friend_user_id = summary.friend_user_id;
  }
  if (summary.friend_nickname) {
    extra.friend_nickname = summary.friend_nickname;
    extra.friendNickname = summary.friend_nickname;
  }
  if (summary.friend_username) {
    extra.friend_username = summary.friend_username;
    extra.friendUsername = summary.friend_username;
    extra.friend_name = summary.friend_username;
    extra.friendName = summary.friend_username;
  }
  if (summary.friend_remark) {
    extra.friend_remark = summary.friend_remark;
    extra.friendRemark = summary.friend_remark;
    extra.remark = summary.friend_remark;
  }
  if (summary.friend_avatar_object_key) {
    extra.friend_avatar_object_key = summary.friend_avatar_object_key;
    extra.friendAvatarObjectKey = summary.friend_avatar_object_key;
  }
  if (summary.description) {
    extra.description = summary.description;
  }
  if (summary.room_avatar_object_key) {
    extra.room_avatar_object_key = summary.room_avatar_object_key;
    extra.roomAvatarObjectKey = summary.room_avatar_object_key;
  }

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
    extra: Object.keys(extra).length > 0 ? extra : null,
  };
};

const mapRoomInfo = (room: BackendRoomInfo): Chat => {

  const roomExtra = room.extra as Record<string, unknown> | null;
  const memberCountRaw = roomExtra ? roomExtra["member_count"] : undefined;
  const memberCount =
    typeof memberCountRaw === "number" ? memberCountRaw : undefined;

  // 构建 extra 对象
  const extra: Record<string, unknown> = {
    ...(roomExtra || {}),
  };

  // 添加 room_avatar_object_key 到 extra
  if (room.avatar_object_key) {
    extra.room_avatar_object_key = room.avatar_object_key;
    extra.roomAvatarObjectKey = room.avatar_object_key;
  } else {
  }

  // 添加 description 到 extra
  if (room.description) {
    extra.description = room.description;
  }

  const result = {
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
    extra: Object.keys(extra).length > 0 ? extra : null,
  };


  return result;
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
  avatarObjectKey: member.avatar_object_key ?? null,
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
    const response = await get<{ info: BackendRoomInfo }>(`/rooms/${params.chatGroupId}/detail`);


    if (!response.success || !response.data || !response.data.info) {
      return {
        ...response,
        data: null,
      };
    }

    const mappedData = mapRoomInfo(response.data.info);

    return {
      ...response,
      data: mappedData,
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

  static async updateGroupInfo(params: {
    groupId: string;
    groupName?: string;
    groupAvatar?: string;
    groupDescription?: string;
  }): Promise<ApiResponse<null>> {
    // 构建请求体，只包含提供的字段
    const payload: Record<string, unknown> = {};

    if (params.groupName !== undefined) {
      payload.name = params.groupName;
    }

    if (params.groupAvatar !== undefined) {
      payload.avatar_url = params.groupAvatar;
    }

    if (params.groupDescription !== undefined) {
      payload.description = params.groupDescription;
    }

    // 如果没有提供任何字段，返回错误
    if (Object.keys(payload).length === 0) {
      return {
        code: 400,
        success: false,
        message: "至少需要提供一个更新字段",
        data: null,
      };
    }

    // 调用后端 API 更新群信息
    const response = await patch<null>(`/rooms/${params.groupId}`, payload);

    return {
      ...response,
      data: null,
    };
  }

  /**
   * 上传群头像 - 使用腾讯 COS 直传
   */
  static async uploadGroupAvatar(
    groupId: string,
    file: File
  ): Promise<ApiResponse<{ avatarUrl: string }>> {

    const contentType = file.type || 'application/octet-stream';

    const directResp = await rustHttp.post<{
      success: boolean;
      message: string;
      key?: string;
      signature?: {
        url: string;
        method: string;
        headers: Record<string, string>;
      };
    }>(`/rooms/${groupId}/avatar/direct-upload`, {
      content_type: contentType,
      filename: file.name,
      file_size: file.size
    });

    const directData = directResp.data;

    if (!directResp.success || !directData || !directData.success || !directData.key || !directData.signature) {
      return {
        code: directResp.code || 500,
        success: false,
        message: directData?.message || directResp.message || '获取上传签名失败',
        data: null
      };
    }

    const { key, signature } = directData;

    const headers = new Headers();
    // 过滤掉 Host 头，避免浏览器 CORS 限制
    Object.entries(signature.headers || {}).forEach(
      ([headerKey, headerValue]) => {
        if (headerKey.toLowerCase() === 'host') {
          return;
        }
        headers.set(headerKey, headerValue);
      }
    );
    if (!headers.has('Content-Type')) {
      headers.set('Content-Type', contentType);
    }

    const fileBuffer = new Uint8Array(await file.arrayBuffer());
    const contentLength = fileBuffer.length.toString();
    const finalHeaders: Record<string, string> = {};
    headers.forEach((value, key) => {
      finalHeaders[key] = value;
    });
    if (!headers.has('Content-Length')) {
      headers.set('Content-Length', contentLength);
    }
    finalHeaders['Content-Length'] = headers.get('Content-Length') || contentLength;


    const uploadResponse = await rustHttp.requestRaw<{ base64?: string }>({
      path: signature.url,
      method: (signature.method || 'PUT') as any,
      headers: finalHeaders,
      binaryBody: fileBuffer,
      injectToken: false,
      forceStreaming: true
    });

    if (!uploadResponse.success) {
      const status = uploadResponse.code;
      let errorMessage = uploadResponse.message || '上传失败，请稍后重试';
      if (status === 403) {
        errorMessage = '上传配置错误：可能存在跨域访问问题，请联系管理员检查存储配置';
      } else if (status === 0) {
        errorMessage = '网络连接失败，请检查网络设置';
      }

      return {
        code: status,
        success: false,
        message: errorMessage,
        data: null
      };
    }


    const commitResp = await rustHttp.post<{
      success: boolean;
      message: string;
      avatar_url?: string;
    }>(`/rooms/${groupId}/avatar/commit`, {
      key
    });

    const commitData = commitResp.data;

    if (!commitResp.success || !commitData || !commitData.success || !commitData.avatar_url) {
      return {
        code: commitResp.code || 500,
        success: false,
        message: commitData?.message || commitResp.message || '提交群头像配置失败',
        data: null
      };
    }


    return {
      code: 200,
      success: true,
      message: '群头像上传成功',
      data: {
        avatarUrl: commitData.avatar_url
      }
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

  // 群公告相关 API
  static async createAnnouncement(params: {
    roomId: string;
    title?: string;
    content: string;
  }): Promise<ApiResponse<{ announcementId: string }>> {
    const payload = {
      title: params.title || '群公告',
      content: params.content,
    };

    const response = await post<{ announcement: { id: string } }>(`/rooms/${params.roomId}/announcements`, payload);

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        announcementId: response.data.announcement.id,
      },
    };
  }

  static async updateAnnouncement(params: {
    roomId: string;
    announcementId: string;
    title?: string;
    content: string;
  }): Promise<ApiResponse<null>> {
    const payload: Record<string, unknown> = {
      content: params.content,
    };

    if (params.title) {
      payload.title = params.title;
    }

    const response = await patch<null>(
      `/rooms/${params.roomId}/announcements/${params.announcementId}`,
      payload
    );

    return response;
  }

  /**
   * 获取群头像临时下载地址
   */
  static async getRoomAvatarDownloadUrl(params: {
    roomId: string;
    expiresInSeconds?: number;
  }): Promise<ApiResponse<{ downloadUrl: string }>> {
    const queryParams = params.expiresInSeconds
      ? `?expires_in_seconds=${params.expiresInSeconds}`
      : '';

    const response = await get<{
      success: boolean;
      message: string;
      download_url?: string;
    }>(`/rooms/${params.roomId}/avatar/url${queryParams}`);

    if (!response.success || !response.data || !response.data.success || !response.data.download_url) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        downloadUrl: response.data.download_url,
      },
    };
  }

  static async listAnnouncements(params: {
    roomId: string;
  }): Promise<ApiResponse<Array<{
    id: string;
    title: string;
    content: string;
    authorId: string;
    isPinned: boolean;
    createdAt: Date;
    updatedAt: Date;
  }>>> {
    interface BackendAnnouncement {
      id: string;
      title: string;
      content: string;
      publisher_id: string;
      is_pinned: boolean;
      created_at: string;
      updated_at: string;
    }

    const response = await get<{ announcements: BackendAnnouncement[] }>(`/rooms/${params.roomId}/announcements`);

    if (!response.success || !response.data || !response.data.announcements) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.announcements.map(announcement => ({
        id: announcement.id,
        title: announcement.title,
        content: announcement.content,
        authorId: announcement.publisher_id,
        isPinned: announcement.is_pinned,
        createdAt: parseTimestamp(announcement.created_at),
        updatedAt: parseTimestamp(announcement.updated_at),
      })),
    };
  }
}
