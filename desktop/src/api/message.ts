import { del, get, post } from "./http";
import type { ApiResponse } from "./http";
import type {
  Message,
  ForwardInfo,
  QuotedMessage,
  MessageReader,
} from "@/types/models";
import { MessageType, MessageStatus, ForwardSourceType } from "@/types/models";

type BackendMessageType =
  | "text"
  | "image"
  | "audio"
  | "video"
  | "file"
  | "system";
type BackendMessageStatus =
  | "sending"
  | "sent"
  | "delivered"
  | "read"
  | "failed";

export interface BackendMessageInfo {
  id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
  sender_avatar_url?: string | null;
  content: string;
  message_type: BackendMessageType;
  status?: BackendMessageStatus | null;
  created_at: string;
  quoted_message?: BackendQuotedMessage | null;
  forward_message?: BackendForwardMessage | null;
  is_deleted?: boolean;
  deleted_at?: string | null;
  is_pinned?: boolean;
  pinned_at?: string | null;
  pinned_by?: string | null;
  extra?: Record<string, unknown> | null;
}

interface BackendQuotedMessage {
  id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
  sender_avatar_url?: string | null;
  content?: string | null;
  message_type: BackendMessageType;
  created_at?: string | null;
  is_deleted: boolean;
}

interface BackendForwardMessage {
  message_id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
  source_type?: string | null;
  source_id?: string | null;
  source_name?: string | null;
  source_avatar?: string | null;
}

interface BackendMessageReader {
  user_id: string;
  username: string;
  nickname?: string | null;
  avatar_url?: string | null;
  read_at: string;
}

interface BackendPinResponse {
  room_id: string;
  is_pinned: boolean;
  message?: BackendMessageInfo | null;
  pinned_at?: string | null;
  pinned_by?: string | null;
}

interface BackendEnsureChatResponse {
  room_id: string;
}

export const parseMessageType = (value: string): MessageType => {
  switch (value) {
    case "image":
      return MessageType.IMAGE;
    case "audio":
      return MessageType.VOICE;
    case "video":
      return MessageType.VIDEO;
    case "file":
      return MessageType.FILE;
    case "system":
      return MessageType.SYSTEM;
    case "text":
    default:
      return MessageType.TEXT;
  }
};

const parseForwardSourceType = (value?: string | null): ForwardSourceType => {
  switch ((value || "").toLowerCase()) {
    case "user":
    case "single":
      return ForwardSourceType.USER;
    case "group":
      return ForwardSourceType.GROUP;
    case "favorite":
      return ForwardSourceType.FAVORITE;
    default:
      return ForwardSourceType.UNKNOWN;
  }
};

