import axios from 'axios';
import type { RouteRecordNormalized } from 'vue-router';

export interface LoginData {
  username: string;
  password: string;
}

export interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  status: string;
}

export interface LoginRes {
  token: string;
  user: BackendUserInfo;
}

export function login(data: LoginData) {
  return axios.post<LoginRes>('/auth/login', data);
}

export function logout(): Promise<void> {
  return Promise.resolve();
}

export function getUserInfo() {
  return axios.get<BackendUserInfo>('/auth/me');
}

export function getMenuList() {
  return axios.post<RouteRecordNormalized[]>('/api/user/menu');
}

export interface UserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  status: 'active' | 'inactive' | 'banned';
  created_at: string;
  updated_at: string;
  deleted_at?: string | null;
}

export interface UserListParams {
  page?: number;
  pageSize?: number;
  status?: string;
  username?: string;
}

export interface UserListResponse {
  users: UserInfo[];
  total: number;
  page: number;
  pageSize: number;
}

export function getUserList(params?: UserListParams) {
  return axios.get<UserListResponse>('/api/admin/users', { params });
}

export function updateUserStatus(
  userId: string,
  status: 'active' | 'inactive' | 'banned'
) {
  return axios.patch(`/api/admin/users/${userId}/status`, { status });
}

export interface CaptchaSetting {
  enabled: boolean;
  captcha_code: string;
  description: string;
  require_captcha_for_login: boolean;
  updated_at: string;
  deleted_at?: string | null;
}

export function getCaptchaSetting() {
  return axios.get<CaptchaSetting>('/api/admin/settings/captcha');
}

export function updateCaptchaSetting(setting: Partial<CaptchaSetting>) {
  return axios.post('/api/admin/settings/captcha', setting);
}
