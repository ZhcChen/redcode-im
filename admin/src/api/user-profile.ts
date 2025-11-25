import axios from 'axios';

export interface UserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  status: string;
  created_at: string;
  updated_at: string;
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

export function uploadAvatar(formData: FormData) {
  return axios.post<UploadAvatarResponse>('/auth/admin/me/avatar', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  });
}

export function updateUserAvatar(avatarUrl: string) {
  return axios.patch<{ success: boolean; message: string; data: UserInfo }>(
    '/auth/admin/me',
    { avatar_url: avatarUrl }
  );
}
