/**
 * HTTP 请求工具类
 * 基于 fetch API 封装，提供统一的请求接口
 */

import { apiConfig, requestConfig } from './config';

/**
 * HTTP 响应接口
 */
export interface ApiResponse<T = any> {
  code: number;
  message: string;
  data: T;
  success: boolean;
}

/**
 * 请求参数接口
 */
export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
  retry?: boolean; // 是否启用重试
  retryTimes?: number; // 重试次数
  retryDelay?: number; // 重试延迟
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
    console.warn('setAuthToken 方法已废弃，系统会自动从 store 中获取 token');
  }

  /**
   * 移除认证 token
   * @deprecated 不再需要手动移除 token，登出时清除 store 中的 token 即可
   */
  removeAuthToken() {
    console.warn('removeAuthToken 方法已废弃，登出时清除 store 中的 token 即可');
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
    console.log('取消所有pending请求，数量:', this.pendingRequests.size);
    this.pendingRequests.forEach((controller, requestId) => {
      try {
        controller.abort();
        console.log('已取消请求:', requestId);
      } catch (error) {
        console.warn('取消请求失败:', requestId, error);
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
          console.warn(`请求失败，${retryDelay}ms后进行第${retryTimes - attempt + 1}次重试:`, lastError.message);
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
      body,
      timeout = requestConfig.timeout
    } = options;

    const fullUrl = url.startsWith('http') ? url : `${this.baseURL}${url}`;

    // 为请求生成唯一ID
    const requestId = `${method}_${fullUrl}_${Date.now()}_${Math.random()}`;

    const requestHeaders = {
      ...this.defaultHeaders,
      ...headers
    };

    const requestOptions: RequestInit = {
      method,
      headers: requestHeaders
    };

    // 处理请求体
    if (body && method !== 'GET') {
      if (body instanceof FormData) {
        // FormData 不需要设置 Content-Type，浏览器会自动设置
        delete requestHeaders['Content-Type'];
        requestOptions.body = body;
      } else {
        requestOptions.body = JSON.stringify(body);
      }
    }

    try {
      // 创建超时和abort控制器
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      // 将请求控制器添加到pending请求列表
      this.pendingRequests.set(requestId, controller);

      requestOptions.signal = controller.signal;

      const response = await fetch(fullUrl, requestOptions);
      clearTimeout(timeoutId);

      // 请求成功，从 pending 列表中移除
      this.pendingRequests.delete(requestId);

      // 处理 HTTP 状态码
      if (response.status === 401) {
        // 401 认证失败的特殊处理 - 防止重复登出
        console.error(`🚫 [${requestId}] 401认证失败:`, {
          url: fullUrl,
          method,
          hasToken: !!requestHeaders['TOKEN_IM'],
          tokenPreview: requestHeaders['TOKEN_IM'] ? `${requestHeaders['TOKEN_IM'].substring(0, 10)}...` : '无token',
          isLoggingOut: this.isLoggingOut,
          storeToken: store.state.token ? `${store.state.token.substring(0, 10)}...` : '无token',
          isLoggedIn: store.getters.isLoggedIn,
          currentPath: window.location.pathname,
          lastLoginTime: this.lastLoginTime,
          timeSinceLogin: this.lastLoginTime ? Date.now() - this.lastLoginTime : 'unknown'
        });

        // 检查是否在登录后的宽容期内（30秒）
        const isInLoginGracePeriod = this.lastLoginTime && (Date.now() - this.lastLoginTime) < 30000;

        // 检查是否在登录页面或刚完成登录
        const isLoginRelated = window.location.pathname === '/login' ||
                               window.location.pathname === '/home' ||
                               isInLoginGracePeriod;

        if (isLoginRelated && isInLoginGracePeriod) {
          console.warn(`⚠️ [${requestId}] 登录后宽容期内的401错误，跳过自动登出处理`);
          throw new Error('登录验证中，请稍后重试');
        }

        if (!this.isLoggingOut) {
          console.error('🚫 认证失败，准备自动登出');
          this.setLoggingOut(true);

          // 增加延迟时间，给用户操作留更多时间
          setTimeout(() => {
            // 再次检查登录状态，避免误操作
            if (store.getters.isLoggedIn && store.state.token) {
              console.log("===============最终确认：身份验证失效，执行自动登出===========");
              store.dispatch('logout');
              if (window.location.pathname !== '/login') {
                window.location.href = '/login';
              }
            } else {
              console.log("用户已手动登出，取消自动登出操作");
              this.setLoggingOut(false);
            }
          }, 3000); // 增加到3秒，给更多反应时间
        } else {
          console.log(`[${requestId}] 已在登出状态，跳过重复401处理`);
        }
        throw new Error('身份验证失效，请重新登录');
      }

      if (!response.ok) {
        throw new Error(`HTTP Error: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();

      // 执行响应拦截器
      return await this.executeResponseInterceptors<T>(result);
    } catch (error) {
      // 请求失败，从 pending 列表中移除
      this.pendingRequests.delete(requestId);

      // 如果是取消操作且正在登出，不记录错误
      if (error instanceof Error && error.name === 'AbortError' && this.isLoggingOut) {
        throw new Error('请求已取消（登出中）');
      }

      console.error('Request failed:', error);
      throw error;
    }
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

// 导入 store 来获取 token
import { store } from '../store';

// 创建 HTTP 客户端实例
export const httpClient = new HttpClient(apiConfig.BASE_API);

// 定义不需要 token 的接口白名单（参考 bear-chat-uniapp 项目）
const noTokenApis = [
  "login",
  "checkMobile", 
  "sendSmsCode",
  "getShareMsgDetail",
  "getAppConfig",
  "senMobileSMS",
  "updateUserInfoKeepAlive",
  "txByToken",
  "authlogin",
  "register",  // 注册接口也不需要 token
  "auth/sms/send",  // 发送验证码
  "auth/login/sms"  // 验证码登录
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
  console.log(`[${requestId}] 📤 发送请求:`, config.method || 'GET', config.url);

  const headers: Record<string, string> = {
    ...config.headers,
    'X-Request-ID': requestId,
    'X-Timestamp': Date.now().toString()
  };

  // 检查是否需要添加 token（除了白名单接口）
  if (checkApiNeedsToken(config.url)) {
    const token = store.state.token;
    const isLoggedIn = store.getters.isLoggedIn;

    console.log(`[${requestId}] 🔑 Token检查:`, {
      hasToken: !!token,
      isLoggedIn,
      tokenPreview: token ? `${token.substring(0, 10)}...` : '无token',
      url: config.url
    });

    if (token) {
      // 只要有token就添加到请求头，不再检查isLoggedIn状态
      // 这样可以避免登录过程中的状态同步问题
      headers['TOKEN_IM'] = token;
      console.log(`[${requestId}] ✅ 已添加token到请求头`);

      // 如果状态不同步，给出警告但不阻止请求
      if (!isLoggedIn) {
        console.warn(`[${requestId}] ⚠️ 有token但登录状态未同步，这可能是登录过程中的正常现象`);
      }
    } else {
      console.warn(`[${requestId}] ⚠️ 接口需要token但token不存在:`, config.url);
      // 对于需要token但没有token的请求，直接拒绝
      throw new Error('未登录或登录已过期，请重新登录');
    }
  } else {
    console.log(`[${requestId}] 🏠 白名单接口，不需要token:`, config.url);
  }

  return {
    ...config,
    headers
  };
});

// 添加默认响应拦截器 - 根据code字段添加success字段
httpClient.addResponseInterceptor((response) => {
  // 根据 code 字段生成 success 字段
  const processedResponse = {
    ...response,
    success: response.code === 200
  };
  
  if (processedResponse.success) {
    console.log(`请求成功:`, processedResponse.code, processedResponse.message);
  } else {
    console.warn(`请求失败:`, processedResponse.code, processedResponse.message);
  }
  
  return processedResponse;
});

// 添加默认错误拦截器 - 统一错误处理
httpClient.addErrorInterceptor((error) => {
  // 根据错误类型进行分类处理
  if (error.name === 'AbortError') {
    // 如果是登出程序中的取消，不要显示超时错误
    if (error.message.includes('登出中')) {
      return error;
    }
    console.error('请求超时:', error.message);
    return new Error('请求超时，请稍后重试');
  }

  // 移除HTTP 401的重复处理，因为在executeRequest中已经处理
  // if (error.message.includes('HTTP 401')) {
  //   已在executeRequest中处理
  // }

  if (error.message.includes('HTTP 403')) {
    console.error('权限不足');
    return new Error('权限不足，无法访问该资源');
  }

  if (error.message.includes('HTTP 5')) {
    console.error('服务器错误:', error.message);
    return new Error('服务器错误，请稍后重试');
  }

  if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
    console.error('网络连接失败:', error.message);
    return new Error('网络连接失败，请检查网络连接');
  }

  // 默认错误处理
  console.error('请求异常:', error.message);
  return error;
});

// 导出便捷方法
export const get = httpClient.get.bind(httpClient);
export const post = httpClient.post.bind(httpClient);
export const put = httpClient.put.bind(httpClient);
export const del = httpClient.delete.bind(httpClient);
export const upload = httpClient.upload.bind(httpClient);

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
