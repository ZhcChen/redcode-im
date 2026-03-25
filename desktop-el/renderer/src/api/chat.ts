import { post, type ApiResponse } from "./http";
import { computeFileHash } from "../utils/fileHash";
import { uploadWithSignature } from "../utils/chat-attachment-upload";

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
  status: number;
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

interface BackendRoomAvatarCommitPayload {
  success?: boolean;
  message?: string;
  avatar_url?: string | null;
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

interface BackendPinResponse {
  room_id: string;
  is_pinned: boolean;
  message?: BackendMessageInfo | null;
  pinned_at?: string | null;
  pinned_by?: string | null;
}

interface BackendReactionSummary {
  reaction_key: string;
  count: number;
  user_ids: string[];
  has_self: boolean;
}

interface BackendReactionResponse {
  success?: boolean;
  message?: string;
  summaries?: BackendReactionSummary[] | null;
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
  forward_message?: BackendForwardMessage | null;
  is_deleted?: boolean;
  is_edited?: boolean;
  is_pinned?: boolean;
  pinned_at?: string | null;
  pinned_by?: string | null;
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

export interface ChatGroupAdmin {
  id: string;
  roomId: string;
  adminId: string;
  appointedBy: string;
  role: string;
  permissions: string[] | null;
  appointedAt: Date | null;
}

export interface ChatGroupJoinRequest {
  id: string;
  roomId: string;
  applicantId: string;
  message: string | null;
  status: "pending" | "approved" | "rejected";
  reviewerId: string | null;
  reviewMessage: string | null;
  createdAt: Date | null;
  reviewedAt: Date | null;
}

export interface ChatGroupMute {
  id: string;
  roomId: string;
  userId: string;
  mutedBy: string;
  reason: string | null;
  muteDurationHours: number;
  mutedAt: Date | null;
  unmutedAt: Date | null;
  isActive: boolean;
  muteUntil: Date | null;
}

export interface ChatGroupRule {
  id: string;
  roomId: string;
  title: string;
  content: string;
  creatorId: string;
  orderIndex: number;
  isActive: boolean;
  createdAt: Date | null;
  updatedAt: Date | null;
}

export interface ChatGroupOperationLog {
  id: string;
  roomId: string;
  operatorId: string;
  targetUserId: string | null;
  operationType: string;
  operationData: Record<string, unknown> | null;
  createdAt: Date | null;
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
  pinnedAt: Date | null;
  pinnedBy: string | null;
  reactions?: ChatMessageReactionSummary[];
  forwardInfo: ChatForwardInfo | null;
  quotedMessage: ChatQuotedMessage | null;
  parts: ChatMessagePart[];
  clientStatus?: "sending" | "failed" | null;
  retryPayload?: {
    content: string;
    quotedMessageId?: string | null;
  } | null;
  errorMessage?: string | null;
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

export interface ChatForwardInfo {
  sourceType: "user" | "group" | "favorite" | "unknown";
  sourceId: string;
  sourceName: string;
  sourceAvatar: string | null;
  originMessageId: string | null;
  originRoomId: string | null;
  originSenderId: string | null;
  originSenderName: string | null;
}

export interface ChatMessageReactionSummary {
  reactionKey: string;
  count: number;
  userIds: string[];
  hasSelf: boolean;
}

export interface ChatMessageReader {
  userId: string;
  username: string;
  nickname: string | null;
  avatarUrl: string | null;
  readAt: Date | null;
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

export interface GroupAvatarUploadData {
  avatarUrl: string;
}

export interface AddGroupMembersData {
  success: boolean;
  addedUserIds: string[];
  skippedUserIds: string[];
}

export interface RemoveGroupMemberData {
  success: boolean;
}

export interface TransferGroupOwnerData {
  roomId: string;
  ownerId: string;
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

export interface PinMessageData {
  message: ChatMessage | null;
  isPinned: boolean;
  pinnedAt: Date | null;
  pinnedBy: string | null;
}

export interface ReactionData {
  summaries: ChatMessageReactionSummary[];
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
  forward_message?: BackendForwardMessage | null;
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
  edited_at?: string | null;
  content?: string | null;
}

interface BackendPushPinUpdate {
  type: "pin_update";
  room_id: string;
  message_id?: string | null;
  is_pinned: boolean;
  pinned_at?: string | null;
  pinned_by?: string | null;
}

interface BackendPushReactionUpdate {
  type: "reaction_update";
  room_id: string;
  message_id: string;
  reaction_key: string;
  user_id: string;
  action: string;
}

interface BackendPushTypingUpdate {
  type: "typing_update";
  room_id: string;
  user_id: string;
  is_typing: boolean;
  expires_in_ms?: number | null;
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
  | BackendPushPinUpdate
  | BackendPushReactionUpdate
  | BackendPushTypingUpdate
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
      editedAt: Date | null;
      content: string | null;
    }
  | {
      type: "pin_update";
      roomId: string;
      messageId: string | null;
      isPinned: boolean;
      pinnedAt: Date | null;
      pinnedBy: string | null;
    }
  | {
      type: "reaction_update";
      roomId: string;
      messageId: string;
      reactionKey: string;
      userId: string;
      action: string;
    }
  | {
      type: "typing_update";
      roomId: string;
      userId: string;
      isTyping: boolean;
      expiresInMs: number;
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

const parseForwardSourceType = (
  value?: string | null,
): ChatForwardInfo["sourceType"] => {
  switch ((value || "").toLowerCase()) {
    case "user":
    case "single":
      return "user";
    case "group":
      return "group";
    case "favorite":
      return "favorite";
    default:
      return "unknown";
  }
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

const isBackendPushPinUpdate = (value: unknown): value is BackendPushPinUpdate =>
  isRecord(value) &&
  value.type === "pin_update" &&
  typeof value.room_id === "string" &&
  typeof value.is_pinned === "boolean";

const isBackendPushReactionUpdate = (
  value: unknown,
): value is BackendPushReactionUpdate =>
  isRecord(value) &&
  value.type === "reaction_update" &&
  typeof value.room_id === "string" &&
  typeof value.message_id === "string" &&
  typeof value.reaction_key === "string" &&
  typeof value.user_id === "string" &&
  typeof value.action === "string";

const isBackendPushTypingUpdate = (
  value: unknown,
): value is BackendPushTypingUpdate =>
  isRecord(value) &&
  value.type === "typing_update" &&
  typeof value.room_id === "string" &&
  typeof value.user_id === "string" &&
  typeof value.is_typing === "boolean";

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

const mapChatGroupAdmin = (admin: BackendGroupAdmin): ChatGroupAdmin => ({
  id: admin.id,
  roomId: admin.room_id,
  adminId: admin.admin_id,
  appointedBy: admin.appointed_by,
  role: admin.role,
  permissions: admin.permissions ?? null,
  appointedAt: parseTimestamp(admin.appointed_at),
});

const mapJoinRequestStatus = (
  status: number,
): "pending" | "approved" | "rejected" => {
  switch (status) {
    case 1:
      return "approved";
    case 2:
      return "rejected";
    default:
      return "pending";
  }
};

const mapChatGroupJoinRequest = (
  request: BackendJoinRequest,
): ChatGroupJoinRequest => ({
  id: request.id,
  roomId: request.room_id,
  applicantId: request.applicant_id,
  message: request.message ?? null,
  status: mapJoinRequestStatus(request.status),
  reviewerId: request.reviewer_id ?? null,
  reviewMessage: request.review_message ?? null,
  createdAt: parseTimestamp(request.created_at),
  reviewedAt: parseTimestamp(request.reviewed_at),
});

const mapChatGroupMute = (mute: BackendGroupMute): ChatGroupMute => {
  const mutedAt = parseTimestamp(mute.muted_at);
  const muteUntil =
    mutedAt && mute.mute_duration_hours > 0
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
    unmutedAt: parseTimestamp(mute.unmuted_at),
    isActive: Boolean(mute.is_active),
    muteUntil,
  };
};

const mapChatGroupRule = (rule: BackendGroupRule): ChatGroupRule => ({
  id: rule.id,
  roomId: rule.room_id,
  title: rule.title,
  content: rule.content,
  creatorId: rule.creator_id,
  orderIndex: rule.order_index,
  isActive: Boolean(rule.is_active),
  createdAt: parseTimestamp(rule.created_at),
  updatedAt: parseTimestamp(rule.updated_at),
});

const mapChatGroupOperationLog = (
  log: BackendGroupOperationLog,
): ChatGroupOperationLog => ({
  id: log.id,
  roomId: log.room_id,
  operatorId: log.operator_id,
  targetUserId: log.target_user_id ?? null,
  operationType: log.operation_type,
  operationData: log.operation_data ?? null,
  createdAt: parseTimestamp(log.created_at),
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

const mapForwardMessage = (
  forward?: BackendForwardMessage | null,
): ChatForwardInfo | null => {
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

const mapPinMessageData = (
  response: ApiResponse<BackendPinResponse>,
  currentUserId?: string,
): ApiResponse<PinMessageData> => {
  if (!response.data) {
    return {
      ...response,
      data: null,
    };
  }

  return {
    ...response,
    data: {
      message: response.data.message
        ? mapChatMessagePayload(response.data.message, currentUserId)
        : null,
      isPinned: Boolean(response.data.is_pinned),
      pinnedAt: parseTimestamp(response.data.pinned_at),
      pinnedBy: response.data.pinned_by ?? null,
    },
  };
};

const mapReactionSummary = (
  summary: BackendReactionSummary,
): ChatMessageReactionSummary => ({
  reactionKey: summary.reaction_key,
  count: summary.count,
  userIds: summary.user_ids ?? [],
  hasSelf: Boolean(summary.has_self),
});

const mapReactionData = (
  response: ApiResponse<BackendReactionResponse>,
): ApiResponse<ReactionData> => {
  if (!response.data) {
    return {
      ...response,
      data: null,
    };
  }

  const message =
    typeof response.data.message === "string"
      ? response.data.message
      : response.message;

  return {
    ...response,
    message,
    data: {
      summaries: (response.data.summaries ?? []).map(mapReactionSummary),
    },
  };
};

const mapMessageReader = (
  reader: BackendMessageReader,
): ChatMessageReader => ({
  userId: reader.user_id,
  username: reader.username,
  nickname: reader.nickname ?? null,
  avatarUrl: reader.avatar_url ?? null,
  readAt: parseTimestamp(reader.read_at),
});

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
    pinnedAt: parseTimestamp(message.pinned_at),
    pinnedBy: message.pinned_by ?? null,
    forwardInfo: mapForwardMessage(message.forward_message),
    quotedMessage: mapQuotedMessage(message.quoted_message),
    parts,
    clientStatus: null,
    retryPayload: null,
    errorMessage: null,
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
      forward_message: message.forward_message,
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
        editedAt: parseTimestamp(
          typeof payload.edited_at === "string" ? payload.edited_at : null,
        ),
        content: typeof payload.content === "string" ? payload.content : null,
      };
    case "pin_update":
      if (!isBackendPushPinUpdate(payload)) {
        return null;
      }
      return {
        type: "pin_update",
        roomId: payload.room_id,
        messageId: payload.message_id ?? null,
        isPinned: payload.is_pinned,
        pinnedAt: parseTimestamp(payload.pinned_at),
        pinnedBy: payload.pinned_by ?? null,
      };
    case "reaction_update":
      if (!isBackendPushReactionUpdate(payload)) {
        return null;
      }
      return {
        type: "reaction_update",
        roomId: payload.room_id,
        messageId: payload.message_id,
        reactionKey: payload.reaction_key,
        userId: payload.user_id,
        action: payload.action,
      };
    case "typing_update":
      if (!isBackendPushTypingUpdate(payload)) {
        return null;
      }
      return {
        type: "typing_update",
        roomId: payload.room_id,
        userId: payload.user_id,
        isTyping: payload.is_typing,
        expiresInMs:
          typeof payload.expires_in_ms === "number" &&
          Number.isFinite(payload.expires_in_ms)
            ? payload.expires_in_ms
            : 6000,
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

  static async uploadGroupAvatar(params: {
    roomId: string;
    file: File;
  }): Promise<ApiResponse<GroupAvatarUploadData>> {
    const contentType = params.file.type || "application/octet-stream";
    const { hashValue, hashAlg } = await computeFileHash(params.file);
    const directUploadBody: Record<string, unknown> = {
      content_type: contentType,
      filename: params.file.name,
      file_size: params.file.size,
    };
    if (hashValue) {
      directUploadBody.hash_value = hashValue;
    }
    if (typeof hashAlg === "number") {
      directUploadBody.hash_alg = hashAlg;
    }

    const directResponse = await post<BackendAttachmentSignaturePayload>(
      `/rooms/${params.roomId}/avatar/direct-upload`,
      directUploadBody,
    );
    if (!directResponse.success || !directResponse.data) {
      return {
        ...directResponse,
        data: null,
      };
    }

    const directPayload = directResponse.data;
    const directSuccess =
      typeof directPayload.success === "boolean"
        ? directPayload.success
        : directResponse.success;
    const key = directPayload.key ?? directPayload.signature?.key ?? null;
    const directMessage =
      directPayload.message || directResponse.message || "";
    if (!directSuccess || !key) {
      return {
        code: directResponse.code,
        success: false,
        message: directMessage || "获取群头像上传签名失败",
        data: null,
      };
    }

    const signature = normalizeDirectUploadSignature(
      directPayload.signature,
      key,
    );
    if (signature) {
      await uploadWithSignature(signature, params.file);
    }

    const commitResponse = await post<BackendRoomAvatarCommitPayload>(
      `/rooms/${params.roomId}/avatar/commit`,
      { key },
    );
    if (!commitResponse.success || !commitResponse.data) {
      return {
        ...commitResponse,
        data: null,
      };
    }

    const commitPayload = commitResponse.data;
    const commitSuccess =
      typeof commitPayload.success === "boolean"
        ? commitPayload.success
        : commitResponse.success;
    const avatarUrl = commitPayload.avatar_url ?? null;
    const commitMessage =
      commitPayload.message || commitResponse.message || "";
    if (!commitSuccess || !avatarUrl) {
      return {
        code: commitResponse.code,
        success: false,
        message: commitMessage || "群头像上传失败",
        data: null,
      };
    }

    return {
      code: commitResponse.code,
      success: true,
      message: commitMessage || "群头像上传成功",
      data: {
        avatarUrl,
      },
    };
  }

  static async addGroupMembers(params: {
    roomId: string;
    userIds: string[];
  }): Promise<ApiResponse<AddGroupMembersData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        success?: boolean;
        added_user_ids?: string[] | null;
        skipped_user_ids?: string[] | null;
      }>
    >("chat.room.members.add", {
      room_id: params.roomId,
      user_ids: params.userIds,
    });

    return {
      ...response,
      data: response.data
        ? {
            success:
              typeof response.data.success === "boolean"
                ? response.data.success
                : response.success,
            addedUserIds: response.data.added_user_ids ?? [],
            skippedUserIds: response.data.skipped_user_ids ?? [],
          }
        : null,
    };
  }

  static async removeGroupMember(params: {
    roomId: string;
    userId: string;
  }): Promise<ApiResponse<RemoveGroupMemberData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        success?: boolean;
      }>
    >("chat.room.member.remove", {
      room_id: params.roomId,
      user_id: params.userId,
    });

    return {
      ...response,
      data: response.data
        ? {
            success:
              typeof response.data.success === "boolean"
                ? response.data.success
                : response.success,
          }
        : null,
    };
  }

