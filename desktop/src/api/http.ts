/**
 * HTTP 请求工具类
 * 基于 fetch API 封装，提供统一的请求接口
 */

import { apiConfig, requestConfig } from './config';
import type { ApiResponse } from './http.types';
import { rustHttp } from './rust-http';
import type { HttpRequestParams } from './rust-http';
import { store } from '../store';
import { arrayBufferToBase64, blobToBase64 } from '../utils/binary';

export type { ApiResponse } from './http.types';

const rustEnvValue = import.meta.env.VITE_USE_RUST_BACKEND;
const USE_RUST_BACKEND = rustEnvValue === undefined || rustEnvValue === '' ? true : rustEnvValue === 'true';

const isTauriEnvironment = (): boolean => {
  if (typeof window === 'undefined') {
    return false;
  }
  const win = window as typeof window & { __TAURI_IPC__?: unknown; __TAURI_INTERNALS__?: unknown };
  return Boolean(win.__TAURI_IPC__ || win.__TAURI_INTERNALS__);
};

let rustInitialized = false;
let rustInitPromise: Promise<boolean> | null = null;
let rustDisabled = false;
let rustTokenSnapshot: string | null = null;

const canUseRustBridge = () => USE_RUST_BACKEND && isTauriEnvironment() && !rustDisabled;

type InternalRequestOptions = RequestOptions & {
  serializedBody?: string;
  binaryBodyBase64?: string;
  injectToken?: boolean;
  forceStreaming?: boolean;
};

const isFormDataBody = (value: unknown): value is FormData =>
  typeof FormData !== 'undefined' && value instanceof FormData;

const isBlobBody = (value: unknown): value is Blob =>
  typeof Blob !== 'undefined' && value instanceof Blob;

const serializeFormData = async (formData: FormData) => {
  if (typeof Response === 'undefined') {
    throw new Error('当前环境不支持 FormData 转换，请在桌面端运行');
  }
  const response = new Response(formData);
  const contentType = response.headers.get('content-type') || 'multipart/form-data';
  const buffer = await response.arrayBuffer();
  return {
    base64: arrayBufferToBase64(buffer),
    contentType
  };
};

const syncRustToken = async (token: string | null) => {
  if (!canUseRustBridge()) {
    return;
  }
  if (token && token !== rustTokenSnapshot) {
    await rustHttp.setToken(token);
    rustTokenSnapshot = token;
  } else if (!token && rustTokenSnapshot) {
    await rustHttp.clearToken();
    rustTokenSnapshot = null;
  }
};

const ensureRustBridgeReady = async (token?: string | null): Promise<boolean> => {
  if (!canUseRustBridge()) {
    return false;
  }

  if (rustInitialized) {
    await syncRustToken(token ?? null);
    return true;
  }

  if (!rustInitPromise) {
    rustInitPromise = rustHttp
      .initialize(token ?? undefined)
      .then(() => {
        rustInitialized = true;
        return true;
      })
      .catch((error) => {
        rustDisabled = true;
        return false;
      })
      .finally(() => {
        rustInitPromise = null;
      });
  }

  const ok = await rustInitPromise;
  if (ok) {
    await syncRustToken(token ?? null);
  }
  return ok;
};

export const syncRustBackendToken = async (token: string | null) => {
  if (!USE_RUST_BACKEND) {
    rustTokenSnapshot = token ?? null;
    return;
  }
  await ensureRustBridgeReady(token);
};

/**
 * 请求参数接口
 */
export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
  retry?: boolean; // 是否启用重试
  retryTimes?: number; // 重试次数
  retryDelay?: number; // 重试延迟
  responseType?: 'json' | 'binary';
  injectToken?: boolean;
  forceStreaming?: boolean;
}

/**
 * 请求拦截器函数类型
 */
export type RequestInterceptor = (config: RequestOptions & { url: string }) => RequestOptions & { url: string } | Promise<RequestOptions & { url: string }>;

/**
 * 响应拦截器函数类型
 */
export type ResponseInterceptor = (response: ApiResponse<any>) => ApiResponse<any> | Promise<ApiResponse<any>>;

/**
 * 错误拦截器函数类型
 */
export type ErrorInterceptor = (error: Error) => Error | Promise<Error>;

/**
 * HTTP 请求类
 */
