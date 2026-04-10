import axios from 'axios';

const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || undefined,
});

export default http;

export function apiGet<T>(
  url: string,
  config?: Parameters<typeof http.get>[1]
) {
  return http.get<T>(url, config);
}

export function apiPost<T>(
  url: string,
  data?: unknown,
  config?: Parameters<typeof http.post>[2]
) {
  return http.post<T>(url, data, config);
}

export function apiPut<T>(
  url: string,
  data?: unknown,
  config?: Parameters<typeof http.put>[2]
) {
  return http.put<T>(url, data, config);
}

export function apiPatch<T>(
  url: string,
  data?: unknown,
  config?: Parameters<typeof http.patch>[2]
) {
  return http.patch<T>(url, data, config);
}

export function apiDelete<T>(
  url: string,
  config?: Parameters<typeof http.delete>[1]
) {
  return http.delete<T>(url, config);
}
