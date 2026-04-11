import http from '@/services/http';

export interface MessageRuntimeSettingsResponse {
  server_storage_mode: 'persist' | 'relay_only';
  content_audit_mode: 'plaintext' | 'e2ee';
  updated_at?: string | null;
  updated_by?: string | null;
}

export interface UpdateMessageRuntimeSettingsPayload {
  server_storage_mode: 'persist' | 'relay_only';
  content_audit_mode: 'plaintext' | 'e2ee';
}

export interface GeneralSettingsResponse {
  app_name: string;
  message_runtime?: MessageRuntimeSettingsResponse;
}

export interface AppNameResponse {
  app_name: string;
}

export interface UpdateAppNamePayload {
  app_name: string;
}

export interface UserAccountLimitResponse {
  enable_phone_validation: boolean;
  enable_email_validation: boolean;
  enable_length_validation: boolean;
  min_length: number;
  max_length: number;
  enable_alphanumeric_validation: boolean;
}

export interface UpdateUserAccountLimitPayload {
  enable_phone_validation: boolean;
  enable_email_validation: boolean;
  enable_length_validation: boolean;
  min_length: number;
  max_length: number;
  enable_alphanumeric_validation: boolean;
}

export interface UploadPolicyMaxSizeMbByPartType {
  image: number;
  video: number;
  audio: number;
  file: number;
}

export interface UploadPolicyMimeByPartType {
  image: string[];
  video: string[];
  audio: string[];
  file: string[];
}

export interface AudioOnlyPolicy {
  enabled: boolean;
  force_single_attachment: boolean;
  allow_text: boolean;
}

export interface UploadPolicyView {
  version: string;
  max_total_size_mb: number;
  max_attachments_per_message: number;
  max_size_mb_by_part_type: UploadPolicyMaxSizeMbByPartType;
  mime_by_part_type: UploadPolicyMimeByPartType;
  mime_whitelist: string[];
  audio_only: AudioOnlyPolicy;
}

export interface UploadPolicyAdminResponse {
  policy: UploadPolicyView;
  updated_at?: string | null;
  updated_by?: string | null;
}

export type UpdateUploadPolicyPayload = Omit<
  UploadPolicyView,
  'mime_whitelist'
>;

export interface IpGeolocationStatusResponse {
  enabled: boolean;
  description: string;
}

export interface SetIpGeolocationEnabledPayload {
  enabled: boolean;
}

export function getGeneralSettings() {
  return http.get<GeneralSettingsResponse>('/settings/general');
}

export function getAppName() {
  return http.get<AppNameResponse>('/settings/app-name');
}

export function updateAppName(payload: UpdateAppNamePayload) {
  return http.put<AppNameResponse>('/api/admin/settings/app-name', payload);
}

export function getMessageRuntimeSettings() {
  return http.get<MessageRuntimeSettingsResponse>(
    '/api/admin/settings/message-runtime'
  );
}

export function updateMessageRuntimeSettings(
  payload: UpdateMessageRuntimeSettingsPayload
) {
  return http.put<MessageRuntimeSettingsResponse>(
    '/api/admin/settings/message-runtime',
    payload
  );
}

export function getUserAccountLimit() {
  return http.get<UserAccountLimitResponse>(
    '/api/admin/settings/user-account-limit'
  );
}

export function updateUserAccountLimit(payload: UpdateUserAccountLimitPayload) {
  return http.put<UserAccountLimitResponse>(
    '/api/admin/settings/user-account-limit',
    payload
  );
}

export function getUploadPolicy() {
  return http.get<UploadPolicyAdminResponse>(
    '/api/admin/settings/upload-policy'
  );
}

export function updateUploadPolicy(payload: UpdateUploadPolicyPayload) {
  return http.put<UploadPolicyAdminResponse>(
    '/api/admin/settings/upload-policy',
    payload
  );
}

export function getIpGeolocationEnabled() {
  return http.get<IpGeolocationStatusResponse>(
    '/api/admin/ip-geolocation/enabled'
  );
}

export function setIpGeolocationEnabled(
  payload: SetIpGeolocationEnabledPayload
) {
  return http.patch<IpGeolocationStatusResponse>(
    '/api/admin/ip-geolocation/enabled',
    payload
  );
}
