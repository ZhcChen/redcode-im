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

export interface E2eeRuntimeReadiness {
  active_devices: number;
  compliant_devices: number;
  coverage_percent: number;
  low_inventory_devices: number;
  pending_approval_devices: number;
  blocking_reasons: string[];
  ready: boolean;
}

export interface E2eeRuntimeGateResponse {
  state: 'plaintext' | 'prepare' | 'active';
  content_audit_mode: 'plaintext' | 'e2ee';
  readiness_revision: number;
  readiness_computed_at?: string | null;
  readiness_expired: boolean;
  min_client_versions: Record<string, string>;
  required_coverage_percent: number;
  key_package_low_watermark: number;
  security_review_approved: boolean;
  readiness: E2eeRuntimeReadiness;
  updated_at: string;
  updated_by?: string | null;
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
  enable_email_auth: boolean;
  enable_phone_validation: boolean;
  enable_email_validation: boolean;
  enable_length_validation: boolean;
  min_length: number;
  max_length: number;
  enable_alphanumeric_validation: boolean;
}

export interface UpdateUserAccountLimitPayload {
  enable_email_auth: boolean;
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

export function getE2eeRuntimeGate() {
  return http.get<E2eeRuntimeGateResponse>(
    '/api/admin/settings/message-runtime/e2ee/gate'
  );
}

export function prepareE2eeRuntime() {
  return http.post<E2eeRuntimeGateResponse>(
    '/api/admin/settings/message-runtime/e2ee/prepare'
  );
}

export function activeE2eeRuntime() {
  return http.post<E2eeRuntimeGateResponse>(
    '/api/admin/settings/message-runtime/e2ee/active'
  );
}

export function rollbackE2eeRuntime() {
  return http.post<E2eeRuntimeGateResponse>(
    '/api/admin/settings/message-runtime/e2ee/rollback'
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
