import axios from 'axios';
import type { AxiosRequestConfig, AxiosResponse } from 'axios';
import { Message, Modal } from '@arco-design/web-vue';
import { useUserStore } from '@/store';
import { getToken } from '@/utils/auth';

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
axios.interceptors.response.use(
  (response: AxiosResponse<HttpResponse>) => {
    const res = response.data;
    const hasCustomCode =
      res && Object.prototype.hasOwnProperty.call(res, 'code');

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
  (error) => {
    const message =
      error?.response?.data?.message ||
      error?.response?.data?.msg ||
      error.message ||
      'Request Error';

    // 只有在没有自定义错误处理时才显示通用错误消息
    const isCustomHandled = error?.config?.suppressGlobalErrorMessage;

    if (!isCustomHandled) {
      // 根据状态码显示不同的错误消息
      let displayMessage = message;
      if (error?.response?.status === 404) {
        displayMessage = '请求的资源不存在';
      } else if (error?.response?.status === 401) {
        displayMessage = '认证失败，请重新登录';
      } else if (error?.response?.status === 403) {
        displayMessage = '没有权限执行此操作';
      } else if (error?.response?.status === 500) {
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
