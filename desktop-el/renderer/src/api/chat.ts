import type { ApiResponse } from "./http";

type BackendRoomType = "private" | "group" | "public" | "favorite";
type BackendMessageType = "text" | "image" | "audio" | "video" | "file" | "system" | "mixed";
type BackendMessagePartType = "text" | "image" | "audio" | "video" | "file";
type BackendMessageDeliveryStatus = "sent" | "read";

interface BackendChatMessagePreview {
  id: string;
  content: string;
  message_type: BackendMessageType;
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
  notification_settings?: number;
  is_muted?: boolean;
  is_pinned?: boolean;
  last_message?: BackendChatMessagePreview | null;
  friend_user_id?: string | null;
  friend_nickname?: string | null;
  friend_username?: string | null;
  friend_remark?: string | null;
  friend_avatar_object_key?: string | null;
}

interface BackendEnsurePrivateChatResponse {
  room_id: string;
  room_name: string;
  room_type: BackendRoomType;
  friend_id: string;
  friend_name: string;
  friend_avatar?: string | null;
  friend_avatar_object_key?: string | null;
}

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

interface BackendMessageInfo {
  id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
  sender_avatar_url?: string | null;
  content: string;
  message_type: BackendMessageType;
  status?: BackendMessageDeliveryStatus | null;
  created_at: string;
  is_deleted?: boolean;
  is_edited?: boolean;
  parts?: BackendMessagePart[];
}

export interface ChatSummary {
  id: string;
  roomId: string;
  title: string;
  subtitle: string | null;
  roomType: BackendRoomType;
  unreadCount: number;
  isMuted: boolean;
  isPinned: boolean;
  avatarUrl: string | null;
  avatarObjectKey: string | null;
  description: string | null;
  lastMessagePreview: string;
  lastMessageAt: Date | null;
  lastMessageType: BackendMessageType | null;
  friendUserId: string | null;
  friendRemark: string | null;
  friendNickname: string | null;
  friendUsername: string | null;
}

export interface EnsuredPrivateChat {
  roomId: string;
  roomName: string;
  roomType: BackendRoomType;
  friendId: string;
  friendName: string;
  friendAvatar: string | null;
  friendAvatarObjectKey: string | null;
}

export interface ChatMessage {
  id: string;
  roomId: string;
  senderId: string;
  senderUsername: string;
  senderName: string;
  senderAvatarUrl: string | null;
  content: string;
  preview: string;
  messageType: BackendMessageType;
  deliveryStatus: BackendMessageDeliveryStatus | null;
  createdAt: Date | null;
  isDeleted: boolean;
  isEdited: boolean;
  isSelf: boolean;
}

const requireDesktopRuntime = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl;
};

const parseTimestamp = (value?: string | null): Date | null => {
  if (!value) {
    return null;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed;
};

const isEmojiOnlyPreviewText = (text: string): boolean => {
  const trimmed = text.trim();
  if (!trimmed) {
    return false;
  }

  const normalized = trimmed.replace(/[\uFE0F\u200D]/g, "");
  return /^(?:[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}])+$/u.test(normalized);
};

const previewLabelForType = (type?: BackendMessageType | BackendMessagePartType | null) => {
  switch (type) {
    case "image":
      return "[图片]";
    case "video":
      return "[视频]";
    case "audio":
      return "[语音]";
    case "file":
      return "[附件]";
    case "system":
      return "[系统消息]";
    default:
      return "";
  }
};

