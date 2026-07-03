import { requestJson } from './http';
import type { AuthSession, AuthUser, BackendLoginResponse, BackendUser } from '@/types/auth';

const mapUser = (user: BackendUser): AuthUser => {
  const id = user.id ?? user.email ?? user.username ?? 'unknown-user';
  const email = user.email ?? user.username ?? '';
  return {
    id,
    username: user.username ?? email,
    nickname: user.nickname || email || 'RedCode 用户',
    email,
    status: user.status ?? 'active',
    avatarUrl: user.avatar_url ?? null,
    avatarObjectKey: user.avatar_object_key ?? null,
  };
};

const normalizeAccount = (account: string) => account.trim().toLowerCase();

const mockUser = (account: string): AuthUser => ({
  id: `mock-user-${account || 'bear'}`,
  username: account || 'bear',
  nickname: account || '熊小熊',
  email: `${account || 'bear'}@account.redcode.local`,
  status: 'active',
});

const delay = (ms = 180) => new Promise((resolve) => window.setTimeout(resolve, ms));

export async function loginWithAccount(account: string, password: string, useMockData = false): Promise<AuthSession> {
  const username = normalizeAccount(account);
  if (useMockData) {
    await delay();
    return {
      token: 'mock-token',
      refreshToken: null,
      user: mockUser(username),
    };
  }

  const response = await requestJson<BackendLoginResponse>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });

  return {
    token: response.token,
    refreshToken: response.refresh_token ?? null,
    user: mapUser(response.user),
  };
}

export async function registerWithAccount(account: string, password: string, useMockData = false): Promise<AuthUser> {
  const username = normalizeAccount(account);
  if (useMockData) {
    await delay();
    return mockUser(username);
  }

  const response = await requestJson<BackendUser>('/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      username,
      password,
      nickname: username,
    }),
  });

  return mapUser(response);
}
