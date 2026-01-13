import { get, post, del, patch } from "./http";
import type { ApiResponse } from "./http";
import { rustHttp } from "./rust-http";
import { parseMessageType } from "./message";
import type {
  Chat,
  RoomMember,
  RoomMemberRole,
  EnsureChatResult,
} from "@/types/models";
import { ChatType, MessageType } from "@/types/models";

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

interface BackendMyMuteInfo {
  is_muted: boolean;
  reason?: string | null;
  muted_at?: string | null;
  mute_until?: string | null;
}

interface BackendGroupSettings {
  room_id: string;
  global_mute_enabled: boolean;
  global_mute_reason?: string | null;
  global_mute_until?: string | null;
  join_approval_required?: boolean;
  member_can_invite?: boolean;
  max_members?: number;
  my_mute?: BackendMyMuteInfo | null;
}

export interface MyMuteInfo {
  isMuted: boolean;
  reason?: string | null;
  mutedAt?: string | null;
  muteUntil?: string | null;
}

export interface GroupSettings {
  roomId: string;
  globalMuteEnabled: boolean;
  globalMuteReason?: string | null;
  globalMuteUntil?: string | null;
  joinApprovalRequired?: boolean;
  memberCanInvite?: boolean;
  maxMembers?: number;
  myMute?: MyMuteInfo | null;
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

// ===== 群管理相关后端类型 =====

interface BackendGroupAdmin {
  id: string;
  room_id: string;
  admin_id: string;
  appointed_by: string;
  role: string;
  permissions?: string[] | null;
  appointed_at: string;
}

interface BackendJoinRequest {
  id: string;
  room_id: string;
  applicant_id: string;
  message?: string | null;
  status: number; // 0=pending, 1=approved, 2=rejected
  reviewer_id?: string | null;
  review_message?: string | null;
  created_at: string;
  reviewed_at?: string | null;
}

interface BackendGroupMute {
  id: string;
  room_id: string;
  user_id: string;
  muted_by: string;
  reason?: string | null;
  mute_duration_hours: number;
  muted_at: string;
  unmuted_at?: string | null;
  is_active: boolean;
}

interface BackendGroupRule {
  id: string;
  room_id: string;
  title: string;
  content: string;
  creator_id: string;
  order_index: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

interface BackendGroupOperationLog {
  id: string;
  room_id: string;
  operator_id: string;
  target_user_id?: string | null;
  operation_type: string;
  operation_data?: Record<string, unknown> | null;
  created_at: string;
}

// ===== 群管理相关前端类型 =====

export interface GroupAdmin {
  id: string;
  roomId: string;
  adminId: string;
  appointedBy: string;
  role: string;
  permissions?: string[] | null;
  appointedAt: Date;
}

export interface JoinRequest {
  id: string;
  roomId: string;
  applicantId: string;
  message?: string | null;
  status: 'pending' | 'approved' | 'rejected';
  reviewerId?: string | null;
  reviewMessage?: string | null;
  createdAt: Date;
  reviewedAt?: Date | null;
}

export interface GroupMute {
  id: string;
  roomId: string;
  userId: string;
  mutedBy: string;
  reason?: string | null;
  muteDurationHours: number;
  mutedAt: Date;
  unmutedAt?: Date | null;
  isActive: boolean;
  muteUntil?: Date | null;
}

export interface GroupRule {
  id: string;
  roomId: string;
  title: string;
  content: string;
  creatorId: string;
  orderIndex: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface GroupOperationLog {
  id: string;
  roomId: string;
  operatorId: string;
  targetUserId?: string | null;
  operationType: string;
  operationData?: Record<string, unknown> | null;
  createdAt: Date;
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

const isEmojiOnlyPreviewText = (text: string): boolean => {
  const trimmed = text.trim();
  if (!trimmed) return false;

  // 去掉变体选择符与零宽连接符，方便匹配由多个 Emoji 组合而成的表情
  const normalized = trimmed.replace(/[\uFE0F\u200D]/g, "");

  // 粗略判断：仅由常见 Emoji 区段字符组成，则认为是表情消息
  const emojiRegex = /^(?:[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}])+$/u;
  return emojiRegex.test(normalized);
};

const buildLastMessagePreview = (
  preview?: BackendChatMessagePreview | null,
): string => {
  if (!preview) {
    return "";
  }

  const type = parseMessageType(preview.message_type || "");
  const rawContent = (preview.content || "").trim();

  // 优先根据消息类型返回固定文案
  switch (type) {
    case MessageType.IMAGE:
      return "[图片]";
    case MessageType.VIDEO:
      return "[视频]";
    case MessageType.VOICE:
      return "[语音]";
    case MessageType.FILE:
      return "[附件]";
    default:
      break;
  }

  if (!rawContent) {
    return "";
  }

  // 处理 mixed 类型消息：根据 content 前缀判断附件类型
  if (rawContent.startsWith("[图片]")) {
    return "[图片]";
  }
  if (rawContent.startsWith("[视频]")) {
    return "[视频]";
  }
  if (rawContent.startsWith("[语音]")) {
    return "[语音]";
  }
  if (rawContent.startsWith("[文件]")) {
    return "[附件]";
  }

  if (isEmojiOnlyPreviewText(rawContent)) {
    return "[表情]";
  }

  return rawContent;
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
    extra.friend_name = summary.friend_nickname;
    extra.friendName = summary.friend_nickname;
    extra.nickname = summary.friend_nickname;
  }
  if (summary.friend_username) {
    extra.friend_username = summary.friend_username;
    extra.friendUsername = summary.friend_username;
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
    lastMessage: buildLastMessagePreview(lastMessage),
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

  if (room.owner_id) {
    extra.owner_id = room.owner_id;
    extra.ownerId = room.owner_id;
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

const mapGroupSettings = (settings: BackendGroupSettings): GroupSettings => ({
  roomId: settings.room_id,
  globalMuteEnabled: Boolean(settings.global_mute_enabled),
  globalMuteReason: settings.global_mute_reason ?? null,
  globalMuteUntil: settings.global_mute_until ?? null,
  joinApprovalRequired: settings.join_approval_required,
  memberCanInvite: settings.member_can_invite,
  maxMembers: settings.max_members ?? undefined,
  myMute: settings.my_mute ? {
    isMuted: Boolean(settings.my_mute.is_muted),
    reason: settings.my_mute.reason ?? null,
    mutedAt: settings.my_mute.muted_at ?? null,
    muteUntil: settings.my_mute.mute_until ?? null,
  } : null,
});

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

// ===== 群管理相关映射函数 =====

const mapGroupAdmin = (admin: BackendGroupAdmin): GroupAdmin => ({
  id: admin.id,
  roomId: admin.room_id,
  adminId: admin.admin_id,
  appointedBy: admin.appointed_by,
  role: admin.role,
  permissions: admin.permissions ?? null,
  appointedAt: parseTimestamp(admin.appointed_at),
});

const mapJoinRequestStatus = (status: number): 'pending' | 'approved' | 'rejected' => {
  switch (status) {
    case 1:
      return 'approved';
    case 2:
      return 'rejected';
    default:
      return 'pending';
  }
};

const mapJoinRequest = (request: BackendJoinRequest): JoinRequest => ({
  id: request.id,
  roomId: request.room_id,
  applicantId: request.applicant_id,
  message: request.message ?? null,
  status: mapJoinRequestStatus(request.status),
  reviewerId: request.reviewer_id ?? null,
  reviewMessage: request.review_message ?? null,
  createdAt: parseTimestamp(request.created_at),
  reviewedAt: request.reviewed_at ? parseTimestamp(request.reviewed_at) : null,
});

const mapGroupMute = (mute: BackendGroupMute): GroupMute => {
  const mutedAt = parseTimestamp(mute.muted_at);
  const muteUntil = mute.mute_duration_hours > 0
    ? new Date(mutedAt.getTime() + mute.mute_duration_hours * 60 * 60 * 1000)
    : null;

  return {
    id: mute.id,
    roomId: mute.room_id,
    userId: mute.user_id,
    mutedBy: mute.muted_by,
    reason: mute.reason ?? null,
    muteDurationHours: mute.mute_duration_hours,
    mutedAt,
    unmutedAt: mute.unmuted_at ? parseTimestamp(mute.unmuted_at) : null,
    isActive: mute.is_active,
    muteUntil,
  };
};

const mapGroupRule = (rule: BackendGroupRule): GroupRule => ({
  id: rule.id,
  roomId: rule.room_id,
  title: rule.title,
  content: rule.content,
  creatorId: rule.creator_id,
  orderIndex: rule.order_index,
  isActive: rule.is_active,
  createdAt: parseTimestamp(rule.created_at),
  updatedAt: parseTimestamp(rule.updated_at),
});

const mapGroupOperationLog = (log: BackendGroupOperationLog): GroupOperationLog => ({
  id: log.id,
  roomId: log.room_id,
  operatorId: log.operator_id,
  targetUserId: log.target_user_id ?? null,
  operationType: log.operation_type,
  operationData: log.operation_data ?? null,
  createdAt: parseTimestamp(log.created_at),
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

  static async getGroupSettings(params: {
    roomId: string;
  }): Promise<ApiResponse<GroupSettings>> {
    const response = await get<{ settings: BackendGroupSettings }>(
      `/rooms/${params.roomId}/settings`,
    );

    if (!response.success || !response.data?.settings) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapGroupSettings(response.data.settings),
    };
  }

  static async updateGlobalMute(params: {
    roomId: string;
    enabled: boolean;
    reason?: string;
    durationMinutes?: number;
  }): Promise<ApiResponse<GroupSettings>> {
    const payload: Record<string, unknown> = {
      enabled: params.enabled,
    };
    if (params.reason && params.reason.trim().length > 0) {
      payload.reason = params.reason.trim();
    }
    if (typeof params.durationMinutes === 'number') {
      payload.duration_minutes = params.durationMinutes;
    }

    const response = await post<{ settings: BackendGroupSettings }>(
      `/rooms/${params.roomId}/mutes/global`,
      payload,
    );

    if (!response.success || !response.data?.settings) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapGroupSettings(response.data.settings),
    };
  }

  static async dissolveGroup(params: {
    roomId: string;
  }): Promise<ApiResponse<{ success: boolean }>> {
    const response = await del<{ success: boolean }>(
      `/rooms/${params.roomId}`,
    );
    return response;
  }

  static async transferGroupOwner(params: {
    roomId: string;
    newOwnerId: string;
  }): Promise<ApiResponse<{ roomId: string; ownerId: string }>> {
    const response = await post<{ room_id: string; owner_id: string }>(
      `/rooms/${params.roomId}/transfer`,
      {
        new_owner_id: params.newOwnerId,
      },
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
        ownerId: response.data.owner_id,
      },
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
      forceStreaming: true,
      timeout: 60000 // 60秒超时，避免上传卡住
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

  // ===== 群管理员管理 =====

  /**
   * 获取群管理员列表
   */
  static async listAdmins(params: {
    roomId: string;
  }): Promise<ApiResponse<GroupAdmin[]>> {
    const response = await get<{ admins: BackendGroupAdmin[] }>(
      `/rooms/${params.roomId}/admins`,
    );

    if (!response.success || !response.data?.admins) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.admins.map(mapGroupAdmin),
    };
  }

  /**
   * 任命管理员
   */
  static async appointAdmin(params: {
    roomId: string;
    userId: string;
    role?: string;
  }): Promise<ApiResponse<GroupAdmin>> {
    const response = await post<{ admin: BackendGroupAdmin }>(
      `/rooms/${params.roomId}/admins`,
      {
        user_id: params.userId,
        role: params.role || 'admin',
      },
    );

    if (!response.success || !response.data?.admin) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapGroupAdmin(response.data.admin),
    };
  }

  /**
   * 撤销管理员
   */
  static async removeAdmin(params: {
    roomId: string;
    adminId: string;
  }): Promise<ApiResponse<null>> {
    const response = await del<null>(
      `/rooms/${params.roomId}/admins/${params.adminId}`,
    );
    return response;
  }

  // ===== 入群申请管理 =====

  /**
   * 获取入群申请列表
   */
  static async listJoinRequests(params: {
    roomId: string;
  }): Promise<ApiResponse<JoinRequest[]>> {
    const response = await get<{ requests: BackendJoinRequest[] }>(
      `/rooms/${params.roomId}/join-requests`,
    );

    if (!response.success || !response.data?.requests) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.requests.map(mapJoinRequest),
    };
  }

