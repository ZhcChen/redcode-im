/**
 * Rust HTTP 客户端 TypeScript 适配层
 * 提供统一的接口，支持双轨运行（Rust + TypeScript）
 */

import { invoke } from '@tauri-apps/api/core'
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

// 功能开关
const FEATURE_FLAGS = {
  USE_RUST_BACKEND: import.meta.env.VITE_USE_RUST_BACKEND === 'true',
  RUST_FILE_UPLOAD: import.meta.env.VITE_RUST_FILE_UPLOAD === 'true',
  RUST_BATCH_REQUESTS: import.meta.env.VITE_RUST_BATCH_REQUESTS === 'true',
  RUST_CONNECTION_POOL: import.meta.env.VITE_RUST_CONNECTION_POOL === 'true',
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
    baseUrl: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8010',
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
      console.log('🚀 初始化 Rust HTTP 客户端...')

      await invoke('http_initialize', {
        baseUrl: this.config.baseUrl,
        token
      })

      this.isInitialized = true
      console.log('✅ Rust HTTP 客户端初始化成功')
    } catch (error) {
      console.error('❌ Rust HTTP 客户端初始化失败:', error)
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
      console.warn('健康检查失败:', error)
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
      console.warn('获取统计信息失败:', error)
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
    console.log('🔑 Token 设置成功')
  }

  /**
   * 清除认证 token
   */
  async clearToken(): Promise<void> {
    if (!this.isInitialized) return
    await invoke('http_clear_token')
    console.log('🗑️ Token 清除成功')
  }

  /**
   * 通用请求方法
   */
  private async request<T = any>(params: HttpRequestParams): Promise<ApiResponse<T>> {
    if (!this.isInitialized) {
      await this.initialize()
    }

    const { path, method = 'GET', body, headers, queryParams, timeout, retryCount } = params
    const methodUpper = method.toUpperCase()

    try {
      let result: string

      switch (methodUpper) {
        case 'GET': {
          const queryString = queryParams
            ? '?' + new URLSearchParams(queryParams).toString()
            : ''
          result = await invoke('http_get', {
            path: path + queryString
          })
          break
        }

        case 'POST': {
          const bodyStr = typeof body === 'string' ? body : body ? JSON.stringify(body) : null
          result = await invoke('http_post', {
            path,
            body: bodyStr
          })
          break
        }

        case 'PUT': {
          const bodyStr = typeof body === 'string' ? body : body ? JSON.stringify(body) : null
          result = await invoke('http_put', {
            path,
            body: bodyStr
          })
          break
        }

        case 'PATCH': {
          const bodyStr = typeof body === 'string' ? body : body ? JSON.stringify(body) : null
          result = await invoke('http_patch', {
            path,
            body: bodyStr
          })
          break
        }

        case 'DELETE': {
          result = await invoke('http_delete', { path })
          break
        }

        default: {
          // 使用通用 request 方法
          const bodyStr = typeof body === 'string' ? body : body ? JSON.stringify(body) : null
          result = await invoke('http_request', {
            method: methodUpper,
            path,
            body: bodyStr,
            headers
          })
          break
        }
      }

      // 解析响应 JSON
      const response: HttpResponseData = JSON.parse(result)
      return {
        code: response.code,
        message: response.message,
        data: response.data,
        success: response.success
      }
    } catch (error: any) {
      console.error(`❌ HTTP 请求失败 [${method} ${path}]:`, error)
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
      console.warn('批量请求功能未启用')
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
      console.error('❌ 批量请求失败:', error)
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
      console.warn('Rust 文件上传功能未启用，使用 TypeScript 模式')
      // 回退到 TypeScript 实现
      return await this.uploadWithTs(path, file as File)
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
        // 如果是 File 对象，转换为 base64 传给 Rust
        const fileBuffer = await file.arrayBuffer()
        const base64 = btoa(String.fromCharCode(...new Uint8Array(fileBuffer)))

        // 调用 Rust 上传（传入 base64 编码的文件内容）
        const result = await invoke<string>('http_upload_base64', {
          path,
          fileData: base64,
          fileName: file.name,
          contentType: file.type
        })

        const response: HttpResponseData = JSON.parse(result)
        return {
          code: response.code,
          message: response.message,
          data: response.data,
          success: response.success
        }
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
      console.error('❌ 文件上传失败:', error)
      return {
        code: 500,
        message: error?.message || '文件上传失败',
        data: null,
        success: false
      }
    }
  }

  /**
   * TypeScript 模式文件上传（回退方案）
   */
  private async uploadWithTs<T = any>(path: string, file: File): Promise<ApiResponse<T>> {
    // 创建 FormData
    const formData = new FormData()
    formData.append('file', file)

    // 使用 fetch 上传
    const response = await fetch(`${this.config.baseUrl}${path}`, {
      method: 'POST',
      body: formData
    })

    if (!response.ok) {
      throw new Error(`Upload failed: ${response.status}`)
    }

    const data = await response.json()
    return {
      code: response.status,
      message: data.message || 'Upload successful',
      data: data.data || data,
      success: response.ok
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
      console.error('❌ 文件下载失败:', error)
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
