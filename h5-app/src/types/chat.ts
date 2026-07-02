export type MessageType = 'text' | 'image' | 'audio' | 'video' | 'file' | 'system' | 'mixed';
export type MessageStatus = 'sending' | 'sent' | 'failed' | 'deleted';

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
  attachments?: MessageAttachment[];
  raw?: Record<string, unknown>;
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
  type: 'private' | 'group';
  isPinned: boolean;
  isMuted: boolean;
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
