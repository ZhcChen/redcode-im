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

export function registerAdminSessionRefresh(
  handler: (() => Promise<boolean>) | null
) {
  refreshHandler = handler;
}

export async function requestAdminSessionRefresh() {
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

export function shouldBypassAdminSessionRefresh(url?: string) {
  const pathname = normalizePath(url);

  return [
    '/api/admin/bootstrap/status',
    '/api/admin/bootstrap/init',
    '/auth/admin/login',
    '/auth/admin/refresh',
  ].includes(pathname);
}
