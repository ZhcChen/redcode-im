const normalizeUrl = (value: string): string => value.replace(/\/+$/, "");

const apiBaseUrl = normalizeUrl(import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8010");
const wsUrl = normalizeUrl(import.meta.env.VITE_WS_URL || "ws://127.0.0.1:8010/ws");

export const apiConfig = {
  API_BASE_URL: apiBaseUrl,
  WS_URL: wsUrl,
  FILE_SAVE_TARGET: "local" as const,
  version: import.meta.env.VITE_APP_VERSION || "0.1.0",
  buildNumber: Number(import.meta.env.VITE_APP_BUILD || "1"),
  channel: import.meta.env.VITE_APP_CHANNEL || "stable"
};

export const fileConfig = {
  uploadUrl: `${apiBaseUrl}/files/upload`,
  uploadAvatarUrl: `${apiBaseUrl}/users/me/avatar`,
  target: apiConfig.FILE_SAVE_TARGET,
  getFileByPath: `${apiBaseUrl}/files/by-path?filePath=`,
  showFile: `${apiBaseUrl}/files/`
};

export const requestConfig = {
  timeout: 15000,
  retryTimes: 2,
  retryDelay: 1000
};

export const getRuntimeConfig = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl.rpc.invoke("core.config.get");
};
