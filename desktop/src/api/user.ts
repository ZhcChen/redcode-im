import { invoke } from '@tauri-apps/api/core';
import type { ApiResponse } from './http';
import type { LegacyUserInfo } from './system';
import { AvatarCache } from '../utils/avatar-cache';
import { store } from '../store';
import { rustHttp } from './rust-http';
import type { HttpRequestParams } from './rust-http';
import { base64ToUint8Array } from '../utils/binary';

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

const emitClientDebug = async (tag: string, payload: Record<string, unknown>) => {
  try {
    await invoke('client_debug', { payload: { tag, ...payload } });
  } catch (error) {
    // Suppress error
  }
};

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
    const response = await rustHttp.get<BackendUserInfo>(endpoint);
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
    const query = params.expiresInSeconds
      ? { expires_in_seconds: params.expiresInSeconds.toString() }
      : undefined;
    return rustHttp.get('/users/me/avatar/url', query);
  }

  /**
   * 获取指定用户的头像临时下载地址
   * @param params.userId - 用户 ID
   * @param params.expiresInSeconds - 有效期（秒），默认 3600（1小时）
   */
  static async getUserAvatarDownloadUrl(params: {
    userId: string;
    expiresInSeconds?: number;
  }): Promise<ApiResponse<{
    success: boolean;
    message: string;
    download_url?: string;
  }>> {
    const query = params.expiresInSeconds
      ? { expires_in_seconds: params.expiresInSeconds.toString() }
      : undefined;
    return rustHttp.get(`/users/${params.userId}/avatar/url`, query);
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

    const response = await rustHttp.patch<BackendUserInfo>('/users/me', payload);
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

    const response = await rustHttp.get<BackendUserInfo[]>(`/users/search?${query.toString()}`);
    if (!response.success || !response.data) {
      return { ...response, data: [] };
    }

    return {
      ...response,
      data: response.data.map(mapBackendToSearchUser)
    };
  }

  static async updateUserPassword(params: { oldPwd: string; newPwd: string }): Promise<ApiResponse<{ success: boolean }>> {
    return rustHttp.post<{ success: boolean }>('/users/me/password', {
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
    const directResp = await rustHttp.post<{
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

    const headers = new Headers();
    // 过滤掉 Host 头，避免浏览器 CORS 限制
    Object.entries(signature.headers || {}).forEach(
      ([headerKey, headerValue]) => {
        if (headerKey.toLowerCase() === 'host') {
          return;
        }
        headers.set(headerKey, headerValue);
      }
    );
    if (!headers.has('Content-Type')) {
      headers.set('Content-Type', contentType);
    }

    const fileBuffer = new Uint8Array(await file.arrayBuffer());
    const contentLength = fileBuffer.length.toString();
    const finalHeaders: Record<string, string> = {};
    headers.forEach((value, key) => {
      finalHeaders[key] = value;
    });
    if (!headers.has('Content-Length')) {
      headers.set('Content-Length', contentLength);
    }
    finalHeaders['Content-Length'] = headers.get('Content-Length') || contentLength;
    const uploadMeta = {
      url: signature.url,
      method: signature.method || 'PUT',
      headers: finalHeaders,
      injectToken: false,
      forceStreaming: true,
      contentLength
    };
    await emitClientDebug('avatarUploadPrepared', uploadMeta);

    const uploadResponse = await rustHttp.requestRaw<{ base64?: string }>({
      path: signature.url,
      method: (signature.method || 'PUT') as HttpRequestParams['method'],
      headers: finalHeaders,
      binaryBody: fileBuffer,
      injectToken: false,
      forceStreaming: true,
      timeout: 60000 // 60秒超时，避免上传卡住
    });
    await emitClientDebug('avatarUploadRawResponse', {
      code: uploadResponse.code,
      success: uploadResponse.success,
      message: uploadResponse.message
    });

    if (!uploadResponse.success) {
      const status = uploadResponse.code;

      // 针对 CORS 错误提供更友好的错误信息
      let errorMessage = uploadResponse.message || '上传失败，请稍后重试';
      if (status === 403) {
        errorMessage = '上传配置错误：可能存在跨域访问问题，请联系管理员检查存储配置';
      } else if (status === 0) {
        errorMessage = '网络连接失败，请检查网络设置';
      }

      return {
        code: status,
        success: false,
        message: errorMessage,
        data: null
      };
    }


    await emitClientDebug('USER_AVATAR_COMMIT_START', { key });
    let commitResp;
    try {
      await emitClientDebug('USER_AVATAR_CALLING_POST', { path: '/users/me/avatar/commit' });
      commitResp = await rustHttp.post<{
        success: boolean;
        message: string;
        download_url?: string;
      }>('/users/me/avatar/commit', {
        key,
        delete_previous: true,
        expires_in_seconds: 600
      });
      await emitClientDebug('USER_AVATAR_POST_COMPLETE', { success: commitResp.success });
    } catch (commitError) {
      await emitClientDebug('USER_AVATAR_COMMIT_ERROR', { error: String(commitError) });
      return {
        code: 500,
        success: false,
        message: `提交头像配置异常: ${commitError}`,
        data: null
      };
    }

    const commitData = commitResp.data;
    await emitClientDebug('USER_AVATAR_COMMIT_DATA', {
      success: commitResp.success,
      hasData: Boolean(commitData),
      dataType: typeof commitData,
      dataKeys: commitData ? Object.keys(commitData) : null,
      dataSuccess: commitData?.success
    });
    if (!commitResp.success || !commitData || !commitData.success) {
      await emitClientDebug('USER_AVATAR_VALIDATION_FAILED', {
        respSuccess: commitResp.success,
        hasData: Boolean(commitData),
        dataSuccess: commitData?.success
      });
      return {
        code: commitResp.code,
        success: false,
        message: commitData?.message || commitResp.message || '提交头像配置失败',
        data: null
      };
    }

    await emitClientDebug('USER_AVATAR_SAVING_CACHE', { key });
    const saved = await AvatarCache.save({
      userId: currentUser.id,
      objectKey: key,
      data: fileBuffer,
      filename: file.name,
      contentType,
      avatarType: 'user'
    });
    await emitClientDebug('USER_AVATAR_CACHE_SAVED', { webPath: saved.webPath });

    const avatarUrl = commitData.download_url || currentUser.avatar || '';
    await emitClientDebug('USER_AVATAR_UPDATING_STORE', {
      avatarUrl,
      avatarObjectKey: key,
      avatarLocalPath: saved.webPath
    });
    store.commit('UPDATE_USER_INFO', {
      avatar: avatarUrl,
      avatarObjectKey: key,
      avatarLocalPath: saved.webPath
    });

    try {
      await store.dispatch('accounts/syncAccountProfile', {
        accountId: currentUser.id,
        userInfo: {
          avatar: avatarUrl,
          avatarObjectKey: key,
          avatarLocalPath: saved.webPath,
          nickname: currentUser.nickname,
          username: currentUser.username
        },
        token: store.state.token || undefined
      });
    } catch (error) {
    }
    await emitClientDebug('USER_AVATAR_STORE_UPDATED', { success: true });

    await emitClientDebug('USER_AVATAR_UPLOAD_COMPLETE', { success: true });
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

  /**
   * 同步指定用户的头像缓存(适用于好友、群成员等)
   *
   * @param userId - 用户 ID
   * @param avatarObjectKey - 头像 object key
   * @param force - 是否强制刷新缓存
   * @returns 本地缓存路径(Blob URL)，失败返回 null
   */
  static async syncUserAvatarCache(
    userId: string,
    avatarObjectKey: string,
    force = false
  ): Promise<string | null> {
    const logId = `USER_AVATAR_SYNC_${userId.substring(0, 8)}_${Date.now()}`;

    try {
      if (!avatarObjectKey) {
        return null;
      }

      // 如果不强制刷新，检查本地缓存
      if (!force) {
        const cached = await AvatarCache.resolve(userId, avatarObjectKey, 'user');
        if (cached) {
          return cached.webPath;
        }
      }

      // 获取临时下载 URL
      const downloadResp = await this.getUserAvatarDownloadUrl({
        userId,
        expiresInSeconds: 3600
      });

      const payload = downloadResp.data;
      if (!payload || !payload.success || !payload.download_url) {
        return null;
      }

      // 下载头像文件
      const downloadResponse = await rustHttp.requestRaw<{
        base64?: string;
        headers?: Record<string, string>
      }>({
        path: payload.download_url,
        method: 'GET',
        responseType: 'binary',
        injectToken: false
      });

      if (!downloadResponse.success || !downloadResponse.data || !downloadResponse.data.base64) {
        return null;
      }

      // 保存到本地缓存
      const buffer = base64ToUint8Array(downloadResponse.data.base64);
      const contentType = downloadResponse.data.headers?.['content-type'] || 'image/jpeg';
      const saved = await AvatarCache.save({
        userId,
        objectKey: avatarObjectKey,
        data: buffer,
        contentType,
        avatarType: 'user'
      });

      return saved.webPath;
    } catch (error) {
      return null;
    }
  }

  /**
   * 同步指定群聊的头像缓存
   *
   * @param groupId - 群聊 ID
   * @param avatarObjectKey - 头像 object key
   * @param force - 是否强制刷新缓存
   * @returns 本地缓存路径(Blob URL)，失败返回 null
   */
  static async syncGroupAvatarCache(
    groupId: string,
    avatarObjectKey: string,
    force = false
  ): Promise<string | null> {
    const logId = `GROUP_AVATAR_SYNC_${groupId.substring(0, 8)}_${Date.now()}`;

    try {
      if (!avatarObjectKey) {
        return null;
      }

      // 如果不强制刷新，检查本地缓存
      if (!force) {
        const cached = await AvatarCache.resolve(groupId, avatarObjectKey, 'group');
        if (cached) {
          return cached.webPath;
        }
      }

      // 获取临时下载 URL
      const { GroupApi } = await import('./group');
      const downloadResp = await GroupApi.getRoomAvatarDownloadUrl({
        roomId: groupId,
        expiresInSeconds: 3600
      });

      if (!downloadResp.success || !downloadResp.data || !downloadResp.data.downloadUrl) {
        return null;
      }

      const downloadUrl = downloadResp.data.downloadUrl;

      // 下载头像文件
      const downloadResponse = await rustHttp.requestRaw<{
        base64?: string;
        headers?: Record<string, string>
      }>({
        path: downloadUrl,
        method: 'GET',
        responseType: 'binary',
        injectToken: false
      });

      if (!downloadResponse.success || !downloadResponse.data || !downloadResponse.data.base64) {
        return null;
      }

      // 保存到本地缓存
      const buffer = base64ToUint8Array(downloadResponse.data.base64);
      const contentType = downloadResponse.data.headers?.['content-type'] || 'image/jpeg';
      const saved = await AvatarCache.save({
        userId: groupId,
        objectKey: avatarObjectKey,
        data: buffer,
        contentType,
        avatarType: 'group'
      });

      return saved.webPath;
    } catch (error) {
      return null;
    }
  }

  static async syncAvatarCache(force = false): Promise<void> {
    const logId = `AVATAR_SYNC_${Date.now()}`;
    
    try {
      const currentUser = store.getters.currentUser as LegacyUserInfo | undefined;
      
      if (!currentUser || !currentUser.id) {
        return;
      }
      
      // 关键修改：如果没有 avatarObjectKey，清除缓存并返回
      if (!currentUser.avatarObjectKey) {
        await AvatarCache.clear(currentUser.id);
        store.commit('UPDATE_USER_INFO', { avatarLocalPath: null });
        return;
      }

      // 如果不强制刷新，检查本地缓存
      if (!force) {
        const cached = await AvatarCache.resolve(currentUser.id, currentUser.avatarObjectKey);
        if (cached) {
          store.commit('UPDATE_USER_INFO', { avatarLocalPath: cached.webPath });
          return;
        }
      } else {
      }

      // 获取临时下载 URL
      const downloadResp = await this.getAvatarDownloadUrl({ expiresInSeconds: 3600 }); // 1小时有效期
      
      const payload = downloadResp.data;
      if (!payload || !payload.success || !payload.download_url) {
        store.commit('UPDATE_USER_INFO', { avatarLocalPath: null });
        return;
      }

      const downloadResponse = await rustHttp.requestRaw<{ base64?: string; headers?: Record<string, string> }>({
        path: payload.download_url,
        method: 'GET',
        responseType: 'binary',
        injectToken: false
      });


      if (!downloadResponse.success || !downloadResponse.data || !downloadResponse.data.base64) {
        throw new Error(`下载头像失败: HTTP ${downloadResponse.code}`);
      }

      const buffer = base64ToUint8Array(downloadResponse.data.base64);
      const contentType = downloadResponse.data.headers?.['content-type'] || 'image/jpeg';
      const saved = await AvatarCache.save({
        userId: currentUser.id,
        objectKey: currentUser.avatarObjectKey,
        data: buffer,
        contentType
      });

      
      // 更新 store，设置 avatarLocalPath
      store.commit('UPDATE_USER_INFO', {
        avatarLocalPath: saved.webPath
      });

      try {
        await store.dispatch('accounts/syncAccountProfile', {
          accountId: currentUser.id,
          userInfo: {
            avatarLocalPath: saved.webPath,
            avatarObjectKey: currentUser.avatarObjectKey
          }
        });
      } catch (error) {
      }
      
    } catch (error) {
    }
  }
}
