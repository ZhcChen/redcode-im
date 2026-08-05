import { beforeEach, describe, expect, it, vi } from 'vitest';

import {
  e2eeDirectMessageCoordinator,
  type E2eeDecryptedPayload,
} from '@/e2ee/direct-message-coordinator';
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
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptPayload').mockImplementation(async (input) => {
      const marker = new TextDecoder().decode(input.ciphertext);
      order.push(marker);
      return textPayload(`${marker} plaintext`, 1);
    });

    const first = await messageService.loadMessages('r1', { limit: 50 }, 'u1');
    const second = await messageService.loadMessages('r1', { limit: 50 }, 'u1');

    expect(order).toEqual(['old', 'new']);
    expect(decrypt).toHaveBeenCalledTimes(2);
    expect(first.map((message) => message.content)).toEqual(['old plaintext', 'new plaintext']);
    expect(second.map((message) => message.content)).toEqual(['old plaintext', 'new plaintext']);
  });

  it('fails closed for unsupported encryption metadata', async () => {
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptPayload');
    const resolved = await messageService.resolveEncryptedMessage({
      id: 'history-unknown-version-unique',
      roomId: 'r1',
      senderId: 'u2',
      senderName: 'Bear',
      content: '[加密消息]',
      type: 'text' as const,
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

  it('resolves the same encrypted websocket message id only once', async () => {
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptPayload').mockResolvedValue(
      textPayload('ws secret', 1),
    );
    const ciphertext = btoa('ws-ciphertext');
    const message = {
      id: 'ws-e2ee-dup-id',
      roomId: 'r1',
      senderId: 'u2',
      senderName: 'Bear',
      content: '[加密消息]',
      type: 'text' as const,
      timestamp: Date.now(),
      encryptedContent: ciphertext,
      encryptionMetadata: { protocol: 'mls', version: 1, content_type: 'application', epoch: 1 },
    };

    const first = await messageService.resolveEncryptedMessage(message, 'u1');
    const second = await messageService.resolveEncryptedMessage(message, 'u1');

    expect(decrypt).toHaveBeenCalledTimes(1);
    expect(first.content).toBe('ws secret');
    expect(second.content).toBe('ws secret');
    expect(first.e2eeDecryptionFailed).toBe(false);
  });

  it('maps E2EE attachment payload parts into message attachments and memory-only raw parts', async () => {
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptPayload').mockResolvedValue({
      payload: {
        version: 1,
        type: 'attachment',
        parts: [{
          partKey: '00000000-0000-4000-8000-000000000001',
          objectKey: 'messages/r1/files/secret.bin',
          name: 'secret.bin',
          mimeType: 'application/octet-stream',
          size: 3,
          partPosition: 0,
          nonce: new Uint8Array(12).fill(7),
          dek: new Uint8Array(32).fill(9),
        }],
      },
      epoch: 1,
    });
    const message = {
      id: 'e2ee-attachment-message-unique',
      roomId: 'r1',
      senderId: 'u2',
      senderName: 'Bear',
      content: '[加密消息]',
      type: 'mixed' as const,
      timestamp: Date.now(),
      encryptedContent: btoa('ciphertext'),
      encryptionMetadata: { protocol: 'mls', version: 1, content_type: 'application', epoch: 1 },
    };

    const resolved = await messageService.resolveEncryptedMessage(message, 'u1');

    expect(decrypt).toHaveBeenCalledTimes(1);
    expect(resolved).toMatchObject({
      content: '[加密附件]',
      type: 'mixed',
      e2eeDecryptionFailed: false,
      attachments: [{
        key: 'messages/r1/files/secret.bin',
        name: 'secret.bin',
        mimeType: 'application/octet-stream',
        size: 3,
      }],
    });
    expect(resolved.raw?.e2ee_epoch).toBe(1);
    expect(resolved.raw?.e2ee_parts).toEqual([{
      partKey: '00000000-0000-4000-8000-000000000001',
      objectKey: 'messages/r1/files/secret.bin',
      name: 'secret.bin',
      mimeType: 'application/octet-stream',
      size: 3,
      partPosition: 0,
      nonce: new Uint8Array(12).fill(7),
      dek: new Uint8Array(32).fill(9),
    }]);
  });

  it('keeps plaintext history untouched while decrypting ciphertext history', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify([
      {
        id: 'history-plain-unique',
        room_id: 'r1',
        sender_id: 'u2',
        sender_username: 'bear',
        content: 'plain hello',
        message_type: 'text',
        created_at: '2026-08-04T11:59:00Z',
      },
      encryptedMessage('history-mixed-cipher-unique', '2026-08-04T12:00:00Z', 'mixed'),
    ]), { status: 200, headers: { 'Content-Type': 'application/json' } })));
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptPayload').mockImplementation(async (input) =>
      textPayload(`${new TextDecoder().decode(input.ciphertext)} plaintext`, 1),
    );

    const messages = await messageService.loadMessages('r1', { limit: 50 }, 'u1');

    expect(decrypt).toHaveBeenCalledTimes(1);
    expect(messages.map((message) => ({ id: message.id, content: message.content }))).toEqual([
      { id: 'history-plain-unique', content: 'plain hello' },
      { id: 'history-mixed-cipher-unique', content: 'mixed plaintext' },
    ]);
    expect(messages[0]?.e2eeDecryptionFailed).toBeUndefined();
  });

  it('fails closed on corrupted ciphertext and retries decryption explicitly', async () => {
    const decrypt = vi.spyOn(e2eeDirectMessageCoordinator, 'decryptPayload')
      .mockRejectedValueOnce(new Error('corrupted ciphertext'))
      .mockResolvedValueOnce(textPayload('recovered secret', 1));
    const message = {
      id: 'history-corrupt-unique',
      roomId: 'r1',
      senderId: 'u2',
      senderName: 'Bear',
      content: '[加密消息]',
      type: 'text' as const,
      timestamp: Date.now(),
      encryptedContent: btoa('corrupted'),
      encryptionMetadata: { protocol: 'mls', version: 1, content_type: 'application', epoch: 1 },
    };

    const failed = await messageService.resolveEncryptedMessage(message, 'u1');
    const retried = await messageService.retryEncryptedMessage(message, 'u1');

    expect(decrypt).toHaveBeenCalledTimes(2);
    expect(failed).toMatchObject({
      content: '[无法解密的消息]',
      status: 'failed',
      e2eeDecryptionFailed: true,
    });
    expect(retried).toMatchObject({
      content: 'recovered secret',
      status: 'delivered',
      e2eeDecryptionFailed: false,
    });
  });
});

const textPayload = (text: string, epoch: number): E2eeDecryptedPayload => ({
  payload: { version: 1 as const, type: 'text' as const, text },
  epoch,
});
