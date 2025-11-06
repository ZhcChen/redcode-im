import { del, get, post } from "./http";
import type { ApiResponse } from "./http";
import type {
  Message,
  ForwardInfo,
  QuotedMessage,
  MessageReader,
  MessagePart,
  MessageAttachment,
} from "@/types/models";
import {
  MessageType,
  MessageStatus,
  ForwardSourceType,
  MessagePartType,
} from "@/types/models";

type BackendMessageType =
  | "text"
  | "image"
  | "audio"
  | "video"
  | "file"
  | "system"
  | "mixed";

type BackendMessagePartType = "text" | "image" | "video" | "audio" | "file";

interface BackendMessageAttachment {
  key: string;
  name?: string | null;
  mime?: string | null;
  size?: number | null;
  width?: number | null;
  height?: number | null;
  duration_ms?: number | null;
  thumbnail_key?: string | null;
}

interface BackendMessagePart {
  position: number;
  part_type: BackendMessagePartType;
  text?: string | null;
  attachment?: BackendMessageAttachment | null;
}

export type MessagePartTypeLiteral = "text" | "image" | "video" | "audio" | "file";

export type MessagePartPayloadInput =
  | {
      type: "text";
      text: string;
    }
  | {
      type: "image" | "video" | "audio" | "file";
      key: string;
      name?: string | null;
      mime?: string | null;
      size?: number | null;
      width?: number | null;
      height?: number | null;
      durationMs?: number | null;
      thumbnailKey?: string | null;
    };

export interface DirectUploadSignatureInfo {
  url: string;
  method: string;
  headers: Record<string, string>;
  key: string;
}

export interface AttachmentSignatureResult {
  key: string;
  signature: DirectUploadSignatureInfo;
  message?: string;
}
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
  parts?: BackendMessagePart[];
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
  parts?: BackendMessagePart[];
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
    case "mixed":
      return MessageType.MIXED;
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
    parts: mapMessageParts(quoted.parts),
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

const mapMessagePartType = (value: BackendMessagePartType): MessagePartType => {
  switch (value) {
    case "image":
      return MessagePartType.IMAGE;
    case "video":
      return MessagePartType.VIDEO;
    case "audio":
      return MessagePartType.AUDIO;
    case "file":
      return MessagePartType.FILE;
    case "text":
    default:
      return MessagePartType.TEXT;
  }
};

const mapMessageAttachment = (
  attachment?: BackendMessageAttachment | null,
): MessageAttachment | undefined => {
  if (!attachment) {
    return undefined;
  }

  return {
    key: attachment.key,
    name: attachment.name ?? null,
    mime: attachment.mime ?? null,
    size: attachment.size ?? null,
    width: attachment.width ?? null,
    height: attachment.height ?? null,
    durationMs: attachment.duration_ms ?? null,
    thumbnailKey: attachment.thumbnail_key ?? null,
  };
};

const mapMessageParts = (
  parts?: BackendMessagePart[] | null,
): MessagePart[] | undefined => {
  if (!parts || !Array.isArray(parts) || parts.length === 0) {
    return undefined;
  }

  return parts
    .map((part) => {
      if (!part || typeof part.position !== "number") {
        return null;
      }
      return {
        position: part.position,
        type: mapMessagePartType(part.part_type),
        text: part.text ?? null,
        attachment: mapMessageAttachment(part.attachment) ?? null,
      } as MessagePart;
    })
    .filter((part): part is MessagePart => Boolean(part))
    .sort((a, b) => a.position - b.position);
};

