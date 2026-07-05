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

type SearchMode = 'fts' | 'like';

interface ReadySearchStorage {
  db: SqlAdapter;
  mode: SearchMode;
}

export class MessageSearchStorage {
  private initializedAdapter: SqlAdapter | null = null;
  private initializedMode: SearchMode | null = null;

  constructor(private readonly adapterFactory: () => Promise<SqlAdapter> = getLocalDatabase) {}

  async replaceRoomIndex(params: {
    roomId: string;
    roomName: string;
    messages: ChatMessage[];
    maxMessages?: number;
  }): Promise<void> {
    const { roomId, roomName, messages, maxMessages = 200 } = params;
    if (!roomId) return;

    const { db } = await this.ready();
    const trimmed = messages
      .filter((message) => message.id && !message.isDeleted)
      .sort((a, b) => a.timestamp - b.timestamp)
      .slice(-maxMessages);

    await db.transaction(async (tx) => {
      await tx.execute('DELETE FROM message_search WHERE room_id = ?', [roomId]);
      for (const message of trimmed) {
        await tx.execute(
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
    messageType?: MessageType | string;
    limit?: number;
    offset?: number;
  }): Promise<MessageSearchResponse> {
    const startedAt = performance.now();
    const query = params.query.trim();
    if (!query) {
      return emptyResponse(query);
    }

    const { db, mode } = await this.ready();
    const limit = Math.min(Math.max(params.limit ?? 50, 1), 100);
    const offset = Math.max(params.offset ?? 0, 0);
    const { whereClause, args } = buildSearchWhere(mode, query, params.roomId, params.messageType);

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
    return this.initialize();
  }

  private async initialize(): Promise<ReadySearchStorage> {
    const db = await this.adapterFactory();
    if (this.initializedAdapter === db && this.initializedMode) {
      return { db, mode: this.initializedMode };
    }
    try {
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
      await assertFtsSearchUsable(db);
      this.initializedAdapter = db;
      this.initializedMode = 'fts';
      return { db, mode: 'fts' };
    } catch (error) {
      console.warn('[h5-app] FTS5 消息搜索不可用，降级到 LIKE 查询', error);
      await db.execute(`
        CREATE TABLE IF NOT EXISTS message_search (
          id TEXT PRIMARY KEY,
          room_id TEXT NOT NULL,
          room_name TEXT NOT NULL,
          sender_id TEXT NOT NULL,
          sender_name TEXT NOT NULL,
          content TEXT NOT NULL,
          message_type TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      `);
      await db.execute('CREATE INDEX IF NOT EXISTS idx_message_search_room ON message_search (room_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_message_search_type ON message_search (message_type)');
      this.initializedAdapter = db;
      this.initializedMode = 'like';
      return { db, mode: 'like' };
    }
  }
}

const assertFtsSearchUsable = async (db: SqlAdapter) => {
  await db.query(
    'SELECT id FROM message_search WHERE message_search MATCH ? LIMIT 1',
    ['"__redcode_noop__"'],
  );
};

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

const buildSearchWhere = (
  mode: SearchMode,
  query: string,
  roomId?: string,
  messageType?: MessageType | string,
) => {
  const where: string[] = [];
  const args: (string | number)[] = [];
  if (mode === 'fts') {
    where.push('message_search MATCH ?');
    args.push(processSearchQuery(query));
  } else {
    where.push('(room_name LIKE ? ESCAPE ? OR sender_name LIKE ? ESCAPE ? OR content LIKE ? ESCAPE ?)');
    const likeQuery = `%${escapeLikeQuery(query)}%`;
    args.push(likeQuery, '\\', likeQuery, '\\', likeQuery, '\\');
  }
  if (roomId) {
    where.push('room_id = ?');
    args.push(roomId);
  }
  if (messageType) {
    where.push('message_type = ?');
    args.push(messageType);
  }
  return {
    whereClause: where.join(' AND '),
    args,
  };
};

const escapeLikeQuery = (query: string) => query.replace(/[\\%_]/g, (match) => `\\${match}`);

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
