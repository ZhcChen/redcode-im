/**
 * 环境配置管理
 * 根据不同的环境加载相应的配置
 */

// 环境类型定义
export type Environment = 'development' | 'staging' | 'production'

// 环境配置接口
export interface EnvironmentConfig {
  // 基础配置
  env: Environment
  apiBaseUrl: string
  useRustBackend: boolean

  // 调试配置
  enableDebugLog: boolean
  enablePerformanceMonitor: boolean
  enableMemoryProfiling: boolean

  // 开发工具
  enableHotReload: boolean
  enableSourceMaps: boolean
  enableDevTools: boolean

  // 错误报告
  enableErrorReporting: boolean
  sentryDsn?: string

  // 性能配置
  httpTimeout: number
  httpMaxRetries: number
  httpRetryDelay: number
}

// 获取当前环境
export const getCurrentEnvironment = (): Environment => {
  const env = import.meta.env.VITE_ENV || import.meta.env.MODE || 'development'

  // 标准化环境名称
  switch (env) {
    case 'production':
    case 'prod':
      return 'production'
    case 'staging':
    case 'stage':
    case 'test':
      return 'staging'
    default:
      return 'development'
  }
}

// 获取 API 基础 URL
export const getApiBaseUrl = (): string => {
  const env = getCurrentEnvironment()
  const envUrl = import.meta.env.VITE_API_BASE_URL

  // 如果环境变量中有设置，优先使用
  if (envUrl) {
    return envUrl
  }

  // 否则使用默认配置
  switch (env) {
    case 'production':
      return 'https://api.chatlyme.com'
    case 'staging':
      return 'https://staging-api.chatlyme.com'
    default:
      return 'http://192.168.31.80:8010'
  }
}

// 获取环境配置
export const getEnvironmentConfig = (): EnvironmentConfig => {
  const env = getCurrentEnvironment()
  const baseConfig: EnvironmentConfig = {
    env,
    apiBaseUrl: getApiBaseUrl(),
    useRustBackend: import.meta.env.VITE_USE_RUST_BACKEND === 'true',

    // 调试配置
    enableDebugLog: import.meta.env.VITE_ENABLE_DEBUG_LOG === 'true',
    enablePerformanceMonitor: import.meta.env.VITE_ENABLE_PERFORMANCE_MONITOR === 'true',
    enableMemoryProfiling: import.meta.env.VITE_ENABLE_MEMORY_PROFILING === 'true',

    // 开发工具
    enableHotReload: import.meta.env.VITE_ENABLE_HOT_RELOAD === 'true',
    enableSourceMaps: import.meta.env.VITE_ENABLE_SOURCE_MAPS === 'true',
    enableDevTools: import.meta.env.VITE_ENABLE_DEV_TOOLS === 'true',

    // 错误报告
    enableErrorReporting: import.meta.env.VITE_ENABLE_ERROR_REPORTING === 'true',
    sentryDsn: import.meta.env.VITE_SENTRY_DSN,

    // 性能配置
    httpTimeout: parseInt(import.meta.env.VITE_HTTP_TIMEOUT || '30000'),
    httpMaxRetries: parseInt(import.meta.env.VITE_HTTP_MAX_RETRIES || '3'),
    httpRetryDelay: parseInt(import.meta.env.VITE_HTTP_RETRY_DELAY || '1000'),
  }

  // 根据环境应用默认值
  if (env === 'development') {
    // 开发环境默认配置
    baseConfig.enableDebugLog = baseConfig.enableDebugLog ?? true
    baseConfig.enablePerformanceMonitor = baseConfig.enablePerformanceMonitor ?? true
    baseConfig.enableHotReload = baseConfig.enableHotReload ?? true
    baseConfig.enableSourceMaps = baseConfig.enableSourceMaps ?? true
    baseConfig.enableDevTools = baseConfig.enableDevTools ?? true
    baseConfig.useRustBackend = baseConfig.useRustBackend ?? false
  } else if (env === 'staging') {
    // 测试环境默认配置
    baseConfig.enableDebugLog = baseConfig.enableDebugLog ?? true
    baseConfig.enablePerformanceMonitor = baseConfig.enablePerformanceMonitor ?? true
    baseConfig.enableSourceMaps = baseConfig.enableSourceMaps ?? true
    baseConfig.enableErrorReporting = baseConfig.enableErrorReporting ?? true
    baseConfig.useRustBackend = baseConfig.useRustBackend ?? true
  } else {
    // 生产环境默认配置
    baseConfig.enableDebugLog = baseConfig.enableDebugLog ?? false
    baseConfig.enablePerformanceMonitor = baseConfig.enablePerformanceMonitor ?? false
    baseConfig.enableHotReload = baseConfig.enableHotReload ?? false
    baseConfig.enableSourceMaps = baseConfig.enableSourceMaps ?? false
    baseConfig.enableDevTools = baseConfig.enableDevTools ?? false
    baseConfig.enableErrorReporting = baseConfig.enableErrorReporting ?? true
    baseConfig.useRustBackend = baseConfig.useRustBackend ?? true
  }

  return baseConfig
}

// 检查是否为开发环境
export const isDevelopment = (): boolean => {
  return getCurrentEnvironment() === 'development'
}

// 检查是否为测试环境
export const isStaging = (): boolean => {
  return getCurrentEnvironment() === 'staging'
}

// 检查是否为生产环境
export const isProduction = (): boolean => {
  return getCurrentEnvironment() === 'production'
}

// 调试日志
export const debugLog = (...args: any[]): void => {
  const config = getEnvironmentConfig()
  if (config.enableDebugLog) {
  }
}

// 性能日志
export const performanceLog = (label: string, startTime: number): void => {
  const config = getEnvironmentConfig()
  if (config.enablePerformanceMonitor) {
    const duration = performance.now() - startTime
  }
}

// 错误报告
export const reportError = (error: Error, context?: any): void => {
  const config = getEnvironmentConfig()

  // 总是在控制台输出错误

  // 如果启用了错误报告，发送到远程服务
  if (config.enableErrorReporting && config.sentryDsn) {
    // 这里可以集成 Sentry 或其他错误监控服务
    // 示例：Sentry.captureException(error, { extra: context })
  }
}

// 导出环境信息
export const getEnvironmentInfo = () => {
  const config = getEnvironmentConfig()
  return {
    environment: config.env,
    apiBaseUrl: config.apiBaseUrl,
    useRustBackend: config.useRustBackend,
    version: import.meta.env.VITE_APP_VERSION || '2.0.0',
    buildTime: import.meta.env.VITE_BUILD_TIME || new Date().toISOString(),
  }
}

// 在控制台输出环境信息（仅开发环境）
if (isDevelopment()) {
}
