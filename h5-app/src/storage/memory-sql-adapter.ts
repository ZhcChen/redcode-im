import type { SqlAdapter, SqlRow, SqlValue } from './sql-adapter';

export interface MemoryMessageRow extends SqlRow {
  id: string;
  room_id: string;
  timestamp: number;
  payload: string;
}

export interface MemorySearchRow extends SqlRow {
  id: string;
  room_id: string;
  room_name: string;
  sender_id: string;
  sender_name: string;
  content: string;
  message_type: string;
  timestamp: number;
}

export class MemorySqlAdapter implements SqlAdapter {
  readonly messages = new Map<string, MemoryMessageRow>();
  readonly searchRows = new Map<string, MemorySearchRow>();

  async execute(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    const normalized = normalizeSql(sql);
    if (normalized.startsWith('delete from messages where room_id = ?')) {
      const roomId = String(params[0] ?? '');
      for (const [id, row] of this.messages.entries()) {
        if (row.room_id === roomId) this.messages.delete(id);
      }
      return;
    }
    if (normalized.startsWith('delete from messages')) {
      this.messages.clear();
      return;
    }
    if (normalized.startsWith('insert or replace into messages')) {
      const [id, roomId, timestamp, payload] = params;
      if (typeof id === 'string' && typeof roomId === 'string' && typeof payload === 'string') {
        this.messages.set(id, {
          id,
          room_id: roomId,
          timestamp: Number(timestamp),
          payload,
        });
      }
      return;
    }
    if (normalized.startsWith('delete from message_search where room_id = ?')) {
      const roomId = String(params[0] ?? '');
      for (const [id, row] of this.searchRows.entries()) {
        if (row.room_id === roomId) this.searchRows.delete(id);
      }
      return;
    }
    if (normalized.startsWith('delete from message_search')) {
      this.searchRows.clear();
      return;
    }
    if (normalized.startsWith('insert or replace into message_search')) {
      const [id, roomId, roomName, senderId, senderName, content, messageType, timestamp] = params;
      if (typeof id === 'string' && typeof roomId === 'string') {
        this.searchRows.set(id, {
          id,
          room_id: roomId,
          room_name: String(roomName ?? ''),
          sender_id: String(senderId ?? ''),
          sender_name: String(senderName ?? ''),
          content: String(content ?? ''),
          message_type: String(messageType ?? 'text'),
          timestamp: Number(timestamp),
        });
      }
      return;
    }
  }

  async query<T = SqlRow>(sql: string, params: readonly SqlValue[] = []): Promise<T[]> {
    const normalized = normalizeSql(sql);
    if (normalized.includes('select distinct room_id from messages')) {
      const roomIds = [...new Set([...this.messages.values()].map((row) => row.room_id))];
      return roomIds.map((room_id) => ({ room_id }) as unknown as T);
    }
    if (normalized.includes('from messages') && normalized.includes('where room_id = ?')) {
      const roomId = String(params[0] ?? '');
      return [...this.messages.values()]
        .filter((row) => row.room_id === roomId)
        .sort((a, b) => a.timestamp - b.timestamp)
        .map((row) => ({ ...row }) as unknown as T);
    }
    if (normalized.includes('from message_search')) {
      return this.querySearch<T>(normalized, params);
    }
    return [];
  }

  async transaction<T>(work: () => Promise<T>): Promise<T> {
    const messages = new Map(this.messages);
    const searchRows = new Map(this.searchRows);
    try {
      return await work();
    } catch (error) {
      this.messages.clear();
      messages.forEach((value, key) => this.messages.set(key, value));
      this.searchRows.clear();
      searchRows.forEach((value, key) => this.searchRows.set(key, value));
      throw error;
    }
  }

  async close(): Promise<void> {
    this.messages.clear();
    this.searchRows.clear();
  }

  private querySearch<T>(normalized: string, params: readonly SqlValue[]) {
    const query = String(params[0] ?? '').trim().toLowerCase();
    const roomId = normalized.includes('room_id = ?') ? String(params[1] ?? '') : '';
    const offset = Number(params.at(-1) ?? 0);
    const limit = Number(params.at(-2) ?? 50);
    const matched = [...this.searchRows.values()]
      .filter((row) => !roomId || row.room_id === roomId)
      .filter((row) => {
        if (!query) return false;
        const haystack = `${row.room_name} ${row.sender_name} ${row.content}`.toLowerCase();
        return haystack.includes(query.replaceAll('"', '').replaceAll('*', ''));
      })
      .sort((a, b) => b.timestamp - a.timestamp);

    if (normalized.includes('count(1) as total')) {
      return [{ total: matched.length } as unknown as T];
    }

    return matched.slice(offset, offset + limit).map((row) => ({
      ...row,
      matched_text: row.content,
      relevance_score: 0,
    }) as unknown as T);
  }
}

const normalizeSql = (sql: string) => sql.replace(/\s+/g, ' ').trim().toLowerCase();
