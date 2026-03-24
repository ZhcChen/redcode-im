import { get, type ApiResponse } from "./http";
import type { LegacyUserInfo } from "./system";

interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
  status: "active" | "inactive" | "banned";
}

export interface SearchUserInfo {
  id: string;
  username: string;
  email: string | null;
  nickname: string | null;
  avatarUrl: string | null;
  avatarObjectKey: string | null;
  status: "active" | "inactive" | "banned" | null;
}

const mapBackendToLegacy = (user: BackendUserInfo): LegacyUserInfo => ({
  id: user.id,
  username: user.username,
  nickname: user.nickname || user.username,
  avatar: user.avatar_url || "",
  avatarObjectKey: user.avatar_object_key || null,
  avatarLocalPath: null,
  mobile: user.username,
  email: user.email || "",
  isLoggedIn: true,
  realName: user.nickname || user.username,
  chatNumber: user.username,
  address: "",
  createTime: null,
  lastLoginTime: null,
  activeStatus: user.status === "active" ? 1 : user.status === "inactive" ? 0 : -1,
  delFlag: null,
  level: null,
  userDeviceId: null,
  userSign: null,
  trcSdkAppId: null,
  powerList: null
});

const mapBackendToSearchUser = (user: BackendUserInfo): SearchUserInfo => ({
  id: user.id,
  username: user.username,
  email: user.email || null,
  nickname: user.nickname || null,
  avatarUrl: user.avatar_url || null,
  avatarObjectKey: user.avatar_object_key || null,
  status: user.status || null
});

const requireDesktopRuntime = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl;
};

export class UserApi {
  static async searchUsers(params: { keyword: string; limit?: number }): Promise<ApiResponse<SearchUserInfo[]>> {
    const keyword = params.keyword.trim();
    if (!keyword) {
      return {
        code: 400,
        success: false,
        message: "请输入搜索关键词",
        data: []
      };
    }

    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendUserInfo[]>>("user.search", {
      keyword,
      limit: params.limit
    });
    return {
      ...response,
      data: response.data ? response.data.map(mapBackendToSearchUser) : []
    };
  }

  static async getUserAccountInfo(params: { userId?: string } = {}): Promise<ApiResponse<LegacyUserInfo>> {
    const path = params.userId && params.userId !== "me" ? `/users/${params.userId}` : "/auth/me";
    const response = await get<BackendUserInfo>(path);
    return {
      ...response,
      data: response.data ? mapBackendToLegacy(response.data) : null
    };
  }

  static async updateMe(params: { nickname?: string; avatarUrl?: string }): Promise<ApiResponse<LegacyUserInfo>> {
    const response = await requireDesktopRuntime().rpc.invoke<ApiResponse<BackendUserInfo>>("user.me.update", {
      nickname: params.nickname,
      avatar_url: params.avatarUrl
    });
    return {
      ...response,
      data: response.data ? mapBackendToLegacy(response.data) : null
    };
  }
}
