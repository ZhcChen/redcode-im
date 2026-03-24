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
}