class HttpClient {
  private baseURL: string;
  private defaultHeaders: Record<string, string>;
  private requestInterceptors: RequestInterceptor[] = [];
  private responseInterceptors: ResponseInterceptor[] = [];
  private errorInterceptors: ErrorInterceptor[] = [];
  private pendingRequests: Map<string, AbortController> = new Map();
  private isLoggingOut: boolean = false;
  private lastLoginTime: number | null = null;

  constructor(baseURL: string) {
    this.baseURL = baseURL;
    this.defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
  }

  /**
   * 设置认证 token
   * @param token 认证令牌
   * @deprecated 不再需要手动设置 token，系统会自动从 store 中获取并添加到请求头
   */
  setAuthToken(token: string) {
  }

  /**
   * 移除认证 token
   * @deprecated 不再需要手动移除 token，登出时清除 store 中的 token 即可
   */
  removeAuthToken() {
  }

  /**
   * 添加请求拦截器
   * @param interceptor 拦截器函数
   */
  addRequestInterceptor(interceptor: RequestInterceptor) {
    this.requestInterceptors.push(interceptor);
  }

  /**
   * 添加响应拦截器
   * @param interceptor 拦截器函数
   */
  addResponseInterceptor(interceptor: ResponseInterceptor) {
    this.responseInterceptors.push(interceptor);
  }

  /**
   * 添加错误拦截器
   * @param interceptor 拦截器函数
   */
  addErrorInterceptor(interceptor: ErrorInterceptor) {
    this.errorInterceptors.push(interceptor);
  }

  /**
   * 移除所有拦截器
   */
  clearInterceptors() {
    this.requestInterceptors = [];
    this.responseInterceptors = [];
    this.errorInterceptors = [];
  }

  /**
   * 取消所有pending的请求
   */
  cancelAllPendingRequests() {
    this.pendingRequests.forEach((controller, requestId) => {
      try {
        controller.abort();
      } catch (error) {
      }
    });
    this.pendingRequests.clear();
  }

  /**
   * 设置登出状态
   */
  setLoggingOut(isLoggingOut: boolean) {
    this.isLoggingOut = isLoggingOut;
    if (isLoggingOut) {
      // 登出时取消所有pending请求
      this.cancelAllPendingRequests();
    }
  }

  private supportsRustBridge(): boolean {
    return canUseRustBridge();
  }

  /**
   * 执行请求拦截器
   * @param config 请求配置
   */
  private async executeRequestInterceptors(config: RequestOptions & { url: string }): Promise<RequestOptions & { url: string }> {
    let processedConfig = config;
    for (const interceptor of this.requestInterceptors) {
      processedConfig = await interceptor(processedConfig);
    }
    return processedConfig;
  }

  /**
   * 执行响应拦截器
   * @param response 响应数据
   */
  private async executeResponseInterceptors<T>(response: ApiResponse<T>): Promise<ApiResponse<T>> {
    let processedResponse = response;
    for (const interceptor of this.responseInterceptors) {
      processedResponse = await interceptor(processedResponse);
    }
    return processedResponse;
  }

  /**
   * 执行错误拦截器
   * @param error 错误对象
   */
  private async executeErrorInterceptors(error: Error): Promise<Error> {
    let processedError = error;
    for (const interceptor of this.errorInterceptors) {
      processedError = await interceptor(processedError);
    }
    return processedError;
  }

  /**
   * 延迟函数
   * @param ms 延迟毫秒数
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 判断是否应该重试
   * @param error 错误对象
   * @param attempt 当前尝试次数
   */
  private shouldRetry(error: Error, attempt: number): boolean {
    // 网络错误、超时错误、5xx服务器错误才重试
    const isNetworkError = error.name === 'TypeError' || error.message.includes('fetch');
    const isTimeoutError = error.name === 'AbortError';
    const isServerError = error.message.includes('HTTP 5');
    
    return (isNetworkError || isTimeoutError || isServerError) && attempt > 0;
  }

