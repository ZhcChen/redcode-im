import { requestJson } from '@/api/http';
import { requireToken } from './session';

interface Signature { url: string; method?: string; headers?: Record<string, string>; key?: string }
interface Descriptor { success?: boolean; message?: string; key?: string | null; signature?: Signature | null }

export const reportService = {
  async uploadScreenshot(file: File, signal?: AbortSignal): Promise<string> {
    if (!file.type.startsWith('image/')) throw new Error('举报凭证仅支持图片');
    if (file.size === 0) throw new Error('举报凭证不能为空');
    const descriptor = await requestJson<Descriptor>('/reports/attachments/signature', {
      method: 'POST',
      body: JSON.stringify({ filename: file.name, content_type: file.type, file_size: file.size }),
      signal,
    }, requireToken());
    const key = descriptor.key ?? descriptor.signature?.key ?? '';
    if (!key) throw new Error('举报凭证签名缺少 object key');
    if (descriptor.signature) {
      const response = await fetch(descriptor.signature.url, {
        method: descriptor.signature.method || 'PUT', headers: descriptor.signature.headers,
        body: await file.arrayBuffer(), signal,
      });
      if (!response.ok) throw new Error(`举报凭证上传失败 (${response.status})`);
    }
    await requestJson('/reports/attachments/commit', {
      method: 'POST', body: JSON.stringify({ key, file_size: file.size }), signal,
    }, requireToken());
    return key;
  },

  async reportUser(userId: string, content: string, screenshot: File): Promise<string> {
    const key = await this.uploadScreenshot(screenshot);
    const response = await requestJson<{ report_id?: string }>('/reports', {
      method: 'POST',
      body: JSON.stringify({ target_type: 'user', target_id: userId, content: content.trim(), attachment_keys: [key] }),
    }, requireToken());
    return String(response.report_id ?? '');
  },
};
