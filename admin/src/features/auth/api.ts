import axios from 'axios';

import type { BackendUserInfo, LoginData, LoginRes } from '@/api/user';

export interface AdminBootstrapStatusResponse {
  bootstrap_required: boolean;
}

export interface AdminBootstrapInitData {
  username: string;
  password: string;
  display_name?: string;
}

export interface AdminRefreshSessionData {
  refresh_token: string;
}

export function loginAdmin(data: LoginData) {
  return axios.post<LoginRes>('/auth/admin/login', data);
}

export function getCurrentAdmin() {
  return axios.get<BackendUserInfo>('/auth/admin/me');
}

export function refreshAdminSession(data: AdminRefreshSessionData) {
  return axios.post<LoginRes>('/auth/admin/refresh', data);
}

export function getAdminBootstrapStatus() {
  return axios.get<AdminBootstrapStatusResponse>('/api/admin/bootstrap/status');
}

export function bootstrapAdmin(data: AdminBootstrapInitData) {
  return axios.post<LoginRes>('/api/admin/bootstrap/init', data);
}
