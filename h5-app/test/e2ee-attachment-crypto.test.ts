import { describe, expect, it } from 'vitest';

import {
  attachmentAad,
  decryptAttachment,
  decodeAttachmentPart,
  encodeAttachmentPart,
  encryptAttachment,
  type E2eeAttachmentPart,
} from '@/e2ee/attachment-crypto';

const makePart = (): E2eeAttachmentPart => ({
  partKey: '00000000-0000-4000-8000-000000000001',
  objectKey: 'messages/r1/files/secret.bin',
  name: 'secret.bin',
  mimeType: 'application/octet-stream',
  size: 3,
  partPosition: 0,
  nonce: new Uint8Array(12),
  dek: new Uint8Array(32),
});

describe('E2EE attachment crypto', () => {
  it('round-trips plaintext through AES-GCM with attachment AAD', async () => {
    const part = makePart();
    const aad = attachmentAad({
      roomId: '11111111-2222-4333-8444-555555555555',
      partKey: part.partKey,
      partPosition: part.partPosition,
      objectKey: part.objectKey,
    });
    const plaintext = new TextEncoder().encode('top secret attachment').buffer;

    const encrypted = await encryptAttachment(plaintext, aad);
    const decrypted = await decryptAttachment(encrypted.ciphertext, aad, encrypted.nonce, encrypted.dek);

    expect(new TextDecoder().decode(decrypted)).toBe('top secret attachment');
    expect(encrypted.ciphertext).not.toEqual(new Uint8Array(plaintext));
    expect(encrypted.nonce).toHaveLength(12);
    expect(encrypted.dek).toHaveLength(32);
  });

  it('fails decryption when AAD is tampered', async () => {
    const part = makePart();
    const aad = attachmentAad({
      roomId: '11111111-2222-4333-8444-555555555555',
      partKey: part.partKey,
      partPosition: part.partPosition,
      objectKey: part.objectKey,
    });
    const encrypted = await encryptAttachment(new TextEncoder().encode('secret').buffer, aad);
    const tampered = attachmentAad({
      roomId: '11111111-2222-4333-8444-555555555555',
      partKey: part.partKey,
      partPosition: 1,
      objectKey: part.objectKey,
    });

    await expect(
      decryptAttachment(encrypted.ciphertext, tampered, encrypted.nonce, encrypted.dek),
    ).rejects.toThrow();
  });

  it('generates fresh nonce and DEK per encryption', async () => {
    const aad = attachmentAad({
      roomId: '11111111-2222-4333-8444-555555555555',
      partKey: makePart().partKey,
      partPosition: 0,
      objectKey: 'messages/r1/files/a.bin',
    });
    const plaintext = new TextEncoder().encode('same input').buffer;

    const first = await encryptAttachment(plaintext, aad);
    const second = await encryptAttachment(plaintext, aad);

    expect(first.nonce).not.toEqual(second.nonce);
    expect(first.dek).not.toEqual(second.dek);
  });

  it('encodes and decodes attachment payload parts', () => {
    const part = makePart();
    const encoded = encodeAttachmentPart(part);
    const decoded = decodeAttachmentPart(encoded);

    expect(encoded.nonce).toBeTypeOf('string');
    expect(encoded.dek).toBeTypeOf('string');
    expect(decoded).toEqual(part);
  });

  it('binds AAD to big-endian part position and UUID room/part key', () => {
    const part = makePart();
    const aad = attachmentAad({
      roomId: '11111111-2222-4333-8444-555555555555',
      partKey: part.partKey,
      partPosition: 0x01020304,
      objectKey: part.objectKey,
    });
    const bytes = [...aad];
    const domain = new TextEncoder().encode('redcode-im/e2ee/attachment/v1\0');
    const position = bytes.slice(
      domain.length + 16 + 16,
      domain.length + 16 + 16 + 4,
    );

    expect(position).toEqual([1, 2, 3, 4]);
    expect(() => attachmentAad({
      roomId: 'not-a-uuid',
      partKey: part.partKey,
      partPosition: 0,
      objectKey: part.objectKey,
    })).toThrow('UUID 格式无效');
  });
});
