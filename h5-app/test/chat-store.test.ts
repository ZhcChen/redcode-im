import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { resetLocalDatabaseForTests } from '@/storage/local-database';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { ChatSummaryStorage } from '@/storage/chat-summary-storage';
import { MessageStorage } from '@/storage/message-storage';
import { formatChatDisplayTime, useChatStore } from '@/stores/chat';
import type { ChatMessage, ChatSummary } from '@/types/chat';

const chat = (roomId: string, overrides: Partial<ChatSummary> = {}): ChatSummary => ({
  id: roomId,
  roomId,
  name: `room-${roomId}`,
  avatar: null,
  avatarObjectKey: null,
  lastMessage: '',
  lastMessageTime: 1000,
  unreadCount: 0,
  type: 'private',
  isPinned: false,
  isMuted: false,
  ...overrides,
});

const message = (id: string, overrides: Partial<ChatMessage> = {}): ChatMessage => ({
  id,
  roomId: 'r1',
  senderId: 'u2',
  senderName: 'Bear',
  content: 'hello',
  type: 'text',
  timestamp: 2000,
  ...overrides,
});

const saveSession = () => {
  window.localStorage.setItem(
    'redcode-h5-session',
    JSON.stringify({
      token: 'token-1',
      user: {
        id: 'u1',
        username: 'u1@example.com',
        nickname: 'U1',
        email: 'u1@example.com',
      },
    }),
  );
};

describe('chat store', () => {
  let adapter: MemorySqlAdapter;

  beforeEach(async () => {
    adapter = new MemorySqlAdapter();
    await resetLocalDatabaseForTests(adapter);
    setActivePinia(createPinia());
    saveSession();
  });

  it('loads cached chat summaries before network refresh', async () => {
    const storage = new ChatSummaryStorage(async () => adapter);
    await storage.saveChats([
      chat('r2', { lastMessageTime: 2000 }),
      chat('r1', { isPinned: true, lastMessageTime: 1000 }),
    ]);

    const store = useChatStore();
    await store.loadCachedChats();

    expect(store.cacheLoaded).toBe(true);
    expect(store.chats.map((item) => item.roomId)).toEqual(['r1', 'r2']);
  });

  it('updates chat summary and local message cache from websocket messages', async () => {
    const store = useChatStore();
    store.chats = [chat('r1')];

    await store.applyIncomingMessage(message('m1'));
    await store.applyIncomingMessage(message('m1', { content: 'hello again', timestamp: 3000 }));

    expect(store.chats[0]).toMatchObject({
      roomId: 'r1',
      lastMessage: 'hello again',
      unreadCount: 1,
    });
    const messages = await new MessageStorage(async () => adapter).loadMessages('r1');
    expect(messages).toHaveLength(1);
    expect(messages[0]?.content).toBe('hello again');
  });

  it('does not increment unread count for self messages', async () => {
    const store = useChatStore();
    store.chats = [chat('r1', { unreadCount: 3 })];

    await store.applyIncomingMessage(message('m1', { senderId: 'u1' }));

    expect(store.chats[0]?.unreadCount).toBe(3);
  });

  it('formats chat display time like Flutter chat model', () => {
    const now = new Date('2026-07-02T10:30:00+08:00');

    expect(formatChatDisplayTime(Date.parse('2026-07-02T10:29:30+08:00'), now)).toBe('刚刚');
    expect(formatChatDisplayTime(Date.parse('2026-07-02T09:15:00+08:00'), now)).toBe('09:15');
    expect(formatChatDisplayTime(Date.parse('2026-07-01T23:00:00+08:00'), now)).toBe('昨天');
    expect(formatChatDisplayTime(Date.parse('2026-06-30T23:00:00+08:00'), now)).toBe('6月30日');
  });
});
