import { defineStore } from 'pinia';

import { appEnv } from '@/config/env';
import { loginWithAccount, registerWithAccount } from '@/api/auth';
import type { AuthSession, AuthUser } from '@/types/auth';

const STORAGE_KEY = 'redcode-h5-session';
let sessionStorageListener: ((event: StorageEvent) => void) | null = null;

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
    async login(account: string, password: string) {
      this.loading = true;
      this.error = '';
      try {
        const session = await loginWithAccount(account, password, appEnv.useMockData);
        this.session = session;
        writeStoredSession(session);
      } catch (error) {
        this.error = error instanceof Error ? error.message : '登录失败，请稍后重试';
        throw error;
      } finally {
        this.loading = false;
      }
    },
    async registerAndLogin(account: string, password: string) {
      this.loading = true;
      this.error = '';
      try {
        await registerWithAccount(account, password, appEnv.useMockData);
        const session = await loginWithAccount(account, password, appEnv.useMockData);
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
    updateCurrentUser(user: AuthUser) {
      if (!this.session) return;
      this.session = { ...this.session, user };
      writeStoredSession(this.session);
    },
    startSessionSync() {
      if (sessionStorageListener) return;
      sessionStorageListener = (event: StorageEvent) => {
        if (event.key !== STORAGE_KEY) return;
        try {
          this.session = event.newValue ? JSON.parse(event.newValue) as AuthSession : null;
          this.error = '';
        } catch {
          this.session = null;
          this.error = '登录状态已失效';
        }
      };
      window.addEventListener('storage', sessionStorageListener);
    },
    stopSessionSync() {
      if (!sessionStorageListener) return;
      window.removeEventListener('storage', sessionStorageListener);
      sessionStorageListener = null;
    },
  },
});
