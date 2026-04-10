const TOKEN_KEY = 'token';
const REFRESH_TOKEN_KEY = 'refresh_token';

let refreshHandler: (() => Promise<boolean>) | null = null;
let refreshPromise: Promise<boolean> | null = null;

function normalizePath(url?: string) {
  if (!url) {
    return '';
  }

  try {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return new URL(url).pathname;
    }
  } catch (error) {
    return url.split('?')[0];
  }

  return url.split('?')[0];
}

export function hasAccessToken() {
  return !!localStorage.getItem(TOKEN_KEY);
}

export function getAccessToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export function setAccessToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearAccessToken() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
}

export function getRefreshToken() {
  return localStorage.getItem(REFRESH_TOKEN_KEY);
}

export function setRefreshToken(refreshToken: string | null | undefined) {
  if (refreshToken && refreshToken.length > 0) {
    localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
  } else {
    localStorage.removeItem(REFRESH_TOKEN_KEY);
  }
}

export function registerAccessTokenRefresh(
  handler: (() => Promise<boolean>) | null
) {
  refreshHandler = handler;
}

export async function requestAccessTokenRefresh() {
  if (!refreshHandler) {
    return false;
  }

  if (!refreshPromise) {
    refreshPromise = refreshHandler().finally(() => {
      refreshPromise = null;
    });
  }

  return refreshPromise;
}

export function shouldBypassAccessTokenRefresh(url?: string) {
  const pathname = normalizePath(url);

  return [
    '/api/admin/bootstrap/status',
    '/api/admin/bootstrap/init',
    '/auth/admin/login',
    '/auth/admin/refresh',
  ].includes(pathname);
}

// compatibility exports for legacy callers during migration
export const isLogin = hasAccessToken;
export const getToken = getAccessToken;
export const setToken = setAccessToken;
export const clearToken = clearAccessToken;
export const registerAdminSessionRefresh = registerAccessTokenRefresh;
export const requestAdminSessionRefresh = requestAccessTokenRefresh;
export const shouldBypassAdminSessionRefresh = shouldBypassAccessTokenRefresh;