  /**
   * 带重试的请求执行
   * @param url 请求地址
   * @param options 请求选项
   * @returns Promise<ApiResponse>
   */
  private async requestWithRetry<T>(url: string, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    const {
      retry = true,
      retryTimes = requestConfig.retryTimes,
      retryDelay = requestConfig.retryDelay,
      ...requestOptions
    } = options;

    let lastError: Error;
    let attempt = retry ? retryTimes : 0;

    while (attempt >= 0) {
      try {
        return await this.executeRequest<T>(url, requestOptions);
      } catch (error) {
        lastError = error as Error;
        
        if (!this.shouldRetry(lastError, attempt)) {
          break;
        }

        if (attempt > 0) {
          await this.sleep(retryDelay);
        }
        
        attempt--;
      }
    }

    // 执行错误拦截器
    const processedError = await this.executeErrorInterceptors(lastError!);
    throw processedError;
  }

  /**
   * 发送请求（核心实现）
   * @param url 请求地址
   * @param options 请求选项
   * @returns Promise<ApiResponse>
   */
  private async executeRequest<T>(url: string, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    // 检查是否在登出状态，如果是则直接抛出错误
    if (this.isLoggingOut) {
      throw new Error('用户正在登出，取消请求');
    }

    const {
      method = 'GET',
      headers = {},
      body
    } = options;

    const fullUrl = url.startsWith('http') ? url : `${this.baseURL}${url}`;

    // 为请求生成唯一ID
    const requestId = `${method}_${fullUrl}_${Date.now()}_${Math.random()}`;

    const requestHeaders = {
      ...this.defaultHeaders,
      ...headers
    };
    let serializedBody: string | undefined;
    let binaryBodyBase64: string | undefined;

    if (body && method !== 'GET') {
      if (isFormDataBody(body)) {
        delete requestHeaders['Content-Type'];
        const formPayload = await serializeFormData(body);
        requestHeaders['Content-Type'] = formPayload.contentType;
        binaryBodyBase64 = formPayload.base64;
      } else if (isBlobBody(body)) {
        delete requestHeaders['Content-Type'];
        binaryBodyBase64 = await blobToBase64(body);
        if (body.type) {
          requestHeaders['Content-Type'] = body.type;
        }
      } else if (body instanceof URLSearchParams) {
        serializedBody = body.toString();
        requestHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
      } else if (typeof body === 'string') {
        serializedBody = body;
      } else {
        serializedBody = JSON.stringify(body);
      }
    }

    const normalizedOptions: InternalRequestOptions = {
      ...options,
      method,
      headers: requestHeaders,
      body,
      serializedBody,
      binaryBodyBase64,
      forceStreaming: options.forceStreaming === true
    };

    if (!this.supportsRustBridge()) {
      throw new Error('当前环境不支持 Rust HTTP 客户端，请在桌面端运行');
    }

    const rustReady = await ensureRustBridgeReady(store.state.token);
    if (!rustReady) {
      throw new Error('Rust HTTP 客户端初始化失败');
    }

    return this.executeRustRequest<T>(requestId, url, fullUrl, normalizedOptions, { ...requestHeaders });
  }

  private async executeRustRequest<T>(
    requestId: string,
    originalUrl: string,
    fullUrl: string,
    options: InternalRequestOptions,
    headers: Record<string, string>
  ): Promise<ApiResponse<T>> {
    const method = (options.method || 'GET').toUpperCase() as HttpRequestParams['method'];
    const timeout = options.timeout ?? requestConfig.timeout;
    const retryCount = options.retryTimes ?? requestConfig.retryTimes;
    const path = originalUrl.startsWith('http') ? originalUrl : originalUrl;


    const response = await rustHttp.requestRaw<T>({
      path,
      method,
      body: options.serializedBody,
      binaryBody: options.binaryBodyBase64,
      headers,
      timeout,
      retryCount,
      responseType: options.responseType,
      injectToken: options.injectToken !== false,
      forceStreaming: options.forceStreaming === true
    });

    // 对于 401 错误，需要区分是登录接口还是需要认证的接口
    // 登录接口返回 401 时，应该直接返回错误消息，而不是触发登出流程
    if (response.code === 401) {
      // 检查是否是登录相关的接口（白名单接口）
      const isLoginApi = !checkApiNeedsToken(originalUrl);
      if (isLoginApi) {
        // 登录接口返回 401，直接返回响应，让调用方处理错误消息
        return this.executeResponseInterceptors<T>(response);
      } else {
        // 需要认证的接口返回 401，触发登出流程
        this.handleUnauthorizedResponse(requestId, fullUrl, method, headers, response.message);
      }
    }

    return this.executeResponseInterceptors<T>(response);
  }

