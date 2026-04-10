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
  avatarUrl?: string | null; // 注意：后端返回的是 avatarUrl（驼峰）
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
  user: BackendUserInfo;
  refresh_token?: string | null;
}

export function login(data: LoginData) {
  return axios.post<LoginRes>('/auth/admin/login', data);
}

export function logout(): Promise<void> {
  return Promise.resolve();
}

export function getUserInfo() {
  return axios.get<BackendUserInfo>('/auth/admin/me');
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

// 管理员用户管理相关接口
export interface AdminUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatarUrl?: string | null;
  status: 'active' | 'inactive' | 'banned' | 'locked';
  lastLoginAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AdminUserListParams {
  page?: number;
  pageSize?: number;
  status?: string;
  username?: string;
}

export interface AdminUserListResponse {
  users: AdminUserInfo[];
  total: number;
  page: number;
  pageSize: number;
}

export interface CreateAdminUserRequest {
  username: string;
  email: string;
  password: string;
  nickname?: string;
}

export function getAdminUserList(params?: AdminUserListParams) {
  return axios.get<AdminUserListResponse>('/api/admin/admin-users', { params });
}

export function createAdminUser(data: CreateAdminUserRequest) {
  return axios.post<AdminUserInfo>('/api/admin/admin-users', data);
}

export function updateAdminUserStatus(
  adminUserId: string,
  status: 'active' | 'inactive' | 'banned' | 'locked'
) {
  return axios.patch(`/api/admin/admin-users/${adminUserId}/status`, {
    status,
  });
}
