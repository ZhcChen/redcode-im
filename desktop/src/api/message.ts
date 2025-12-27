import { del, get, patch, post } from "./http";
import type { ApiResponse } from "./http";
import type {
  Message,
  ForwardInfo,
  QuotedMessage,
  MessageReader,
  MessagePart,
  MessageAttachment,
  MessageReactionSummary,
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
  signature: DirectUploadSignatureInfo | null;
  message?: string;
}

export interface AttachmentMultipartInitiateResult {
  key: string;
  sessionId: string | null;
  partSize?: number;
  totalParts?: number;
  message?: string;
}

export interface MultipartCompletedPart {
  partNumber: number;
  etag: string;
}

export interface AttachmentDownloadResult {
  success: boolean;
  message: string;
  downloadUrl?: string | null;
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
  /** 消息是否已编辑 */
  is_edited?: boolean;
  /** 消息编辑时间 */
  edited_at?: string | null;
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
    // 不设置 senderAvatar，避免直接使用 COS URL 导致 403 错误
    senderAvatar: undefined,
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

/**
 * 检查 URL 是否是有效的完整 URL(以 http:// 或 https:// 开头)
 * 如果是相对路径或 object key,返回 false
 */
const isValidHttpUrl = (url: string | null | undefined): boolean => {
  if (!url || typeof url !== 'string' || url.trim() === '') {
    return false;
  }
  const trimmed = url.trim();
  return trimmed.startsWith('http://') || trimmed.startsWith('https://');
};

export const transformBackendMessage = (
  message: BackendMessageInfo,
  currentUserId?: string,
): Message => {
  const senderName = message.sender_nickname?.trim()
    ? message.sender_nickname.trim()
    : message.sender_username;

  const timestamp = parseTimestamp(message.created_at);

  // 检查 sender_avatar_url 是否是有效的完整 URL
  // 如果是相对路径(如 "avatars/xxx/file.png")则将其作为 object key
  // 避免浏览器尝试加载相对路径导致 403 错误
  let senderAvatarObjectKey: string | undefined;
  if (message.sender_avatar_url && !isValidHttpUrl(message.sender_avatar_url)) {
    // sender_avatar_url 看起来像相对路径,将其作为 object key
    senderAvatarObjectKey = message.sender_avatar_url;
  }

  return {
    id: message.id,
    roomId: message.room_id,
    senderId: message.sender_id,
    senderUsername: message.sender_username,
    senderName,
    // 不设置 senderAvatar，等待后续通过 avatarObjectKey 同步头像为 blob URL
    // 这样可以避免直接使用 COS URL 导致 403 错误
    senderAvatar: undefined,
    senderAvatarObjectKey: senderAvatarObjectKey,
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
    isEdited: Boolean(message.is_edited),
    editedAt: message.edited_at ? parseTimestamp(message.edited_at) : null,
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
  static async generateMessageAttachmentSignature(params: {
    roomId: string;
    partType: number;
    filename?: string;
    contentType?: string;
    fileSize?: number;
  }): Promise<ApiResponse<{ key: string; signature: any }>> {
    const response = await post<{ key: string; signature: any }>(
      `/rooms/${params.roomId}/messages/attachments/signature`,
      {
        part_type: params.partType,
        filename: params.filename,
        content_type: params.contentType,
        file_size: params.fileSize,
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
        key: response.data.key,
        signature: response.data.signature,
      },
    };
  }

  static async updateNotificationSettings(params: {
    roomId: string;
    notificationSettings: number; // 0 = all, 1 = mentions only, 2 = muted
  }): Promise<ApiResponse<{ notificationSettings: number }>> {
    const response = await post<{ notificationSettings: number }>(
      `/rooms/${params.roomId}/notification-settings`,
      { notification_settings: params.notificationSettings },
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
        notificationSettings: response.data.notificationSettings,
      },
    };
  }

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
    fileSize?: number;
    hashValue?: string;
    hashAlg?: number;
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
    if (typeof params.fileSize === "number" && params.fileSize > 0) {
      payload.file_size = params.fileSize;
    }
    if (params.hashValue) {
      payload.hash_value = params.hashValue;
    }
    if (typeof params.hashAlg === "number") {
      payload.hash_alg = params.hashAlg;
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

    const rawSignature = rawData?.signature ?? null;
    const key = rawData?.key ?? rawSignature?.key ?? null;

    if (!key || typeof key !== "string") {
      return {
        code: response.code,
        success: false,
        message: "上传签名响应不包含有效的 key",
        data: null,
      };
    }

    let signature: DirectUploadSignatureInfo | null = null;
    if (
      rawSignature &&
      typeof rawSignature === "object" &&
      typeof rawSignature.url === "string" &&
      rawSignature.url.length > 0
    ) {
      const headers: Record<string, string> = {};
      if (rawSignature.headers && typeof rawSignature.headers === "object") {
        Object.entries(rawSignature.headers).forEach(([headerKey, headerValue]) => {
          if (typeof headerKey === "string" && typeof headerValue === "string") {
            headers[headerKey] = headerValue;
          }
        });
      }

      const methodRaw = typeof rawSignature.method === "string"
        ? rawSignature.method.trim().toUpperCase()
        : "PUT";

      signature = {
        url: rawSignature.url,
        method: methodRaw || "PUT",
        headers,
        key: rawSignature.key ?? key,
      };
    }

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

  static async initiateAttachmentMultipartUpload(params: {
    groupId: string;
    partType: MessagePartTypeLiteral;
    fileName?: string;
    contentType?: string;
    fileSize: number;
    hashValue?: string;
    hashAlg?: number;
  }): Promise<ApiResponse<AttachmentMultipartInitiateResult>> {
    const payload: Record<string, unknown> = {
      part_type: params.partType,
      file_size: params.fileSize,
    };

    if (params.fileName) {
      payload.filename = params.fileName;
    }
    if (params.contentType) {
      payload.content_type = params.contentType;
    }
    if (params.hashValue) {
      payload.hash_value = params.hashValue;
    }
    if (typeof params.hashAlg === "number") {
      payload.hash_alg = params.hashAlg;
    }

    const response = await post<Record<string, unknown>>(
      `/rooms/${params.groupId}/messages/attachments/multipart/initiate`,
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
        message:
          typeof rawData?.message === "string"
            ? rawData.message
            : response.message || "初始化分片上传失败",
        data: null,
      };
    }

    const key = rawData?.key ?? null;
    if (!key || typeof key !== "string") {
      return {
        code: response.code,
        success: false,
        message: "分片上传初始化响应不包含有效的 key",
        data: null,
      };
    }

    const sessionIdRaw = rawData?.session_id ?? rawData?.sessionId ?? null;
    const sessionId =
      typeof sessionIdRaw === "string" && sessionIdRaw.length > 0
        ? sessionIdRaw
        : null;

    const partSizeRaw = rawData?.part_size ?? rawData?.partSize ?? null;
    const totalPartsRaw = rawData?.total_parts ?? rawData?.totalParts ?? null;

    const partSize =
      typeof partSizeRaw === "number" && partSizeRaw > 0 ? partSizeRaw : undefined;
    const totalParts =
      typeof totalPartsRaw === "number" && totalPartsRaw > 0
        ? totalPartsRaw
        : undefined;

    const message =
      typeof rawData?.message === "string" ? rawData.message : response.message || "";

    return {
      code: response.code,
      success: true,
      message,
      data: {
        key,
        sessionId,
        partSize,
        totalParts,
        message,
      },
    };
  }

  static async generateMultipartPartSignature(params: {
    sessionId: string;
    partNumber: number;
  }): Promise<ApiResponse<{ signature: DirectUploadSignatureInfo }>> {
    const response = await post<Record<string, unknown>>(
      `/uploads/multipart/sessions/${params.sessionId}/parts/signature`,
      { part_number: params.partNumber },
    );

    if (!response.success || !response.data) {
      return {
        code: response.code,
        success: false,
        message: response.message || "获取分片上传签名失败",
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
        message:
          typeof rawData?.message === "string"
            ? rawData.message
            : response.message || "获取分片上传签名失败",
        data: null,
      };
    }

    const rawSignature = rawData?.signature ?? null;
    if (!rawSignature || typeof rawSignature !== "object") {
      return {
        code: response.code,
        success: false,
        message: "分片上传签名响应不包含有效的 signature",
        data: null,
      };
    }

    const headers: Record<string, string> = {};
    if (rawSignature.headers && typeof rawSignature.headers === "object") {
      Object.entries(rawSignature.headers).forEach(([headerKey, headerValue]) => {
        if (typeof headerKey === "string" && typeof headerValue === "string") {
          headers[headerKey] = headerValue;
        }
      });
    }

    const signature: DirectUploadSignatureInfo = {
      url: rawSignature.url,
      method: typeof rawSignature.method === "string" ? rawSignature.method : "PUT",
      headers,
      key: rawSignature.key,
    };

    return {
      code: response.code,
      success: true,
      message: typeof rawData?.message === "string" ? rawData.message : response.message || "",
      data: { signature },
    };
  }

  static async commitMultipartPart(params: {
    sessionId: string;
    partNumber: number;
    etag: string;
  }): Promise<ApiResponse<{ success: boolean; message: string }>> {
    const response = await post<Record<string, unknown>>(
      `/uploads/multipart/sessions/${params.sessionId}/parts/commit`,
      { part_number: params.partNumber, etag: params.etag },
    );

    if (!response.success || !response.data) {
      return {
        code: response.code,
        success: false,
        message: response.message || "提交分片进度失败",
        data: null,
      };
    }

    const rawData: any = response.data;
    const successFlag =
      typeof rawData?.success === "boolean" ? rawData.success : response.success;
    const message =
      typeof rawData?.message === "string" ? rawData.message : response.message || "";

    return {
      code: response.code,
      success: successFlag,
      message,
      data: { success: successFlag, message },
    };
  }

  static async completeMultipartUpload(params: {
    sessionId: string;
    parts: MultipartCompletedPart[];
  }): Promise<ApiResponse<{ success: boolean; message: string }>> {
    const response = await post<Record<string, unknown>>(
      `/uploads/multipart/sessions/${params.sessionId}/complete`,
      {
        parts: params.parts.map((part) => ({
          part_number: part.partNumber,
          etag: part.etag,
        })),
      },
    );

    if (!response.success || !response.data) {
      return {
        code: response.code,
        success: false,
        message: response.message || "完成分片上传失败",
        data: null,
      };
    }

    const rawData: any = response.data;
    const successFlag =
      typeof rawData?.success === "boolean" ? rawData.success : response.success;
    const message =
      typeof rawData?.message === "string" ? rawData.message : response.message || "";

    return {
      code: response.code,
      success: successFlag,
      message,
      data: { success: successFlag, message },
    };
  }

  static async abortMultipartUpload(params: {
    sessionId: string;
  }): Promise<ApiResponse<{ success: boolean; message: string }>> {
    const response = await post<Record<string, unknown>>(
      `/uploads/multipart/sessions/${params.sessionId}/abort`,
      {},
    );

    if (!response.success || !response.data) {
      return {
        code: response.code,
        success: false,
        message: response.message || "中止分片上传失败",
        data: null,
      };
    }

    const rawData: any = response.data;
    const successFlag =
      typeof rawData?.success === "boolean" ? rawData.success : response.success;
    const message =
      typeof rawData?.message === "string" ? rawData.message : response.message || "";

    return {
      code: response.code,
      success: successFlag,
      message,
      data: { success: successFlag, message },
    };
  }

  static async getAttachmentDownloadUrl(params: {
    roomId: string;
    key: string;
    expiresInSeconds?: number;
  }): Promise<ApiResponse<AttachmentDownloadResult>> {
    const query: Record<string, string | number> = {
      key: params.key,
    };

    if (typeof params.expiresInSeconds === "number") {
      query.expires_in_seconds = params.expiresInSeconds;
    }

    const response = await get<Record<string, unknown>>(
      `/rooms/${params.roomId}/messages/attachments/download`,
      query,
    );

    if (!response.success || !response.data) {
      return {
        code: response.code,
        success: false,
        message: response.message || "获取附件下载链接失败",
        data: null,
      };
    }

    const rawData: any = response.data;
    const successFlag = typeof rawData?.success === "boolean"
      ? rawData.success
      : response.success;
    const downloadUrl = rawData?.download_url ?? rawData?.downloadUrl ?? null;

    if (!successFlag || typeof downloadUrl !== "string" || downloadUrl.length === 0) {
      return {
        code: response.code,
        success: false,
        message: typeof rawData?.message === "string"
          ? rawData.message
          : response.message || "附件下载链接无效",
        data: null,
      };
    }

    const message = typeof rawData?.message === "string" ? rawData.message : response.message || "";

    return {
      code: response.code,
      success: true,
      message,
      data: {
        success: true,
        message,
        downloadUrl,
      },
    };
  }

  static async commitAttachmentUpload(params: {
    roomId: string;
    key: string;
    hashValue?: string;
    hashAlg?: number;
    fileSize?: number;
  }): Promise<ApiResponse<{ success: boolean; message: string }>> {
    const payload: Record<string, unknown> = {
      key: params.key,
    };

    if (params.hashValue) {
      payload.hash_value = params.hashValue;
    }
    if (typeof params.hashAlg === "number") {
      payload.hash_alg = params.hashAlg;
    }
    if (typeof params.fileSize === "number" && params.fileSize > 0) {
      payload.file_size = params.fileSize;
    }

    const response = await post<Record<string, unknown>>(
      `/rooms/${params.roomId}/messages/attachments/commit`,
      payload,
    );

    if (!response.success || !response.data) {
      return {
        code: response.code,
        success: false,
        message: response.message || "标记附件上传完成失败",
        data: null,
      };
    }

    const rawData: any = response.data;
    const successFlag = typeof rawData?.success === "boolean"
      ? rawData.success
      : response.success;
    const message = typeof rawData?.message === "string"
      ? rawData.message
      : response.message || "";

    return {
      code: response.code,
      success: successFlag,
      message,
      data: {
        success: successFlag,
        message,
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

  /**
   * 编辑消息（仅支持编辑自己发送的文本消息）
   */
  static async editMessage(params: {
    groupId: string;
    messageId: string;
    content: string;
  }): Promise<ApiResponse<Message | null>> {
    const response = await patch<{ message?: BackendMessageInfo }>(
      `/rooms/${params.groupId}/messages/${params.messageId}`,
      { content: params.content },
    );

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const rawData = response.data as Record<string, unknown>;
    // 后端直接返回 MessageInfo 结构，不需要 .message 包装
    const backendMessage = (rawData.id ? rawData : rawData.message) as BackendMessageInfo | undefined;
    if (!backendMessage) {
      return {
        ...response,
        data: null,
      };
    }

    return {
      ...response,
      data: transformBackendMessage(backendMessage, backendMessage.sender_id),
    };
  }

  static async forwardMessage(params: {
    targetRoomId: string;
    originalMessageId: string;
  }): Promise<ApiResponse<null>> {
    const response = await post<{ message: BackendMessageInfo }>(
      `/rooms/${params.targetRoomId}/messages/forward`,
      {
        original_message_id: params.originalMessageId,
      },
    );

    return {
      ...response,
      data: null,
    };
  }

  /**
   * 添加消息反应
   */
  static async addReaction(params: {
    groupId: string;
    messageId: string;
    reactionKey: string;
  }): Promise<ApiResponse<{ summaries: MessageReactionSummary[] } | null>> {
    const response = await post<{
      success: boolean;
      message: string;
      summaries?: MessageReactionSummary[];
    }>(
      `/rooms/${params.groupId}/messages/${params.messageId}/reactions`,
      { reaction_key: params.reactionKey },
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
        summaries: response.data.summaries || [],
      },
    };
  }

  /**
   * 删除消息反应
   */
  static async removeReaction(params: {
    groupId: string;
    messageId: string;
    reactionKey: string;
  }): Promise<ApiResponse<{ summaries: MessageReactionSummary[] } | null>> {
    // DELETE 请求使用 query 参数传递 reaction_key
    const response = await del<{
      success: boolean;
      message: string;
      summaries?: MessageReactionSummary[];
    }>(
      `/rooms/${params.groupId}/messages/${params.messageId}/reactions?reaction_key=${encodeURIComponent(params.reactionKey)}`,
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
        summaries: response.data.summaries || [],
      },
    };
  }

  /**
   * 获取消息的所有反应
   */
  static async getReactions(params: {
    groupId: string;
    messageId: string;
  }): Promise<ApiResponse<{ summaries: MessageReactionSummary[] } | null>> {
    const response = await get<{
      success: boolean;
      message: string;
      summaries?: MessageReactionSummary[];
    }>(
      `/rooms/${params.groupId}/messages/${params.messageId}/reactions`,
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
        summaries: response.data.summaries || [],
      },
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

  // 群组管理API
  static async addGroupMembers(params: {
    roomId: string;
    userIds: string[];
  }): Promise<ApiResponse<null>> {
    const response = await post(`/rooms/${params.roomId}/members/add`, {
      user_ids: params.userIds,
    });
    return {
      ...response,
      data: null,
    };
  }

  static async removeGroupMember(params: {
    roomId: string;
    userId: string;
  }): Promise<ApiResponse<null>> {
    const response = await del(`/rooms/${params.roomId}/members/${params.userId}`);
    return {
      ...response,
      data: null,
    };
  }

  static async clearGroupHistory(params: {
    roomId: string;
  }): Promise<ApiResponse<null>> {
    const response = await del(`/rooms/${params.roomId}/messages`);
    return {
      ...response,
      data: null,
    };
  }

  static async leaveGroup(params: {
    roomId: string;
  }): Promise<ApiResponse<null>> {
    const response = await post(`/rooms/${params.roomId}/leave`);
    return {
      ...response,
      data: null,
    };
  }
}