  private handleUnauthorizedResponse(
    requestId: string,
    fullUrl: string,
    method: string,
    requestHeaders: Record<string, string>,
    responseMessage?: string
  ): never {
    const authorizationHeader = requestHeaders['Authorization'] || '';
    const handle401Id = `401_${Date.now()}`;
    

    // 登录后 60 秒宽容期，避免登录过程中的 401 导致自动登出
    const isInLoginGracePeriod = this.lastLoginTime && (Date.now() - this.lastLoginTime) < 60000;
    
    if (isInLoginGracePeriod) {
      throw new Error('登录验证中，请稍后重试');
    }

    if (!store.getters.isLoggedIn || !store.state.token) {
      this.setLoggingOut(false);
      try {
        store.dispatch('hideGlobalLoading');
      } catch (dispatchError) {
      }
      throw new Error('未登录，无需重复登出');
    }

    if (!this.isLoggingOut) {
      this.setLoggingOut(true);

      setTimeout(() => {
        if (store.getters.isLoggedIn && store.state.token) {
          store.dispatch('logout');
          if (typeof window !== 'undefined' && window.location.pathname !== '/login') {
            window.location.href = '/login';
          }
        } else {
          this.setLoggingOut(false);
        }
      }, 3000);
    } else {
    }

    throw new Error('身份验证失效，请重新登录');
  }

  /**
   * 发送请求（公共接口）
   * @param url 请求地址
   * @param options 请求选项
   * @returns Promise<ApiResponse>
   */
  private async request<T>(url: string, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    // 执行请求拦截器
    const config = await this.executeRequestInterceptors({ url, ...options });
    
    // 使用处理后的配置发送请求
    return this.requestWithRetry<T>(config.url, config);
  }

  /**
   * GET 请求
   * @param url 请求地址
   * @param params 查询参数
   * @returns Promise<ApiResponse>
   */
  async get<T>(url: string, params?: Record<string, any>): Promise<ApiResponse<T>> {
    let fullUrl = url;
    if (params) {
      const searchParams = new URLSearchParams();
      Object.keys(params).forEach(key => {
        if (params[key] !== undefined && params[key] !== null) {
          searchParams.append(key, String(params[key]));
        }
      });
      fullUrl += `?${searchParams.toString()}`;
    }

    return this.request<T>(fullUrl, { method: 'GET' });
  }

  /**
   * POST 请求
   * @param url 请求地址
   * @param data 请求数据
   * @param options 请求配置
   * @returns Promise<ApiResponse>
   */
  async post<T>(url: string, data?: any, options?: Partial<RequestOptions>): Promise<ApiResponse<T>> {
    return this.request<T>(url, {
      method: 'POST',
      body: data,
      ...options
    });
  }

  /**
   * PUT 请求
   * @param url 请求地址
   * @param data 请求数据
   * @returns Promise<ApiResponse>
   */
  async put<T>(url: string, data?: any): Promise<ApiResponse<T>> {
    return this.request<T>(url, {
      method: 'PUT',
      body: data
    });
  }

  /**
   * PATCH 请求
   * @param url 请求地址
   * @param data 请求数据
   * @returns Promise<ApiResponse>
   */
  async patch<T>(url: string, data?: any): Promise<ApiResponse<T>> {
    return this.request<T>(url, {
      method: 'PATCH',
      body: data
    });
  }

  /**
   * DELETE 请求
   * @param url 请求地址
   * @returns Promise<ApiResponse>
   */
  async delete<T>(url: string): Promise<ApiResponse<T>> {
    return this.request<T>(url, { method: 'DELETE' });
  }

  /**
   * 文件上传
   * @param url 上传地址
   * @param file 文件对象
   * @param additionalData 额外数据
   * @returns Promise<ApiResponse>
   */
  async upload<T>(url: string, file: File, additionalData?: Record<string, any>): Promise<ApiResponse<T>> {
    const formData = new FormData();
    // 使用 fileName 作为字段名，与 bear-chat-uniapp 保持一致
    formData.append('fileName', file);

    if (additionalData) {
      Object.keys(additionalData).forEach(key => {
        formData.append(key, String(additionalData[key]));
      });
    }

    return this.request<T>(url, {
      method: 'POST',
      body: formData
    });
  }
}

// 创建 HTTP 客户端实例
export const httpClient = new HttpClient(apiConfig.API_BASE_URL);

