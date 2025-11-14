import { get } from './http';
import type { ApiResponse } from './http';

type SupportedPlatform = 'windows' | 'macos' | 'linux';

const detectPlatform = (): SupportedPlatform => {
  if (typeof navigator !== 'undefined') {
    const ua = navigator.userAgent?.toLowerCase?.() ?? '';
    if (ua.includes('mac') || ua.includes('darwin')) {
      return 'macos';
    }
    if (ua.includes('win')) {
      return 'windows';
    }
    if (ua.includes('linux')) {
      return 'linux';
    }
  }

  if (typeof process !== 'undefined' && typeof process.platform === 'string') {
    switch (process.platform) {
      case 'darwin':
        return 'macos';
      case 'win32':
        return 'windows';
      case 'linux':
        return 'linux';
      default:
        break;
    }
  }

  return 'windows';
};

export interface AppVersionInfo {
  id: string;
  platform: string;
  version: string;
  build_number: number;
  channel: string;
  download_key: string;
  download_url?: string | null;
  file_size?: number | null;
  checksum?: string | null;
  signature?: string | null;
  release_notes?: string | null;
  mandatory: boolean;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  released_at?: string | null;
}

export interface LatestVersionResponse {
  has_update: boolean;
  current_version?: string | null;
  version?: AppVersionInfo | null;
}

export interface VersionDownloadResponse {
  success: boolean;
  message: string;
  download_url?: string;
}

export class VersionApi {
  static async getLatestVersion(params: {
    channel?: string;
    currentVersion?: string;
  }): Promise<ApiResponse<LatestVersionResponse>> {
    // 自动识别平台：windows、macos、linux
    const platformName = detectPlatform();

    const query: Record<string, string> = {
      platform: platformName,
      channel: params.channel ?? 'stable'
    };
    if (params.currentVersion) {
      query.current_version = params.currentVersion;
    }
    return get<LatestVersionResponse>('/versions/latest', query);
  }

  static async getDownloadUrl(params: {
    id: string;
    expiresInSeconds?: number;
  }): Promise<ApiResponse<VersionDownloadResponse>> {
    const query: Record<string, string> = {
      id: params.id
    };
    if (params.expiresInSeconds) {
      query.expires_in_seconds = String(params.expiresInSeconds);
    }
    return get<VersionDownloadResponse>('/versions/download', query);
  }
}
