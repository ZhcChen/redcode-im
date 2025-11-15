/**
 * Rust HTTP 客户端 TypeScript 适配层
 * 提供统一的接口，支持双轨运行（Rust + TypeScript）
 */

import { invoke } from '@tauri-apps/api/core'
import { arrayBufferToBase64, blobToBase64, uint8ArrayToBase64 } from '../utils/binary'
import type { ApiResponse } from './http.types'

// 配置接口
interface RustHttpConfig {
  baseUrl: string
  timeout?: number
  maxRetries?: number
  retryDelay?: number
  connectionPool?: {
    maxConnections?: number
    maxIdleConnections?: number
    idleTimeout?: number
  }
}

// 请求参数接口
export interface HttpRequestParams {
  path: string
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD' | 'OPTIONS'
  body?: any
  headers?: Record<string, string>
  queryParams?: Record<string, string>
  timeout?: number
  retryCount?: number
  binaryBody?: ArrayBuffer | ArrayBufferView | Blob | string
  responseType?: 'json' | 'binary'
  injectToken?: boolean
  forceStreaming?: boolean
}

// 响应数据接口
interface HttpResponseData {
  success: boolean
  code: number
  message: string
  data: any
}

// 错误类型
interface RustHttpError {
  code: number
  message: string
  errorType: string
}

const resolveFlag = (value: string | undefined, fallback: boolean) => {
  if (value === undefined || value === '') {
    return fallback
  }
  return value === 'true'
}

// 功能开关
const FEATURE_FLAGS = {
  USE_RUST_BACKEND: resolveFlag(import.meta.env.VITE_USE_RUST_BACKEND, true),
  RUST_FILE_UPLOAD: resolveFlag(import.meta.env.VITE_RUST_FILE_UPLOAD, true),
  RUST_BATCH_REQUESTS: resolveFlag(import.meta.env.VITE_RUST_BATCH_REQUESTS, true),
  RUST_CONNECTION_POOL: resolveFlag(import.meta.env.VITE_RUST_CONNECTION_POOL, true),
}

// 检查是否启用 Rust 后端
const isRustEnabled = (feature: keyof typeof FEATURE_FLAGS): boolean => {
  return FEATURE_FLAGS[feature] && FEATURE_FLAGS.USE_RUST_BACKEND
}

/**
 * Rust HTTP 客户端主类
 */
class RustHttpClient {
  private isInitialized = false
  private config: RustHttpConfig = {
    baseUrl: import.meta.env.VITE_API_BASE_URL || 'http://192.168.31.80:8010',
    timeout: 30000,
    maxRetries: 3,
    retryDelay: 1000,
    connectionPool: {
      maxConnections: 100,
      maxIdleConnections: 20,
      idleTimeout: 300,
    }
  }

  /**
   * 初始化 HTTP 客户端
   */
  async initialize(token?: string): Promise<void> {
    try {

      await invoke('http_initialize', {
        baseUrl: this.config.baseUrl,
        token
      })

      this.isInitialized = true
    } catch (error) {
      throw new Error(`HTTP client initialization failed: ${error}`)
    }
  }

  /**
   * 检查客户端健康状态
   */
  async healthCheck(): Promise<boolean> {
    if (!this.isInitialized) return false

    try {
      const result = await invoke<string>('http_health')
      const data: HttpResponseData = JSON.parse(result)
      return data.success
    } catch (error) {
      return false
    }
  }

  /**
   * 获取客户端统计信息
   */
  async getStats(): Promise<any> {
    if (!this.isInitialized) return null

    try {
      const result = await invoke<string>('http_stats')
      const data: HttpResponseData = JSON.parse(result)
      return data.data
    } catch (error) {
      return null
    }
  }

  /**
   * 设置认证 token
   */
  async setToken(token: string): Promise<void> {
    if (!this.isInitialized) {
      await this.initialize()
    }
    await invoke('http_set_token', { token })
  }

