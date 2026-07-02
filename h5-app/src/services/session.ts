import type { AuthSession } from '@/types/auth';

const STORAGE_KEY = 'redcode-h5-session';

export const readSession = (): AuthSession | null => {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as AuthSession) : null;
  } catch {
    return null;
  }
};

export const readToken = () => readSession()?.token ?? null;

export const requireToken = () => {
  const token = readToken();
  if (!token) {
    throw new Error('用户未登录');
  }
  return token;
};
