import type { ApiResponse } from "./http";

type BackendRoomType = "private" | "group" | "public" | "favorite";
type BackendMessageType =
  | "text"
  | "image"
  | "audio"
  | "video"
  | "file"
  | "system"
  | "mixed";
type BackendMessagePartType = "text" | "image" | "audio" | "video" | "file";
type BackendMessageDeliveryStatus = "sent" | "read";
type AttachmentPartType = Exclude<BackendMessagePartType, "text">;

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

interface BackendCreateGroupRoom {
  id: string;
  name: string;
  room_type: BackendRoomType;
}

interface BackendCreateGroupResponse {
  room: BackendCreateGroupRoom;
}

type BackendRoomMemberRole = "owner" | "admin" | "member";

interface BackendRoomInfo {
  id: string;
  name: string;
  description?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
  room_type: BackendRoomType;
  owner_id: string;
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

interface BackendRoomDetailResponse {
  success?: boolean;
  room: BackendRoomInfo;
}

interface BackendRoomMember {
  user_id: string;
  username: string;
  nickname?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
  role: BackendRoomMemberRole;
  joined_at?: string | null;
}

interface BackendGroupSettings {
  id: string;
  room_id: string;
  join_approval_required: boolean;
  member_can_invite: boolean;
  member_can_add_friends: boolean;
  require_admin_to_add_friends: boolean;
  max_members: number;
  global_mute_enabled: boolean;
  global_mute_until?: string | null;
  global_mute_reason?: string | null;
  global_mute_set_by?: string | null;
  created_at: string;
  updated_at: string;
}

interface BackendGroupMyMute {
  is_muted: boolean;
  reason?: string | null;
  muted_at?: string | null;
  mute_until?: string | null;
}

interface BackendGroupSettingsResponse {
  settings: BackendGroupSettings;
  my_mute?: BackendGroupMyMute | null;
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

interface BackendAttachmentDownloadPayload {
  success?: boolean;
  message?: string;
  download_url?: string | null;
  downloadUrl?: string | null;
}

interface BackendDirectUploadSignature {
  url?: string | null;
  method?: string | null;
  headers?: Record<string, string> | null;
  key?: string | null;
}

interface BackendAttachmentSignaturePayload {
  success?: boolean;
  message?: string;
  key?: string | null;
  signature?: BackendDirectUploadSignature | null;
}

interface BackendAttachmentMultipartInitiatePayload {
  success?: boolean;
  message?: string;
  key?: string | null;
  session_id?: string | null;
  sessionId?: string | null;
  part_size?: number | null;
  partSize?: number | null;
  total_parts?: number | null;
  totalParts?: number | null;
}

interface BackendMultipartSimplePayload {
  success?: boolean;
  message?: string;
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
  quoted_message?: BackendQuotedMessage | null;
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

export interface CreatedGroupChat {
  roomId: string;
  roomName: string;
  roomType: BackendRoomType;
}

export interface ChatRoomDetail {
  roomId: string;
  roomName: string;
  roomType: BackendRoomType;
  description: string | null;
  avatarUrl: string | null;
  avatarObjectKey: string | null;
  ownerId: string;
  createdAt: Date | null;
  updatedAt: Date | null;
}

export interface ChatRoomMember {
  userId: string;
  username: string;
  nickname: string | null;
  avatarUrl: string | null;
  avatarObjectKey: string | null;
  role: BackendRoomMemberRole;
  joinedAt: Date | null;
}

export interface ChatGroupMyMute {
  isMuted: boolean;
  reason: string | null;
  mutedAt: Date | null;
  muteUntil: Date | null;
}

export interface ChatGroupSettings {
  roomId: string;
  joinApprovalRequired: boolean;
  memberCanInvite: boolean;
  memberCanAddFriends: boolean;
  requireAdminToAddFriends: boolean;
  maxMembers: number;
  globalMuteEnabled: boolean;
  globalMuteUntil: Date | null;
  globalMuteReason: string | null;
  globalMuteSetBy: string | null;
  createdAt: Date | null;
  updatedAt: Date | null;
  myMute: ChatGroupMyMute | null;
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
  quotedMessage: ChatQuotedMessage | null;
  parts: ChatMessagePart[];
}

export interface ChatQuotedMessage {
  id: string;
  roomId: string;
  senderId: string;
  senderUsername: string;
  senderName: string;
  senderAvatarUrl: string | null;
  content: string | null;
  messageType: BackendMessageType;
  createdAt: Date | null;
  isDeleted: boolean;
  parts: ChatMessagePart[];
}

export interface ChatMessageAttachment {
  key: string;
  name: string | null;
  mime: string | null;
  size: number | null;
  width: number | null;
  height: number | null;
  durationMs: number | null;
  thumbnailKey: string | null;
}

export interface ChatMessagePart {
  position: number;
  partType: BackendMessagePartType;
  text: string | null;
  attachment: ChatMessageAttachment | null;
}

export interface AttachmentDownloadData {
  success: boolean;
  message: string;
  downloadUrl: string;
}

export interface DirectUploadSignatureInfo {
  url: string;
  method: string;
  headers: Record<string, string>;
  key: string;
}

export interface AttachmentSignatureData {
  key: string;
  signature: DirectUploadSignatureInfo | null;
  message?: string;
}

export interface AttachmentMultipartInitiateData {
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

export interface SimpleSuccessData {
  success: boolean;
  message: string;
}

export type ChatMessagePartInput =
  | {
      type: "text";
      text: string;
    }
  | {
      type: AttachmentPartType;
      key: string;
      name?: string | null;
      mime?: string | null;
      size?: number | null;
      width?: number | null;
      height?: number | null;
      durationMs?: number | null;
      thumbnailKey?: string | null;
    };

interface BackendSendMessagePayload {
  message?: BackendMessageInfo;
}

interface BackendPushMessage {
  type: "message";
  id: string;
  message_id: string;
  room_id: string;
  sender_id: string;
  sender_username: string;
  sender_nickname?: string | null;
  sender_avatar_url?: string | null;
  content: string;
  message_type: BackendMessageType;
  timestamp: string;
  quoted_message?: BackendQuotedMessage | null;
  parts?: BackendMessagePart[];
}

interface BackendPushMessageRead {
  type: "message_read";
  room_id: string;
  message_id: string;
  reader_id: string;
  read_at: string;
}

interface BackendPushMessageUpdate {
  type: "message_update";
  room_id: string;
  message_id: string;
  is_deleted?: boolean;
  deleted_at?: string | null;
}

interface BackendPushRoomCreated {
  type: "room_created";
  room_id: string;
  room_name: string;
  room_type: BackendRoomType;
  initiator_id: string;
  owner_id: string;
  description?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
  created_at?: string | null;
}

interface BackendPushRoomUpdated {
  type: "room_updated";
  room_id: string;
  room_name: string;
  room_type: BackendRoomType;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
  description?: string | null;
}

interface BackendPushGroupSettingsUpdated {
  type: "group_settings_updated";
  room_id: string;
  global_mute_enabled: boolean;
  global_mute_reason?: string | null;
  global_mute_until?: string | null;
  global_mute_set_by?: string | null;
}

interface BackendPushGroupMemberChanged {
  type: "group_member_changed";
  room_id: string;
  member_id: string;
  change_type: string;
  new_role?: string | null;
  operator_id?: string | null;
  reason?: string | null;
  until?: string | null;
}

export type ChatWebSocketPush =
  | BackendPushMessage
  | BackendPushMessageRead
  | BackendPushMessageUpdate
  | BackendPushRoomCreated
  | BackendPushRoomUpdated
  | BackendPushGroupSettingsUpdated
  | BackendPushGroupMemberChanged
  | {
      type: string;
      [key: string]: unknown;
    };

export type ChatRealtimeEvent =
  | {
      type: "message";
      message: ChatMessage;
    }
  | {
      type: "message_read";
      roomId: string;
      messageId: string;
      readerId: string;
      readAt: Date | null;
    }
  | {
      type: "message_update";
      roomId: string;
      messageId: string;
      isDeleted: boolean;
      deletedAt: Date | null;
    }
  | {
      type: "room_created";
      roomId: string;
      roomName: string;
      roomType: BackendRoomType;
      initiatorId: string;
      ownerId: string;
      description: string | null;
      avatarUrl: string | null;
      avatarObjectKey: string | null;
      createdAt: Date | null;
    }
  | {
      type: "room_updated";
      roomId: string;
      roomName: string;
      roomType: BackendRoomType;
      avatarUrl: string | null;
      avatarObjectKey: string | null;
      description: string | null;
    }
  | {
      type: "group_settings_updated";
      roomId: string;
      globalMuteEnabled: boolean;
      globalMuteReason: string | null;
      globalMuteUntil: Date | null;
      globalMuteSetBy: string | null;
    }
  | {
      type: "group_member_changed";
      roomId: string;
      memberId: string;
      changeType: string;
      newRole: string | null;
      operatorId: string | null;
      reason: string | null;
      until: Date | null;
    };

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

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const isBackendPushMessage = (value: unknown): value is BackendPushMessage =>
  isRecord(value) &&
  value.type === "message" &&
  typeof value.room_id === "string" &&
  typeof value.message_id === "string" &&
  typeof value.sender_id === "string" &&
  typeof value.sender_username === "string" &&
  typeof value.content === "string" &&
  typeof value.message_type === "string" &&
  typeof value.timestamp === "string";

const isBackendPushMessageRead = (
  value: unknown,
): value is BackendPushMessageRead =>
  isRecord(value) &&
  value.type === "message_read" &&
  typeof value.room_id === "string" &&
  typeof value.message_id === "string" &&
  typeof value.reader_id === "string";

const isBackendPushMessageUpdate = (
  value: unknown,
): value is BackendPushMessageUpdate =>
  isRecord(value) &&
  value.type === "message_update" &&
  typeof value.room_id === "string" &&
  typeof value.message_id === "string";

const isBackendPushRoomCreated = (
  value: unknown,
): value is BackendPushRoomCreated =>
  isRecord(value) &&
  value.type === "room_created" &&
  typeof value.room_id === "string" &&
  typeof value.room_name === "string" &&
  typeof value.room_type === "string" &&
  typeof value.initiator_id === "string" &&
  typeof value.owner_id === "string";

const isBackendPushRoomUpdated = (
  value: unknown,
): value is BackendPushRoomUpdated =>
  isRecord(value) &&
  value.type === "room_updated" &&
  typeof value.room_id === "string" &&
  typeof value.room_name === "string" &&
  typeof value.room_type === "string";

const isBackendPushGroupSettingsUpdated = (
  value: unknown,
): value is BackendPushGroupSettingsUpdated =>
  isRecord(value) &&
  value.type === "group_settings_updated" &&
  typeof value.room_id === "string" &&
  typeof value.global_mute_enabled === "boolean";

const isBackendPushGroupMemberChanged = (
  value: unknown,
): value is BackendPushGroupMemberChanged =>
  isRecord(value) &&
  value.type === "group_member_changed" &&
  typeof value.room_id === "string" &&
  typeof value.member_id === "string" &&
  typeof value.change_type === "string";

const isEmojiOnlyPreviewText = (text: string): boolean => {
  const trimmed = text.trim();
  if (!trimmed) {
    return false;
  }

  const normalized = trimmed.replace(/[\uFE0F\u200D]/g, "");
  return /^(?:[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}])+$/u.test(
    normalized,
  );
};

const previewLabelForType = (
  type?: BackendMessageType | BackendMessagePartType | null,
) => {
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
  if (
    typedLabel &&
    payload.messageType !== "text" &&
    payload.messageType !== "mixed"
  ) {
    return typedLabel;
  }

  const rawContent = (payload.content || "").trim();
  if (rawContent) {
    return normalizePreviewText(rawContent);
  }

  return buildPartsPreview(payload.parts);
};

const buildLastMessagePreview = (
  preview?: BackendChatMessagePreview | null,
) => {
  if (!preview) {
    return "";
  }

  return buildMessagePreview({
    content: preview.content,
    messageType: preview.message_type,
  });
};

const buildChatTitle = (summary: BackendChatSummary) =>
  summary.friend_remark ||
  summary.friend_nickname ||
  summary.name ||
  summary.friend_username ||
  "未命名会话";

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
  avatarObjectKey:
    summary.room_avatar_object_key ?? summary.friend_avatar_object_key ?? null,
  description: summary.description ?? null,
  lastMessagePreview: buildLastMessagePreview(summary.last_message),
  lastMessageAt: parseTimestamp(summary.last_message?.created_at),
  lastMessageType: summary.last_message?.message_type ?? null,
  friendUserId: summary.friend_user_id ?? null,
  friendRemark: summary.friend_remark ?? null,
  friendNickname: summary.friend_nickname ?? null,
  friendUsername: summary.friend_username ?? null,
});

const mapEnsuredPrivateChat = (
  response: BackendEnsurePrivateChatResponse,
): EnsuredPrivateChat => ({
  roomId: response.room_id,
  roomName: response.room_name,
  roomType: response.room_type,
  friendId: response.friend_id,
  friendName: response.friend_name,
  friendAvatar: response.friend_avatar ?? null,
  friendAvatarObjectKey: response.friend_avatar_object_key ?? null,
});

const mapCreatedGroupChat = (
  response: BackendCreateGroupResponse,
): CreatedGroupChat => ({
  roomId: response.room.id,
  roomName: response.room.name,
  roomType: response.room.room_type,
});

const mapChatRoomDetail = (
  response: BackendRoomDetailResponse,
): ChatRoomDetail => ({
  roomId: response.room.id,
  roomName: response.room.name,
  roomType: response.room.room_type,
  description: response.room.description ?? null,
  avatarUrl: response.room.avatar_url ?? null,
  avatarObjectKey: response.room.avatar_object_key ?? null,
  ownerId: response.room.owner_id,
  createdAt: parseTimestamp(response.room.created_at),
  updatedAt: parseTimestamp(response.room.updated_at),
});

const mapChatRoomMember = (member: BackendRoomMember): ChatRoomMember => ({
  userId: member.user_id,
  username: member.username,
  nickname: member.nickname ?? null,
  avatarUrl: member.avatar_url ?? null,
  avatarObjectKey: member.avatar_object_key ?? null,
  role: member.role,
  joinedAt: parseTimestamp(member.joined_at),
});

const mapChatGroupSettings = (
  response: BackendGroupSettingsResponse,
): ChatGroupSettings => ({
  roomId: response.settings.room_id,
  joinApprovalRequired: Boolean(response.settings.join_approval_required),
  memberCanInvite: Boolean(response.settings.member_can_invite),
  memberCanAddFriends: Boolean(response.settings.member_can_add_friends),
  requireAdminToAddFriends: Boolean(
    response.settings.require_admin_to_add_friends,
  ),
  maxMembers: response.settings.max_members,
  globalMuteEnabled: Boolean(response.settings.global_mute_enabled),
  globalMuteUntil: parseTimestamp(response.settings.global_mute_until),
  globalMuteReason: response.settings.global_mute_reason ?? null,
  globalMuteSetBy: response.settings.global_mute_set_by ?? null,
  createdAt: parseTimestamp(response.settings.created_at),
  updatedAt: parseTimestamp(response.settings.updated_at),
  myMute: response.my_mute
    ? {
        isMuted: Boolean(response.my_mute.is_muted),
        reason: response.my_mute.reason ?? null,
        mutedAt: parseTimestamp(response.my_mute.muted_at),
        muteUntil: parseTimestamp(response.my_mute.mute_until),
      }
    : null,
});

const mapChatMessageAttachment = (
  attachment?: BackendMessageAttachment | null,
): ChatMessageAttachment | null => {
  if (!attachment?.key) {
    return null;
  }

  return {
    key: attachment.key,
    name: attachment.name ?? null,
    mime: attachment.mime ?? null,
    size: typeof attachment.size === "number" ? attachment.size : null,
    width: typeof attachment.width === "number" ? attachment.width : null,
    height: typeof attachment.height === "number" ? attachment.height : null,
    durationMs:
      typeof attachment.duration_ms === "number"
        ? attachment.duration_ms
        : null,
    thumbnailKey: attachment.thumbnail_key ?? null,
  };
};

const mapChatMessagePart = (part: BackendMessagePart): ChatMessagePart => ({
  position: part.position,
  partType: part.part_type,
  text: part.text ?? null,
  attachment: mapChatMessageAttachment(part.attachment),
});

const mapQuotedMessage = (
  quoted?: BackendQuotedMessage | null,
): ChatQuotedMessage | null => {
  if (!quoted) {
    return null;
  }

  return {
    id: quoted.id,
    roomId: quoted.room_id,
    senderId: quoted.sender_id,
    senderUsername: quoted.sender_username,
    senderName: quoted.sender_nickname?.trim() || quoted.sender_username,
    senderAvatarUrl: quoted.sender_avatar_url ?? null,
    content: quoted.content ?? null,
    messageType: quoted.message_type,
    createdAt: parseTimestamp(quoted.created_at),
    isDeleted: Boolean(quoted.is_deleted),
    parts: (quoted.parts ?? [])
      .slice()
      .sort((left, right) => left.position - right.position)
      .map(mapChatMessagePart),
  };
};

const mapPartPayloadInput = (
  part: ChatMessagePartInput,
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

const normalizeDirectUploadSignature = (
  rawSignature: BackendDirectUploadSignature | null | undefined,
  key: string,
): DirectUploadSignatureInfo | null => {
  if (
    !rawSignature ||
    typeof rawSignature.url !== "string" ||
    !rawSignature.url
  ) {
    return null;
  }

  const headers: Record<string, string> = {};
  if (rawSignature.headers && typeof rawSignature.headers === "object") {
    Object.entries(rawSignature.headers).forEach(([headerKey, headerValue]) => {
      if (typeof headerKey === "string" && typeof headerValue === "string") {
        headers[headerKey] = headerValue;
      }
    });
  }

  const method =
    typeof rawSignature.method === "string"
      ? rawSignature.method.trim().toUpperCase()
      : "PUT";

  return {
    url: rawSignature.url,
    method: method || "PUT",
    headers,
    key: rawSignature.key ?? key,
  };
};

const mapSimpleSuccessData = (
  response: ApiResponse<BackendMultipartSimplePayload>,
): ApiResponse<SimpleSuccessData> => {
  const payload = response.data;
  const successFlag =
    typeof payload?.success === "boolean" ? payload.success : response.success;
  const message =
    typeof payload?.message === "string"
      ? payload.message
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
};

export const mapChatMessagePayload = (
  message: BackendMessageInfo,
  currentUserId?: string,
): ChatMessage => {
  const senderName = message.sender_nickname?.trim() || message.sender_username;
  const preview = buildMessagePreview({
    content: message.content,
    messageType: message.message_type,
    parts: message.parts ?? [],
    isDeleted: message.is_deleted,
  });
  const parts = (message.parts ?? [])
    .slice()
    .sort((left, right) => left.position - right.position)
    .map(mapChatMessagePart);

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
    isSelf: currentUserId === message.sender_id,
    quotedMessage: mapQuotedMessage(message.quoted_message),
    parts,
  };
};

const mapPushMessage = (
  message: BackendPushMessage,
  currentUserId?: string,
): ChatMessage =>
  mapChatMessagePayload(
    {
      id: message.message_id || message.id,
      room_id: message.room_id,
      sender_id: message.sender_id,
      sender_username: message.sender_username,
      sender_nickname: message.sender_nickname,
      sender_avatar_url: message.sender_avatar_url,
      content: message.content,
      message_type: message.message_type,
      created_at: message.timestamp,
      quoted_message: message.quoted_message,
      parts: message.parts ?? [],
    },
    currentUserId,
  );

export const mapChatRealtimeEvent = (
  payload: unknown,
  currentUserId?: string,
): ChatRealtimeEvent | null => {
  if (!isRecord(payload) || typeof payload.type !== "string") {
    return null;
  }

  switch (payload.type) {
    case "message":
      if (!isBackendPushMessage(payload)) {
        return null;
      }
      return {
        type: "message",
        message: mapPushMessage(payload, currentUserId),
      };
    case "message_read":
      if (!isBackendPushMessageRead(payload)) {
        return null;
      }
      return {
        type: "message_read",
        roomId: payload.room_id,
        messageId: payload.message_id,
        readerId: payload.reader_id,
        readAt: parseTimestamp(
          typeof payload.read_at === "string" ? payload.read_at : null,
        ),
      };
    case "message_update":
      if (!isBackendPushMessageUpdate(payload)) {
        return null;
      }
      return {
        type: "message_update",
        roomId: payload.room_id,
        messageId: payload.message_id,
        isDeleted: payload.is_deleted === true,
        deletedAt: parseTimestamp(
          typeof payload.deleted_at === "string" ? payload.deleted_at : null,
        ),
      };
    case "room_created":
      if (!isBackendPushRoomCreated(payload)) {
        return null;
      }
      return {
        type: "room_created",
        roomId: payload.room_id,
        roomName: payload.room_name,
        roomType: payload.room_type,
        initiatorId: payload.initiator_id,
        ownerId: payload.owner_id,
        description: payload.description ?? null,
        avatarUrl: payload.avatar_url ?? null,
        avatarObjectKey: payload.avatar_object_key ?? null,
        createdAt: parseTimestamp(payload.created_at),
      };
    case "room_updated":
      if (!isBackendPushRoomUpdated(payload)) {
        return null;
      }
      return {
        type: "room_updated",
        roomId: payload.room_id,
        roomName: payload.room_name,
        roomType: payload.room_type,
        avatarUrl: payload.avatar_url ?? null,
        avatarObjectKey: payload.avatar_object_key ?? null,
        description: payload.description ?? null,
      };
    case "group_settings_updated":
      if (!isBackendPushGroupSettingsUpdated(payload)) {
        return null;
      }
      return {
        type: "group_settings_updated",
        roomId: payload.room_id,
        globalMuteEnabled: payload.global_mute_enabled,
        globalMuteReason: payload.global_mute_reason ?? null,
        globalMuteUntil: parseTimestamp(payload.global_mute_until),
        globalMuteSetBy: payload.global_mute_set_by ?? null,
      };
    case "group_member_changed":
      if (!isBackendPushGroupMemberChanged(payload)) {
        return null;
      }
      return {
        type: "group_member_changed",
        roomId: payload.room_id,
        memberId: payload.member_id,
        changeType: payload.change_type,
        newRole: payload.new_role ?? null,
        operatorId: payload.operator_id ?? null,
        reason: payload.reason ?? null,
        until: parseTimestamp(payload.until),
      };
    default:
      return null;
  }
};

export class ChatApi {
  static async list(): Promise<ApiResponse<ChatSummary[]>> {
    const response =
      await requireDesktopRuntime().rpc.invoke<
        ApiResponse<BackendChatSummary[]>
      >("chat.list");
    return {
      ...response,
      data: response.data ? response.data.map(mapChatSummary) : null,
    };
  }