const normalizePreviewText = (rawContent: string) => {
  if (!rawContent) {
    return "";
  }
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

const buildPartsPreview = (parts: BackendMessagePart[] = []) => {
  const textContent = parts
    .filter((part) => part.part_type === "text" && part.text?.trim())
    .map((part) => part.text!.trim())
    .join(" ")
    .trim();
  if (textContent) {
    return normalizePreviewText(textContent);
  }

  const firstAttachment = parts.find((part) => part.part_type !== "text");
  return previewLabelForType(firstAttachment?.part_type);
};

const buildMessagePreview = (payload: {
  content?: string | null;
  messageType?: BackendMessageType | null;
  parts?: BackendMessagePart[];
  isDeleted?: boolean;
}) => {
  if (payload.isDeleted) {
    return "[消息已删除]";
  }

  const typedLabel = previewLabelForType(payload.messageType);
  if (typedLabel && payload.messageType !== "text" && payload.messageType !== "mixed") {
    return typedLabel;
  }

  const rawContent = (payload.content || "").trim();
  if (rawContent) {
    return normalizePreviewText(rawContent);
  }

  return buildPartsPreview(payload.parts);
};

const buildLastMessagePreview = (preview?: BackendChatMessagePreview | null) => {
  if (!preview) {
    return "";
  }

  return buildMessagePreview({
    content: preview.content,
    messageType: preview.message_type
  });
};

const buildChatTitle = (summary: BackendChatSummary) =>
  summary.friend_remark || summary.friend_nickname || summary.name || summary.friend_username || "未命名会话";

const buildChatSubtitle = (summary: BackendChatSummary) => {
  if (summary.room_type === "private") {
    return summary.friend_username || summary.description || null;
  }
  return summary.description || null;
};

const mapChatSummary = (summary: BackendChatSummary): ChatSummary => ({
  id: summary.room_id,
  roomId: summary.room_id,
  title: buildChatTitle(summary),
  subtitle: buildChatSubtitle(summary),
  roomType: summary.room_type,
  unreadCount: summary.unread_count,
  isMuted: Boolean(summary.is_muted),
  isPinned: Boolean(summary.is_pinned),
  avatarUrl: summary.avatar_url ?? null,
  avatarObjectKey: summary.room_avatar_object_key ?? summary.friend_avatar_object_key ?? null,
  description: summary.description ?? null,
  lastMessagePreview: buildLastMessagePreview(summary.last_message),
  lastMessageAt: parseTimestamp(summary.last_message?.created_at),
  lastMessageType: summary.last_message?.message_type ?? null,
  friendUserId: summary.friend_user_id ?? null,
  friendRemark: summary.friend_remark ?? null,
  friendNickname: summary.friend_nickname ?? null,
  friendUsername: summary.friend_username ?? null
});

const mapEnsuredPrivateChat = (response: BackendEnsurePrivateChatResponse): EnsuredPrivateChat => ({
  roomId: response.room_id,
  roomName: response.room_name,
  roomType: response.room_type,
  friendId: response.friend_id,
  friendName: response.friend_name,
  friendAvatar: response.friend_avatar ?? null,
  friendAvatarObjectKey: response.friend_avatar_object_key ?? null
});

const mapChatMessage = (message: BackendMessageInfo, currentUserId?: string): ChatMessage => {
  const senderName = message.sender_nickname?.trim() || message.sender_username;
  const preview = buildMessagePreview({
    content: message.content,
    messageType: message.message_type,
    parts: message.parts ?? [],
    isDeleted: message.is_deleted
  });

  return {
    id: message.id,
    roomId: message.room_id,
    senderId: message.sender_id,
    senderUsername: message.sender_username,
    senderName,
    senderAvatarUrl: message.sender_avatar_url ?? null,
    content: message.content,
    preview,
    messageType: message.message_type,
    deliveryStatus: message.status ?? null,
    createdAt: parseTimestamp(message.created_at),
    isDeleted: Boolean(message.is_deleted),
    isEdited: Boolean(message.is_edited),
    isSelf: currentUserId === message.sender_id
  };
};

export class ChatApi {
  static async list(): Promise<ApiResponse<ChatSummary[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendChatSummary[]>>("chat.list");
    return {
      ...response,
      data: response.data ? response.data.map(mapChatSummary) : null
    };
  }

  static async ensurePrivateChat(params: { friendUserId: string }): Promise<ApiResponse<EnsuredPrivateChat>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendEnsurePrivateChatResponse>>(
      "chat.private.ensure",
      {
        friend_user_id: params.friendUserId
      }
    );
    return {
      ...response,
      data: response.data ? mapEnsuredPrivateChat(response.data) : null
    };
  }

  static async listMessages(params: {
    roomId: string;
    limit?: number;
    beforeId?: string;
    sinceId?: string;
    currentUserId?: string;
  }): Promise<ApiResponse<ChatMessage[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendMessageInfo[]>>("chat.messages.list", {
      room_id: params.roomId,
      limit: params.limit,
      before_id: params.beforeId,
      since_id: params.sinceId
    });
    return {
      ...response,
      data: response.data ? response.data.map((message) => mapChatMessage(message, params.currentUserId)).reverse() : null
    };
  }
}
