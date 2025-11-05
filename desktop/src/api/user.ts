import { get, patch, post } from './http';
import type { ApiResponse } from './http';
import type { LegacyUserInfo } from './system';
import { AvatarCache } from '../utils/avatar-cache';
import { store } from '../store';

interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
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
  avatarObjectKey: user.avatar_object_key || null,
  avatarLocalPath: (() => {
    const currentUser = store.getters?.currentUser as LegacyUserInfo | undefined;
    if (!currentUser) return null;
    if (currentUser.id !== user.id) return null;
    if (currentUser.avatarObjectKey !== (user.avatar_object_key || null)) return null;
    return currentUser.avatarLocalPath || null;
  })(),
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

  static async getAvatarDownloadUrl(params: { expiresInSeconds?: number } = {}): Promise<ApiResponse<{
    success: boolean;
    message: string;
    download_url?: string;
  }>> {
    const query = params.expiresInSeconds ? { expires_in_seconds: params.expiresInSeconds } : undefined;
    return get('/users/me/avatar/url', query);
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

  static async uploadAvatar(file: File): Promise<ApiResponse<{
    avatarUrl: string;
    avatarObjectKey: string;
    avatarLocalPath: string;
  }>> {
    const currentUser = store.getters.currentUser as LegacyUserInfo | undefined;
    if (!currentUser || !currentUser.id) {
      return {
        code: 400,
        success: false,
        message: '当前未登录',
        data: null
      };
    }

    const contentType = file.type || 'application/octet-stream';
    const directResp = await post<{
      success: boolean;
      message: string;
      key?: string;
      signature?: {
        url: string;
        method: string;
        headers: Record<string, string>;
      };
    }>('/users/me/avatar/direct-upload', { content_type: contentType });

    const directData = directResp.data;
    if (!directResp.success || !directData || !directData.success || !directData.key || !directData.signature) {
      return {
        code: directResp.code,
        success: false,
        message: directData?.message || directResp.message || '获取上传签名失败',
        data: null
      };
    }

    const { key, signature } = directData;
    const headers = new Headers(signature.headers || {});
    if (!headers.has('Content-Type')) {
      headers.set('Content-Type', contentType);
    }

    const fileBuffer = new Uint8Array(await file.arrayBuffer());
    const uploadResponse = await fetch(signature.url, {
      method: signature.method || 'PUT',
      headers,
      body: fileBuffer
    });

    if (!uploadResponse.ok) {
      const errorText = await uploadResponse.text();
      return {
        code: uploadResponse.status,
        success: false,
        message: errorText || '上传失败，请稍后重试',
        data: null
      };
    }

    const commitResp = await post<{
      success: boolean;
      message: string;
      download_url?: string;
    }>('/users/me/avatar/commit', {
      key,
      delete_previous: true,
      expires_in_seconds: 600
    });

    const commitData = commitResp.data;
    if (!commitResp.success || !commitData || !commitData.success) {
      return {
        code: commitResp.code,
        success: false,
        message: commitData?.message || commitResp.message || '提交头像配置失败',
        data: null
      };
    }

    const saved = await AvatarCache.save({
      userId: currentUser.id,
      objectKey: key,
      data: fileBuffer,
      filename: file.name,
      contentType
    });

    const avatarUrl = commitData.download_url || currentUser.avatar || '';
    store.commit('UPDATE_USER_INFO', {
      avatar: avatarUrl,
      avatarObjectKey: key,
      avatarLocalPath: saved.webPath
    });

    return {
      code: commitResp.code,
      success: true,
      message: commitData.message || '头像更新成功',
      data: {
        avatarUrl,
        avatarObjectKey: key,
        avatarLocalPath: saved.webPath
      }
    };
  }

  static async syncAvatarCache(force = false): Promise<void> {
    try {
      const currentUser = store.getters.currentUser as LegacyUserInfo | undefined;
      if (!currentUser || !currentUser.id) {
        return;
      }
      if (!currentUser.avatarObjectKey) {
        await AvatarCache.clear(currentUser.id);
        store.commit('UPDATE_USER_INFO', { avatarLocalPath: null });
        return;
      }

      if (!force) {
        const cached = await AvatarCache.resolve(currentUser.id, currentUser.avatarObjectKey);
        if (cached) {
          store.commit('UPDATE_USER_INFO', { avatarLocalPath: cached.webPath });
          return;
        }
      }

      const downloadResp = await this.getAvatarDownloadUrl({ expiresInSeconds: 600 });
      const payload = downloadResp.data;
      if (!payload || !payload.success || !payload.download_url) {
        store.commit('UPDATE_USER_INFO', { avatarLocalPath: null });
        return;
      }

      const response = await fetch(payload.download_url);
      if (!response.ok) {
        throw new Error(`下载头像失败: HTTP ${response.status}`);
      }
      const buffer = new Uint8Array(await response.arrayBuffer());
      const contentType = response.headers.get('content-type') || undefined;
      const saved = await AvatarCache.save({
        userId: currentUser.id,
        objectKey: currentUser.avatarObjectKey,
        data: buffer,
        contentType
      });

      store.commit('UPDATE_USER_INFO', {
        avatarLocalPath: saved.webPath,
        avatar: payload.download_url
      });
    } catch (error) {
      console.warn('[UserApi] 同步头像缓存失败:', error);
    }
  }
}
