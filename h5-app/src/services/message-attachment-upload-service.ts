import { requestJson } from '@/api/http';
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

    if (descriptor.signature) {
      if (!descriptor.signature.url) throw new Error('附件签名缺少上传地址');
      const response = await fetch(descriptor.signature.url, {
        method: descriptor.signature.method || 'PUT',
        headers: descriptor.signature.headers,
        body: await file.arrayBuffer(),
        signal,
      });
      if (!response.ok) throw new Error(`附件上传失败 (${response.status})`);
    }

    await requestJson(`/rooms/${roomId}/messages/attachments/commit`, {
      method: 'POST',
      body: JSON.stringify({ key, file_size: file.size }),
      signal,
    }, requireToken());

    return {
      type,
      key,
      name: file.name,
      mimeType: file.type || 'application/octet-stream',
      size: file.size,
    };
  },
};

export const validateMessageAttachment = (file: File, type: BrowserAttachmentType) => {
  if (!file) throw new Error('请选择文件');
  if (file.size === 0) throw new Error('不能发送空文件');
  if (type === 'image' && !file.type.startsWith('image/')) throw new Error('请选择图片文件');
};
