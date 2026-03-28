import axios from 'axios';
import type { AxiosRequestConfig, AxiosResponse } from 'axios';
import { Message, Modal } from '@arco-design/web-vue';
import { getStoredLocale } from '@/locale';
import { useUserStore } from '@/store';
import {
  getToken,
  getRefreshToken,
  setToken,
  setRefreshToken,
  clearToken,
} from '@/utils/auth';
import {
  resolveApiMessage,
  resolveHttpErrorMessage,
  resolveMessageKey,
} from '@/utils/i18n';

export interface HttpResponse<T = unknown> {
  status?: number;
  msg?: string;
  message?: string;
  message_key?: string;
  message_params?: Record<string, unknown> | null;
  code?: number;
  data: T;
}

if (import.meta.env.VITE_API_BASE_URL) {
  axios.defaults.baseURL = import.meta.env.VITE_API_BASE_URL;
}

axios.interceptors.request.use(
  (config: AxiosRequestConfig) => {
    // let each request carry token
    // this example using the JWT token
    // Authorization is a custom headers key
    // please modify it according to the actual situation
    const token = getToken();
    if (token) {
      if (!config.headers) {
        config.headers = {};
      }
      config.headers.Authorization = `Bearer ${token}`;
    }
    if (!config.headers) {
      config.headers = {};
    }
    config.headers['Accept-Language'] = getStoredLocale();
    return config;
  },
  (error) => {
    // do something
    return Promise.reject(error);
  }
);
// add response interceptors
let isRefreshing = false;
let refreshPromise: Promise<void> | null = null;

axios.interceptors.response.use(
  (response: AxiosResponse<HttpResponse>) => {
    const res = response.data;
    const hasCustomCode =
      res && Object.prototype.hasOwnProperty.call(res, 'code');

    if (hasCustomCode && res.code !== 20000) {
      const displayMessage = resolveApiMessage(res, {
        fallbackKey: 'common.request_failed',
      });
      Message.error({
        content: displayMessage,
        duration: (5 * 1000) as number,
      });
      if (
        res.code &&
        [50008, 50012, 50014].includes(res.code) &&
        response.config.url !== '/api/user/info'
      ) {
        Modal.error({
          title:
            resolveMessageKey('common.session_expired.title') ?? 'Session expired',
          content:
            resolveMessageKey('common.session_expired.content') ??
            'Your session has expired. Please log in again.',
          okText:
            resolveMessageKey('common.session_expired.confirm') ?? 'Re-Login',
          async onOk() {
            const userStore = useUserStore();

            await userStore.logout();
            window.location.reload();
          },
        });
      }
      return Promise.reject(new Error(displayMessage));
    }

    if (!hasCustomCode) {
      return {
        data: res,
        code: 20000,
        msg: 'success',
        status: response.status,
      } as HttpResponse;
    }

    return res;
  },
  async (error) => {
    const status = error?.response?.status;

    // 处理 401：尝试使用刷新令牌无感续签
    if (status === 401) {
      const originalRequest = error.config || {};
      const refreshToken = getRefreshToken();

      // 登录接口本身或没有刷新令牌时，直接走原有逻辑
      if (!refreshToken || originalRequest.url === '/auth/admin/login') {
        // 清理本地 token 并提示
        clearToken();
      } else {
        try {
          if (!isRefreshing) {
            isRefreshing = true;
            refreshPromise = axios
              .post('/auth/admin/refresh', { refresh_token: refreshToken })
              .then((res) => {
                const body = res.data;
                if (body?.token) {
                  setToken(body.token);
                  setRefreshToken(body.refresh_token ?? refreshToken);
                } else {
                  clearToken();
                  throw new Error(
                    resolveMessageKey('auth.invalid_token') ?? 'Request failed'
                  );
                }
              })
              .finally(() => {
                isRefreshing = false;
              });
          }

          await refreshPromise;

          // 使用新的 token 重试原请求
          const newToken = getToken();
          if (newToken) {
            originalRequest.headers = originalRequest.headers || {};
            originalRequest.headers.Authorization = `Bearer ${newToken}`;
            originalRequest.suppressGlobalErrorMessage = true;
            return axios(originalRequest);
          }
        } catch (refreshError) {
          clearToken();
        }
      }
    }

    // 只有在没有自定义错误处理时才显示通用错误消息
    const isCustomHandled = error?.config?.suppressGlobalErrorMessage;

    if (!isCustomHandled) {
      Message.error({
        content: resolveHttpErrorMessage(error, {
          fallbackKey:
            status === 401 ? 'auth.unauthorized' : undefined,
        }),
        duration: 5 * 1000,
      });
    }

    return Promise.reject(error);
  }
);
