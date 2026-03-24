import type { ApiResponse } from "./http";

type BackendRoomType = "private" | "group" | "public" | "favorite";
type BackendMessageType = "text" | "image" | "audio" | "video" | "file" | "system" | "mixed";

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

const buildLastMessagePreview = (preview?: BackendChatMessagePreview | null) => {
  if (!preview) {
    return "";
  }

  const rawContent = (preview.content || "").trim();
  switch (preview.message_type) {
    case "image":
      return "[图片]";
    case "video":
      return "[视频]";
    case "audio":
      return "[语音]";
    case "file":
      return "[附件]";
    default:
      break;
  }

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

export class ChatApi {
  static async list(): Promise<ApiResponse<ChatSummary[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendChatSummary[]>>("chat.list");
    return {
      ...response,
      data: response.data ? response.data.map(mapChatSummary) : null
    };
  }
}
