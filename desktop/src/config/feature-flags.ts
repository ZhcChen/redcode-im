/**
 * 功能开关系统
 * 控制各个模块是否使用 Rust 后端
 */

const boolFlag = (value: string | undefined, defaultValue = false) => {
  if (value === undefined || value === '') {
    return defaultValue
  }
  return value === 'true'
}

// 基础配置
export const CONFIG = {
  // API 配置
  API_BASE_URL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8010',
  HTTP_TIMEOUT: parseInt(import.meta.env.VITE_HTTP_TIMEOUT || '30000'),
  HTTP_MAX_RETRIES: parseInt(import.meta.env.VITE_HTTP_MAX_RETRIES || '3'),
  HTTP_RETRY_DELAY: parseInt(import.meta.env.VITE_HTTP_RETRY_DELAY || '1000'),

  // 性能配置
  BATCH_SIZE: parseInt(import.meta.env.VITE_BATCH_SIZE || '10'),
  BATCH_CONCURRENCY: parseInt(import.meta.env.VITE_BATCH_CONCURRENCY || '5'),

  // 文件配置
  MAX_FILE_SIZE: parseInt(import.meta.env.VITE_MAX_FILE_SIZE || '10485760'),
  UPLOAD_CHUNK_SIZE: parseInt(import.meta.env.VITE_UPLOAD_CHUNK_SIZE || '1048576'),
  UPLOAD_CONCURRENCY: parseInt(import.meta.env.VITE_UPLOAD_CONCURRENCY || '3'),

  // 缓存配置
  ENABLE_CACHE: import.meta.env.VITE_ENABLE_CACHE === 'true',
  CACHE_TTL: parseInt(import.meta.env.VITE_CACHE_TTL || '300'),
  CACHE_MAX_SIZE: parseInt(import.meta.env.VITE_CACHE_MAX_SIZE || '1000'),

  // 调试配置
  ENABLE_DEBUG_LOG: import.meta.env.VITE_ENABLE_DEBUG_LOG === 'true',
  ENABLE_PERFORMANCE_MONITOR: import.meta.env.VITE_ENABLE_PERFORMANCE_MONITOR === 'true',
  ENABLE_MEMORY_PROFILING: import.meta.env.VITE_ENABLE_MEMORY_PROFILING === 'true',
}

// 功能开关
export const FEATURE_FLAGS = {
  // 基础开关
  USE_RUST_BACKEND: boolFlag(import.meta.env.VITE_USE_RUST_BACKEND, true),

  // 模块开关
  RUST_USER_API: boolFlag(import.meta.env.VITE_RUST_USER_API),
  RUST_SYSTEM_API: boolFlag(import.meta.env.VITE_RUST_SYSTEM_API),
  RUST_FILE_UPLOAD: boolFlag(import.meta.env.VITE_RUST_FILE_UPLOAD, true),
  RUST_MESSAGES: boolFlag(import.meta.env.VITE_RUST_MESSAGES),
  RUST_FRIENDS: boolFlag(import.meta.env.VITE_RUST_FRIENDS),
  RUST_GROUPS: boolFlag(import.meta.env.VITE_RUST_GROUPS),
  RUST_SEARCH: boolFlag(import.meta.env.VITE_RUST_SEARCH),
  RUST_ACCOUNT: boolFlag(import.meta.env.VITE_RUST_ACCOUNT),
  RUST_CHATGPT: boolFlag(import.meta.env.VITE_RUST_CHATGPT),
  RUST_FRIEND_CIRCLE: boolFlag(import.meta.env.VITE_RUST_FRIEND_CIRCLE),
  RUST_MUSIC: boolFlag(import.meta.env.VITE_RUST_MUSIC),
  RUST_VERSION: boolFlag(import.meta.env.VITE_RUST_VERSION),

  // 高级功能
  RUST_BATCH_REQUESTS: boolFlag(import.meta.env.VITE_RUST_BATCH_REQUESTS),
  RUST_CONNECTION_POOL: boolFlag(import.meta.env.VITE_RUST_CONNECTION_POOL),
  RUST_FILE_DOWNLOAD: boolFlag(import.meta.env.VITE_RUST_FILE_DOWNLOAD),
  RUST_PROXY: boolFlag(import.meta.env.VITE_RUST_PROXY),
  RUST_SSL_VERIFY: boolFlag(import.meta.env.VITE_RUST_SSL_VERIFY)
}

// 检查是否启用特定功能
export const isFeatureEnabled = (feature: keyof typeof FEATURE_FLAGS): boolean => {
  return FEATURE_FLAGS[feature] && FEATURE_FLAGS.USE_RUST_BACKEND
}

// 获取模块配置
export const getModuleConfig = (module: keyof typeof FEATURE_FLAGS) => {
  return {
    enabled: isFeatureEnabled(module),
    config: CONFIG,
    featureFlags: FEATURE_FLAGS
  }
}

// 打印当前配置
export const printCurrentConfig = () => {
  if (CONFIG.ENABLE_DEBUG_LOG) {
  }
}

// 开发模式检查
export const isDevelopment = import.meta.env.MODE === 'development'
export const isProduction = import.meta.env.MODE === 'production'

// 自动启用建议
export const getAutoEnableSuggestions = (): string[] => {
  const suggestions: string[] = []

  if (isDevelopment) {
    // 开发环境建议
    suggestions.push('开发环境建议启用 RUST_FILE_UPLOAD 以解决 CORS 问题')
    suggestions.push('开发环境建议启用 RUST_BATCH_REQUESTS 以提高性能')
  }

  if (isProduction) {
    // 生产环境建议
    suggestions.push('生产环境建议启用所有模块的 Rust 后端')
    suggestions.push('生产环境建议启用 RUST_SSL_VERIFY 确保安全')
  }

  return suggestions
}

// 验证配置
export const validateConfig = (): { valid: boolean; errors: string[] } => {
  const errors: string[] = []

  // 检查必要配置
  if (!CONFIG.API_BASE_URL) {
    errors.push('VITE_API_BASE_URL 未配置')
  }

  // 检查超时配置
  if (CONFIG.HTTP_TIMEOUT < 1000) {
    errors.push('VITE_HTTP_TIMEOUT 太小，建议 >= 1000')
  }

  // 检查重试配置
  if (CONFIG.HTTP_MAX_RETRIES > 10) {
    errors.push('VITE_HTTP_MAX_RETRIES 太大，建议 <= 10')
  }

  // 检查文件大小配置
  if (CONFIG.MAX_FILE_SIZE < 1024) {
    errors.push('VITE_MAX_FILE_SIZE 太小，建议 >= 1024')
  }

  return {
    valid: errors.length === 0,
    errors
  }
}

// 在控制台输出建议
export const printSuggestions = () => {
  const suggestions = getAutoEnableSuggestions()
  const validation = validateConfig()


  if (suggestions.length > 0) {
    suggestions.forEach(suggestion => {
    })
  }

  if (!validation.valid) {
    validation.errors.forEach(error => {
    })
  } else {
  }

}

// 初始化时自动打印配置
if (isDevelopment) {
  printCurrentConfig()
  printSuggestions()
}