  static async ensurePrivateChat(params: {
    friendUserId: string;
  }): Promise<ApiResponse<EnsuredPrivateChat>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendEnsurePrivateChatResponse>
    >("chat.private.ensure", {
      friend_user_id: params.friendUserId,
    });
    return {
      ...response,
      data: response.data ? mapEnsuredPrivateChat(response.data) : null,
    };
  }

  static async createGroup(params: {
    name: string;
    memberUserIds: string[];
  }): Promise<ApiResponse<CreatedGroupChat>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendCreateGroupResponse>
    >("chat.group.create", {
      name: params.name,
      member_user_ids: params.memberUserIds,
    });
    return {
      ...response,
      data: response.data ? mapCreatedGroupChat(response.data) : null,
    };
  }

  static async getRoom(params: {
    roomId: string;
  }): Promise<ApiResponse<ChatRoomDetail>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendRoomDetailResponse>
    >("chat.room.get", {
      room_id: params.roomId,
    });
    return {
      ...response,
      data: response.data ? mapChatRoomDetail(response.data) : null,
    };
  }

  static async listRoomMembers(params: {
    roomId: string;
  }): Promise<ApiResponse<ChatRoomMember[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendRoomMember[]>
    >("chat.room.members.list", {
      room_id: params.roomId,
    });
    return {
      ...response,
      data: response.data ? response.data.map(mapChatRoomMember) : null,
    };
  }

  static async getGroupSettings(params: {
    roomId: string;
  }): Promise<ApiResponse<ChatGroupSettings>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendGroupSettingsResponse>
    >("chat.group.settings.get", {
      room_id: params.roomId,
    });
    return {
      ...response,
      data: response.data ? mapChatGroupSettings(response.data) : null,
    };
  }

  static async updateGroupGlobalMute(params: {
    roomId: string;
    enabled: boolean;
    reason?: string;
    durationMinutes?: number;
  }): Promise<ApiResponse<ChatGroupSettings>> {
    const payload: Record<string, unknown> = {
      room_id: params.roomId,
      enabled: params.enabled,
    };
    if (params.reason?.trim()) {
      payload.reason = params.reason.trim();
    }
    if (typeof params.durationMinutes === "number" && params.durationMinutes > 0) {
      payload.duration_minutes = params.durationMinutes;
    }

    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendGroupSettingsResponse>
    >("chat.group.settings.global_mute.update", payload);
    return {
      ...response,
      data: response.data ? mapChatGroupSettings(response.data) : null,
    };
  }

  static async listMessages(params: {
    roomId: string;
    limit?: number;
    beforeId?: string;
    sinceId?: string;
    currentUserId?: string;
  }): Promise<ApiResponse<ChatMessage[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMessageInfo[]>
    >("chat.messages.list", {
      room_id: params.roomId,
      limit: params.limit,
      before_id: params.beforeId,
      since_id: params.sinceId,
    });
    return {
      ...response,
      data: response.data
        ? response.data
            .map((message) =>
              mapChatMessagePayload(message, params.currentUserId),
            )
            .reverse()
        : null,
    };
  }

  static async sendMessage(params: {
    roomId: string;
    content?: string;
    parts?: ChatMessagePartInput[];
    quotedMessageId?: string;
    currentUserId?: string;
  }): Promise<ApiResponse<ChatMessage>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMessageInfo | BackendSendMessagePayload>
    >("chat.send", {
      room_id: params.roomId,
      content: params.content,
      parts: params.parts?.map(mapPartPayloadInput),
      quoted_message_id: params.quotedMessageId,
    });
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const payload =
      typeof response.data === "object" &&
      response.data !== null &&
      "message" in response.data &&
      response.data.message
        ? response.data.message
        : response.data;

    return {
      ...response,
      data: mapChatMessagePayload(
        payload as BackendMessageInfo,
        params.currentUserId,
      ),
    };
  }

  static async sendTextMessage(params: {
    roomId: string;
    content: string;
    quotedMessageId?: string;
    currentUserId?: string;
  }): Promise<ApiResponse<ChatMessage>> {
    return this.sendMessage(params);
  }

  static async readUntil(params: {
    roomId: string;
    messageId: string;
  }): Promise<ApiResponse<null>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<unknown>
    >("chat.read_until", {
      room_id: params.roomId,
      message_id: params.messageId,
    });
    return {
      ...response,
      data: null,
    };
  }

  static async deleteMessage(params: {
    roomId: string;
    messageId: string;
  }): Promise<ApiResponse<ChatMessage>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMessageInfo>
    >("chat.delete", {
      room_id: params.roomId,
      message_id: params.messageId,
    });
    return {
      ...response,
      data: response.data
        ? mapChatMessagePayload(response.data, undefined)
        : null,
    };
  }

  static async getAttachmentDownloadUrl(params: {
    roomId: string;
    key: string;
    expiresInSeconds?: number;
  }): Promise<ApiResponse<AttachmentDownloadData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendAttachmentDownloadPayload>
    >("chat.attachment.download_url", {
      room_id: params.roomId,
      key: params.key,
      expires_in_seconds: params.expiresInSeconds,
    });

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const payload = response.data;
    const successFlag =
      typeof payload.success === "boolean" ? payload.success : response.success;
    const downloadUrl = payload.download_url ?? payload.downloadUrl ?? null;
    const message =
      typeof payload.message === "string"
        ? payload.message
        : response.message || "";

    if (
      !successFlag ||
      typeof downloadUrl !== "string" ||
      downloadUrl.length === 0
    ) {
      return {
        code: response.code,
        success: false,
        message: message || "获取附件下载链接失败",
        data: null,
      };
    }

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

  static async requestAttachmentSignature(params: {
    roomId: string;
    partType: AttachmentPartType;
    fileName?: string;
    contentType?: string;
    fileSize?: number;
    hashValue?: string;
    hashAlg?: number;
  }): Promise<ApiResponse<AttachmentSignatureData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendAttachmentSignaturePayload>
    >("chat.attachment.signature", {
      room_id: params.roomId,
      part_type: params.partType,
      filename: params.fileName,
      content_type: params.contentType,
      file_size: params.fileSize,
      hash_value: params.hashValue,
      hash_alg: params.hashAlg,
    });

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const payload = response.data;
    const successFlag =
      typeof payload.success === "boolean" ? payload.success : response.success;
    const key = payload.key ?? payload.signature?.key ?? null;
    const message =
      typeof payload.message === "string"
        ? payload.message
        : response.message || "";

    if (!successFlag || typeof key !== "string" || key.length === 0) {
      return {
        code: response.code,
        success: false,
        message: message || "获取附件上传签名失败",
        data: null,
      };
    }

    return {
      code: response.code,
      success: true,
      message,
      data: {
        key,
        signature: normalizeDirectUploadSignature(payload.signature, key),
        message,
      },
    };
  }

  static async initiateAttachmentMultipartUpload(params: {
    roomId: string;
    partType: AttachmentPartType;
    fileName?: string;
    contentType?: string;
    fileSize: number;
    hashValue?: string;
    hashAlg?: number;
  }): Promise<ApiResponse<AttachmentMultipartInitiateData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendAttachmentMultipartInitiatePayload>
    >("chat.attachment.multipart.initiate", {
      room_id: params.roomId,
      part_type: params.partType,
      filename: params.fileName,
      content_type: params.contentType,
      file_size: params.fileSize,
      hash_value: params.hashValue,
      hash_alg: params.hashAlg,
    });

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const payload = response.data;
    const successFlag =
      typeof payload.success === "boolean" ? payload.success : response.success;
    const key = payload.key ?? null;
    const message =
      typeof payload.message === "string"
        ? payload.message
        : response.message || "";

    if (!successFlag || typeof key !== "string" || key.length === 0) {
      return {
        code: response.code,
        success: false,
        message: message || "初始化分片上传失败",
        data: null,
      };
    }

    const sessionIdRaw = payload.session_id ?? payload.sessionId ?? null;
    const partSizeRaw = payload.part_size ?? payload.partSize ?? null;
    const totalPartsRaw = payload.total_parts ?? payload.totalParts ?? null;

    return {
      code: response.code,
      success: true,
      message,
      data: {
        key,
        sessionId:
          typeof sessionIdRaw === "string" && sessionIdRaw.length > 0
            ? sessionIdRaw
            : null,
        partSize:
          typeof partSizeRaw === "number" && partSizeRaw > 0
            ? partSizeRaw
            : undefined,
        totalParts:
          typeof totalPartsRaw === "number" && totalPartsRaw > 0
            ? totalPartsRaw
            : undefined,
        message,
      },
    };
  }

  static async generateMultipartPartSignature(params: {
    sessionId: string;
    partNumber: number;
  }): Promise<ApiResponse<{ signature: DirectUploadSignatureInfo }>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendAttachmentSignaturePayload>
    >("chat.attachment.multipart.part_signature", {
      session_id: params.sessionId,
      part_number: params.partNumber,
    });

    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }

    const payload = response.data;
    const successFlag =
      typeof payload.success === "boolean" ? payload.success : response.success;
    const signature = normalizeDirectUploadSignature(
      payload.signature,
      payload.signature?.key ?? "",
    );
    const message =
      typeof payload.message === "string"
        ? payload.message
        : response.message || "";

    if (!successFlag || !signature) {
      return {
        code: response.code,
        success: false,
        message: message || "获取分片上传签名失败",
        data: null,
      };
    }

    return {
      code: response.code,
      success: true,
      message,
      data: { signature },
    };
  }

  static async commitMultipartPart(params: {
    sessionId: string;
    partNumber: number;
    etag: string;
  }): Promise<ApiResponse<SimpleSuccessData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMultipartSimplePayload>
    >("chat.attachment.multipart.part_commit", {
      session_id: params.sessionId,
      part_number: params.partNumber,
      etag: params.etag,
    });
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }
    return mapSimpleSuccessData(response);
  }

  static async completeMultipartUpload(params: {
    sessionId: string;
    parts: MultipartCompletedPart[];
  }): Promise<ApiResponse<SimpleSuccessData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMultipartSimplePayload>
    >("chat.attachment.multipart.complete", {
      session_id: params.sessionId,
      parts: params.parts.map((part) => ({
        part_number: part.partNumber,
        etag: part.etag,
      })),
    });
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }
    return mapSimpleSuccessData(response);
  }

  static async abortMultipartUpload(params: {
    sessionId: string;
  }): Promise<ApiResponse<SimpleSuccessData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMultipartSimplePayload>
    >("chat.attachment.multipart.abort", {
      session_id: params.sessionId,
    });
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }
    return mapSimpleSuccessData(response);
  }

  static async commitAttachmentUpload(params: {
    roomId: string;
    key: string;
    hashValue?: string;
    hashAlg?: number;
    fileSize?: number;
  }): Promise<ApiResponse<SimpleSuccessData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMultipartSimplePayload>
    >("chat.attachment.upload.commit", {
      room_id: params.roomId,
      key: params.key,
      hash_value: params.hashValue,
      hash_alg: params.hashAlg,
      file_size: params.fileSize,
    });
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null,
      };
    }
    return mapSimpleSuccessData(response);
  }
}
