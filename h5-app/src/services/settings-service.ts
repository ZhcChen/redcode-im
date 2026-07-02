import { requestJson } from '@/api/http';
import type { DocumentContent, GeneralSettings, MessageRuntimeSettings } from '@/types/settings';

import { requireToken } from './session';

export const settingsService = {
  async fetchGeneralSettings(): Promise<GeneralSettings> {
    const response = await requestJson<Record<string, unknown>>('/settings/general');
    return {
      appName: String(response.app_name ?? ''),
      messageRuntime: mapRuntime(response.message_runtime),
    };
  },

  async fetchAppName(): Promise<string> {
    const response = await requestJson<Record<string, unknown>>('/settings/app-name');
    return String(response.app_name ?? '');
  },

  async fetchPrivacyPolicy(): Promise<DocumentContent> {
    return mapDocument(await requestJson<Record<string, unknown>>('/settings/privacy-policy'));
  },

  async fetchUserAgreement(): Promise<DocumentContent> {
    return mapDocument(await requestJson<Record<string, unknown>>('/settings/user-agreement'));
  },

  async submitFeedback(params: { content: string; contact?: string }): Promise<string> {
    const response = await requestJson<Record<string, unknown>>('/feedbacks', {
      method: 'POST',
      body: JSON.stringify({
        content: params.content.trim(),
        ...(params.contact?.trim() ? { contact: params.contact.trim() } : {}),
      }),
    }, requireToken());
    return String(response.message ?? '反馈提交成功');
  },
};

const mapRuntime = (value: unknown): MessageRuntimeSettings => {
  const data = typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {};
  return {
    serverStorageMode: String(data.server_storage_mode ?? 'persist'),
    contentAuditMode: String(data.content_audit_mode ?? 'plaintext'),
  };
};

const mapDocument = (data: Record<string, unknown>): DocumentContent => ({
  title: String(data.title ?? ''),
  content: String(data.content ?? ''),
  updatedAt: data.updated_at == null ? null : String(data.updated_at),
});
