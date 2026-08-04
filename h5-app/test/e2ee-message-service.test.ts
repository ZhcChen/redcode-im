import { beforeEach, describe, expect, it, vi } from 'vitest';

import { e2eeDirectMessageCoordinator } from '@/e2ee/direct-message-coordinator';
import { messageService } from '@/services/message-service';

const saveSession = () => {
  window.localStorage.setItem('redcode-h5-session', JSON.stringify({
    token: 'token-1',
    user: { id: 'u1', username: 'u1@example.com', nickname: 'U1', email: 'u1@example.com' },
  }));
};

const encryptedMessage = (id: string, createdAt: string, marker: string) => ({
  id,
  room_id: 'r1',
  sender_id: 'u2',
  sender_username: 'bear',
  content: '[加密消息]',
  encrypted_content: btoa(marker),
  encryption_metadata: { protocol: 'mls', version: 1, content_type: 'application', epoch: 1 },
  message_type: 'text',
  created_at: createdAt,
});

describe('H5 E2EE message service', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    saveSession();
  });

  it('decrypts history chronologically and reuses resolved message ids', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify([
      encryptedMessage('history-new-unique', '2026-08-04T12:01:00Z', 'new'),
      encryptedMessage('history-old-unique', '2026-08-04T12:00:00Z', 'old'),
    ]), { status: 200, headers: { 'Content-Type': 'application/json' } })));
    const order: string[] = [];
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptText').mockImplementation(async (input) => {
      const marker = new TextDecoder().decode(input.ciphertext);
      order.push(marker);
      return { text: `${marker} plaintext`, epoch: 1 };
    });

    const first = await messageService.loadMessages('r1', { limit: 50 }, 'u1');
    const second = await messageService.loadMessages('r1', { limit: 50 }, 'u1');

    expect(order).toEqual(['old', 'new']);
    expect(decrypt).toHaveBeenCalledTimes(2);
    expect(first.map((message) => message.content)).toEqual(['old plaintext', 'new plaintext']);
    expect(second.map((message) => message.content)).toEqual(['old plaintext', 'new plaintext']);
  });

  it('fails closed for unsupported encryption metadata', async () => {
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptText');
    const resolved = await messageService.resolveEncryptedMessage({
      id: 'history-unknown-version-unique',
      roomId: 'r1',
      senderId: 'u2',
      senderName: 'Bear',
      content: '[加密消息]',
      type: 'text',
      timestamp: Date.now(),
      encryptedContent: btoa('ciphertext'),
      encryptionMetadata: { protocol: 'mls', version: 2, content_type: 'application' },
    }, 'u1');

    expect(decrypt).not.toHaveBeenCalled();
    expect(resolved).toMatchObject({
      content: '[无法解密的消息]',
      status: 'failed',
      e2eeDecryptionFailed: true,
    });
  });
});
