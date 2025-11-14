/**
 * 桌面端 API 配置
 * 统一读取 Vite 环境变量，并提供默认值，便于在不同环境部署。
 */

import { getApiBaseUrl } from '../config/environment'

const DEFAULT_APP_VERSION = '1.0.0'
const DEFAULT_APP_BUILD = '100'

const normalizeUrl = (value: string): string => {
  if (!value) return value;
  return value.replace(/\/+$/, '');
};

const resolveEnv = (key: string, fallback?: string): string | undefined => {
  const metaEnv = ((import.meta as any)?.env ?? {}) as Record<string, string | undefined>;
  const processEnv = ((globalThis as any)?.process?.env ?? {}) as Record<string, string | undefined>;
  return metaEnv[key] ?? processEnv[key] ?? fallback;
};

const rawApiBase = resolveEnv('VITE_API_BASE_URL', getApiBaseUrl());

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

const rawWsUrl = resolveEnv('VITE_WS_URL', inferredWsUrl);

const rawFileBase = resolveEnv('VITE_FILE_BASE_URL', apiBaseUrl);
const appSemver = resolveEnv('VITE_APP_VERSION', DEFAULT_APP_VERSION) ?? DEFAULT_APP_VERSION
const appBuild = Number(resolveEnv('VITE_APP_BUILD', DEFAULT_APP_BUILD)) || 100
const appChannel = resolveEnv('VITE_APP_CHANNEL', 'stable') ?? 'stable'

export const apiConfig = {
  API_BASE_URL: apiBaseUrl,
  WS_URL: normalizeUrl(rawWsUrl),
  FILE_SAVE_TARGET: 'local' as const,
  version: appSemver,
  buildNumber: appBuild,
  channel: appChannel,
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