const mapPartPayloadInput = (
  part: MessagePartPayloadInput,
): Record<string, unknown> => {
  if (part.type === "text") {
    return {
      type: "text",
      text: part.text,
    };
  }

  const payload: Record<string, unknown> = {
    type: part.type,
    key: part.key,
  };

  if (part.name) {
    payload.name = part.name;
  }
  if (part.mime) {
    payload.mime = part.mime;
  }
  if (typeof part.size === "number") {
    payload.size = part.size;
  }
  if (typeof part.width === "number") {
    payload.width = part.width;
  }
  if (typeof part.height === "number") {
    payload.height = part.height;
  }
  if (typeof part.durationMs === "number") {
    payload.duration_ms = part.durationMs;
  }
  if (part.thumbnailKey) {
    payload.thumbnail_key = part.thumbnailKey;
  }

  return payload;
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
    parts: mapMessageParts(message.parts),
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

export interface SendMessageParams {
  groupId: string;
  content?: string;
  parts?: MessagePartPayloadInput[];
  replyToMessageId?: string;
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

  static async sendMessage(
    params: SendMessageParams,
  ): Promise<ApiResponse<Message>> {
    const payload: Record<string, unknown> = {};

    const trimmedContent = params.content?.trim();
    if (trimmedContent) {
      payload.content = trimmedContent;
    }

    if (params.parts && params.parts.length > 0) {
      payload.parts = params.parts.map(mapPartPayloadInput);
    }

    if (params.replyToMessageId) {
      payload.quoted_message_id = params.replyToMessageId;
    }

    if (!payload.content && !payload.parts) {
      return {
        code: 400,
        success: false,
        message: "消息内容不能为空",
        data: null,
      };
    }

    const response = await post<BackendMessageInfo | { message: BackendMessageInfo }>(
      `/rooms/${params.groupId}/messages`,
      payload,
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const rawData: any = response.data;
    const successFlag =
      typeof rawData?.success === "boolean" ? rawData.success : response.success;

    if (!successFlag) {
      return {
        code: response.code,
        success: false,
        message: typeof rawData?.message === "string"
          ? rawData.message
          : response.message || "消息发送失败",
        data: null,
      };
    }

    const messagePayload: any =
      rawData && typeof rawData === "object" && !Array.isArray(rawData)
        ? (rawData.message && typeof rawData.message === "object"
            ? rawData.message
            : rawData)
        : rawData;

    if (!messagePayload || typeof messagePayload !== "object" || !messagePayload.id) {
      return {
        code: response.code,
        success: false,
        message: "消息发送结果不完整",
        data: null,
      };
    }

    return {
      code: response.code,
      success: true,
      message: typeof rawData?.message === "string" ? rawData.message : response.message || "",
      data: transformBackendMessage(messagePayload, params.currentUserId),
    };
  }

  static async sendTextMessage(params: {
    groupId: string;
    content: string;
    replyToMessageId?: string;
    currentUserId?: string;
  }): Promise<ApiResponse<Message>> {
    return this.sendMessage({
      groupId: params.groupId,
      content: params.content,
      replyToMessageId: params.replyToMessageId,
      currentUserId: params.currentUserId,
    });
  }

  static async requestAttachmentSignature(params: {
    groupId: string;
    partType: MessagePartTypeLiteral;
    fileName?: string;
    contentType?: string;
  }): Promise<ApiResponse<AttachmentSignatureResult>> {
    const payload: Record<string, unknown> = {
      part_type: params.partType,
    };

    if (params.fileName) {
      payload.filename = params.fileName;
    }
    if (params.contentType) {
      payload.content_type = params.contentType;
    }

    const response = await post<Record<string, unknown>>(
      `/rooms/${params.groupId}/messages/attachments/signature`,
      payload,
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const rawData: any = response.data;
    const successFlag =
      typeof rawData?.success === "boolean" ? rawData.success : response.success;

    if (!successFlag) {
      return {
        code: response.code,
        success: false,
        message: typeof rawData?.message === "string"
          ? rawData.message
          : response.message || "获取附件上传签名失败",
        data: null,
      };
    }

    const signaturePayload = rawData?.signature;
    const key = rawData?.key ?? signaturePayload?.key;

    if (
      !signaturePayload ||
      typeof signaturePayload !== "object" ||
      !signaturePayload.url ||
      !key
    ) {
      return {
        code: response.code,
        success: false,
        message: "上传签名响应不完整",
        data: null,
      };
    }

    const headers: Record<string, string> = {};
    if (signaturePayload.headers && typeof signaturePayload.headers === "object") {
      Object.entries(signaturePayload.headers).forEach(([headerKey, headerValue]) => {
        if (typeof headerKey === "string" && typeof headerValue === "string") {
          headers[headerKey] = headerValue;
        }
      });
    }

    const methodRaw = typeof signaturePayload.method === "string"
      ? signaturePayload.method.trim().toUpperCase()
      : "PUT";

    const signature: DirectUploadSignatureInfo = {
      url: signaturePayload.url,
      method: methodRaw || "PUT",
      headers,
      key: signaturePayload.key ?? key,
    };

    return {
      code: response.code,
      success: true,
      message: typeof rawData?.message === "string" ? rawData.message : response.message || "",
      data: {
        key,
        signature,
        message: typeof rawData?.message === "string" ? rawData.message : undefined,
      },
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
