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
    console.log('[UserApi] 🧾 收到头像上传请求', {
      hasUser: Boolean(currentUser?.id),
      userId: currentUser?.id,
      fileName: file.name,
      fileType: file.type,
      fileSize: file.size
    });
    if (!currentUser || !currentUser.id) {
      console.warn('[UserApi] ⚠️ uploadAvatar 调用失败：当前未登录');
      return {
        code: 400,
        success: false,
        message: '当前未登录',
        data: null
      };
    }

    const contentType = file.type || 'application/octet-stream';
    console.log('[UserApi] 🔐 请求头像直传签名', { contentType });
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
    console.log('[UserApi] 🔐 直传签名响应', {
      success: directResp.success,
      code: directResp.code,
      key: directData?.key,
      hasSignature: Boolean(directData?.signature)
    });
    if (!directResp.success || !directData || !directData.success || !directData.key || !directData.signature) {
      console.error('[UserApi] ❌ 获取上传签名失败', {
        code: directResp.code,
        message: directResp.message,
        payload: directData
      });
      return {
        code: directResp.code,
        success: false,
        message: directData?.message || directResp.message || '获取上传签名失败',
        data: null
      };
    }

    const { key, signature } = directData;
    console.log('[UserApi] 📋 服务端返回的签名 headers:', signature.headers);

    const headers = new Headers();
    // 过滤掉 Host 头，避免浏览器 CORS 限制
    Object.entries(signature.headers || {}).forEach(
      ([headerKey, headerValue]) => {
        if (headerKey.toLowerCase() === 'host') {
          console.log('[UserApi] 🚫 已过滤 Host 头:', headerValue);
          return;
        }
        headers.set(headerKey, headerValue);
      }
    );
    if (!headers.has('Content-Type')) {
      headers.set('Content-Type', contentType);
    }

    const fileBuffer = new Uint8Array(await file.arrayBuffer());
    const finalHeaders: Record<string, string> = {};
    headers.forEach((value, key) => {
      finalHeaders[key] = value;
    });
    console.log('[UserApi] ☁️ 准备执行对象存储上传', {
      url: signature.url,
      method: signature.method || 'PUT',
      headers: finalHeaders
    });
    const uploadResponse = await fetch(signature.url, {
      method: signature.method || 'PUT',
      headers,
      mode: 'cors',
      body: fileBuffer
    });

    if (!uploadResponse.ok) {
      const errorText = await uploadResponse.text();

      // 针对 CORS 错误提供更友好的错误信息
      let errorMessage = errorText || '上传失败，请稍后重试';
      if (uploadResponse.status === 403) {
        errorMessage = '上传配置错误：可能存在跨域访问问题，请联系管理员检查存储配置';
      } else if (uploadResponse.status === 0) {
        errorMessage = '网络连接失败，请检查网络设置';
      }

      console.error('[UserApi] ❌ 对象存储上传失败', {
        status: uploadResponse.status,
        errorText
      });
      return {
        code: uploadResponse.status,
        success: false,
        message: errorMessage,
        data: null
      };
    }

    console.log('[UserApi] ✅ 对象存储上传成功，等待提交', {
      status: uploadResponse.status,
      key
    });

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
    console.log('[UserApi] 📝 提交头像配置响应', {
      success: commitResp.success,
      code: commitResp.code,
      message: commitResp.message,
      payloadSuccess: commitData?.success
    });
    if (!commitResp.success || !commitData || !commitData.success) {
      console.error('[UserApi] ❌ 提交头像配置失败', {
        code: commitResp.code,
        message: commitResp.message,
        payload: commitData
      });
      return {
        code: commitResp.code,
        success: false,
        message: commitData?.message || commitResp.message || '提交头像配置失败',
        data: null
      };
    }

    console.log('[UserApi] 💾 保存头像缓存文件', { key });
    const saved = await AvatarCache.save({
      userId: currentUser.id,
      objectKey: key,
      data: fileBuffer,
      filename: file.name,
      contentType
    });
    console.log('[UserApi] 💾 头像缓存完成', { webPath: saved.webPath });

    const avatarUrl = commitData.download_url || currentUser.avatar || '';
    console.log('[UserApi] 🔁 同步头像信息到 store', {
      avatarUrl,
      avatarObjectKey: key,
      avatarLocalPath: saved.webPath
    });
    store.commit('UPDATE_USER_INFO', {
      avatar: avatarUrl,
      avatarObjectKey: key,
      avatarLocalPath: saved.webPath
    });

    console.log('[UserApi] 🎉 头像上传流程完成');
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
