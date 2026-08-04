export type ChatType = 'private' | 'group' | 'favorite';
export type MessageType = 'text' | 'image' | 'audio' | 'video' | 'file' | 'system' | 'mixed';
export type MessageStatus = 'sending' | 'sent' | 'delivered' | 'read' | 'failed' | 'deleted';

export interface MessageForwardInfo {
  messageId: string;
  roomId: string;
  senderId: string;
  senderUsername: string | null;
  senderNickname: string | null;
}

export interface MessageAttachment {
  key: string;
  name?: string;
  mimeType?: string;
  size?: number;
  url?: string;
  cacheKey?: string;
  blobUrl?: string;
  objectUrl?: string;
  cachedAt?: number;
}

export interface MessageReader {
  userId: string;
  username: string;
  nickname: string | null;
  avatarUrl: string | null;
  readAt: number;
}

export interface MessageReceiptMember {
  userId: string;
  username: string;
  nickname: string | null;
  avatarUrl: string | null;
}

export interface ChatMessage {
  id: string;
  roomId: string;
  senderId: string;
  senderName: string;
  content: string;
  type: MessageType;
  timestamp: number;
  status?: MessageStatus;
  isDeleted?: boolean;
  isPinned?: boolean;
  pinnedAt?: number | null;
  pinnedBy?: string | null;
  quotedMessage?: ChatMessageQuote | null;
  attachments?: MessageAttachment[];
  forwardInfo?: MessageForwardInfo | null;
  encryptedContent?: string | null;
  encryptionMetadata?: Record<string, unknown> | null;
  e2eeDecryptionFailed?: boolean;
  raw?: Record<string, unknown>;
}

export interface OutgoingMessagePart {
  type: Exclude<MessageType, 'system' | 'mixed'>;
  text?: string;
  key?: string;
  name?: string;
  mimeType?: string;
  size?: number;
  width?: number;
  height?: number;
  durationMs?: number;
  thumbnailKey?: string;
}

export interface ChatMessageQuote {
  id: string;
  roomId: string;
  senderId: string;
  senderName: string;
  content: string;
  type: MessageType;
  timestamp?: number;
  isDeleted?: boolean;
}

export interface ChatSummary {
  id: string;
  roomId: string;
  name: string;
  avatar?: string | null;
  avatarObjectKey?: string | null;
  avatarCacheKey?: string | null;
  lastMessage: string;
  lastMessageTime: number;
  unreadCount: number;
  type: ChatType;
  isPinned: boolean;
  isMuted: boolean;
  raw?: Record<string, unknown>;
}

export interface MessageSearchResult {
  id: string;
  roomId: string;
  roomName: string;
  senderId: string;
  senderName: string;
  content: string;
  messageType: MessageType;
  timestamp: number;
  relevanceScore: number;
  matchedText?: string;
}

export interface MessageSearchResponse {
  results: MessageSearchResult[];
  stats: {
    totalResults: number;
    searchTimeMs: number;
    query: string;
  };
  hasMore: boolean;
}
