const trimRightSlash = (value: string) => value.replace(/\/+$/, '');

export const appEnv = {
  apiBaseUrl: trimRightSlash(import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8010'),
  wsUrl: import.meta.env.VITE_WS_URL || 'ws://127.0.0.1:8010/ws',
  useMockData: import.meta.env.VITE_USE_MOCK_DATA === 'true',
};
