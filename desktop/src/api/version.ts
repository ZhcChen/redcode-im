import { get, post } from './http';
import type { ApiResponse } from './http';

// 收集客户端详细信息的辅助函数
function collectClientDetails(): Partial<UpdateEventReport> {
  const details: Partial<UpdateEventReport> = {
    client_type: 'desktop', // 桌面端固定为desktop
    trigger_source: 'manual', // 默认手动触发，后续可根据实际情况修改
  };

  // 操作系统信息
  if (typeof navigator !== 'undefined') {
    // 操作系统版本
    if (navigator.userAgent) {
      const ua = navigator.userAgent;
      if (ua.includes('Windows NT')) {
        const match = ua.match(/Windows NT (\d+\.\d+)/);
        if (match) {
          details.os_version = `Windows ${match[1]}`;
        } else {
          details.os_version = 'Windows';
        }
      } else if (ua.includes('Mac OS X')) {
        const match = ua.match(/Mac OS X (\d+[._]\d+[._]\d+)/);
        if (match) {
          details.os_version = `macOS ${match[1].replace(/_/g, '.')}`;
        } else {
          details.os_version = 'macOS';
        }
      } else if (ua.includes('Linux')) {
        details.os_version = 'Linux';
      }
    }

    // 网络类型检测
    if ('connection' in navigator) {
      const connection = (navigator as any).connection;
      if (connection && connection.effectiveType) {
        details.network_type = connection.effectiveType;
      }
    }

    // 设备信息摘要
    const deviceInfo: string[] = [];
    if (navigator.platform) {
      deviceInfo.push(`platform:${navigator.platform}`);
    }
    if (navigator.language) {
      deviceInfo.push(`lang:${navigator.language}`);
    }
    if (navigator.cookieEnabled !== undefined) {
      deviceInfo.push(`cookies:${navigator.cookieEnabled}`);
    }
    details.device_info = deviceInfo.join(',');
  }

  // 架构信息（通过process或navigator获取）
  if (typeof process !== 'undefined' && process.arch) {
    details.app_arch = process.arch;
    details.os_arch = process.arch;
  } else if (typeof navigator !== 'undefined') {
    // 尝试从userAgent推断架构
    const ua = navigator.userAgent;
    if (ua.includes('x64') || ua.includes('x86_64') || ua.includes('amd64')) {
      details.app_arch = 'x64';
      details.os_arch = 'x64';
    } else if (ua.includes('arm64') || ua.includes('aarch64')) {
      details.app_arch = 'arm64';
      details.os_arch = 'arm64';
    } else if (ua.includes('x86') || ua.includes('i386') || ua.includes('i686')) {
      details.app_arch = 'x86';
      details.os_arch = 'x86';
    }
  }

  return details;
}

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

export interface UpdateEventReport {
  platform: string;
  channel?: string;
  base_version: string;
  patch_version: string;
  event_type: 'download_success' | 'download_failed' | 'apply_success' | 'apply_failed' | 'rollback';
  client_id?: string;
  message?: string;
  // 增强的详细信息
  client_type: 'desktop' | 'frontend'; // 触发来源：桌面端或移动端
  os_version?: string; // 操作系统版本
  os_arch?: string; // 操作系统架构
  app_arch?: string; // 应用架构 (x64, arm64等)
  build_number?: number; // 构建号
  trigger_source?: string; // 触发来源 (manual, auto, notification等)
  network_type?: string; // 网络类型 (wifi, cellular等)
  device_info?: string; // 设备信息摘要
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

  static async reportUpdateEvent(event: Omit<UpdateEventReport, 'client_type' | 'os_version' | 'os_arch' | 'app_arch' | 'device_info'>): Promise<ApiResponse<any>> {
    // 自动收集客户端详细信息
    const clientDetails = collectClientDetails();

    // 合并事件数据和客户端详细信息
    const fullEvent: UpdateEventReport = {
      ...event,
      ...clientDetails,
    } as UpdateEventReport;

    return post<any>('/versions/hot-update-events', fullEvent);
  }
}
