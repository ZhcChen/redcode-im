import { requestJson } from '@/api/http';
import type { AuthSession, AuthUser, BackendLoginResponse, BackendUser } from '@/types/auth';

import { mapUser } from './mappers';
import { readSession, requireToken } from './session';

export const authService = {
  async me(): Promise<AuthUser | null> {
    const token = readSession()?.token;
    if (!token) return null;
    const response = await requestJson<BackendUser>('/auth/me', {}, token);
    return mapUser(response);
  },

  async refresh(refreshToken: string): Promise<AuthSession> {
    const response = await requestJson<BackendLoginResponse>('/auth/refresh', {
      method: 'POST',
      body: JSON.stringify({ refresh_token: refreshToken }),
    });
    return {
      token: response.token,
      refreshToken: response.refresh_token ?? refreshToken,
      user: mapUser(response.user),
    };
  },

  async updateProfile(params: { nickname?: string; avatarUrl?: string }): Promise<AuthUser> {
    const payload: Record<string, string> = {};
    if (params.nickname !== undefined) payload.nickname = params.nickname.trim();
    if (params.avatarUrl !== undefined) payload.avatar_url = params.avatarUrl.trim();
    const response = await requestJson<BackendUser>('/users/me', {
      method: 'PATCH',
      body: JSON.stringify(payload),
    }, requireToken());
    return mapUser(response);
  },

  async changePassword(oldPassword: string, newPassword: string): Promise<void> {
    await requestJson('/users/me/password', {
      method: 'POST',
      body: JSON.stringify({ old_password: oldPassword, new_password: newPassword }),
    }, requireToken());
  },

  async deactivateAccount(): Promise<void> {
    await requestJson('/users/me', { method: 'DELETE' }, requireToken());
  },
};
