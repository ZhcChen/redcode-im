import { createPinia, setActivePinia } from 'pinia';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { appEnv } from '@/config/env';
import { ApiError } from '@/api/http';
import { e2eeDirectMessageCoordinator } from '@/e2ee/direct-message-coordinator';
import { messageAttachmentUploadService } from '@/services/message-attachment-upload-service';
import { messageService } from '@/services/message-service';
import { settingsService } from '@/services/settings-service';
import { resetLocalDatabaseForTests } from '@/storage/local-database';
import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { MessageSearchStorage } from '@/storage/message-search-storage';
import { MessageStorage } from '@/storage/message-storage';
import type { SqlValue } from '@/storage/sql-adapter';
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

const encryptedResponse = (id: string) => ({
  message: {
    id,
    room_id: 'r1',
    sender_id: 'u1',
    sender_username: 'u1@example.com',
    content: '[加密消息]',
    encrypted_content: btoa('ciphertext'),
    encryption_metadata: { protocol: 'mls', version: 1, content_type: 'application', epoch: 1 },
    message_type: 'text',
    created_at: '2026-08-04T12:00:00Z',
  },
});

describe('chat detail store', () => {
  let adapter: MemorySqlAdapter;

  beforeEach(async () => {
    vi.restoreAllMocks();
    appEnv.useMockData = true;
    adapter = new MemorySqlAdapter();
    await resetLocalDatabaseForTests(adapter);
    setActivePinia(createPinia());
    saveSession();
  });

  afterEach(() => {
    appEnv.useMockData = true;
  });

  it('prepares E2EE text before exposing the optimistic message', async () => {
    appEnv.useMockData = false;
    const store = useChatDetailStore();
    store.roomId = 'r1';
    store.chat = {
      id: 'r1', roomId: 'r1', name: 'Bear', lastMessage: '', lastMessageTime: 1,
      unreadCount: 0, type: 'private', isPinned: false, isMuted: false,
      raw: { friend_user_id: 'u2' },
    };
    vi.spyOn(settingsService, 'fetchGeneralSettings').mockResolvedValue({
      appName: 'RedCode IM',
      messageRuntime: { serverStorageMode: 'persist', contentAuditMode: 'e2ee' },
    });
    const prepare = vi.spyOn(e2eeDirectMessageCoordinator, 'prepareText').mockImplementation(async () => {
      expect(store.messages).toHaveLength(0);
    });
    const retry = vi.spyOn(e2eeDirectMessageCoordinator, 'retryPendingSend').mockImplementation(async () => {
      expect(store.messages).toHaveLength(1);
      expect(store.messages[0]?.status).toBe('sending');
      return encryptedResponse('server-e2ee-1');
    });

    await store.sendText(' browser secret ');

    expect(prepare).toHaveBeenCalledWith(expect.objectContaining({
      accountId: 'u1', roomId: 'r1', peerUserId: 'u2', text: 'browser secret',
    }));
    expect(retry).toHaveBeenCalledOnce();
    expect(store.messages).toEqual([
      expect.objectContaining({ id: 'server-e2ee-1', content: 'browser secret', status: 'sent' }),
    ]);
  });

  it('refreshes runtime after E2EE conflict without automatic resend', async () => {
    appEnv.useMockData = false;
    const store = useChatDetailStore();
    store.roomId = 'r1';
    store.chat = {
      id: 'r1', roomId: 'r1', name: 'Bear', lastMessage: '', lastMessageTime: 1,
      unreadCount: 0, type: 'private', isPinned: false, isMuted: false,
      raw: { friend_user_id: 'u2' },
    };
    const runtime = vi.spyOn(settingsService, 'fetchGeneralSettings').mockResolvedValue({
      appName: 'RedCode IM',
      messageRuntime: { serverStorageMode: 'persist', contentAuditMode: 'e2ee' },
    });
    vi.spyOn(e2eeDirectMessageCoordinator, 'prepareText').mockResolvedValue();
    const retry = vi.spyOn(e2eeDirectMessageCoordinator, 'retryPendingSend')
      .mockRejectedValue(new ApiError('runtime conflict', 409, { code: 40902 }));

    await store.sendText('keep draft');

    expect(runtime).toHaveBeenCalledTimes(2);
    expect(retry).toHaveBeenCalledOnce();
    expect(store.messages).toEqual([
      expect.objectContaining({ content: 'keep draft', status: 'failed' }),
    ]);
  });

  it('does not refresh runtime after an unrelated send conflict', async () => {
    appEnv.useMockData = false;
    const store = useChatDetailStore();
    store.roomId = 'r1';
    const runtime = vi.spyOn(settingsService, 'fetchGeneralSettings').mockResolvedValue({
      appName: 'RedCode IM',
      messageRuntime: { serverStorageMode: 'persist', contentAuditMode: 'server' },
    });
    vi.spyOn(messageService, 'sendTextMessage')
      .mockRejectedValue(new ApiError('already exists', 409, { code: 40901 }));

    await store.sendText('plain message');

    expect(runtime).toHaveBeenCalledOnce();
    expect(store.messages).toEqual([
      expect.objectContaining({ content: 'plain message', status: 'failed' }),
    ]);
  });

  it('decrypts a duplicate encrypted websocket message only once', async () => {
    appEnv.useMockData = false;
    const store = useChatDetailStore();
    store.roomId = 'r1';
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptText').mockResolvedValue({
      text: 'live browser secret',
      epoch: 1,
    });
    const event = {
      type: 'message', id: 'ws-e2ee-unique', message_id: 'ws-e2ee-unique', room_id: 'r1',
      sender_id: 'u2', sender_username: 'bear', content: '[加密消息]', message_type: 'text',
      timestamp: '2026-08-04T12:00:00Z', encrypted_content: btoa('ciphertext'),
      encryption_metadata: { protocol: 'mls', version: 1, content_type: 'application', epoch: 1 },
    };

    await store.handleWebSocketEvent(event);
    await store.handleWebSocketEvent(event);

    expect(decrypt).toHaveBeenCalledOnce();
    expect(store.messages).toEqual([
      expect.objectContaining({ id: 'ws-e2ee-unique', content: 'live browser secret' }),
    ]);
  });

  it('loads cached room messages before mock fallback', async () => {
    await new MessageStorage(async () => adapter).saveMessages('r1', [
      message('m1', { content: 'cached hello' }),
    ]);

    const store = useChatDetailStore();
    await store.enterRoom('r1');

    expect(store.messages.map((item) => item.content)).toContain('cached hello');
  });

  it('loads older pages until a deep-linked message is found', async () => {
    appEnv.useMockData = false;
    const store = useChatDetailStore();
    store.roomId = 'r1';
    store.messages = [message('m51', { timestamp: 51 }), message('m52', { timestamp: 52 })];
    const load = vi.spyOn(messageService, 'loadMessages').mockResolvedValue([
      message('target-old', { timestamp: 1 }),
      message('m50', { timestamp: 50 }),
    ]);

    await expect(store.loadUntilFound('target-old')).resolves.toBe(true);
    expect(load).toHaveBeenCalledWith('r1', { limit: 50, beforeId: 'm51' }, 'u1');
    expect(store.messages[0]?.id).toBe('target-old');
  });

  it('updates the local search index when room messages are persisted', async () => {
    const store = useChatDetailStore();
    await store.enterRoom('r1', {
      id: 'r1',
      roomId: 'r1',
      name: '搜索项目群',
      avatar: null,
      avatarObjectKey: null,
      lastMessage: '',
      lastMessageTime: 1,
      unreadCount: 0,
      type: 'group',
      isPinned: false,
      isMuted: false,
    });
    await store.sendText('indexed browser search');

    const result = await new MessageSearchStorage(async () => adapter).searchMessages({ query: 'browser' });

    expect(result.results.at(0)).toMatchObject({
      roomId: 'r1',
      roomName: '搜索项目群',
      content: 'indexed browser search',
    });
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

  it('sends browser attachments and updates the local conversation', async () => {
    const store = useChatDetailStore();
    await store.enterRoom('r1');

    await store.sendAttachment(new File(['image'], 'photo.png', { type: 'image/png' }), 'image');

    expect(store.uploadingAttachment).toBe(false);
    expect(store.failedAttachment).toBeNull();
    expect(store.messages.at(-1)).toMatchObject({
      type: 'image',
      status: 'sent',
      attachments: [expect.objectContaining({ name: 'photo.png', mimeType: 'image/png' })],
    });
  });

  it('keeps failed attachments available for retry', async () => {
    appEnv.useMockData = false;
    const store = useChatDetailStore();
    store.roomId = 'r1';
    const file = new File(['document'], 'report.txt', { type: 'text/plain' });
    vi.spyOn(messageAttachmentUploadService, 'upload')
      .mockRejectedValueOnce(new Error('storage unavailable'))
      .mockResolvedValueOnce({ type: 'file', key: 'messages/r1/files/report.txt', name: file.name, mimeType: file.type, size: file.size });
    vi.spyOn(messageService, 'sendRichMessage').mockResolvedValue(message('server-file', {
      senderId: 'u1',
      content: '',
      type: 'file',
      attachments: [{ key: 'messages/r1/files/report.txt', name: file.name }],
    }));

    await store.sendAttachment(file, 'file');
    expect(store.error).toBe('storage unavailable');
    expect(store.failedAttachment?.file).toBe(file);

    await store.retryAttachment();
    expect(store.failedAttachment).toBeNull();
    expect(store.messages.at(-1)?.id).toBe('server-file');
  });

  it('cancels an active attachment upload without retaining retry state', async () => {
    appEnv.useMockData = false;
    const store = useChatDetailStore();
    store.roomId = 'r1';
    vi.spyOn(messageAttachmentUploadService, 'upload').mockImplementation((_roomId, _file, _type, signal) => (
      new Promise((_resolve, reject) => signal?.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError'))))
    ));

    const sending = store.sendAttachment(new File(['x'], 'cancel.txt', { type: 'text/plain' }), 'file');
    await Promise.resolve();
    store.cancelAttachmentUpload();
    await sending;

    expect(store.uploadingAttachment).toBe(false);
    expect(store.failedAttachment).toBeNull();
    expect(store.error).toBe('已取消附件发送');
  });

  it('keeps sending when local search index persistence fails', async () => {
    adapter = new SearchWriteFailingAdapter();
    await resetLocalDatabaseForTests(adapter);
    const store = useChatDetailStore();

    await store.enterRoom('r1');
    await store.sendText('send despite search failure');

    expect(store.messages.at(-1)).toMatchObject({
      content: 'send despite search failure',
      status: 'sent',
    });
    const persisted = await new MessageStorage(async () => adapter).loadMessages('r1');
    expect(persisted.some((item) => item.content === 'send despite search failure')).toBe(true);
  });

  it('does not expose a new local message until the cache write has completed', async () => {
    const delayedAdapter = new DelayedMessageWriteAdapter('m-delayed');
    adapter = delayedAdapter;
    await resetLocalDatabaseForTests(adapter);
    const store = useChatDetailStore();
    store.roomId = 'r1';

    const upsert = store.upsertLocalMessage(message('m-delayed', { content: 'durable before visible' }));
    await delayedAdapter.waitForWrite();

    expect(store.messages.some((item) => item.id === 'm-delayed')).toBe(false);

    delayedAdapter.releaseWrite();
    await upsert;

    expect(store.messages.some((item) => item.id === 'm-delayed')).toBe(true);
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

  it('marks own messages through the read receipt target as read', async () => {
    const store = useChatDetailStore();
    store.roomId = 'r1';
    store.messages = [
      message('own-1', { senderId: 'u1', status: 'sent', timestamp: 1 }),
      message('incoming', { senderId: 'u2', timestamp: 2 }),
      message('own-2', { senderId: 'u1', status: 'sent', timestamp: 3 }),
    ];

    await store.handleWebSocketEvent({
      type: 'message_read', room_id: 'r1', message_id: 'own-2', reader_id: 'u2',
    });

    expect(store.messages.find((item) => item.id === 'own-1')?.status).toBe('read');
    expect(store.messages.find((item) => item.id === 'own-2')?.status).toBe('read');
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
      forward_message: {
        message_id: 'origin-1', room_id: 'origin-room', sender_id: 'u3',
        sender_username: 'neo', sender_nickname: 'Neo',
      },
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
    expect(store.messages.find((item) => item.id === 'm-attachment')?.forwardInfo).toMatchObject({
      messageId: 'origin-1', senderNickname: 'Neo',
    });
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

class SearchWriteFailingAdapter extends MemorySqlAdapter {
  async execute(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    if (sql.toLowerCase().includes('message_search')) {
      throw new Error('search index unavailable');
    }
    await super.execute(sql, params);
  }
}

class DelayedMessageWriteAdapter extends MemorySqlAdapter {
  private writeStartedResolve: () => void = () => undefined;
  private writeReleaseResolve: () => void = () => undefined;
  private readonly writeStarted = new Promise<void>((resolve) => {
    this.writeStartedResolve = resolve;
  });
  private readonly writeReleased = new Promise<void>((resolve) => {
    this.writeReleaseResolve = resolve;
  });

  constructor(private readonly delayedMessageId: string) {
    super();
  }

  async execute(sql: string, params: readonly SqlValue[] = []): Promise<void> {
    if (
      sql.toLowerCase().includes('insert or replace into messages')
      && params[0] === this.delayedMessageId
    ) {
      this.writeStartedResolve();
      await this.writeReleased;
    }
    await super.execute(sql, params);
  }

  waitForWrite() {
    return this.writeStarted;
  }

  releaseWrite() {
    this.writeReleaseResolve();
  }
}
