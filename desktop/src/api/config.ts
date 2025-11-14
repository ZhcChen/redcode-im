/**
 * 桌面端 API 配置
 * 统一读取 Vite 环境变量，并提供默认值，便于在不同环境部署。
 */

import { getApiBaseUrl } from '../config/environment'

const DEFAULT_APP_VERSION = '1.0.0';
const DEFAULT_APP_BUILD = '100';

const normalizeUrl = (value: string): string => {
  if (!value) return value;
  return value.replace(/\/+$/, '');
};

const processEnv = ((globalThis as any)?.process?.env ?? {}) as Record<string, string | undefined>;

const resolveEnv = (valueFromMeta: string | undefined, key: keyof typeof processEnv, fallback?: string) => {
  return valueFromMeta ?? processEnv[key as string] ?? fallback;
};

const rawApiBase = resolveEnv(import.meta.env.VITE_API_BASE_URL, 'VITE_API_BASE_URL', getApiBaseUrl());

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

const rawWsUrl = resolveEnv(import.meta.env.VITE_WS_URL, 'VITE_WS_URL', inferredWsUrl);

const rawFileBase = resolveEnv(import.meta.env.VITE_FILE_BASE_URL, 'VITE_FILE_BASE_URL', apiBaseUrl);

const appSemver = resolveEnv(import.meta.env.VITE_APP_VERSION, 'VITE_APP_VERSION', DEFAULT_APP_VERSION) ?? DEFAULT_APP_VERSION;
const parsedBuild = Number(resolveEnv(import.meta.env.VITE_APP_BUILD, 'VITE_APP_BUILD', DEFAULT_APP_BUILD));
const appBuild = Number.isFinite(parsedBuild) && parsedBuild > 0 ? parsedBuild : 100;
const appChannel = resolveEnv(import.meta.env.VITE_APP_CHANNEL, 'VITE_APP_CHANNEL', 'stable') ?? 'stable';

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
