import { get, type ApiResponse } from "./http";

export type SupportedPlatform = "windows" | "macos" | "linux";

export const detectPlatform = (): SupportedPlatform => {
  const platform = typeof navigator !== "undefined" ? navigator.userAgent.toLowerCase() : "";
  if (platform.includes("mac")) {
    return "macos";
  }
  if (platform.includes("linux")) {
    return "linux";
  }
  return "windows";
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

interface VersionDownloadPayload {
  success?: boolean;
  message?: string;
  download_url?: string | null;
}

export interface VersionDownloadResponse {
  success: boolean;
  message: string;
  downloadUrl: string | null;
}

export class VersionApi {
  static async getLatestVersion(params: {
    channel?: string;
    currentVersion?: string;
  }): Promise<ApiResponse<LatestVersionResponse>> {
    const platform = detectPlatform();

    if (window.desktopEl) {
      return window.desktopEl.rpc.invoke<ApiResponse<LatestVersionResponse>>("version.latest.get", {
        platform,
        channel: params.channel,
        current_version: params.currentVersion
      });
    }

    return get<LatestVersionResponse>("/versions/latest", {
      platform,
      channel: params.channel ?? "stable",
      current_version: params.currentVersion ?? ""
    });
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

    const response = await get<VersionDownloadPayload>("/versions/download", query);
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null
      };
    }

    return {
      ...response,
      data: {
        success: typeof response.data.success === "boolean" ? response.data.success : response.success,
        message: response.data.message || response.message || "",
        downloadUrl: response.data.download_url ?? null
      }
    };
  }
}
