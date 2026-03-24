import type { LegacyUserInfo } from "@/api/system";

export interface BootstrapSnapshot {
  accounts: Array<{ id: string; display_name: string }>;
  config: {
    app_name: string;
    environment: string;
    api_base_url?: string;
    ws_url?: string;
    version?: string;
    build_number?: number;
    channel?: string;
  };
  recent_conversations: Array<{ id: string; title: string }>;
  connection: {
    status: string;
  };
  feature_flags: Record<string, boolean>;
  auth: {
    logged_in: boolean;
    current_user: BootstrapUserSnapshot | null;
  };
}

export interface BootstrapUserSnapshot {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatar_url?: string | null;
  status: "active" | "inactive" | "banned";
}

const mapStatusToActiveFlag = (status: BootstrapUserSnapshot["status"]): number | null => {
  switch (status) {
    case "active":
      return 1;
    case "inactive":
      return 0;
    case "banned":
      return -1;
    default:
      return null;
  }
};

export const mapBootstrapUserToLegacy = (user: BootstrapUserSnapshot): LegacyUserInfo => ({
  id: user.id,
  username: user.username,
  nickname: user.nickname || user.username,
  avatar: user.avatar_url || "",
  avatarObjectKey: null,
  avatarLocalPath: null,
  mobile: user.username,
  email: user.email || "",
  isLoggedIn: true,
  realName: user.nickname || user.username,
  chatNumber: user.username,
  address: "",
  createTime: null,
  lastLoginTime: null,
  activeStatus: mapStatusToActiveFlag(user.status),
  delFlag: null,
  level: null,
  userDeviceId: null,
  userSign: null,
  trcSdkAppId: null,
  powerList: null
});
