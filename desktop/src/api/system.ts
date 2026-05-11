import { get, post } from './http';
import type { ApiResponse } from './http';

type BackendUserStatus = 'active' | 'inactive' | 'banned';

interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
  status: BackendUserStatus;
}

interface BackendLoginResponse {
  token: string;
  user: BackendUserInfo;
  refresh_token?: string | null;
}

export interface LoginParams {
  username?: string;
  mobile?: string;
  password: string;
  captcha?: string;
  userDeviceId?: number;
}

export interface SmsLoginParams {
  phone: string;
  code: string;
}

export interface LoginResponse {
  token: string;
  userInfo: LegacyUserInfo;
  refreshToken?: string | null;
}

export interface RegisterParams {
  username?: string;
  email: string;
  password: string;
  nickname?: string;
}

export interface LegacyUserInfo {
  id: string;
  username: string;
  nickname: string;
  avatar: string;
  avatarObjectKey?: string | null;
  avatarLocalPath?: string | null;
  mobile: string;
  email: string;
  isLoggedIn: boolean;
  realName?: string | null;
  chatNumber?: string | null;
  address?: string | null;
  createTime?: string | null;
  lastLoginTime?: string | null;
  activeStatus?: number | null;
  delFlag?: number | null;
  level?: number | null;
  userDeviceId?: string | null;
  userSign?: string | null;
  trcSdkAppId?: number | null;
  powerList?: any[] | null;
}

export interface UploadPolicyMaxSizeMbByPartType {
  image: number;
  video: number;
  audio: number;
  file: number;
}

export interface UploadPolicyMimeByPartType {
  image: string[];
  video: string[];
  audio: string[];
  file: string[];
}

export interface AudioOnlyPolicy {
  enabled: boolean;
  force_single_attachment: boolean;
  allow_text: boolean;
}

export interface UploadPolicyView {
  version: string;
  max_total_size_mb: number;
  max_attachments_per_message: number;
  max_size_mb_by_part_type: UploadPolicyMaxSizeMbByPartType;
  mime_by_part_type: UploadPolicyMimeByPartType;
  mime_whitelist: string[];
  audio_only: AudioOnlyPolicy;
}

const mapStatusToActiveFlag = (status: BackendUserStatus): number | null => {
  switch (status) {
    case 'active':
      return 1;
    case 'inactive':
      return 0;
    case 'banned':
      return -1;
    default:
      return null;
  }
};

const mapBackendUserToLegacy = (user: BackendUserInfo): LegacyUserInfo => ({
  id: String(user.id),
  username: user.username,
  nickname: user.nickname || user.username,
  avatar: user.avatar_url || '',
  avatarObjectKey: user.avatar_object_key || null,
  avatarLocalPath: null,
  mobile: user.username,
  email: user.email || '',
  isLoggedIn: true,
  realName: user.nickname || user.username,
  chatNumber: user.username,
  address: '',
  createTime: null,
  lastLoginTime: null,
  activeStatus: mapStatusToActiveFlag(user.status),
  delFlag: null,
  level: null,
  userDeviceId: null,
  userSign: null,
  trcSdkAppId: null,
  powerList: null
});

const wrapLoginResponse = (
  response: ApiResponse<BackendLoginResponse>
): ApiResponse<LoginResponse> => {
  if (!response.success || !response.data) {
    return {
      ...response,
      data: null
    };
  }

  const mappedUser = mapBackendUserToLegacy(response.data.user);
  return {
    ...response,
    data: {
      token: response.data.token,
      userInfo: mappedUser,
      refreshToken: response.data.refresh_token ?? null
    }
  };
};

export class SystemApi {
  /**
   * 用户名 / 手机号 + 密码登录
   */
  static async login(params: LoginParams): Promise<ApiResponse<LoginResponse>> {
    const payload = {
      username: params.username || params.mobile || '',
      password: params.password
    };

    const response = await post<BackendLoginResponse>('/auth/login', payload);
    return wrapLoginResponse(response);
  }

  /**
   * 短信验证码登录
   */
  static async loginWithSMS(params: SmsLoginParams): Promise<ApiResponse<LoginResponse>> {
    const response = await post<BackendLoginResponse>('/auth/login/sms', params);
    return wrapLoginResponse(response);
  }

  /**
   * 发送登录短信验证码
   */
  static async sendLoginSMS(params: { phone: string }): Promise<ApiResponse<{ success: boolean; message?: string }>> {
    return post<{ success: boolean; message?: string }>('/auth/sms/send', params);
  }

  /**
   * 获取当前登录用户信息
   */
  static async getCurrentUser(): Promise<ApiResponse<LegacyUserInfo>> {
    const response = await get<BackendUserInfo>('/auth/me');
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null
      };
    }

    return {
      ...response,
      data: mapBackendUserToLegacy(response.data)
    };
  }

  /**
   * 用户注册
   */
  static async register(params: RegisterParams): Promise<ApiResponse<LegacyUserInfo>> {
    const response = await post<BackendUserInfo>('/auth/register', params);
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null
      };
    }

    return {
      ...response,
      data: mapBackendUserToLegacy(response.data)
    };
  }

  /**
   * 修改密码（通过短信验证码）
   */
  static async resetPasswordWithSMS(params: { phone: string; code: string; newPassword: string }): Promise<ApiResponse<{ success: boolean }>> {
    return post<{ success: boolean }>('/auth/password/reset', {
      phone: params.phone,
      code: params.code,
      new_password: params.newPassword
    });
  }

  /**
   * 获取上传策略（登录态）
   */
  static async getUploadPolicy(): Promise<ApiResponse<UploadPolicyView>> {
    return get<UploadPolicyView>('/system/upload-policy');
  }

  /**
   * 本地登出：直接清空客户端状态
   */
  static async logout(): Promise<ApiResponse<null>> {
    return Promise.resolve({
      code: 200,
      success: true,
      message: '已退出登录',
      data: null
    });
  }
}
