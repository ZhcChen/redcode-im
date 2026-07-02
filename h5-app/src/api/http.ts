import { appEnv } from '@/config/env';

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly payload: unknown,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

const extractMessage = (payload: unknown, fallback: string) => {
  if (payload && typeof payload === 'object') {
    const data = payload as Record<string, unknown>;
    if (typeof data.message === 'string' && data.message.trim()) {
      return data.message;
    }
    if (typeof data.error === 'string' && data.error.trim()) {
      return data.error;
    }
  }
  return fallback;
};

export async function requestJson<T>(
  path: string,
  options: RequestInit = {},
  token?: string | null,
): Promise<T> {
  const headers = new Headers(options.headers);
  if (!headers.has('Content-Type') && options.body) {
    headers.set('Content-Type', 'application/json');
  }
  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  const response = await fetch(`${appEnv.apiBaseUrl}${path}`, {
    ...options,
    headers,
  });
  const text = await response.text();
  const payload = parseResponsePayload(text);

  if (!response.ok) {
    throw new ApiError(
      extractMessage(payload, `请求失败 (${response.status})`),
      response.status,
      payload,
    );
  }

  return payload as T;
}

export const withQuery = (path: string, query: Record<string, string | number | boolean | null | undefined>) => {
  const params = new URLSearchParams();
  Object.entries(query).forEach(([key, value]) => {
    if (value === null || value === undefined || value === '') return;
    params.set(key, String(value));
  });
  const serialized = params.toString();
  return serialized ? `${path}?${serialized}` : path;
};

const parseResponsePayload = (text: string) => {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return { message: text };
  }
};