  /**
   * 审批入群申请
   */
  static async reviewJoinRequest(params: {
    roomId: string;
    requestId: string;
    status: 'approved' | 'rejected';
    reviewMessage?: string;
  }): Promise<ApiResponse<JoinRequest>> {
    const response = await patch<{ request: BackendJoinRequest }>(
      `/rooms/${params.roomId}/join-requests/${params.requestId}/review`,
      {
        status: params.status,
        review_message: params.reviewMessage,
      },
    );

    if (!response.success || !response.data?.request) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapJoinRequest(response.data.request),
    };
  }

  // ===== 禁言管理 =====

  /**
   * 获取被禁言的成员列表
   */
  static async listMutedUsers(params: {
    roomId: string;
  }): Promise<ApiResponse<GroupMute[]>> {
    const response = await get<{ mutes: BackendGroupMute[] }>(
      `/rooms/${params.roomId}/mutes`,
    );

    if (!response.success || !response.data?.mutes) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.mutes.map(mapGroupMute),
    };
  }

  /**
   * 禁言成员
   */
  static async muteUser(params: {
    roomId: string;
    userId: string;
    durationHours: number;
    reason?: string;
  }): Promise<ApiResponse<GroupMute>> {
    const response = await post<{ mute: BackendGroupMute }>(
      `/rooms/${params.roomId}/mutes`,
      {
        user_id: params.userId,
        duration_hours: params.durationHours,
        reason: params.reason,
      },
    );

    if (!response.success || !response.data?.mute) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapGroupMute(response.data.mute),
    };
  }

  /**
   * 解除禁言
   */
  static async unmuteUser(params: {
    roomId: string;
    userId: string;
  }): Promise<ApiResponse<null>> {
    const response = await del<null>(
      `/rooms/${params.roomId}/mutes/${params.userId}`,
    );
    return response;
  }

  // ===== 群规管理 =====

  /**
   * 获取群规列表
   */
  static async listRules(params: {
    roomId: string;
  }): Promise<ApiResponse<GroupRule[]>> {
    const response = await get<{ rules: BackendGroupRule[] }>(
      `/rooms/${params.roomId}/rules`,
    );

    if (!response.success || !response.data?.rules) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.rules.map(mapGroupRule),
    };
  }

  /**
   * 创建群规
   */
  static async createRule(params: {
    roomId: string;
    title: string;
    content: string;
    orderIndex?: number;
  }): Promise<ApiResponse<GroupRule>> {
    const response = await post<{ rule: BackendGroupRule }>(
      `/rooms/${params.roomId}/rules`,
      {
        title: params.title,
        content: params.content,
        order_index: params.orderIndex,
      },
    );

    if (!response.success || !response.data?.rule) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapGroupRule(response.data.rule),
    };
  }

  /**
   * 更新群规
   */
  static async updateRule(params: {
    roomId: string;
    ruleId: string;
    title?: string;
    content?: string;
    orderIndex?: number;
    isActive?: boolean;
  }): Promise<ApiResponse<GroupRule>> {
    const payload: Record<string, unknown> = {};
    if (params.title !== undefined) payload.title = params.title;
    if (params.content !== undefined) payload.content = params.content;
    if (params.orderIndex !== undefined) payload.order_index = params.orderIndex;
    if (params.isActive !== undefined) payload.is_active = params.isActive;

    const response = await patch<{ rule: BackendGroupRule }>(
      `/rooms/${params.roomId}/rules/${params.ruleId}`,
      payload,
    );

    if (!response.success || !response.data?.rule) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapGroupRule(response.data.rule),
    };
  }

  /**
   * 删除群规
   */
  static async deleteRule(params: {
    roomId: string;
    ruleId: string;
  }): Promise<ApiResponse<null>> {
    const response = await del<null>(
      `/rooms/${params.roomId}/rules/${params.ruleId}`,
    );
    return response;
  }

  // ===== 操作日志 =====

  /**
   * 获取群操作日志
   */
  static async listOperationLogs(params: {
    roomId: string;
    limit?: number;
    offset?: number;
  }): Promise<ApiResponse<{ logs: GroupOperationLog[]; total: number }>> {
    const queryParams = new URLSearchParams();
    if (params.limit !== undefined) queryParams.set('limit', String(params.limit));
    if (params.offset !== undefined) queryParams.set('offset', String(params.offset));

    const queryString = queryParams.toString();
    const url = `/rooms/${params.roomId}/operation-logs${queryString ? `?${queryString}` : ''}`;

    const response = await get<{ logs: BackendGroupOperationLog[]; total: number }>(url);

    if (!response.success || !response.data?.logs) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: {
        logs: response.data.logs.map(mapGroupOperationLog),
        total: response.data.total,
      },
    };
  }

  // ===== 群设置管理 =====

  /**
   * 更新群设置
   */
  static async updateGroupSettings(params: {
    roomId: string;
    joinApprovalRequired?: boolean;
    memberCanInvite?: boolean;
    maxMembers?: number;
  }): Promise<ApiResponse<GroupSettings>> {
    const payload: Record<string, unknown> = {};
    if (params.joinApprovalRequired !== undefined) {
      payload.join_approval_required = params.joinApprovalRequired;
    }
    if (params.memberCanInvite !== undefined) {
      payload.member_can_invite = params.memberCanInvite;
    }
    if (params.maxMembers !== undefined) {
      payload.max_members = params.maxMembers;
    }

    const response = await patch<{ settings: BackendGroupSettings }>(
      `/rooms/${params.roomId}/settings`,
      payload,
    );

    if (!response.success || !response.data?.settings) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: mapGroupSettings(response.data.settings),
    };
  }
}
