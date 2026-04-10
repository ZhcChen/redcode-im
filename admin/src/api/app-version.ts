import http from '@/services/http';

// 平台枚举类型
// eslint-disable-next-line no-shadow
export enum AppPlatform {
  Android = 'android',
  IOS = 'ios',
  Windows = 'windows',
  MacOS = 'macos',
  Linux = 'linux',
}

// 平台显示名称映射
export const PlatformLabels: Record<AppPlatform, string> = {
  [AppPlatform.Android]: 'Android',
  [AppPlatform.IOS]: 'iOS',
  [AppPlatform.Windows]: 'Windows',
  [AppPlatform.MacOS]: 'macOS',
  [AppPlatform.Linux]: 'Linux',
};

export interface AppVersionInfo {
  id: string;
  platform: AppPlatform;
  version: string;
  build_number: number;
  channel: string;
  download_key: string;
  download_url?: string | null;
  app_store_url?: string | null;
  file_size?: number | null;
  checksum?: string | null;
  signature?: string | null;
  release_notes?: string | null;
  mandatory: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  released_at?: string | null;
}

export interface ListAppVersionsResponse {
  total: number;
  items: AppVersionInfo[];
}

export interface ListAppVersionsParams {
  platform: AppPlatform;
  channel?: string;
  limit?: number;
  offset?: number;
}

export function listAppVersions(params: ListAppVersionsParams) {
  return http.get<ListAppVersionsResponse>('/api/admin/app-versions', {
    params,
  });
}

export interface CreateAppVersionPayload {
  platform: AppPlatform;
  version: string;
  build_number: number;
  channel: string;
  download_key: string;
  download_url?: string | null;
  app_store_url?: string | null;
  file_size?: number | null;
  checksum?: string | null;
  signature?: string | null;
  release_notes?: string | null;
  mandatory?: boolean;
  is_active?: boolean;
  released_at?: string | null;
}

export function createAppVersion(payload: CreateAppVersionPayload) {
  return http.post<AppVersionInfo>('/api/admin/app-versions', payload);
}

export interface UpdateAppVersionPayload {
  download_key?: string | null;
  download_url?: string | null;
  app_store_url?: string | null;
  file_size?: number | null;
  checksum?: string | null;
  signature?: string | null;
  release_notes?: string | null;
  mandatory?: boolean | null;
  is_active?: boolean | null;
  released_at?: string | null;
}

export function updateAppVersion(id: string, payload: UpdateAppVersionPayload) {
  return http.patch<AppVersionInfo>(`/api/admin/app-versions/${id}`, payload);
}

export function getAppVersion(id: string) {
  return http.get<AppVersionInfo>(`/api/admin/app-versions/${id}`);
}

export function deleteAppVersion(id: string) {
  return http.delete(`/api/admin/app-versions/${id}`);
}

export function deactivateAppVersion(id: string) {
  return http.post<AppVersionInfo>(`/api/admin/app-versions/${id}/deactivate`);
}

export interface VersionUploadSignatureRequest {
  platform: AppPlatform;
  channel: string;
  filename?: string;
  file_size?: number;
  hash_value?: string;
  hash_alg?: number;
}

export interface DirectUploadSignature {
  url: string;
  method: string;
  headers: Record<string, string>;
  key: string;
}

export interface VersionUploadSignatureResponse {
  success: boolean;
  message: string;
  key?: string;
  signature?: DirectUploadSignature;
}

export function generateVersionUploadSignature(
  payload: VersionUploadSignatureRequest
) {
  return http.post<VersionUploadSignatureResponse>(
    '/api/admin/app-versions/upload/signature',
    payload
  );
}

export interface VersionMultipartInitiateRequest {
  platform: AppPlatform;
  channel: string;
  filename?: string;
  file_size: number;
  hash_value?: string;
  hash_alg?: number;
  content_type?: string;
}

export interface VersionMultipartInitiateResponse {
  success: boolean;
  message: string;
  key?: string;
  session_id?: string;
  part_size?: number;
  total_parts?: number;
}

export function initiateVersionMultipartUpload(
  payload: VersionMultipartInitiateRequest
) {
  return http.post<VersionMultipartInitiateResponse>(
    '/api/admin/app-versions/upload/multipart/initiate',
    payload
  );
}

export interface DownloadVersionParams {
  id: string;
  expires_in_seconds?: number;
}

export interface VersionDownloadResponse {
  success: boolean;
  message: string;
  download_url?: string;
}

export function generateVersionDownloadUrl(params: DownloadVersionParams) {
  return http.get<VersionDownloadResponse>('/versions/download', {
    params,
  });
}
