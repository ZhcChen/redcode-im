import { requestJson, withQuery } from '@/api/http';
import type { ChatMessage, ChatSummary, MessageSearchResponse, MessageSearchResult, MessageType } from '@/types/chat';

import { requireToken } from './session';

export const messageService = {
  async fetchChats(): Promise<ChatSummary[]> {
    const response = await requestJson<Record<string, unknown>[] | { chats?: Record<string, unknown>[] }>(
      '/chats',
      {},
      requireToken(),
    );
    const rows = Array.isArray(response) ? response : response.chats ?? [];
    return rows.map(mapChatSummary);
  },

  async deleteChat(roomId: string): Promise<void> {
    await requestJson(`/chats/${roomId}`, { method: 'DELETE' }, requireToken());
  },

  async loadMessages(roomId: string, params: { limit?: number; beforeId?: string; sinceId?: string } = {}): Promise<ChatMessage[]> {
    const response = await requestJson<Record<string, unknown>[]>(
      withQuery(`/rooms/${roomId}/messages`, {
        limit: params.limit ?? 50,
        before_id: params.beforeId,
        since_id: params.sinceId,
      }),
      {},
      requireToken(),
    );
    return response.map((row) => mapMessage(row, roomId)).sort((a, b) => a.timestamp - b.timestamp);
  },

  async sendTextMessage(roomId: string, content: string, quotedMessageId?: string): Promise<ChatMessage> {
    const response = await requestJson<Record<string, unknown>>(`/rooms/${roomId}/messages`, {
      method: 'POST',
      body: JSON.stringify({
        content: content.trim(),
        ...(quotedMessageId ? { quoted_message_id: quotedMessageId } : {}),
      }),
    }, requireToken());
    return mapMessage(response, roomId);
  },

  async clearRoomMessages(roomId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}/messages`, { method: 'DELETE' }, requireToken());
  },

  async deleteMessage(roomId: string, messageId: string): Promise<void> {
    await requestJson(`/rooms/${roomId}/messages/${messageId}`, { method: 'DELETE' }, requireToken());
  },

  async pinMessage(roomId: string, messageId: string, pinned: boolean): Promise<void> {
    await requestJson(`/rooms/${roomId}/messages/${messageId}/pin`, { method: pinned ? 'POST' : 'DELETE' }, requireToken());
  },

  async fetchMessageReaders(roomId: string, messageId: string): Promise<Record<string, unknown>[]> {
    return requestJson<Record<string, unknown>[]>(
      `/rooms/${roomId}/messages/${messageId}/reads`,
      {},
      requireToken(),
    );
  },

  async searchMessages(params: {
    query: string;
    roomId?: string;
    messageType?: string;
    limit?: number;
    offset?: number;
  }): Promise<MessageSearchResponse> {
    const response = await requestJson<Record<string, unknown>>(
      withQuery('/messages/search', {
        query: params.query,
        room_id: params.roomId,
        message_type: params.messageType,
        limit: params.limit ?? 50,
        offset: params.offset ?? 0,
      }),
      {},
      requireToken(),
    );
    const results = Array.isArray(response.results)
      ? response.results.map((row) => mapSearchResult(row as Record<string, unknown>))
      : [];
    const stats = typeof response.stats === 'object' && response.stats !== null
      ? (response.stats as Record<string, unknown>)
      : {};
    return {
      results,
      stats: {
        totalResults: Number(stats.total_results ?? results.length),
        searchTimeMs: Number(stats.search_time_ms ?? 0),
        query: String(stats.query ?? params.query),
      },
      hasMore: Boolean(response.has_more ?? false),
    };
  },
};

const mapChatSummary = (row: Record<string, unknown>): ChatSummary => ({
  id: String(row.id ?? row.room_id ?? ''),
  roomId: String(row.room_id ?? row.id ?? ''),
  name: String(row.name ?? row.room_name ?? ''),
  avatar: row.avatar_url == null ? null : String(row.avatar_url),
  avatarObjectKey: row.avatar_object_key == null ? null : String(row.avatar_object_key),
  lastMessage: String(row.last_message ?? ''),
  lastMessageTime: parseTimestamp(row.last_message_time ?? row.updated_at),
  unreadCount: Number(row.unread_count ?? 0),
  type: String(row.room_type ?? row.type ?? 'private') === 'group' ? 'group' : 'private',
  isPinned: Boolean(row.is_pinned ?? false),
  isMuted: Boolean(row.is_muted ?? false),
});

const mapMessage = (row: Record<string, unknown>, fallbackRoomId: string): ChatMessage => ({
  id: String(row.id ?? row.message_id ?? ''),
  roomId: String(row.room_id ?? fallbackRoomId),
  senderId: String(row.sender_id ?? ''),
  senderName: String(row.sender_name ?? row.sender_nickname ?? row.sender_username ?? ''),
  content: String(row.content ?? ''),
  type: normalizeMessageType(row.message_type ?? row.type),
  timestamp: parseTimestamp(row.created_at ?? row.timestamp),
  isDeleted: Boolean(row.is_deleted ?? false),
  raw: row,
});

const mapSearchResult = (row: Record<string, unknown>): MessageSearchResult => ({
  id: String(row.id ?? ''),
  roomId: String(row.room_id ?? ''),
  roomName: String(row.room_name ?? ''),
  senderId: String(row.sender_id ?? ''),
  senderName: String(row.sender_name ?? ''),
  content: String(row.content ?? ''),
  messageType: normalizeMessageType(row.message_type),
  timestamp: parseTimestamp(row.timestamp),
  relevanceScore: Number(row.relevance_score ?? 0),
  matchedText: row.matched_text == null ? undefined : String(row.matched_text),
});

const normalizeMessageType = (value: unknown): MessageType => {
  const normalized = String(value ?? 'text');
  if (['text', 'image', 'audio', 'video', 'file', 'system', 'mixed'].includes(normalized)) {
    return normalized as MessageType;
  }
  return 'text';
};

const parseTimestamp = (value: unknown) => {
  if (typeof value === 'number') return value > 1_000_000_000_000 ? value : value * 1000;
  if (typeof value === 'string' && value) {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : Date.now();
  }
  return Date.now();
};
