import type { ApiResponse } from "./http";

interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  status: "active" | "inactive" | "banned";
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
}

export interface SmsLoginParams {
  phone: string;
  code: string;
}

export interface LegacyUserInfo {
  id: string;
  username: string;
  nickname: string;
  avatar: string;
  mobile: string;
  email: string;
  isLoggedIn: boolean;
  realName?: string | null;
  chatNumber?: string | null;
}

export interface LoginResponse {
  token: string;
  userInfo: LegacyUserInfo;
  refreshToken?: string | null;
}

const requireDesktopRuntime = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl;
};

const mapBackendUserToLegacy = (user: BackendUserInfo): LegacyUserInfo => ({
  id: user.id,
  username: user.username,
  nickname: user.nickname || user.username,
  avatar: user.avatar_url || "",
  mobile: user.username,
  email: user.email || "",
  isLoggedIn: true,
  realName: user.nickname || user.username,
  chatNumber: user.username
});

const wrapLoginResponse = (response: BackendLoginResponse): LoginResponse => ({
  token: response.token,
  userInfo: mapBackendUserToLegacy(response.user),
  refreshToken: response.refresh_token ?? null
});

export class SystemApi {
  static async login(params: LoginParams): Promise<ApiResponse<LoginResponse>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendLoginResponse>>("auth.login", {
      username: params.username || params.mobile || "",
      password: params.password
    });
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null
      };
    }
    return {
      ...response,
      data: wrapLoginResponse(response.data)
    };
  }

  static async loginWithSMS(params: SmsLoginParams): Promise<ApiResponse<LoginResponse>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendLoginResponse>>(
      "auth.login.sms",
      params as unknown as Record<string, unknown>
    );
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null
      };
    }
    return {
      ...response,
      data: wrapLoginResponse(response.data)
    };
  }

  static async sendLoginSMS(params: { phone: string }): Promise<ApiResponse<{ success: boolean; message?: string }>> {
    return requireDesktopRuntime().rpc.invoke<ApiResponse<{ success: boolean; message?: string }>>("auth.sms.send", params);
  }

  static async getCurrentUser(): Promise<ApiResponse<LegacyUserInfo>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendUserInfo>>("auth.me.get");
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
}
