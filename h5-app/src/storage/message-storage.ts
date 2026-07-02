import type { ChatMessage } from '@/types/chat';

import { getLocalDatabase } from './local-database';
import type { SqlAdapter } from './sql-adapter';

const MAX_CACHE_COUNT = 200;

interface MessageRow {
  id: string;
  room_id: string;
  timestamp: number;
  payload: string;
}

export class MessageStorage {
  constructor(private readonly adapterFactory: () => Promise<SqlAdapter> = getLocalDatabase) {}

  async listRoomIds(): Promise<string[]> {
    const db = await this.ready();
    const rows = await db.query<{ room_id: string }>('SELECT DISTINCT room_id FROM messages');
    return rows.map((row) => row.room_id).filter(Boolean);
  }

  async loadMessages(roomId: string): Promise<ChatMessage[]> {
    if (!roomId) return [];
    const db = await this.ready();
    const rows = await db.query<MessageRow>(
      'SELECT id, room_id, timestamp, payload FROM messages WHERE room_id = ? ORDER BY timestamp ASC',
      [roomId],
    );
    return rows.flatMap((row) => parseMessage(row.payload));
  }

  async saveMessages(roomId: string, messages: ChatMessage[]): Promise<void> {
    if (!roomId) return;
    const db = await this.ready();
    const trimmed = messages
      .slice()
      .sort((a, b) => a.timestamp - b.timestamp)
      .slice(-MAX_CACHE_COUNT);

    await db.transaction(async () => {
      await db.execute('DELETE FROM messages WHERE room_id = ?', [roomId]);
      for (const message of trimmed) {
        if (!message.id) continue;
        await db.execute(
          'INSERT OR REPLACE INTO messages (id, room_id, timestamp, payload) VALUES (?, ?, ?, ?)',
          [message.id, roomId, message.timestamp, JSON.stringify(message)],
        );
      }
    });
  }

  async clear(roomId: string): Promise<void> {
    if (!roomId) return;
    const db = await this.ready();
    await db.execute('DELETE FROM messages WHERE room_id = ?', [roomId]);
  }

  async clearAll(): Promise<void> {
    const db = await this.ready();
    await db.execute('DELETE FROM messages');
  }

  private async ready() {
    const db = await this.adapterFactory();
    await db.execute(`
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        room_id TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    `);
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_room_timestamp ON messages (room_id, timestamp)');
    return db;
  }
}

const parseMessage = (payload: string): ChatMessage[] => {
  try {
    const parsed = JSON.parse(payload) as Partial<ChatMessage>;
    if (!parsed.id || !parsed.roomId || typeof parsed.timestamp !== 'number') {
      return [];
    }
    return [parsed as ChatMessage];
  } catch {
    return [];
  }
};
