import { beforeEach, describe, expect, it } from 'vitest';

import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { MessageSearchStorage } from '@/storage/message-search-storage';
import { MessageStorage } from '@/storage/message-storage';
import type { SqlAdapter, SqlRow, SqlValue } from '@/storage/sql-adapter';
import type { ChatMessage } from '@/types/chat';

const message = (id: string, roomId: string, timestamp: number, content: string): ChatMessage => ({
  id,
  roomId,
  senderId: 'u1',
  senderName: '熊小熊',
  content,
  type: 'text',
  timestamp,
});

describe('MessageSearchStorage', () => {
  let adapter: MemorySqlAdapter;
  let searchStorage: MessageSearchStorage;
  let messageStorage: MessageStorage;

  beforeEach(() => {
    adapter = new MemorySqlAdapter();
    searchStorage = new MessageSearchStorage(async () => adapter);
    messageStorage = new MessageStorage(async () => adapter);
  });

  it('rebuilds a room index and searches cached messages', async () => {
    const messages = [
      message('m1', 'r1', 1000, 'hello redcode'),
      message('m2', 'r1', 2000, 'browser sqlite cache'),
      message('m3', 'r2', 3000, 'redcode in another room'),
    ];
    await messageStorage.saveMessages('r1', messages.slice(0, 2));
    await searchStorage.replaceRoomIndex({
      roomId: 'r1',
      roomName: '项目组',
      messages: await messageStorage.loadMessages('r1'),
    });

    const result = await searchStorage.searchMessages({ query: 'sqlite' });

    expect(result.results.map((item) => item.id)).toEqual(['m2']);
    expect(result.stats.totalResults).toBe(1);
    expect(result.hasMore).toBe(false);
  });

  it('supports empty query and room filtering', async () => {
    await searchStorage.replaceRoomIndex({
      roomId: 'r1',
      roomName: '房间一',
      messages: [message('m1', 'r1', 1000, 'hello')],
    });
    await searchStorage.replaceRoomIndex({
      roomId: 'r2',
      roomName: '房间二',
      messages: [message('m2', 'r2', 2000, 'hello')],
    });

    expect(await searchStorage.searchMessages({ query: '' })).toMatchObject({
      results: [],
      hasMore: false,
    });

    const result = await searchStorage.searchMessages({ query: 'hello', roomId: 'r2' });
    expect(result.results.map((item) => item.id)).toEqual(['m2']);
  });

  it('skips deleted messages when replacing an index', async () => {
    await searchStorage.replaceRoomIndex({
      roomId: 'r1',
      roomName: '房间一',
      messages: [
        message('m1', 'r1', 1000, 'visible'),
        { ...message('m2', 'r1', 2000, 'hidden'), isDeleted: true },
      ],
    });

    const result = await searchStorage.searchMessages({ query: 'hidden' });

    expect(result.results).toEqual([]);
  });

  it('filters by message type', async () => {
    await searchStorage.replaceRoomIndex({
      roomId: 'r1',
      roomName: '房间一',
      messages: [
        message('m1', 'r1', 1000, 'release plan'),
        { ...message('m2', 'r1', 2000, 'release image'), type: 'image' },
      ],
    });

    const result = await searchStorage.searchMessages({ query: 'release', messageType: 'image' });

    expect(result.results.map((item) => item.id)).toEqual(['m2']);
  });

  it('falls back to LIKE search when FTS5 is unavailable', async () => {
    const fallback = new LikeOnlySearchAdapter();
    const storage = new MessageSearchStorage(async () => fallback);

    await storage.replaceRoomIndex({
      roomId: 'r1',
      roomName: '降级房间',
      messages: [message('m1', 'r1', 1000, 'fallback keyword')],
    });
    const result = await storage.searchMessages({ query: 'keyword' });

    expect(result.results.map((item) => item.id)).toEqual(['m1']);
  });
});

class LikeOnlySearchAdapter extends MemorySqlAdapter implements SqlAdapter {
  async execute(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    if (sql.toLowerCase().includes('using fts5')) {
      throw new Error('fts5 unavailable');
    }
    await super.execute(sql, params);
  }

  async query<T = SqlRow>(sql: string, params: readonly SqlValue[] = []): Promise<T[]> {
    return super.query<T>(sql, params);
  }
}
