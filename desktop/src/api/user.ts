import { get, patch, post, upload } from './http';
import type { AuthUser } from './system';
import type { ApiResponse } from './http';

export interface UserProfile {
  id: string;
  username: string;
  email?: string;
  nickname?: string;
  avatar_url?: string;
  status?: string;
}

export interface UpdateProfilePayload {
  nickname?: string;
  avatar_url?: string;
}

export interface ChangePasswordPayload {
  current_password: string;
  new_password: string;
}

export interface UploadAvatarResponse {
  avatar_url: string;
}

export interface UserSearchParams {
  keyword: string;
  limit?: number;
}

export class UserApi {
  static getMe(): Promise<ApiResponse<UserProfile>> {
    return get<UserProfile>('/auth/me');
  }

  static updateProfile(
    payload: UpdateProfilePayload,
  ): Promise<ApiResponse<UserProfile>> {
    return patch<UserProfile>('/users/me', payload);
  }

  static changePassword(
    payload: ChangePasswordPayload,
  ): Promise<ApiResponse<{ ok: boolean }>> {
    return post<{ ok: boolean }>('/users/me/password', payload);
  }

  static uploadAvatar(
    file: File,
  ): Promise<ApiResponse<UploadAvatarResponse>> {
    const formData = new FormData();
    formData.append('avatar', file);
    return upload<UploadAvatarResponse>('/users/me/avatar', formData);
  }

  static searchUsers(
    params: UserSearchParams,
  ): Promise<ApiResponse<AuthUser[]>> {
    const { keyword, limit } = params;
    return get<AuthUser[]>('/users/search', {
      keyword,
      ...(limit ? { limit } : {}),
    });
  }
}
