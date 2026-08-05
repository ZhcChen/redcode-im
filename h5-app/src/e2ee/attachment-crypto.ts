const ATTACHMENT_AAD_DOMAIN = 'redcode-im/e2ee/attachment/v1\0';
const textEncoder = new TextEncoder();

export interface E2eeAttachmentPart {
  partKey: string;
  objectKey: string;
  name: string;
  mimeType: string;
  size: number;
  partPosition: number;
  nonce: Uint8Array;
  dek: Uint8Array;
}

export interface E2eeAttachmentPayloadPart {
  partKey: string;
  objectKey: string;
  name: string;
  mimeType: string;
  size: number;
  partPosition: number;
  nonce: string;
  dek: string;
}

export const encodeAttachmentPart = (part: E2eeAttachmentPart): E2eeAttachmentPayloadPart => ({
  partKey: part.partKey,
  objectKey: part.objectKey,
  name: part.name,
  mimeType: part.mimeType,
  size: part.size,
  partPosition: part.partPosition,
  nonce: bytesToBase64(part.nonce),
  dek: bytesToBase64(part.dek),
});

export const decodeAttachmentPart = (part: E2eeAttachmentPayloadPart): E2eeAttachmentPart => ({
  partKey: part.partKey,
  objectKey: part.objectKey,
  name: part.name,
  mimeType: part.mimeType,
  size: part.size,
  partPosition: part.partPosition,
  nonce: base64ToBytes(part.nonce),
  dek: base64ToBytes(part.dek),
});

/**
 * AAD 绑定 room、part_key、part_position 与 object key；part_key 只在一
 * 条消息中出现一次，等价绑定 message。重试必须重新生成 part_key/nonce/DEK。
 */
export const attachmentAad = (input: {
  roomId: string;
  partKey: string;
  partPosition: number;
  objectKey: string;
}): Uint8Array => {
  if (!Number.isSafeInteger(input.partPosition) || input.partPosition < 0) {
    throw new Error('E2EE 附件 part_position 无效');
  }
  const domain = textEncoder.encode(ATTACHMENT_AAD_DOMAIN);
  const roomId = parseUuidBytes(input.roomId);
  const partKey = parseUuidBytes(input.partKey);
  const position = new Uint8Array(4);
  new DataView(position.buffer).setUint32(0, input.partPosition, false);
  const objectKey = textEncoder.encode(input.objectKey);
  const aad = new Uint8Array(domain.length + roomId.length + partKey.length + position.length + objectKey.length);
  let offset = 0;
  aad.set(domain, offset);
  offset += domain.length;
  aad.set(roomId, offset);
  offset += roomId.length;
  aad.set(partKey, offset);
  offset += partKey.length;
  aad.set(position, offset);
  offset += position.length;
  aad.set(objectKey, offset);
  return aad;
};

export const encryptAttachment = async (
  plaintext: ArrayBuffer,
  aad: Uint8Array,
  cryptoProvider: Crypto = globalThis.crypto,
): Promise<{ ciphertext: Uint8Array; nonce: Uint8Array; dek: Uint8Array }> => {
  if (!cryptoProvider?.subtle) throw new Error('WebCrypto 不可用');
  const dek = cryptoProvider.getRandomValues(new Uint8Array(32));
  const nonce = cryptoProvider.getRandomValues(new Uint8Array(12));
  const key = await cryptoProvider.subtle.importKey(
    'raw',
    toArrayBuffer(dek),
    { name: 'AES-GCM' },
    false,
    ['encrypt'],
  );
  const ciphertext = await cryptoProvider.subtle.encrypt(
    { name: 'AES-GCM', iv: toArrayBuffer(nonce), additionalData: toArrayBuffer(aad) },
    key,
    plaintext,
  );
  return { ciphertext: new Uint8Array(ciphertext), nonce, dek };
};

export const decryptAttachment = async (
  ciphertext: Uint8Array,
  aad: Uint8Array,
  nonce: Uint8Array,
  dek: Uint8Array,
  cryptoProvider: Crypto = globalThis.crypto,
): Promise<Uint8Array> => {
  if (!cryptoProvider?.subtle) throw new Error('WebCrypto 不可用');
  if (nonce.length !== 12 || dek.length !== 32) {
    throw new Error('E2EE 附件密钥参数无效');
  }
  const key = await cryptoProvider.subtle.importKey(
    'raw',
    toArrayBuffer(dek),
    { name: 'AES-GCM' },
    false,
    ['decrypt'],
  );
  const plaintext = await cryptoProvider.subtle.decrypt(
    { name: 'AES-GCM', iv: toArrayBuffer(nonce), additionalData: toArrayBuffer(aad) },
    key,
    toArrayBuffer(ciphertext),
  );
  return new Uint8Array(plaintext);
};

const toArrayBuffer = (value: Uint8Array): ArrayBuffer => {
  const buffer = new ArrayBuffer(value.byteLength);
  new Uint8Array(buffer).set(value);
  return buffer;
};

const parseUuidBytes = (value: string): Uint8Array => {
  const hex = value.replace(/-/g, '').trim();
  if (!/^[0-9a-fA-F]{32}$/.test(hex)) throw new Error('E2EE 附件 UUID 格式无效');
  const bytes = new Uint8Array(16);
  for (let index = 0; index < 16; index += 1) {
    bytes[index] = Number.parseInt(hex.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
};

const bytesToBase64 = (value: Uint8Array) => {
  let binary = '';
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
};

const base64ToBytes = (value: string) => Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