  static async transferGroupOwner(params: {
    roomId: string;
    newOwnerId: string;
  }): Promise<ApiResponse<TransferGroupOwnerData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        room_id?: string | null;
        owner_id?: string | null;
      }>
    >("chat.group.owner.transfer", {
      room_id: params.roomId,
      new_owner_id: params.newOwnerId,
    });

    return {
      ...response,
      data:
        response.data?.room_id && response.data.owner_id
          ? {
              roomId: response.data.room_id,
              ownerId: response.data.owner_id,
            }
          : null,
    };
  }

  static async listGroupAdmins(params: {
    roomId: string;
  }): Promise<ApiResponse<ChatGroupAdmin[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        admins?: BackendGroupAdmin[] | null;
      }>
    >("chat.group.admins.list", {
      room_id: params.roomId,
    });

    return {
      ...response,
      data: response.data?.admins
        ? response.data.admins.map(mapChatGroupAdmin)
        : null,
    };
  }

  static async appointGroupAdmin(params: {
    roomId: string;
    userId: string;
    role?: string;
  }): Promise<ApiResponse<ChatGroupAdmin>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        admin?: BackendGroupAdmin | null;
      }>
    >("chat.group.admin.appoint", {
      room_id: params.roomId,
      user_id: params.userId,
      role: params.role ?? "admin",
    });

