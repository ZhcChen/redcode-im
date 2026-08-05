import { beforeEach, describe, expect, it } from 'vitest';

import { MemorySqlAdapter } from '@/storage/memory-sql-adapter';
import { MessageStorage } from '@/storage/message-storage';
import type { ChatMessage } from '@/types/chat';

const message = (id: string, roomId: string, timestamp: number, content = id): ChatMessage => ({
  id,
  roomId,
  senderId: 'u1',
  senderName: '熊小熊',
  content,
  type: 'text',
  timestamp,
});

describe('MessageStorage', () => {
  let adapter: MemorySqlAdapter;
  let storage: MessageStorage;

  beforeEach(() => {
    adapter = new MemorySqlAdapter();
    storage = new MessageStorage(async () => adapter);
  });

  it('saves and loads room messages ordered by timestamp', async () => {
    await storage.saveMessages('r1', [
      message('m2', 'r1', 2000),
      message('m1', 'r1', 1000),
      message('m3', 'r1', 3000),
    ]);

    const loaded = await storage.loadMessages('r1');

    expect(loaded.map((item) => item.id)).toEqual(['m1', 'm2', 'm3']);
    expect(await storage.listRoomIds()).toEqual(['r1']);
  });

  it('strips memory-only E2EE attachment key material before persisting', async () => {
    const e2eeMessage: ChatMessage = {
      ...message('m-e2ee', 'r1', 1000),
      content: '[加密附件]',
      type: 'mixed',
      attachments: [{ key: 'messages/r1/files/secret.bin', name: 'secret.bin' }],
      raw: {
        e2ee_epoch: 1,
        e2ee_parts: [{
          partKey: '00000000-0000-4000-8000-000000000001',
          objectKey: 'messages/r1/files/secret.bin',
          name: 'secret.bin',
          mimeType: 'application/octet-stream',
          size: 3,
          partPosition: 0,
          nonce: new Uint8Array(12),
          dek: new Uint8Array(32),
        }],
      },
    };

    await storage.saveMessages('r1', [e2eeMessage]);
    const loaded = await storage.loadMessages('r1');

    expect(loaded[0]?.raw?.e2ee_parts).toBeUndefined();
    expect(loaded[0]?.raw?.e2ee_epoch).toBe(1);
    expect(loaded[0]?.attachments).toEqual([{ key: 'messages/r1/files/secret.bin', name: 'secret.bin' }]);
  });

  it('keeps only the latest 200 messages for one room', async () => {
    const messages = Array.from({ length: 205 }, (_, index) => message(`m${index}`, 'r1', index));

    await storage.saveMessages('r1', messages);

    const loaded = await storage.loadMessages('r1');
    expect(loaded).toHaveLength(200);
    expect(loaded[0]?.id).toBe('m5');
    expect(loaded.at(-1)?.id).toBe('m204');
  });

  it('ignores empty room ids and corrupted payload rows', async () => {
    await storage.saveMessages('', [message('m1', '', 1)]);
    adapter.messages.set('bad', {
      id: 'bad',
      room_id: 'r1',
      timestamp: 1,
      payload: '{bad-json',
    });
    await storage.saveMessages('r1', [message('m1', 'r1', 2)]);
    adapter.messages.set('bad', {
      id: 'bad',
      room_id: 'r1',
      timestamp: 1,
      payload: '{bad-json',
    });

    const loaded = await storage.loadMessages('r1');

    expect(await storage.loadMessages('')).toEqual([]);
    expect(loaded.map((item) => item.id)).toEqual(['m1']);
  });

  it('clears one room or all cached messages', async () => {
    await storage.saveMessages('r1', [message('m1', 'r1', 1)]);
    await storage.saveMessages('r2', [message('m2', 'r2', 2)]);

    await storage.clear('r1');
    expect(await storage.loadMessages('r1')).toEqual([]);
    expect(await storage.loadMessages('r2')).toHaveLength(1);

    await storage.clearAll();
    expect(await storage.loadMessages('r2')).toEqual([]);
  });
});
