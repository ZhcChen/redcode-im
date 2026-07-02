import { defineStore } from 'pinia';

import { appEnv } from '@/config/env';
import { loginWithEmail, registerWithEmail } from '@/api/auth';
import type { AuthSession } from '@/types/auth';

const STORAGE_KEY = 'redcode-h5-session';

const readStoredSession = (): AuthSession | null => {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as AuthSession) : null;
  } catch {
    return null;
  }
};

const writeStoredSession = (session: AuthSession | null) => {
  if (session) {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  } else {
    window.localStorage.removeItem(STORAGE_KEY);
  }
};

export const useAuthStore = defineStore('auth', {
  state: () => ({
    session: readStoredSession() as AuthSession | null,
    loading: false,
    error: '',
  }),
  getters: {
    isAuthenticated: (state) => Boolean(state.session?.token),
    currentUser: (state) => state.session?.user ?? null,
  },
  actions: {
    async login(email: string, password: string) {
      this.loading = true;
      this.error = '';
      try {
        const session = await loginWithEmail(email, password, appEnv.useMockData);
        this.session = session;
        writeStoredSession(session);
      } catch (error) {
        this.error = error instanceof Error ? error.message : '登录失败，请稍后重试';
        throw error;
      } finally {
        this.loading = false;
      }
    },
    async registerAndLogin(email: string, password: string) {
      this.loading = true;
      this.error = '';
      try {
        await registerWithEmail(email, password, appEnv.useMockData);
        const session = await loginWithEmail(email, password, appEnv.useMockData);
        this.session = session;
        writeStoredSession(session);
      } catch (error) {
        this.error = error instanceof Error ? error.message : '注册失败，请稍后重试';
        throw error;
      } finally {
        this.loading = false;
      }
    },
    logout() {
      this.session = null;
      this.error = '';
      writeStoredSession(null);
    },
  },
});
