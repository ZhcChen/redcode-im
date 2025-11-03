import { get, patch, post } from './http';
import type { ApiResponse } from './http';
import type { LegacyUserInfo } from './system';

interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  status: 'active' | 'inactive' | 'banned';
}

export interface UserInfo {
  id: string;
  userName: string;
  realName: string;
  chatNumber: string;
  mobile: string;
  email?: string | null;
  avatar?: string | null;
  isFriend: boolean;
}

const mapBackendToLegacy = (user: BackendUserInfo): LegacyUserInfo => ({
  id: user.id,
  username: user.username,
  nickname: user.nickname || user.username,
  avatar: user.avatar_url || '',
  mobile: user.username,
  email: user.email || '',
  isLoggedIn: true,
  realName: user.nickname || user.username,
  chatNumber: user.username,
  address: '',
  createTime: null,
  lastLoginTime: null,
  activeStatus: user.status === 'active' ? 1 : user.status === 'inactive' ? 0 : -1,
  delFlag: null,
  level: null,
  userDeviceId: null,
  userSign: null,
  trcSdkAppId: null,
  powerList: null
});

const mapBackendToSearchUser = (user: BackendUserInfo): UserInfo => ({
  id: user.id,
  userName: user.username,
  realName: user.nickname || user.username,
  chatNumber: user.username,
  mobile: user.username,
  email: user.email || '',
  avatar: user.avatar_url || '',
  isFriend: false
});

export class UserApi {
  static async getUserAccountInfo(params: { userId?: string } = {}): Promise<ApiResponse<LegacyUserInfo>> {
    const endpoint = params.userId && params.userId !== 'me' ? `/users/${params.userId}` : '/auth/me';
    const response = await get<BackendUserInfo>(endpoint);
    if (!response.success || !response.data) {
      return { ...response, data: null };
    }
    return { ...response, data: mapBackendToLegacy(response.data) };
  }

  static async updateUserInfo(params: Partial<UserInfo & LegacyUserInfo>): Promise<ApiResponse<LegacyUserInfo>> {
    const payload: Record<string, any> = {};
    if (params.userName || params.nickname || params.realName) {
      payload.nickname = params.userName ?? params.nickname ?? params.realName;
    }
    if (params.avatar) {
      payload.avatar_url = params.avatar;
    }

    if (Object.keys(payload).length === 0) {
      return {
        code: 400,
        success: false,
        message: '缺少可更新字段',
        data: null
      };
    }

    const response = await patch<BackendUserInfo>('/users/me', payload);
    if (!response.success || !response.data) {
      return { ...response, data: null };
    }

    return { ...response, data: mapBackendToLegacy(response.data) };
  }

  static async searchUser(params: { keyWord: string; limit?: number }): Promise<ApiResponse<UserInfo[]>> {
    const keyword = params.keyWord.trim();
    if (!keyword) {
      return {
        code: 400,
        success: false,
        message: '请输入搜索关键词',
        data: []
      };
    }

    const query = new URLSearchParams({ keyword });
    if (params.limit) {
      query.set('limit', params.limit.toString());
    }

    const response = await get<BackendUserInfo[]>(`/users/search?${query.toString()}`);
    if (!response.success || !response.data) {
      return { ...response, data: [] };
    }

    return {
      ...response,
      data: response.data.map(mapBackendToSearchUser)
    };
  }

  static async updateUserPassword(params: { oldPwd: string; newPwd: string }): Promise<ApiResponse<{ success: boolean }>> {
    return post<{ success: boolean }>('/users/me/password', {
      current_password: params.oldPwd,
      new_password: params.newPwd
    });
  }

  static async uploadAvatar(): Promise<ApiResponse<{ avatarUrl: string }>> {
    const response = await post<{ avatar_url: string }>('/users/me/avatar', {});
    if (!response.success || !response.data) {
      return { ...response, data: null };
    }

    return {
      ...response,
      data: {
        avatarUrl: response.data.avatar_url
      }
    };
  }
}
