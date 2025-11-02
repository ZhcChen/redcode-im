export interface ApiConfig {
  BASE_API: string;
  MULTIPART_API: string;
  WS_URL: string;
  version: number;
}

const trimTrailingSlash = (value: string): string =>
  value.endsWith('/') ? value.slice(0, -1) : value;

const rawBaseUrl =
  import.meta.env.VITE_API_BASE_URL?.toString().trim() ||
  'http://127.0.0.1:8010';

const normalizedBaseUrl = trimTrailingSlash(rawBaseUrl);
const wsUrl =
  import.meta.env.VITE_WS_URL?.toString().trim() ||
  `${normalizedBaseUrl.replace(/^http/i, 'ws')}/ws`;

export const apiConfig: ApiConfig = {
  BASE_API: normalizedBaseUrl,
  MULTIPART_API:
    import.meta.env.VITE_API_UPLOAD_BASE_URL?.toString().trim() ||
    normalizedBaseUrl,
  WS_URL: wsUrl,
  version: 1,
};

export const fileConfig = {
  uploadAvatarUrl: `${apiConfig.MULTIPART_API}/users/me/avatar`,
};

export const requestConfig = {
  timeout: 15000,
  retryTimes: 2,
  retryDelay: 800,
};
