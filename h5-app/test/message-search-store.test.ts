import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { resetLocalDatabaseForTests } from '@/storage/local-database';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { MessageSearchStorage } from '@/storage/message-search-storage';
import { useMessageSearchStore } from '@/stores/message-search';
import type { ChatMessage } from '@/types/chat';

const message = (id: string, content: string, roomId = 'r1'): ChatMessage => ({
  id,
  roomId,
  senderId: 'u1',
  senderName: '熊小熊',
  content,
  type: 'text',
  timestamp: Number(id.replace(/\D/g, '')) || 1,
});

describe('message search store', () => {
  let adapter: MemorySqlAdapter;

  beforeEach(async () => {
    adapter = new MemorySqlAdapter();
    await resetLocalDatabaseForTests(adapter);
    setActivePinia(createPinia());
  });

  it('searches indexed messages and keeps result stats', async () => {
    await new MessageSearchStorage(async () => adapter).replaceRoomIndex({
      roomId: 'r1',
      roomName: '项目群',
      messages: [
        message('m1', 'hello indexed cache'),
        message('m2', 'other text'),
      ],
    });
    const store = useMessageSearchStore();
    store.setKeyword('indexed');

    await store.search();

    expect(store.results.map((item) => item.id)).toEqual(['m1']);
    expect(store.totalResults).toBe(1);
    expect(store.hasMore).toBe(false);
    expect(store.error).toBe('');
  });

  it('clears results for empty queries', async () => {
    const store = useMessageSearchStore();
    store.results = [{
      id: 'old',
      roomId: 'r1',
      roomName: '项目群',
      senderId: 'u1',
      senderName: '熊小熊',
      content: 'old',
      messageType: 'text',
      timestamp: 1,
      relevanceScore: 0,
    }];
    store.totalResults = 1;
    store.setKeyword('   ');

    await store.search();

    expect(store.results).toEqual([]);
    expect(store.totalResults).toBe(0);
    expect(store.hasMore).toBe(false);
  });

  it('applies room filter and appends more results', async () => {
    const storage = new MessageSearchStorage(async () => adapter);
    await storage.replaceRoomIndex({
      roomId: 'r1',
      roomName: '一组',
      messages: Array.from({ length: 21 }, (_, index) => message(`m${index + 1}`, `hello ${index + 1}`, 'r1')),
    });
    await storage.replaceRoomIndex({
      roomId: 'r2',
      roomName: '二组',
      messages: [message('m99', 'hello outside', 'r2')],
    });
    const store = useMessageSearchStore();
    store.setKeyword('hello');
    store.setRoomId('r1');

    await store.search();
    expect(store.results).toHaveLength(20);
    expect(store.hasMore).toBe(true);

    await store.loadMore();
    expect(store.results).toHaveLength(21);
    expect(store.results.every((item) => item.roomId === 'r1')).toBe(true);
  });

  it('records index write errors without throwing', async () => {
    await resetLocalDatabaseForTests(new ThrowingSearchAdapter());
    const store = useMessageSearchStore();

    await store.replaceRoomIndex({
      roomId: 'r1',
      roomName: '错误房间',
      messages: [message('m1', 'ignored')],
    });

    expect(store.lastIndexError).toBeTruthy();
  });
});

class ThrowingSearchAdapter extends MemorySqlAdapter {
  async execute(): Promise<void> {
    throw new Error('write failed');
  }
}
