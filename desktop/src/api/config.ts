/**
 * 桌面端 API 配置
 * 统一读取 Vite 环境变量，并提供默认值，便于在不同环境部署。
 */

const APP_VERSION = 103;

const normalizeUrl = (value: string): string => {
  if (!value) return value;
  return value.replace(/\/+$/, '');
};

const rawApiBase =
  (import.meta as any).env?.VITE_API_BASE_URL ||
  process.env.VITE_API_BASE_URL ||
  'http://localhost:8010';

const apiBaseUrl = normalizeUrl(rawApiBase);

const inferredWsUrl = (() => {
  if (apiBaseUrl.startsWith('https://')) {
    return `wss://${apiBaseUrl.slice('https://'.length)}/ws`;
  }
  if (apiBaseUrl.startsWith('http://')) {
    return `ws://${apiBaseUrl.slice('http://'.length)}/ws`;
  }
  return `${apiBaseUrl}/ws`;
})();

const rawWsUrl =
  (import.meta as any).env?.VITE_WS_URL ||
  process.env.VITE_WS_URL ||
  inferredWsUrl;

const rawFileBase =
  (import.meta as any).env?.VITE_FILE_BASE_URL ||
  process.env.VITE_FILE_BASE_URL ||
  apiBaseUrl;

export const apiConfig = {
  API_BASE_URL: apiBaseUrl,
  WS_URL: normalizeUrl(rawWsUrl),
  FILE_SAVE_TARGET: 'local' as const,
  version: APP_VERSION,
};

/**
 * 文件上传相关配置（当前后端文件服务待补齐，先保留占位路径）
 */
export const fileConfig = {
  uploadUrl: `${normalizeUrl(rawFileBase)}/files/upload`,
  uploadAvatarUrl: `${normalizeUrl(rawFileBase)}/users/me/avatar`,
  target: apiConfig.FILE_SAVE_TARGET,
  getFileByPath: `${normalizeUrl(rawFileBase)}/files/by-path?filePath=`,
  showFile: `${normalizeUrl(rawFileBase)}/files/`,
};

/**
 * 请求超时与重试配置
 */
export const requestConfig = {
  timeout: 15000,
  retryTimes: 2,
  retryDelay: 1000,
};
