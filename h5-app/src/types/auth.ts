export interface AuthUser {
  id: string;
  username: string;
  nickname: string;
  email: string;
  status?: string;
  avatarUrl?: string | null;
  avatarObjectKey?: string | null;
  avatarCacheKey?: string | null;
}

export interface AuthSession {
  token: string;
  refreshToken?: string | null;
  user: AuthUser;
}

export interface BackendUser {
  id?: string;
  username?: string;
  nickname?: string | null;
  email?: string | null;
  status?: string | null;
  avatar_url?: string | null;
  avatar_object_key?: string | null;
}

export interface BackendLoginResponse {
  token: string;
  refresh_token?: string | null;
  user: BackendUser;
}