    return {
      ...response,
      data: response.data?.admin ? mapChatGroupAdmin(response.data.admin) : null,
    };
  }

  static async removeGroupAdmin(params: {
    roomId: string;
    adminId: string;
  }): Promise<ApiResponse<SimpleSuccessData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMultipartSimplePayload>
    >("chat.group.admin.remove", {
      room_id: params.roomId,
      admin_id: params.adminId,
    });

    return mapSimpleSuccessData(response);
  }

  static async listGroupJoinRequests(params: {
    roomId: string;
  }): Promise<ApiResponse<ChatGroupJoinRequest[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        requests?: BackendJoinRequest[] | null;
      }>
    >("chat.group.join_requests.list", {
      room_id: params.roomId,
    });

    return {
      ...response,
      data: response.data?.requests
        ? response.data.requests.map(mapChatGroupJoinRequest)
        : null,
    };
  }

  static async reviewGroupJoinRequest(params: {
    roomId: string;
    requestId: string;
    status: "approved" | "rejected";
    reviewMessage?: string;
  }): Promise<ApiResponse<ChatGroupJoinRequest>> {
    const payload: Record<string, unknown> = {
      room_id: params.roomId,
      request_id: params.requestId,
      status: params.status,
    };
    if (params.reviewMessage?.trim()) {
      payload.review_message = params.reviewMessage.trim();
    }

    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        request?: BackendJoinRequest | null;
      }>
    >("chat.group.join_request.review", payload);

    return {
      ...response,
      data: response.data?.request
        ? mapChatGroupJoinRequest(response.data.request)
        : null,
    };
  }

  static async listGroupMutes(params: {
    roomId: string;
  }): Promise<ApiResponse<ChatGroupMute[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        mutes?: BackendGroupMute[] | null;
      }>
    >("chat.group.mutes.list", {
      room_id: params.roomId,
    });

    return {
      ...response,
      data: response.data?.mutes
        ? response.data.mutes.map(mapChatGroupMute)
        : null,
    };
  }

  static async muteGroupMember(params: {
    roomId: string;
    userId: string;
    durationHours: number;
    reason?: string;
  }): Promise<ApiResponse<ChatGroupMute>> {
    const payload: Record<string, unknown> = {
      room_id: params.roomId,
      user_id: params.userId,
      duration_hours: params.durationHours,
    };
    if (params.reason?.trim()) {
      payload.reason = params.reason.trim();
    }

    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        mute?: BackendGroupMute | null;
      }>
    >("chat.group.mute.create", payload);

    return {
      ...response,
      data: response.data?.mute ? mapChatGroupMute(response.data.mute) : null,
    };
  }

  static async unmuteGroupMember(params: {
    roomId: string;
    userId: string;
  }): Promise<ApiResponse<SimpleSuccessData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMultipartSimplePayload>
    >("chat.group.mute.remove", {
      room_id: params.roomId,
      user_id: params.userId,
    });

    return mapSimpleSuccessData(response);
  }

  static async listGroupRules(params: {
    roomId: string;
  }): Promise<ApiResponse<ChatGroupRule[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        rules?: BackendGroupRule[] | null;
      }>
    >("chat.group.rules.list", {
      room_id: params.roomId,
    });

    return {
      ...response,
      data: response.data?.rules
        ? response.data.rules.map(mapChatGroupRule)
        : null,
    };
  }

  static async createGroupRule(params: {
    roomId: string;
    title: string;
    content: string;
    orderIndex?: number;
  }): Promise<ApiResponse<ChatGroupRule>> {
    const payload: Record<string, unknown> = {
      room_id: params.roomId,
      title: params.title,
      content: params.content,
    };
    if (typeof params.orderIndex === "number") {
      payload.order_index = params.orderIndex;
    }

    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        rule?: BackendGroupRule | null;
      }>
    >("chat.group.rule.create", payload);

    return {
      ...response,
      data: response.data?.rule ? mapChatGroupRule(response.data.rule) : null,
    };
  }

  static async updateGroupRule(params: {
    roomId: string;
    ruleId: string;
    title?: string;
    content?: string;
    orderIndex?: number;
    isActive?: boolean;
  }): Promise<ApiResponse<ChatGroupRule>> {
    const payload: Record<string, unknown> = {
      room_id: params.roomId,
      rule_id: params.ruleId,
    };
    if (params.title !== undefined) {
      payload.title = params.title;
    }
    if (params.content !== undefined) {
      payload.content = params.content;
    }
    if (typeof params.orderIndex === "number") {
      payload.order_index = params.orderIndex;
    }
    if (typeof params.isActive === "boolean") {
      payload.is_active = params.isActive;
    }

    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        rule?: BackendGroupRule | null;
      }>
    >("chat.group.rule.update", payload);

    return {
      ...response,
      data: response.data?.rule ? mapChatGroupRule(response.data.rule) : null,
    };
  }

  static async deleteGroupRule(params: {
    roomId: string;
    ruleId: string;
  }): Promise<ApiResponse<SimpleSuccessData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMultipartSimplePayload>
    >("chat.group.rule.delete", {
      room_id: params.roomId,
      rule_id: params.ruleId,
    });

    return mapSimpleSuccessData(response);
  }

  static async listGroupOperationLogs(params: {
    roomId: string;
    limit?: number;
    offset?: number;
  }): Promise<
    ApiResponse<{
      logs: ChatGroupOperationLog[];
      total: number;
    }>
  > {
    const payload: Record<string, unknown> = {
      room_id: params.roomId,
    };
    if (typeof params.limit === "number") {
      payload.limit = params.limit;
    }
    if (typeof params.offset === "number") {
      payload.offset = params.offset;
    }

    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<{
        logs?: BackendGroupOperationLog[] | null;
        total?: number | null;
      }>
    >("chat.group.operation_logs.list", payload);

    return {
      ...response,
      data: response.data?.logs
        ? {
            logs: response.data.logs.map(mapChatGroupOperationLog),
            total: response.data.total ?? response.data.logs.length,
          }
        : null,
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

  static async updateGroupSettings(params: {
    roomId: string;
    joinApprovalRequired?: boolean;
    memberCanInvite?: boolean;
    memberCanAddFriends?: boolean;
    requireAdminToAddFriends?: boolean;
    maxMembers?: number;
  }): Promise<ApiResponse<ChatGroupSettings>> {
    const payload: Record<string, unknown> = {
      room_id: params.roomId,
    };
    if (typeof params.joinApprovalRequired === "boolean") {
      payload.join_approval_required = params.joinApprovalRequired;
    }
    if (typeof params.memberCanInvite === "boolean") {
      payload.member_can_invite = params.memberCanInvite;
    }
    if (typeof params.memberCanAddFriends === "boolean") {
      payload.member_can_add_friends = params.memberCanAddFriends;
    }
    if (typeof params.requireAdminToAddFriends === "boolean") {
      payload.require_admin_to_add_friends = params.requireAdminToAddFriends;
    }
    if (typeof params.maxMembers === "number") {
      payload.max_members = params.maxMembers;
    }

    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendGroupSettingsResponse>
    >("chat.group.settings.update", payload);
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

  static async forwardMessage(params: {
    roomId: string;
    originalMessageId: string;
    currentUserId?: string;
  }): Promise<ApiResponse<ChatMessage>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMessageInfo | BackendSendMessagePayload>
    >("chat.forward", {
      room_id: params.roomId,
      original_message_id: params.originalMessageId,
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

  static async pinMessage(params: {
    roomId: string;
    messageId: string;
    currentUserId?: string;
  }): Promise<ApiResponse<PinMessageData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendPinResponse>
    >("chat.pin", {
      room_id: params.roomId,
      message_id: params.messageId,
    });
    return mapPinMessageData(response, params.currentUserId);
  }

  static async unpinMessage(params: {
    roomId: string;
    messageId: string;
    currentUserId?: string;
  }): Promise<ApiResponse<PinMessageData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendPinResponse>
    >("chat.unpin", {
      room_id: params.roomId,
      message_id: params.messageId,
    });
    return mapPinMessageData(response, params.currentUserId);
  }

  static async addReaction(params: {
    roomId: string;
    messageId: string;
    reactionKey: string;
  }): Promise<ApiResponse<ReactionData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendReactionResponse>
    >("chat.reactions.add", {
      room_id: params.roomId,
      message_id: params.messageId,
      reaction_key: params.reactionKey,
    });
    return mapReactionData(response);
  }

  static async removeReaction(params: {
    roomId: string;
    messageId: string;
    reactionKey: string;
  }): Promise<ApiResponse<ReactionData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendReactionResponse>
    >("chat.reactions.remove", {
      room_id: params.roomId,
      message_id: params.messageId,
      reaction_key: params.reactionKey,
    });
    return mapReactionData(response);
  }

  static async getReactions(params: {
    roomId: string;
    messageId: string;
  }): Promise<ApiResponse<ReactionData>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendReactionResponse>
    >("chat.reactions.list", {
      room_id: params.roomId,
      message_id: params.messageId,
    });
    return mapReactionData(response);
  }

  static async getMessageReaders(params: {
    roomId: string;
    messageId: string;
  }): Promise<ApiResponse<ChatMessageReader[]>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMessageReader[]>
    >("chat.message.readers.list", {
      room_id: params.roomId,
      message_id: params.messageId,
    });
    return {
      ...response,
      data: response.data ? response.data.map(mapMessageReader) : null,
    };
  }

  static async sendTyping(params: {
    roomId: string;
    isTyping: boolean;
  }): Promise<ApiResponse<null>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<unknown>
    >("chat.typing.send", {
      room_id: params.roomId,
      is_typing: params.isTyping,
    });
    return {
      ...response,
      data: null,
    };
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

  static async editMessage(params: {
    roomId: string;
    messageId: string;
    content: string;
    currentUserId?: string;
  }): Promise<ApiResponse<ChatMessage>> {
    const response = await requireDesktopRuntime().rpc.invoke<
      ApiResponse<BackendMessageInfo>
    >("chat.edit", {
      room_id: params.roomId,
      message_id: params.messageId,
      content: params.content,
    });
    return {
      ...response,
      data: response.data
        ? mapChatMessagePayload(response.data, params.currentUserId)
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