  /**
   * 清除认证 token
   */
  async clearToken(): Promise<void> {
    if (!this.isInitialized) return
    await invoke('http_clear_token')
  }

  private async encodeBinaryBody(input?: ArrayBuffer | ArrayBufferView | Blob | string): Promise<string | undefined> {
    if (!input) {
      return undefined
    }
    if (typeof input === 'string') {
      return input
    }
    if (input instanceof Blob) {
      return await blobToBase64(input)
    }
    if (input instanceof ArrayBuffer) {
      return arrayBufferToBase64(input)
    }
    if (ArrayBuffer.isView(input)) {
      const view = new Uint8Array(
        input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength)
      )
      return uint8ArrayToBase64(view)
    }
    throw new Error('不支持的二进制请求体类型')
  }

  /**
   * 通用请求方法
   */
  private async request<T = any>(params: HttpRequestParams): Promise<ApiResponse<T>> {
    if (!this.isInitialized) {
      await this.initialize()
    }

    const {
      path,
      method = 'GET',
      body,
      headers,
      queryParams,
      timeout,
      retryCount,
      binaryBody,
      responseType
    } = params
    const methodUpper = method.toUpperCase()

    try {
      const bodyStr =
        typeof body === 'string'
          ? body
          : body !== undefined && body !== null
            ? JSON.stringify(body)
            : null
      const binaryBodyEncoded = await this.encodeBinaryBody(binaryBody)


      try {
        await invoke('client_debug', {
          payload: {
            tag: 'requestRawArgs',
            method: methodUpper,
            path,
            hasBinaryBody: Boolean(binaryBodyEncoded),
            injectToken: params.injectToken !== false,
            forceStreaming: params.forceStreaming === true,
            bodyLength: bodyStr ? bodyStr.length : 0,
            binaryLength: binaryBodyEncoded ? binaryBodyEncoded.length : 0
          }
        })
      } catch (debugError) {
      }

      const args = {
        method: methodUpper,
        path,
        body: bodyStr,
        binaryBody: binaryBodyEncoded,
        headers,
        queryParams: queryParams ?? null,
        timeout,
        retryCount,
        expectBinary: responseType === 'binary',
        injectToken: params.injectToken !== false,
        forceStreaming: params.forceStreaming === true
      }

      try {
        await invoke('client_debug', { payload: { tag: 'requestRawArgsFull', args } })
      } catch (debugError) {
      }

      const emitDebug = async (msg: string, data: any) => {
        try {
          await invoke('client_debug', { payload: { tag: 'JSLOG', message: msg, data } })
        } catch {}
      }

      await emitDebug('[RustHTTP] 🔵 开始调用 Tauri invoke...', { method: methodUpper, path });
      const result = await invoke<string>('http_request', args)
      await emitDebug('[RustHTTP] 📥 Raw result from Rust', { result: result.substring(0, 500) });

      let response: HttpResponseData
      try {
        response = JSON.parse(result)
        await emitDebug('[RustHTTP] ✅ JSON.parse 成功', {});
      } catch (parseError) {
        await emitDebug('[RustHTTP] ❌ JSON.parse 失败', { error: String(parseError) });
        throw parseError;
      }
      return {
        code: response.code,
        message: response.message,
        data: response.data,
        success: response.success
      }
    } catch (error: any) {
      return {
        code: error?.code || 500,
        message: error?.message || '请求失败',
        data: null,
        success: false
      }
    }
  }

  // 便捷方法
  async get<T = any>(path: string, params?: Record<string, any>): Promise<ApiResponse<T>> {
    return this.request<T>({
      path,
      method: 'GET',
      queryParams: params
    })
  }

  async post<T = any>(path: string, body?: any): Promise<ApiResponse<T>> {
    return this.request<T>({
      path,
      method: 'POST',
      body
    })
  }

  async put<T = any>(path: string, body?: any): Promise<ApiResponse<T>> {
    return this.request<T>({
      path,
      method: 'PUT',
      body
    })
  }

  async patch<T = any>(path: string, body?: any): Promise<ApiResponse<T>> {
    return this.request<T>({
      path,
      method: 'PATCH',
      body
    })
  }

  async delete<T = any>(path: string): Promise<ApiResponse<T>> {
    return this.request<T>({
      path,
      method: 'DELETE'
    })
  }

  /**
   * 批量请求
   */
  async batch<T = any>(requests: HttpRequestParams[]): Promise<ApiResponse<T[]>> {
    if (!isRustEnabled('RUST_BATCH_REQUESTS')) {
      return {
        code: 501,
        message: '批量请求功能未启用',
        data: [],
        success: false
      }
    }

    try {
      const batchRequest = requests.map(req => ({
        method: req.method || 'GET',
        path: req.path,
        body: req.body ? JSON.stringify(req.body) : null,
        headers: req.headers,
        queryParams: req.queryParams,
        timeout: req.timeout,
        retryCount: req.retryCount
      }))

      const result = await invoke<string>('http_batch', {
        requests: batchRequest
      })

      const response: HttpResponseData = JSON.parse(result)
      return {
        code: response.code,
        message: response.message,
        data: response.data?.results || [],
        success: response.success
      }
    } catch (error: any) {
      return {
        code: 500,
        message: error?.message || '批量请求失败',
        data: [],
        success: false
      }
    }
  }

  /**
   * 文件上传（支持大文件）
   */
  async upload<T = any>(path: string, file: File | string): Promise<ApiResponse<T>> {
    if (!isRustEnabled('RUST_FILE_UPLOAD')) {
      throw new Error('Rust 文件上传功能未启用，请开启 VITE_RUST_FILE_UPLOAD')
    }

    if (!this.isInitialized) {
      await this.initialize()
    }

    try {
      let filePath: string
      let contentType: string | undefined

      if (typeof file === 'string') {
        // 如果是路径（已在 Rust 端）
        filePath = file
        contentType = 'application/octet-stream'
      } else {
        throw new Error('Rust 上传目前仅支持传入已保存的文件路径')
      }

      // 调用 Rust 上传（文件路径方式）
      const result = await invoke<string>('http_upload', {
        path,
        filePath,
        contentType
      })

      const response: HttpResponseData = JSON.parse(result)
      return {
        code: response.code,
        message: response.message,
        data: response.data,
        success: response.success
      }
    } catch (error: any) {
      return {
        code: 500,
        message: error?.message || '文件上传失败',
        data: null,
        success: false
      }
    }
  }

  /**
   * 文件下载
   */
  async download(url: string, filename: string): Promise<{ success: boolean, message: string, path?: string }> {
    if (!this.isInitialized) {
      await this.initialize()
    }

    try {
      // 调用 Rust 下载（让 Rust 端处理文件保存路径）
      const result = await invoke<string>('http_download', {
        url,
        filename
      })

      const response: HttpResponseData = JSON.parse(result)
      return {
        success: response.success,
        message: response.message,
        path: response.data?.path
      }
    } catch (error: any) {
      return {
        success: false,
        message: error?.message || '文件下载失败'
      }
    }
  }

  async requestRaw<T = any>(params: HttpRequestParams): Promise<ApiResponse<T>> {
    return this.request<T>(params)
  }
}

// 创建全局实例
export const rustHttp = new RustHttpClient()

// 导出便捷方法
export const {
  get,
  post,
  put,
  patch,
  delete: del,
  upload,
  download,
  batch,
  setToken,
  clearToken,
  healthCheck,
  getStats,
  requestRaw
} = rustHttp

// 导出类型
export type {
  HttpResponseData,
  RustHttpConfig,
  RustHttpError
}

// 导出功能检查函数
export { isRustEnabled, FEATURE_FLAGS }

// 导出适配器类
export { RustHttpClient }
