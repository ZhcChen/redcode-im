import { apiConfig, requestConfig } from './config';
import { store } from '../store';

export interface ApiResponse<T = unknown> {
  code: number;
  message: string;
  data: T;
  success: boolean;
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
  retry?: boolean;
  retryTimes?: number;
  retryDelay?: number;
}

export type RequestInterceptor = (config: RequestOptions & { url: string }) =>
  | (RequestOptions & { url: string })
  | Promise<RequestOptions & { url: string }>;

export type ResponseInterceptor = (response: ApiResponse<any>) =>
  | ApiResponse<any>
  | Promise<ApiResponse<any>>;

export type ErrorInterceptor = (error: Error) => Error | Promise<Error>;

const NO_AUTH_PATHS = new Set([
  '/auth/login',
  '/auth/register',
  '/auth/login/sms',
  '/auth/sms/send',
  '/settings/privacy-policy',
]);

const buildApiUrl = (base: string, path: string): string => {
  if (path.startsWith('http')) {
    return path;
  }
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${base}${normalizedPath}`;
};

const parseJsonSafely = async (response: Response) => {
  const text = await response.text();
  if (!text) {
    return null;
  }
  try {
    return JSON.parse(text);
  } catch (error) {
    console.warn('响应 JSON 解析失败，返回原始文本', error);
    return text;
  }
};

class HttpClient {
  private readonly baseURL: string;
  private defaultHeaders: Record<string, string>;
  private requestInterceptors: RequestInterceptor[] = [];
  private responseInterceptors: ResponseInterceptor[] = [];
  private errorInterceptors: ErrorInterceptor[] = [];
  private pendingRequests: Map<string, AbortController> = new Map();
  private isLoggingOut = false;
  private lastLoginTime: number | null = null;

  constructor(baseURL: string) {
    this.baseURL = baseURL;
    this.defaultHeaders = {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    };
  }

  addRequestInterceptor(interceptor: RequestInterceptor) {
    this.requestInterceptors.push(interceptor);
  }

  addResponseInterceptor(interceptor: ResponseInterceptor) {
    this.responseInterceptors.push(interceptor);
  }

  addErrorInterceptor(interceptor: ErrorInterceptor) {
    this.errorInterceptors.push(interceptor);
  }

  clearInterceptors() {
    this.requestInterceptors = [];
    this.responseInterceptors = [];
    this.errorInterceptors = [];
  }

  cancelAllPendingRequests() {
    this.pendingRequests.forEach((controller) => controller.abort());
    this.pendingRequests.clear();
  }

  setLoggingOut(value: boolean) {
    this.isLoggingOut = value;
    if (value) {
      this.cancelAllPendingRequests();
    }
  }

  setLastLoginTime(timestamp?: number) {
    this.lastLoginTime = timestamp ?? Date.now();
  }

  clearLastLoginTime() {
    this.lastLoginTime = null;
  }

  private async executeRequestInterceptors(
    config: RequestOptions & { url: string },
  ) {
    let current = config;
    for (const interceptor of this.requestInterceptors) {
      current = await interceptor(current);
    }
    return current;
  }

  private async executeResponseInterceptors<T>(
    response: ApiResponse<T>,
  ): Promise<ApiResponse<T>> {
    let current = response;
    for (const interceptor of this.responseInterceptors) {
      current = await interceptor(current);
    }
    return current;
  }

  private async executeErrorInterceptors(error: Error): Promise<Error> {
    let current = error;
    for (const interceptor of this.errorInterceptors) {
      current = await interceptor(current);
    }
    return current;
  }

  private shouldRetry(error: Error, attemptsLeft: number) {
    if (attemptsLeft <= 0) {
      return false;
    }
    const retriable =
      error.name === 'AbortError' ||
      error.message.includes('NetworkError') ||
      error.message.includes('Failed to fetch') ||
      error.message.includes('timeout');
    return retriable;
  }

  private needsAuth(fullUrl: string): boolean {
    try {
      const { pathname } = new URL(fullUrl);
      return !NO_AUTH_PATHS.has(pathname);
    } catch (_err) {
      return true;
    }
  }

  private async requestWithRetry<T>(
    url: string,
    options: RequestOptions = {},
  ): Promise<ApiResponse<T>> {
    const {
      retry = true,
      retryTimes = requestConfig.retryTimes,
      retryDelay = requestConfig.retryDelay,
      ...rest
    } = options;

    let attemptsLeft = retry ? retryTimes : 0;
    let lastError: Error | null = null;

    while (attemptsLeft >= 0) {
      try {
        return await this.executeRequest<T>(url, rest);
      } catch (error) {
        lastError = error as Error;
        if (!this.shouldRetry(lastError, attemptsLeft)) {
          break;
        }
        if (attemptsLeft > 0) {
          await new Promise((resolve) => setTimeout(resolve, retryDelay));
        }
        attemptsLeft -= 1;
      }
    }

    const processedError = await this.executeErrorInterceptors(
      lastError ?? new Error('未知错误'),
    );
    throw processedError;
  }

  private async executeRequest<T>(
    url: string,
    options: RequestOptions = {},
  ): Promise<ApiResponse<T>> {
    if (this.isLoggingOut) {
      throw new Error('用户正在退出登录');
    }

    const {
      method = 'GET',
      headers = {},
      body,
      timeout = requestConfig.timeout,
    } = options;

    const fullUrl = buildApiUrl(this.baseURL, url);
    const requestId = `${Date.now().toString(36)}-${Math.random()
      .toString(36)
      .slice(2)}`;

    const requestHeaders: Record<string, string> = {
      ...this.defaultHeaders,
      ...headers,
    };

    if (this.needsAuth(fullUrl)) {
      const token = store.state.token;
      if (!token) {
        throw new Error('未登录或凭证已过期');
      }
      requestHeaders.Authorization = `Bearer ${token}`;
    } else {
      delete requestHeaders.Authorization;
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);
    const fetchOptions: RequestInit = {
      method,
      headers: requestHeaders,
      signal: controller.signal,
    };

    if (body !== undefined && method !== 'GET') {
      if (body instanceof FormData) {
        delete requestHeaders['Content-Type'];
        fetchOptions.body = body;
      } else if (typeof body === 'string' || body instanceof Blob) {
        fetchOptions.body = body;
      } else {
        fetchOptions.body = JSON.stringify(body);
      }
    }

    this.pendingRequests.set(requestId, controller);

    try {
      const response = await fetch(fullUrl, fetchOptions);
      clearTimeout(timeoutId);
      this.pendingRequests.delete(requestId);

      if (response.status === 401) {
        this.handleUnauthorized();
        throw new Error('身份验证失败，请重新登录');
      }

      const parsed = await parseJsonSafely(response);
      const message =
        (parsed && typeof parsed === 'object' && 'message' in parsed
          ? (parsed as any).message
          : undefined) || response.statusText || '';

      const apiResponse: ApiResponse<T> = {
        code: response.status,
        message,
        data: (parsed as T) ?? (undefined as unknown as T),
        success: response.ok,
      };

      return this.executeResponseInterceptors(apiResponse);
    } catch (error) {
      this.pendingRequests.delete(requestId);
      if (error instanceof Error && error.name === 'AbortError') {
        throw new Error('请求超时，请稍后重试');
      }
      throw error;
    }
  }

  private handleUnauthorized() {
    if (this.isLoggingOut) {
      return;
    }
    this.setLoggingOut(true);

    const elapsed =
      this.lastLoginTime !== null ? Date.now() - this.lastLoginTime : null;
    const inGracePeriod = elapsed !== null && elapsed < 30_000;

    if (inGracePeriod) {
      console.warn('登录刚完成，忽略短期内的 401 响应');
      this.setLoggingOut(false);
      return;
    }

    setTimeout(() => {
      if (store.getters.isLoggedIn) {
        store.dispatch('logout');
      }
      if (window.location.pathname !== '/login') {
        window.location.href = '/login';
      }
      this.setLoggingOut(false);
    }, 300);
  }

  private async request<T>(
    url: string,
    options: RequestOptions = {},
  ): Promise<ApiResponse<T>> {
    const finalConfig = await this.executeRequestInterceptors({
      url,
      ...options,
    });
    return this.requestWithRetry<T>(finalConfig.url, finalConfig);
  }

  async get<T>(
    url: string,
    params?: Record<string, string | number | boolean | undefined>,
  ): Promise<ApiResponse<T>> {
    let target = url;
    if (params && Object.keys(params).length > 0) {
      const searchParams = new URLSearchParams();
      Object.entries(params).forEach(([key, value]) => {
        if (value === undefined || value === null) return;
        searchParams.append(key, String(value));
      });
      target = `${url}?${searchParams.toString()}`;
    }
    return this.request<T>(target, { method: 'GET' });
  }

  async post<T>(
    url: string,
    data?: any,
    options?: Partial<RequestOptions>,
  ): Promise<ApiResponse<T>> {
    return this.request<T>(url, {
      method: 'POST',
      body: data,
      ...options,
    });
  }

  async put<T>(url: string, data?: any): Promise<ApiResponse<T>> {
    return this.request<T>(url, {
      method: 'PUT',
      body: data,
    });
  }

  async patch<T>(url: string, data?: any): Promise<ApiResponse<T>> {
    return this.request<T>(url, {
      method: 'PATCH',
      body: data,
    });
  }

  async delete<T>(
    url: string,
    data?: any,
    options?: Partial<RequestOptions>,
  ): Promise<ApiResponse<T>> {
    return this.request<T>(url, {
      method: 'DELETE',
      body: data,
      ...options,
    });
  }

  async upload<T>(
    url: string,
    formData: FormData,
    options?: Partial<RequestOptions>,
  ): Promise<ApiResponse<T>> {
    return this.request<T>(url, {
      method: 'POST',
      body: formData,
      headers: {
        ...(options?.headers ?? {}),
      },
      ...options,
    });
  }
}

export const httpClient = new HttpClient(apiConfig.BASE_API);

httpClient.addResponseInterceptor((response) => ({
  ...response,
  success: response.code >= 200 && response.code < 300,
}));

httpClient.addErrorInterceptor((error) => {
  if (error.message.includes('Failed to fetch')) {
    return new Error('网络连接失败，请检查网络状态');
  }
  if (error.message.includes('超时')) {
    return new Error('请求超时，请稍后再试');
  }
  return error;
});

export const get = <T>(
  url: string,
  params?: Record<string, string | number | boolean | undefined>,
) => httpClient.get<T>(url, params);

export const post = <T>(
  url: string,
  data?: any,
  options?: Partial<RequestOptions>,
) => httpClient.post<T>(url, data, options);

export const put = <T>(url: string, data?: any) =>
  httpClient.put<T>(url, data);

export const patch = <T>(url: string, data?: any) =>
  httpClient.patch<T>(url, data);

export const del = <T>(
  url: string,
  data?: any,
  options?: Partial<RequestOptions>,
) => httpClient.delete<T>(url, data, options);

export const upload = <T>(
  url: string,
  formData: FormData,
  options?: Partial<RequestOptions>,
) => httpClient.upload<T>(url, formData, options);

export const addRequestInterceptor =
  httpClient.addRequestInterceptor.bind(httpClient);
export const addResponseInterceptor =
  httpClient.addResponseInterceptor.bind(httpClient);
export const addErrorInterceptor =
  httpClient.addErrorInterceptor.bind(httpClient);
export const clearInterceptors = httpClient.clearInterceptors.bind(httpClient);

export const cancelAllPendingRequests =
  httpClient.cancelAllPendingRequests.bind(httpClient);
export const setLoggingOut = httpClient.setLoggingOut.bind(httpClient);

export const setLoginTime = (time?: number) =>
  httpClient.setLastLoginTime(time);
export const clearLoginTime = () => httpClient.clearLastLoginTime();
