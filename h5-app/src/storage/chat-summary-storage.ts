import type { ChatSummary } from '@/types/chat';

import { getLocalDatabase } from './local-database';
import type { SqlAdapter } from './sql-adapter';

interface ChatSummaryRow {
  room_id: string;
  pinned_rank: number;
  last_message_time: number;
  payload: string;
}

export class ChatSummaryStorage {
  constructor(private readonly adapterFactory: () => Promise<SqlAdapter> = getLocalDatabase) {}

  async loadChats(): Promise<ChatSummary[]> {
    const db = await this.ready();
    const rows = await db.query<ChatSummaryRow>(
      `SELECT room_id, pinned_rank, last_message_time, payload
       FROM chat_summaries
       ORDER BY pinned_rank ASC, last_message_time DESC`,
    );
    return rows.flatMap((row) => parseChat(row.payload));
  }

  async saveChats(chats: ChatSummary[]): Promise<void> {
    const db = await this.ready();
    await db.transaction(async () => {
      await db.execute('DELETE FROM chat_summaries');
      for (const chat of chats) {
        if (!chat.roomId) continue;
        await db.execute(
          `INSERT OR REPLACE INTO chat_summaries
           (room_id, pinned_rank, last_message_time, payload)
           VALUES (?, ?, ?, ?)`,
          [
            chat.roomId,
            chat.isPinned ? 0 : 1,
            chat.lastMessageTime,
            JSON.stringify(chat),
          ],
        );
      }
    });
  }

  async clear(): Promise<void> {
    const db = await this.ready();
    await db.execute('DELETE FROM chat_summaries');
  }

  private async ready() {
    const db = await this.adapterFactory();
    await db.execute(`
      CREATE TABLE IF NOT EXISTS chat_summaries (
        room_id TEXT PRIMARY KEY,
        pinned_rank INTEGER NOT NULL,
        last_message_time INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    `);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_summaries_sort ON chat_summaries (pinned_rank, last_message_time)',
    );
    return db;
  }
}

const parseChat = (payload: string): ChatSummary[] => {
  try {
    const parsed = JSON.parse(payload) as Partial<ChatSummary>;
    if (!parsed.roomId || !parsed.name || typeof parsed.lastMessageTime !== 'number') {
      return [];
    }
    return [parsed as ChatSummary];
  } catch {
    return [];
  }
};
