import axios from 'axios';
import type { AxiosRequestConfig, AxiosResponse } from 'axios';
import { Message, Modal } from '@arco-design/web-vue';
import { useUserStore } from '@/store';
import {
  getToken,
  getRefreshToken,
  setToken,
  setRefreshToken,
  clearToken,
} from '@/utils/auth';

export interface HttpResponse<T = unknown> {
  status?: number;
  msg?: string;
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
      res &&
      typeof res === 'object' &&
      Object.prototype.hasOwnProperty.call(res, 'code') &&
      typeof (res as { code?: unknown }).code === 'number';

    if (hasCustomCode && res.code !== 20000) {
      Message.error({
        content: res.msg || 'Error',
        duration: (5 * 1000) as number,
      });
      if (
        res.code &&
        [50008, 50012, 50014].includes(res.code) &&
        response.config.url !== '/api/user/info'
      ) {
        Modal.error({
          title: 'Confirm logout',
          content:
            'You have been logged out, you can cancel to stay on this page, or log in again',
          okText: 'Re-Login',
          async onOk() {
            const userStore = useUserStore();

            await userStore.logout();
            window.location.reload();
          },
        });
      }
      return Promise.reject(new Error(res.msg || 'Error'));
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
    const message =
      error?.response?.data?.message ||
      error?.response?.data?.msg ||
      error.message ||
      'Request Error';

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
                  throw new Error('刷新令牌响应异常');
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
      // 根据状态码显示不同的错误消息
      let displayMessage = message;
      if (status === 404) {
        displayMessage = '请求的资源不存在';
      } else if (status === 401) {
        displayMessage = '认证失败，请重新登录';
      } else if (status === 403) {
        displayMessage = '没有权限执行此操作';
      } else if (status === 500) {
        displayMessage = '服务器内部错误';
      }

      Message.error({
        content: displayMessage,
        duration: 5 * 1000,
      });
    }

    return Promise.reject(error);
  }
);
