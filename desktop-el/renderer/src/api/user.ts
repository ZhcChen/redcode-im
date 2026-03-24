import { get, type ApiResponse } from "./http";
import type { LegacyUserInfo } from "./system";

interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  status: "active" | "inactive" | "banned";
}

const mapBackendToLegacy = (user: BackendUserInfo): LegacyUserInfo => ({
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

export class UserApi {
  static async getUserAccountInfo(params: { userId?: string } = {}): Promise<ApiResponse<LegacyUserInfo>> {
    const path = params.userId && params.userId !== "me" ? `/users/${params.userId}` : "/auth/me";
    const response = await get<BackendUserInfo>(path);
    return {
      ...response,
      data: response.data ? mapBackendToLegacy(response.data) : null
    };
  }
}
