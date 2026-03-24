export interface ApiResponse<T = any> {
  code: number;
  message: string;
  data: T | null;
  success: boolean;
}

export interface RequestOptions {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  headers?: Record<string, string>;
  body?: Record<string, unknown>;
  injectToken?: boolean;
}

const requireDesktopRuntime = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl;
};

export const request = <T>(path: string, options: RequestOptions = {}, queryParams?: Record<string, string>) => {
  return requireDesktopRuntime().rpc.invoke<ApiResponse<T>>("http.request", {
    method: options.method ?? "GET",
    path,
    headers: options.headers,
    body: options.body,
    query_params: queryParams,
    inject_token: options.injectToken
  });
};

export const get = <T>(path: string, params?: Record<string, string>) =>
  request<T>(path, { method: "GET" }, params);

export const post = <T>(path: string, data?: Record<string, unknown>, options: Partial<RequestOptions> = {}) =>
  request<T>(path, { ...options, method: "POST", body: data });

export const put = <T>(path: string, data?: Record<string, unknown>) =>
  request<T>(path, { method: "PUT", body: data });

export const patch = <T>(path: string, data?: Record<string, unknown>) =>
  request<T>(path, { method: "PATCH", body: data });

export const del = <T>(path: string) =>
  request<T>(path, { method: "DELETE" });
