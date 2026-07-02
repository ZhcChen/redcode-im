import { createPinia, setActivePinia } from 'pinia';
import { beforeEach, describe, expect, it } from 'vitest';

import { resetLocalDatabaseForTests } from '@/storage/local-database';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { MessageStorage } from '@/storage/message-storage';
import { useChatStore } from '@/stores/chat';
import { mergeMessages, useChatDetailStore } from '@/stores/chat-detail';
import type { ChatMessage } from '@/types/chat';

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

const message = (id: string, overrides: Partial<ChatMessage> = {}): ChatMessage => ({
  id,
  roomId: 'r1',
  senderId: 'u2',
  senderName: 'Bear',
  content: id,
  type: 'text',
  timestamp: 1000,
  status: 'sent',
  ...overrides,
});

describe('chat detail store', () => {
  let adapter: MemorySqlAdapter;

  beforeEach(async () => {
    adapter = new MemorySqlAdapter();
    await resetLocalDatabaseForTests(adapter);
    setActivePinia(createPinia());
    saveSession();
  });

  it('loads cached room messages before mock fallback', async () => {
    await new MessageStorage(async () => adapter).saveMessages('r1', [
      message('m1', { content: 'cached hello' }),
    ]);

    const store = useChatDetailStore();
    await store.enterRoom('r1');

    expect(store.messages.map((item) => item.content)).toContain('cached hello');
  });

  it('sends text, persists it and updates chat summary in mock mode', async () => {
    const chatStore = useChatStore();
    chatStore.chats = [{
      id: 'r1',
      roomId: 'r1',
      name: '项目群',
      avatar: null,
      avatarObjectKey: null,
      lastMessage: '',
      lastMessageTime: 1,
      unreadCount: 0,
      type: 'group',
      isPinned: false,
      isMuted: false,
    }];

    const store = useChatDetailStore();
    await store.enterRoom('r1');
    await store.sendText(' hello from detail ');

    expect(store.messages.at(-1)).toMatchObject({
      content: 'hello from detail',
      senderId: 'u1',
      status: 'sent',
    });
    expect(chatStore.chats[0]).toMatchObject({
      lastMessage: 'hello from detail',
      unreadCount: 0,
    });
    const persisted = await new MessageStorage(async () => adapter).loadMessages('r1');
    expect(persisted.some((item) => item.content === 'hello from detail')).toBe(true);
  });

  it('sends quoted text and clears quote selection', async () => {
    const store = useChatDetailStore();
    await store.enterRoom('r1');
    store.quoteMessage(`mock-r1-1`);

    await store.sendText('quoted reply');

    expect(store.quotedMessage).toBeNull();
    expect(store.messages.at(-1)).toMatchObject({
      content: 'quoted reply',
      quotedMessage: expect.objectContaining({ id: `mock-r1-1` }),
    });
  });

  it('marks own messages deleted and persists the local state in mock mode', async () => {
    const store = useChatDetailStore();
    await store.enterRoom('r1');
    await store.sendText('delete me');
    const ownMessageId = store.messages.at(-1)?.id ?? '';

    await store.deleteMessage(ownMessageId);

    expect(store.messages.find((item) => item.id === ownMessageId)).toMatchObject({
      isDeleted: true,
      status: 'deleted',
      content: '',
    });
    const persisted = await new MessageStorage(async () => adapter).loadMessages('r1');
    expect(persisted.find((item) => item.id === ownMessageId)?.isDeleted).toBe(true);
  });

  it('toggles message pin state and applies websocket pin updates', async () => {
    const store = useChatDetailStore();
    await store.enterRoom('r1');
    const messageId = `mock-r1-1`;

    await store.setMessagePinned(messageId, true);
    expect(store.messages.find((item) => item.id === messageId)).toMatchObject({
      isPinned: true,
      pinnedBy: 'u1',
    });

    await store.handleWebSocketEvent({
      type: 'pin_update',
      room_id: 'r1',
      message_id: messageId,
      is_pinned: false,
    });
    expect(store.messages.find((item) => item.id === messageId)).toMatchObject({
      isPinned: false,
      pinnedAt: null,
    });
  });

  it('applies websocket message delete updates', async () => {
    const store = useChatDetailStore();
    await store.enterRoom('r1');
    const messageId = `mock-r1-1`;

    await store.handleWebSocketEvent({
      type: 'message_update',
      room_id: 'r1',
      message_id: messageId,
      is_deleted: true,
    });

    expect(store.messages.find((item) => item.id === messageId)).toMatchObject({
      isDeleted: true,
      status: 'deleted',
      content: '',
    });
  });

  it('maps websocket message parts into local attachments', async () => {
    const store = useChatDetailStore();
    await store.enterRoom('r1');

    await store.handleWebSocketEvent({
      type: 'message',
      id: 'm-attachment',
      room_id: 'r1',
      sender_id: 'u2',
      sender_nickname: 'Bear',
      content: '',
      message_type: 'image',
      timestamp: '2026-07-02T01:00:00Z',
      parts: [{
        part_type: 'image',
        attachment: {
          key: 'messages/r1/images/a.png',
          name: 'a.png',
          mime: 'image/png',
          size: 123,
        },
      }],
    });

    expect(store.messages.find((item) => item.id === 'm-attachment')?.attachments).toEqual([
      {
        key: 'messages/r1/images/a.png',
        name: 'a.png',
        mimeType: 'image/png',
        size: 123,
        cacheKey: 'message:messages/r1/images/a.png',
      },
    ]);
  });

  it('deduplicates websocket and local messages by id', () => {
    const merged = mergeMessages(
      [message('m1', { content: 'old', timestamp: 1 })],
      [message('m1', { content: 'new', timestamp: 2 })],
    );

    expect(merged).toHaveLength(1);
    expect(merged[0]?.content).toBe('new');
  });

  it('replaces matching local pending messages with server messages', () => {
    const merged = mergeMessages(
      [
        message('local-1', {
          senderId: 'u1',
          content: 'same payload',
          status: 'sending',
        }),
      ],
      [
        message('server-1', {
          senderId: 'u1',
          content: 'same payload',
          status: 'sent',
        }),
      ],
    );

    expect(merged).toHaveLength(1);
    expect(merged[0]).toMatchObject({
      id: 'server-1',
      status: 'sent',
    });
  });

  it('does not merge same-content pending messages when quoted message differs', () => {
    const merged = mergeMessages(
      [
        message('local-1', {
          senderId: 'u1',
          content: 'same payload',
          status: 'sending',
          quotedMessage: {
            id: 'q1',
            roomId: 'r1',
            senderId: 'u2',
            senderName: 'Bear',
            content: 'quote',
            type: 'text',
          },
        }),
      ],
      [
        message('server-1', {
          senderId: 'u1',
          content: 'same payload',
          status: 'sent',
          quotedMessage: {
            id: 'q2',
            roomId: 'r1',
            senderId: 'u2',
            senderName: 'Bear',
            content: 'other quote',
            type: 'text',
          },
        }),
      ],
    );

    expect(merged.map((item) => item.id)).toEqual(['local-1', 'server-1']);
  });
});