const parseMessageStatus = (value?: string | null): MessageStatus => {
  switch (value) {
    case "sending":
      return MessageStatus.SENDING;
    case "delivered":
      return MessageStatus.DELIVERED;
    case "read":
      return MessageStatus.READ;
    case "failed":
      return MessageStatus.FAILED;
    case "sent":
    default:
      return MessageStatus.SENT;
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

const mapQuotedMessage = (
  quoted?: BackendQuotedMessage | null,
): QuotedMessage | null => {
  if (!quoted) {
    return null;
  }

  return {
    id: quoted.id,
    roomId: quoted.room_id,
    senderId: quoted.sender_id,
    senderUsername: quoted.sender_username,
    senderName: quoted.sender_nickname?.trim() || quoted.sender_username,
    senderAvatar: quoted.sender_avatar_url ?? null,
    content: quoted.content ?? null,
    type: parseMessageType(quoted.message_type),
    createdAt: quoted.created_at ? parseTimestamp(quoted.created_at) : null,
    isDeleted: Boolean(quoted.is_deleted),
  };
};

const mapForwardMessage = (
  forward?: BackendForwardMessage | null,
): ForwardInfo | null => {
  if (!forward) {
    return null;
  }

  return {
    sourceType: parseForwardSourceType(forward.source_type),
    sourceId: forward.source_id ?? forward.room_id ?? "",
    sourceName:
      forward.source_name ??
      forward.sender_nickname ??
      forward.sender_username ??
      forward.source_id ??
      "",
    sourceAvatar: forward.source_avatar ?? null,
    originMessageId: forward.message_id ?? null,
    originRoomId: forward.room_id ?? null,
    originSenderId: forward.sender_id ?? null,
    originSenderName:
      forward.sender_nickname ?? forward.sender_username ?? null,
  };
};

export const transformBackendMessage = (
  message: BackendMessageInfo,
  currentUserId?: string,
): Message => {
  const senderName = message.sender_nickname?.trim()
    ? message.sender_nickname.trim()
    : message.sender_username;

  const timestamp = parseTimestamp(message.created_at);

  return {
    id: message.id,
    roomId: message.room_id,
    senderId: message.sender_id,
    senderUsername: message.sender_username,
    senderName,
    senderAvatar: message.sender_avatar_url ?? null,
    content: message.content,
    type: parseMessageType(message.message_type),
    status: parseMessageStatus(message.status),
    timestamp,
    isSelf: currentUserId
      ? currentUserId.toString() === message.sender_id.toString()
      : false,
    extra: message.extra ?? null,
    quotedMessage: mapQuotedMessage(message.quoted_message),
    forwardInfo: mapForwardMessage(message.forward_message),
    isDeleted: Boolean(message.is_deleted),
    pinnedAt: message.pinned_at ? parseTimestamp(message.pinned_at) : null,
  };
};

const mapBackendReader = (reader: BackendMessageReader): MessageReader => ({
  userId: reader.user_id,
  username: reader.username,
  nickname: reader.nickname ?? null,
  avatarUrl: reader.avatar_url ?? null,
  readAt: parseTimestamp(reader.read_at),
});

export interface GetMessageListParams {
  groupId: string;
  limit?: number;
  size?: number;
  beforeId?: string;
  lastMessageId?: string;
  sinceId?: string;
  currentUserId?: string;
}

const buildMessageQuery = (
  params: GetMessageListParams,
): Record<string, string> => {
  const query: Record<string, string> = {};
  const limit = params.limit ?? params.size;
  if (limit) {
    query.limit = String(limit);
  }
  const beforeId = params.beforeId ?? params.lastMessageId;
  if (beforeId) {
    query.before_id = beforeId;
  }
  if (params.sinceId) {
    query.since_id = params.sinceId;
  }
  return query;
};

export class MessageApi {
  static async getMessageListByChatGroupId(
    params: GetMessageListParams,
  ): Promise<ApiResponse<Message[]>> {
    const query = buildMessageQuery(params);
    const response = await get<BackendMessageInfo[]>(
      `/rooms/${params.groupId}/messages`,
      query,
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const mapped = response.data.map((item) =>
      transformBackendMessage(item, params.currentUserId),
    );
    return {
      ...response,
      data: mapped,
    };
  }

  static async sendTextMessage(params: {
    groupId: string;
    content: string;
    replyToMessageId?: string;
    currentUserId?: string;
  }): Promise<ApiResponse<Message>> {
    const payload: Record<string, unknown> = {
      content: params.content,
      message_type: "text",
    };

    if (params.replyToMessageId) {
      payload.quoted_message_id = params.replyToMessageId;
    }

    const response = await post<BackendMessageInfo>(
      `/rooms/${params.groupId}/messages`,
      payload,
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: transformBackendMessage(response.data, params.currentUserId),
    };
  }

  static async markMessagesAsRead(params: {
    groupId: string;
    messageIds: string[];
  }): Promise<ApiResponse<unknown>> {
    const normalizedIds = params.messageIds
      .map((id) => id?.trim())
      .filter((id): id is string => Boolean(id && id.length));

    if (!normalizedIds.length) {
      return {
        code: 400,
        success: false,
        message: "缺少消息 ID，无法标记为已读",
        data: null,
      };
    }

    const targetMessageId = normalizedIds[normalizedIds.length - 1];
    const endpoint = normalizedIds.length > 1
      ? `/rooms/${params.groupId}/messages/read_until`
      : `/rooms/${params.groupId}/messages/read`;

    return post(endpoint, {
      message_id: targetMessageId,
    });
  }

  static async getUnreadMessageCount(
    params: { groupId?: string } = {},
  ): Promise<ApiResponse<any>> {
    if (params.groupId) {
      return get(`/rooms/${params.groupId}/unread_count`);
    }
    return get("/unread_counts");
  }

  static async deleteMessage(params: {
    groupId: string;
    messageId: string;
  }): Promise<ApiResponse<null>> {
    const response = await del<unknown>(
      `/rooms/${params.groupId}/messages/${params.messageId}`,
    );
    return {
      ...response,
      data: null,
    };
  }

  static async forwardMessage(params: {
    groupId: string;
    messageId: string;
    targetRoomIds: string[];
  }): Promise<ApiResponse<ForwardInfo[]>> {
    const response = await post<BackendForwardMessage[]>(
      `/rooms/${params.groupId}/messages/forward`,
      {
        message_id: params.messageId,
        target_room_ids: params.targetRoomIds,
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
      data: response.data
        .map((item) => mapForwardMessage(item))
        .filter((item): item is ForwardInfo => Boolean(item)),
    };
  }

  static async pinMessage(params: {
    groupId: string;
    messageId: string;
    currentUserId?: string;
  }): Promise<
    ApiResponse<{
      message: Message | null;
      isPinned: boolean;
      pinnedAt?: Date | null;
      pinnedBy?: string | null;
    }>
  > {
    const response = await post<BackendPinResponse>(
      `/rooms/${params.groupId}/messages/${params.messageId}/pin`,
      {},
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const mappedMessage = response.data.message
      ? transformBackendMessage(response.data.message, params.currentUserId)
      : null;

    return {
      ...response,
      data: {
        message: mappedMessage,
        isPinned: Boolean(response.data.is_pinned),
        pinnedAt: response.data.pinned_at
          ? parseTimestamp(response.data.pinned_at)
          : null,
        pinnedBy: response.data.pinned_by ?? null,
      },
    };
  }

  static async unpinMessage(params: {
    groupId: string;
    messageId: string;
  }): Promise<ApiResponse<{ isPinned: boolean }>> {
    const response = await del<{ is_pinned: boolean }>(
      `/rooms/${params.groupId}/messages/${params.messageId}/pin`,
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
        isPinned: Boolean(response.data.is_pinned),
      },
    };
  }

  static async getMessageReaders(params: {
    groupId: string;
    messageId: string;
  }): Promise<ApiResponse<MessageReader[]>> {
    const response = await get<BackendMessageReader[]>(
      `/rooms/${params.groupId}/messages/${params.messageId}/reads`,
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: response.data.map(mapBackendReader),
    };
  }

  static async ensureChatRoom(params: {
    friendId: string;
  }): Promise<ApiResponse<{ roomId: string }>> {
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
      },
    };
  }
}
