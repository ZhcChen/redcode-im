export interface LoginData {
  username: string;
  password: string;
}

export interface BackendUserInfo {
  id: string;
  username: string;
  email: string;
  nickname?: string | null;
  avatarUrl?: string | null;
  status: string;
  roleCodes?: string[];
  permissionKeys?: string[];
  isSuperAdmin?: boolean;
  lastLoginAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface LoginRes {
  token: string;
  user?: BackendUserInfo;
  refresh_token?: string | null;
}
