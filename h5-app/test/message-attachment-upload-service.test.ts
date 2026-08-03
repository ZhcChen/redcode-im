import { beforeEach, describe, expect, it, vi } from 'vitest';

import { appEnv } from '@/config/env';
import { messageAttachmentUploadService, validateMessageAttachment } from '@/services/message-attachment-upload-service';

describe('message attachment upload service', () => {
  beforeEach(() => {
    appEnv.apiBaseUrl = 'http://127.0.0.1:8010';
    window.localStorage.setItem('redcode-h5-session', JSON.stringify({ token: 'token-1', user: { id: 'u1' } }));
  });

  it('signs, uploads and commits a browser file', async () => {
    const calls: Array<{ url: string; init?: RequestInit }> = [];
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      calls.push({ url, init });
      if (url.endsWith('/attachments/signature')) {
        return new Response(JSON.stringify({ key: 'messages/r1/files/a.txt', signature: { url: 'http://storage/upload', method: 'PUT' } }), { status: 200 });
      }
      if (url === 'http://storage/upload') return new Response('', { status: 200 });
      return new Response(JSON.stringify({ success: true }), { status: 200 });
    }));

    const part = await messageAttachmentUploadService.upload('r1', new File(['abc'], 'a.txt', { type: 'text/plain' }), 'file');

    expect(part).toMatchObject({ type: 'file', key: 'messages/r1/files/a.txt', name: 'a.txt', size: 3 });
    expect(calls.map((call) => call.url)).toEqual([
      'http://127.0.0.1:8010/rooms/r1/messages/attachments/signature',
      'http://storage/upload',
      'http://127.0.0.1:8010/rooms/r1/messages/attachments/commit',
    ]);
    expect(JSON.parse(String(calls[2]?.init?.body))).toEqual({ key: 'messages/r1/files/a.txt', file_size: 3 });
  });

  it('rejects non-image and empty files before upload', () => {
    expect(() => validateMessageAttachment(new File(['x'], 'a.txt', { type: 'text/plain' }), 'image')).toThrow('请选择图片文件');
    expect(() => validateMessageAttachment(new File([], 'empty.txt', { type: 'text/plain' }), 'file')).toThrow('不能发送空文件');
  });
});
