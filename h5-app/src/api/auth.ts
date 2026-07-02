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

const mockUser = (email: string): AuthUser => ({
  id: `mock-user-${email || 'bear'}`,
  username: email || 'bear@example.com',
  nickname: email ? email.split('@')[0] : '熊小熊',
  email: email || 'bear@example.com',
  status: 'active',
});

const delay = (ms = 180) => new Promise((resolve) => window.setTimeout(resolve, ms));

export async function loginWithEmail(email: string, password: string, useMockData = false): Promise<AuthSession> {
  const normalizedEmail = email.trim().toLowerCase();
  if (useMockData) {
    await delay();
    return {
      token: 'mock-token',
      refreshToken: null,
      user: mockUser(normalizedEmail),
    };
  }

  const response = await requestJson<BackendLoginResponse>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email: normalizedEmail, password }),
  });

  return {
    token: response.token,
    refreshToken: response.refresh_token ?? null,
    user: mapUser(response.user),
  };
}

export async function registerWithEmail(email: string, password: string, useMockData = false): Promise<AuthUser> {
  const normalizedEmail = email.trim().toLowerCase();
  if (useMockData) {
    await delay();
    return mockUser(normalizedEmail);
  }

  const response = await requestJson<BackendUser>('/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      email: normalizedEmail,
      password,
      nickname: normalizedEmail,
    }),
  });

  return mapUser(response);
}
