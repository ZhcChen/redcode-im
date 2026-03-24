import { request, type ApiResponse } from "./http";

export interface DocumentContent {
  key: string;
  title: string;
  content: string;
  updated_at: string;
  updated_by?: string | null;
}

export interface AppNameResponse {
  app_name: string;
}

export interface GeneralSettingsResponse {
  app_name: string;
}

export interface CaptchaSettingPublicResponse {
  require_captcha_for_login: boolean;
}

const requireDesktopRuntime = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl;
};

export class SettingsApi {
  static async getPrivacyPolicy(): Promise<ApiResponse<DocumentContent>> {
    return requireDesktopRuntime().rpc.invoke<ApiResponse<DocumentContent>>("settings.privacy.get");
  }

  static async getUserAgreement(): Promise<ApiResponse<DocumentContent>> {
    return requireDesktopRuntime().rpc.invoke<ApiResponse<DocumentContent>>("settings.user-agreement.get");
  }

  static async getAppName(): Promise<ApiResponse<AppNameResponse>> {
    return requireDesktopRuntime().rpc.invoke<ApiResponse<AppNameResponse>>("settings.app-name.get");
  }

  static async getGeneralSettings(): Promise<ApiResponse<GeneralSettingsResponse>> {
    return request<GeneralSettingsResponse>("/settings/general", { method: "GET", injectToken: false });
  }

  static async getCaptchaSetting(): Promise<ApiResponse<CaptchaSettingPublicResponse>> {
    return requireDesktopRuntime().rpc.invoke<ApiResponse<CaptchaSettingPublicResponse>>("settings.captcha.get");
  }
}
