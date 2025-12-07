import axios from 'axios';

export interface UserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatarUrl?: string | null; // 注意：后端返回的是 avatarUrl（驼峰）
  status: string;
  lastLoginAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface UpdateUserProfileRequest {
  nickname?: string;
  avatar_url?: string;
}

export interface ChangePasswordRequest {
  new_password: string;
}

export interface UploadAvatarResponse {
  success: boolean;
  message: string;
  avatar_url?: string;
}

export function getCurrentUserInfo() {
  return axios.get<UserInfo>('/auth/admin/me');
}

export function updateCurrentUserProfile(data: UpdateUserProfileRequest) {
  return axios.patch<UserInfo>('/auth/admin/me', data);
}

export function changeCurrentUserPassword(data: ChangePasswordRequest) {
  return axios.post('/auth/admin/me/password', data);
}

export function updateUserAvatar(avatarUrl: string) {
  return axios.patch<{ success: boolean; message: string; data: UserInfo }>(
    '/auth/admin/me',
    { avatar_url: avatarUrl }
  );
}
