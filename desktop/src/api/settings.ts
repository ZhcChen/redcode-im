import { httpClient } from './http';
import type { ApiResponse } from './http.types';

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

export class SettingsApi {
  static async getPrivacyPolicy(): Promise<ApiResponse<DocumentContent>> {
    return httpClient.get<DocumentContent>('/settings/privacy-policy');
  }

  /**
   * 获取应用名称（公开 API，无需 token）
   */
  static async getAppName(): Promise<ApiResponse<AppNameResponse>> {
    return httpClient.get<AppNameResponse>('/settings/app-name');
  }

  /**
   * 获取通用设置（公开 API，无需 token）
   */
  static async getGeneralSettings(): Promise<ApiResponse<GeneralSettingsResponse>> {
    return httpClient.get<GeneralSettingsResponse>('/settings/general');
  }
}
