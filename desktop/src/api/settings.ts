import { httpClient } from './http';
import type { ApiResponse } from './http.types';

export interface DocumentContent {
  key: string;
  title: string;
  content: string;
  updated_at: string;
  updated_by?: string | null;
}

export class SettingsApi {
  static async getPrivacyPolicy(): Promise<ApiResponse<DocumentContent>> {
    return httpClient.get<DocumentContent>('/settings/privacy-policy');
  }
}