// 定义不需要 token 的接口白名单（参考 bear-chat-uniapp 项目）
const noTokenApis = [
  '/auth/login',
  '/auth/login/sms',
  '/auth/register',
  '/auth/sms/send',
  '/settings/privacy-policy',
  '/healthz',
  '/ws'
];

/**
 * 检查接口是否需要携带 token
 * @param url 请求地址
 * @returns true: 需要token, false: 不需要token
 */
const checkApiNeedsToken = (url: string): boolean => {
  for (const whiteApi of noTokenApis) {
    if (url.indexOf(whiteApi) !== -1) {
      return false;
    }
  }
  return true;
};

// 添加默认请求拦截器 - 添加时间戳、请求ID和 token
httpClient.addRequestInterceptor((config) => {
  const requestId = Date.now().toString(36) + Math.random().toString(36).substr(2);

  const headers: Record<string, string> = {
    ...config.headers,
    'X-Request-ID': requestId,
    'X-Timestamp': Date.now().toString()
  };

  // 检查是否需要添加 token（除了白名单接口）
  if (checkApiNeedsToken(config.url)) {
    const token = store.state.token;
    const isLoggedIn = store.getters.isLoggedIn;


    if (token) {
      headers['Authorization'] = `Bearer ${token}`;

      // 如果状态不同步，给出警告但不阻止请求
      if (!isLoggedIn) {
      }
    } else {
      // 对于需要token但没有token的请求，直接拒绝
      throw new Error('未登录或登录已过期，请重新登录');
    }
  } else {
  }

  return {
    ...config,
    headers
  };
});

// 添加默认响应拦截器 - 根据code字段添加success字段
httpClient.addResponseInterceptor((response) => {
  if (response.success) {
  } else {
  }

  return response;
});

// 添加默认错误拦截器 - 统一错误处理
httpClient.addErrorInterceptor((error) => {
  // 根据错误类型进行分类处理
  if (error.name === 'AbortError') {
    // 如果是登出程序中的取消，不要显示超时错误
    if (error.message.includes('登出中')) {
      return error;
    }
    return new Error('请求超时，请稍后重试');
  }

  // 移除HTTP 401的重复处理，因为在executeRequest中已经处理
  // if (error.message.includes('HTTP 401')) {
  //   已在executeRequest中处理
  // }

  if (error.message.includes('HTTP 403')) {
    // 区分不同场景的403错误
    if (error.message.includes('/auth/login')) {
      // 登录接口返回403，说明账号被封禁
      return new Error('账号已被封禁，无法登录');
    }
    return new Error('权限不足，无法访问该资源');
  }

  if (error.message.includes('HTTP 5')) {
    return new Error('服务器错误，请稍后重试');
  }

  if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
    return new Error('网络连接失败，请检查网络连接');
  }

  // 默认错误处理
  return error;
});

// 导出便捷方法
export const get = <T>(url: string, params?: Record<string, any>) => httpClient.get<T>(url, params);
export const post = <T>(url: string, data?: any, options?: Partial<RequestOptions>) => httpClient.post<T>(url, data, options);
export const put = <T>(url: string, data?: any) => httpClient.put<T>(url, data);
export const patch = <T>(url: string, data?: any) => httpClient.patch<T>(url, data);
export const del = <T>(url: string) => httpClient.delete<T>(url);
export const upload = <T>(url: string, file: File, additionalData?: Record<string, any>) => httpClient.upload<T>(url, file, additionalData);

// 导出拦截器管理函数
export const addRequestInterceptor = httpClient.addRequestInterceptor.bind(httpClient);
export const addResponseInterceptor = httpClient.addResponseInterceptor.bind(httpClient);
export const addErrorInterceptor = httpClient.addErrorInterceptor.bind(httpClient);
export const clearInterceptors = httpClient.clearInterceptors.bind(httpClient);

// 导出请求状态管理函数
export const cancelAllPendingRequests = httpClient.cancelAllPendingRequests.bind(httpClient);
export const setLoggingOut = httpClient.setLoggingOut.bind(httpClient);

// 导出登录时间管理函数
export const setLoginTime = (time?: number) => {
  (httpClient as any).lastLoginTime = time || Date.now();
};
export const clearLoginTime = () => {
  (httpClient as any).lastLoginTime = null;
};
