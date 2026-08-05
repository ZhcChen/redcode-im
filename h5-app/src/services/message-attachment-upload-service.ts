import { requestJson } from '@/api/http';
import {
  attachmentAad,
  encryptAttachment,
  type E2eeAttachmentPart,
} from '@/e2ee/attachment-crypto';
import type { OutgoingMessagePart } from '@/types/chat';

import { requireToken } from './session';

interface DirectUploadSignature {
  url: string;
  method?: string;
  headers?: Record<string, string>;
  key?: string;
}

interface DirectUploadResponse {
  success?: boolean;
  message?: string;
  key?: string | null;
  signature?: DirectUploadSignature | null;
}

export type BrowserAttachmentType = 'image' | 'file';

export const messageAttachmentUploadService = {
  async upload(roomId: string, file: File, type: BrowserAttachmentType, signal?: AbortSignal): Promise<OutgoingMessagePart> {
    if (!roomId) throw new Error('会话不存在');
    validateMessageAttachment(file, type);
    const descriptor = await requestAttachmentSignature(roomId, file, type, signal);
    const key = descriptor.key;
    await uploadObjectBytes(descriptor.descriptor, await file.arrayBuffer(), signal);
    await commitAttachment(roomId, key, file.size, signal);
    return {
      type,
      key,
      name: file.name,
      mimeType: file.type || 'application/octet-stream',
      size: file.size,
    };
  },

  /**
   * E2EE 附件：独立随机 DEK/nonce 先加密再上传密文；DEK/nonce/part_key
   * 随加密消息 payload 发送，服务端与对象存储只接触密文。
   */
  async uploadEncrypted(
    roomId: string,
    file: File,
    type: BrowserAttachmentType,
    signal?: AbortSignal,
  ): Promise<{ part: OutgoingMessagePart; e2eePart: E2eeAttachmentPart }> {
    if (!roomId) throw new Error('会话不存在');
    validateMessageAttachment(file, type);
    const descriptor = await requestAttachmentSignature(roomId, file, type, signal);
    const key = descriptor.key;
    const partKey = globalThis.crypto.randomUUID();
    const aad = attachmentAad({
      roomId,
      partKey,
      partPosition: 0,
      objectKey: key,
    });
    const encrypted = await encryptAttachment(await file.arrayBuffer(), aad);
    await uploadObjectBytes(descriptor.descriptor, encrypted.ciphertext, signal);
    await commitAttachment(roomId, key, encrypted.ciphertext.byteLength, signal);
    return {
      part: {
        type,
        key,
        name: file.name,
        mimeType: file.type || 'application/octet-stream',
        size: file.size,
      },
      e2eePart: {
        partKey,
        objectKey: key,
        name: file.name,
        mimeType: file.type || 'application/octet-stream',
        size: file.size,
        partPosition: 0,
        nonce: encrypted.nonce,
        dek: encrypted.dek,
      },
    };
  },
};

const requestAttachmentSignature = async (
  roomId: string,
  file: File,
  type: BrowserAttachmentType,
  signal?: AbortSignal,
) => {
  const descriptor = await requestJson<DirectUploadResponse>(
    `/rooms/${roomId}/messages/attachments/signature`,
    {
      method: 'POST',
      body: JSON.stringify({
        part_type: type,
        filename: file.name,
        content_type: file.type || 'application/octet-stream',
        file_size: file.size,
      }),
      signal,
    },
    requireToken(),
  );
  if (descriptor.success === false) throw new Error(descriptor.message || '附件签名生成失败');
  const key = descriptor.key ?? descriptor.signature?.key ?? '';
  if (!key) throw new Error('附件签名缺少 object key');
  return { descriptor, key };
};

const uploadObjectBytes = async (
  descriptor: { signature?: DirectUploadSignature | null },
  body: ArrayBuffer | Uint8Array,
  signal?: AbortSignal,
) => {
  if (!descriptor.signature) return;
  if (!descriptor.signature.url) throw new Error('附件签名缺少上传地址');
  const payload = body instanceof ArrayBuffer
    ? body
    : (() => {
        const buffer = new ArrayBuffer(body.byteLength);
        new Uint8Array(buffer).set(body);
        return buffer;
      })();
  const response = await fetch(descriptor.signature.url, {
    method: descriptor.signature.method || 'PUT',
    headers: descriptor.signature.headers,
    body: payload,
    signal,
  });
  if (!response.ok) throw new Error(`附件上传失败 (${response.status})`);
};

const commitAttachment = async (
  roomId: string,
  key: string,
  fileSize: number,
  signal?: AbortSignal,
) => {
  await requestJson(`/rooms/${roomId}/messages/attachments/commit`, {
    method: 'POST',
    body: JSON.stringify({ key, file_size: fileSize }),
    signal,
  }, requireToken());
};

export const validateMessageAttachment = (file: File, type: BrowserAttachmentType) => {
  if (!file) throw new Error('请选择文件');
  if (file.size === 0) throw new Error('不能发送空文件');
  if (type === 'image' && !file.type.startsWith('image/')) throw new Error('请选择图片文件');
};
