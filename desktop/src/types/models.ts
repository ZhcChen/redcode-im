export enum ChatType {
  SINGLE = 'single',
  GROUP = 'group',
  FAVORITE = 'favorite',
}

export interface ChatConversation {
  id: string;
  name: string;
  lastMessage: string;
  lastMessageTime: Date;
  lastMessageId?: string;
  unreadCount: number;
  isPinned: boolean;
  avatar?: string | null;
}

export interface Chat {
  id: string;
  roomId: string;
  name: string;
  avatar?: string | null;
  type: ChatType;
  lastMessage: string;
  lastMessageTime: Date;
  lastMessageId?: string | null;
  unreadCount: number;
  isPinned: boolean;
  isMuted: boolean;
  memberCount?: number;
  extra?: Record<string, unknown> | null;
}

export interface AppVersionInfo {
  id: string;
  platform: string;
  version: string;
  build_number: number;
  channel: string;
  download_key: string;
  download_url?: string | null;
  file_size?: number | null;
  checksum?: string | null;
  signature?: string | null;
  release_notes?: string | null;
  mandatory: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  released_at?: string | null;
}

export enum MessageType {
  TEXT = 'text',
  IMAGE = 'image',
  VOICE = 'voice',
  VIDEO = 'video',
  FILE = 'file',
  SYSTEM = 'system',
  MIXED = 'mixed',
}

export enum MessagePartType {
  TEXT = 'text',
  IMAGE = 'image',
  VIDEO = 'video',
  AUDIO = 'audio',
  FILE = 'file',
}

export interface MessageAttachment {
  key: string;
  name?: string | null;
  mime?: string | null;
  size?: number | null;
  width?: number | null;
  height?: number | null;
  durationMs?: number | null;
  thumbnailKey?: string | null;
  localPath?: string | null;
  uploadProgress?: number | null;
  downloadUrl?: string | null;
}

export interface MessagePart {
  position: number;
  type: MessagePartType;
  text?: string | null;
  attachment?: MessageAttachment | null;
}

export enum ForwardSourceType {
  USER = 'user',
  GROUP = 'group',
  FAVORITE = 'favorite',
  UNKNOWN = 'unknown',
}

export interface ForwardInfo {
  sourceType: ForwardSourceType;
  sourceId: string;
  sourceName: string;
  sourceAvatar?: string | null;
  originMessageId?: string | null;
  originRoomId?: string | null;
  originSenderId?: string | null;
  originSenderName?: string | null;
}

export interface QuotedMessage {
  id: string;
  roomId: string;
  senderId: string;
  senderUsername: string;
  senderName: string;
  senderAvatar?: string | null;
  content?: string | null;
  type: MessageType;
  createdAt?: Date | null;
  isDeleted: boolean;
  parts?: MessagePart[];
}

export enum MessageStatus {
  SENDING = 'sending',
  SENT = 'sent',
  DELIVERED = 'delivered',
  READ = 'read',
  FAILED = 'failed',
}

export interface Message {
  id: string;
  roomId: string;
  senderId: string;
  senderUsername: string;
  senderName: string;
  senderAvatar?: string | null;
  senderAvatarObjectKey?: string | null;
  content: string;
  type: MessageType;
  status: MessageStatus;
  timestamp: Date;
  isSelf: boolean;
  extra?: Record<string, unknown> | null;
  quotedMessage?: QuotedMessage | null;
  forwardInfo?: ForwardInfo | null;
  isDeleted: boolean;
  pinnedAt?: Date | null;
  parts?: MessagePart[];
}

export interface MessageReader {
  userId: string;
  username: string;
  nickname?: string | null;
  avatarUrl?: string | null;
  readAt: Date;
}

export type RoomMemberRole = 'owner' | 'admin' | 'member';

export interface RoomMember {
  userId: string;
  username: string;
  nickname?: string | null;
  avatarUrl?: string | null;
  avatarObjectKey?: string | null;
  role: RoomMemberRole;
  joinedAt?: Date | null;
}

export interface AuthUser {
  id: string;
  username: string;
  email?: string | null;
  nickname?: string | null;
  avatarUrl?: string | null;
  avatarObjectKey?: string | null;
  status?: string | null;
}

export enum FriendRequestStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  DECLINED = 'declined',
}

export interface FriendInfo {
  id: string;
  user: AuthUser;
  createdAt: Date;
  friendRemark?: string | null;
}

export interface FriendRequestInfo {
  id: string;
  requester: AuthUser;
  addressee: AuthUser;
  status: FriendRequestStatus;
  createdAt: Date;
  respondedAt?: Date | null;
  message?: string | null;
  isIncoming: boolean;
}

export interface EnsureChatResult {
  roomId: string;
  roomName: string;
  roomType: string;
  friendId: string;
  friendName: string;
  friendAvatar?: string | null;
  friendAvatarObjectKey?: string | null;
}

export const getDisplayName = (user: Pick<AuthUser, 'nickname' | 'username'>): string => {
  const nickname = user.nickname?.trim();
  if (nickname) {
    return nickname;
  }
  return user.username;
};

export const getReaderDisplayName = (reader: MessageReader): string => {
  const nickname = reader.nickname?.trim();
  if (nickname) {
    return nickname;
  }
  return reader.username;
};
