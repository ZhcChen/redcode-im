import axios from 'axios';
import type { AppPlatform } from './app-version';

export interface HotUpdateInfo {
  id: string;
  platform: AppPlatform | string;
  app_version_id: string;
  patch_version: string;
  channel: string;
  download_key: string;
  download_url?: string;
  file_size?: number | null;
  checksum?: string;
  signature?: string;
  rollout_percentage: number;
  mandatory: boolean;
  description?: string;
  is_active: boolean;
  released_at?: string;
  created_at: string;
  updated_at: string;
}

export interface ListHotUpdatesResponse {
  total: number;
  items: HotUpdateInfo[];
}

export interface HotUpdateEventInfo {
  id: string;
  platform: string;
  channel?: string;
  base_version: string;
  patch_version: string;
  event_type: string;
  client_id?: string;
  message?: string;
  created_at: string;
  // 新增的详细字段
  client_type?: string;
  os_version?: string;
  os_arch?: string;
  app_arch?: string;
  build_number?: number;
  trigger_source?: string;
  network_type?: string;
  device_info?: string;
}

export interface ListHotUpdateEventsResponse {
  total: number;
  items: HotUpdateEventInfo[];
}

export interface ListHotUpdatesParams {
  platform?: AppPlatform | string;
  channel?: string;
  limit?: number;
  offset?: number;
}

export interface ListHotUpdateEventsParams {
  platform?: AppPlatform | string;
  channel?: string;
  event_type?: string;
  start_time?: string;
  end_time?: string;
  limit?: number;
  offset?: number;
  // 新增筛选字段
  client_type?: string;
  os_version?: string;
  trigger_source?: string;
  network_type?: string;
}

export interface CreateHotUpdatePayload {
  platform: AppPlatform | string;
  app_version_id: string;
  patch_version: string;
  channel: string;
  download_key: string;
  download_url?: string;
  file_size?: number | null;
  checksum?: string;
  signature?: string;
  rollout_percentage?: number;
  mandatory?: boolean;
  description?: string;
  released_at?: string;
}

export interface UpdateHotUpdatePayload {
  patch_version?: string;
  channel?: string;
  download_key?: string;
  download_url?: string;
  file_size?: number | null;
  checksum?: string;
  signature?: string;
  rollout_percentage?: number;
  mandatory?: boolean;
  description?: string;
  is_active?: boolean;
  released_at?: string;
}

export function listHotUpdates(params: ListHotUpdatesParams) {
  return axios.get<ListHotUpdatesResponse>('/api/admin/hot-updates', {
    params,
  });
}

export function createHotUpdate(payload: CreateHotUpdatePayload) {
  return axios.post<HotUpdateInfo>('/api/admin/hot-updates', payload);
}

export function listHotUpdateEvents(params: ListHotUpdateEventsParams) {
  return axios.get<ListHotUpdateEventsResponse>(
    '/api/admin/hot-updates/events',
    {
      params,
    }
  );
}

export function updateHotUpdate(id: string, payload: UpdateHotUpdatePayload) {
  return axios.patch<HotUpdateInfo>(`/api/admin/hot-updates/${id}`, payload);
}

export function getHotUpdate(id: string) {
  return axios.get<HotUpdateInfo>(`/api/admin/hot-updates/${id}`);
}

export function deleteHotUpdate(id: string) {
  return axios.delete(`/api/admin/hot-updates/${id}`);
}

export function activateHotUpdate(id: string) {
  return axios.post<HotUpdateInfo>(`/api/admin/hot-updates/${id}/activate`);
}

export function deactivateHotUpdate(id: string) {
  return axios.post<HotUpdateInfo>(`/api/admin/hot-updates/${id}/deactivate`);
}
