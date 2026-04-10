import axios from 'axios';

export interface LoginData {
  username: string;
  password: string;
}

export interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatarUrl?: string | null;
  status: string;
  roleCodes?: string[];
  permissionKeys?: string[];
  isSuperAdmin?: boolean;
  lastLoginAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface LoginRes {
  token: string;
  user?: BackendUserInfo;
  refresh_token?: string | null;
}

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
