import type { AxiosResponse, InternalAxiosRequestConfig } from 'axios';
import { Message, Modal } from '@arco-design/web-vue';
import { useUserStore } from '@/store';
import http from '@/services/http';
import {
  clearAccessToken,
  getAccessToken,
  requestAccessTokenRefresh,
  shouldBypassAccessTokenRefresh,
} from '@/services/auth-runtime';

export interface HttpResponse<T = unknown> {
  status?: number;
  msg?: string;
  code?: number;
  data: T;
}

http.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = getAccessToken();
    if (token) {
      config.headers.set('Authorization', `Bearer ${token}`);
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Axios types response interceptors as shape-preserving, while this client intentionally unwraps payloads.
http.interceptors.response.use(
  ((response: AxiosResponse<HttpResponse>) => {
    const res = response.data;
    const hasCustomCode =
      res &&
      typeof res === 'object' &&
      Object.prototype.hasOwnProperty.call(res, 'code') &&
      typeof (res as { code?: unknown }).code === 'number';

    if (hasCustomCode && res.code !== 20000) {
      Message.error({
        content: res.msg || 'Error',
        duration: 5 * 1000,
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
  }) as never,
  async (error) => {
    const message =
      error?.response?.data?.message ||
      error?.response?.data?.msg ||
      error.message ||
      'Request Error';

    const status = error?.response?.status;

    if (status === 401) {
      const originalRequest = error.config || {};
      const shouldRetry = !shouldBypassAccessTokenRefresh(originalRequest.url);

      if (shouldRetry && (await requestAccessTokenRefresh())) {
        const newToken = getAccessToken();
        if (newToken) {
          originalRequest.headers = originalRequest.headers || {};
          originalRequest.headers.Authorization = `Bearer ${newToken}`;
          originalRequest.suppressGlobalErrorMessage = true;
          return http(originalRequest);
        }
      } else {
        clearAccessToken();
        try {
          const userStore = useUserStore();
          userStore.logoutCallBack();
        } catch (logoutError) {
          // ignore pinia availability errors
        }
      }
    }

    const isCustomHandled = error?.config?.suppressGlobalErrorMessage;

    if (!isCustomHandled) {
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
