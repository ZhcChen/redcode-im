import type { ChatMessage, MessageSearchResponse, MessageSearchResult, MessageType } from '@/types/chat';

import { getLocalDatabase } from './local-database';
import type { SqlAdapter } from './sql-adapter';

interface SearchRow {
  id: string;
  room_id: string;
  room_name: string;
  sender_id: string;
  sender_name: string;
  content: string;
  message_type: string;
  timestamp: number;
  matched_text?: string | null;
  relevance_score?: number | null;
}

export class MessageSearchStorage {
  constructor(private readonly adapterFactory: () => Promise<SqlAdapter> = getLocalDatabase) {}

  async replaceRoomIndex(params: {
    roomId: string;
    roomName: string;
    messages: ChatMessage[];
    maxMessages?: number;
  }): Promise<void> {
    const { roomId, roomName, messages, maxMessages = 200 } = params;
    if (!roomId) return;

    const db = await this.ready();
    const trimmed = messages
      .filter((message) => message.id && !message.isDeleted)
      .sort((a, b) => a.timestamp - b.timestamp)
      .slice(-maxMessages);

    await db.transaction(async () => {
      await db.execute('DELETE FROM message_search WHERE room_id = ?', [roomId]);
      for (const message of trimmed) {
        await db.execute(
          `
            INSERT OR REPLACE INTO message_search
              (id, room_id, room_name, sender_id, sender_name, content, message_type, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          `,
          [
            message.id,
            roomId,
            roomName,
            message.senderId,
            message.senderName,
            normalizeContent(message),
            message.type,
            message.timestamp,
          ],
        );
      }
    });
  }

  async searchMessages(params: {
    query: string;
    roomId?: string;
    limit?: number;
    offset?: number;
  }): Promise<MessageSearchResponse> {
    const startedAt = performance.now();
    const query = params.query.trim();
    if (!query) {
      return emptyResponse(query);
    }

    const db = await this.ready();
    const limit = Math.min(Math.max(params.limit ?? 50, 1), 100);
    const offset = Math.max(params.offset ?? 0, 0);
    const where = ['message_search MATCH ?'];
    const args: (string | number)[] = [processSearchQuery(query)];
    if (params.roomId) {
      where.push('room_id = ?');
      args.push(params.roomId);
    }
    const whereClause = where.join(' AND ');

    const countRows = await db.query<{ total: number }>(
      `SELECT COUNT(1) AS total FROM message_search WHERE ${whereClause}`,
      args,
    );
    const rows = await db.query<SearchRow>(
      `
        SELECT
          id,
          room_id,
          room_name,
          sender_id,
          sender_name,
          content,
          message_type,
          timestamp,
          content AS matched_text,
          0 AS relevance_score
        FROM message_search
        WHERE ${whereClause}
        ORDER BY timestamp DESC
        LIMIT ? OFFSET ?
      `,
      [...args, limit, offset],
    );

    const total = Number(countRows[0]?.total ?? rows.length);
    const results = rows.map(toSearchResult);
    return {
      results,
      stats: {
        totalResults: total,
        searchTimeMs: Math.round(performance.now() - startedAt),
        query,
      },
      hasMore: offset + results.length < total,
    };
  }

  private async ready() {
    const db = await this.adapterFactory();
    await db.execute(`
      CREATE VIRTUAL TABLE IF NOT EXISTS message_search USING fts5(
        id UNINDEXED,
        room_id UNINDEXED,
        room_name,
        sender_id UNINDEXED,
        sender_name,
        content,
        message_type UNINDEXED,
        timestamp UNINDEXED
      )
    `);
    return db;
  }
}

const normalizeContent = (message: ChatMessage) => {
  const trimmed = message.content.trim();
  if (trimmed) return trimmed;
  const labels: Record<MessageType, string> = {
    text: '[消息]',
    image: '[图片]',
    audio: '[语音]',
    video: '[视频]',
    file: '[文件]',
    system: '[系统消息]',
    mixed: '[多媒体消息]',
  };
  return labels[message.type] ?? '[消息]';
};

const processSearchQuery = (query: string) => {
  const trimmed = query.trim();
  if (!trimmed) return '';
  if (trimmed.includes('"') || /\b(AND|OR|NOT)\b/.test(trimmed)) {
    return trimmed;
  }
  const words = trimmed.split(/\s+/).filter(Boolean);
  if (words.length === 1) return `"${words[0]}"*`;
  return words.map((word) => `"${word}"*`).join(' AND ');
};

const toSearchResult = (row: SearchRow): MessageSearchResult => ({
  id: row.id,
  roomId: row.room_id,
  roomName: row.room_name,
  senderId: row.sender_id,
  senderName: row.sender_name,
  content: row.content,
  messageType: (row.message_type || 'text') as MessageType,
  timestamp: Number(row.timestamp),
  relevanceScore: Number(row.relevance_score ?? 0),
  matchedText: row.matched_text ?? undefined,
});

const emptyResponse = (query: string): MessageSearchResponse => ({
  results: [],
  stats: {
    totalResults: 0,
    searchTimeMs: 0,
    query,
  },
  hasMore: false,
});
