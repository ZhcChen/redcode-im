import http from '@/services/http';

export interface PushProviderConfigView {
  id: string;
  provider: string;
  platform: string;
  enabled: boolean;
  config_public: Record<string, any>;
  has_secret: boolean;
  secret_fingerprint?: string | null;
  updated_at: string;
  updated_by?: string | null;
}

export interface GetPushSettingsResponse {
  enabled: boolean;
  skip_if_online: boolean;
  providers: PushProviderConfigView[];
}

export interface UpdatePushSettingsPayload {
  enabled: boolean;
  skip_if_online: boolean;
}

export interface UpsertFcmProviderPayload {
  enabled: boolean;
  service_account_json?: string;
}

export interface TestPushPayload {
  provider: string;
  user_id?: string;
  device_token?: string;
  title: string;
  body: string;
}

export interface TestPushResponse {
  success: boolean;
  message: string;
}

export interface PushJobQueueStatsResponse {
  pending: number;
  retry: number;
  done: number;
  failed: number;
  due: number;
  next_run_at?: string | null;
  oldest_created_at?: string | null;
}

export function getPushSettings() {
  return http.get<GetPushSettingsResponse>('/api/admin/settings/push');
}

export function updatePushSettings(payload: UpdatePushSettingsPayload) {
  return http.put<GetPushSettingsResponse>('/api/admin/settings/push', payload);
}

export function upsertPushProviderConfig(provider: string, payload: any) {
  return http.put<PushProviderConfigView>(
    `/api/admin/settings/push/providers/${provider}`,
    payload
  );
}

export function testPush(payload: TestPushPayload) {
  return http.post<TestPushResponse>('/api/admin/settings/push/test', payload);
}

export function getPushJobQueueStats() {
  return http.get<PushJobQueueStatsResponse>('/api/admin/push/job-queue/stats');
}
