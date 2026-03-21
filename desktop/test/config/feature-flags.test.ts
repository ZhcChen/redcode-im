import { afterEach, describe, expect, it } from 'vitest'

import {
  CONFIG,
  FEATURE_FLAGS,
  getModuleConfig,
  validateConfig
} from '@/config/feature-flags'

describe('feature flags config', () => {
  const snapshot = {
    HTTP_TIMEOUT: CONFIG.HTTP_TIMEOUT,
    HTTP_MAX_RETRIES: CONFIG.HTTP_MAX_RETRIES,
    MAX_FILE_SIZE: CONFIG.MAX_FILE_SIZE
  }

  afterEach(() => {
    CONFIG.HTTP_TIMEOUT = snapshot.HTTP_TIMEOUT
    CONFIG.HTTP_MAX_RETRIES = snapshot.HTTP_MAX_RETRIES
    CONFIG.MAX_FILE_SIZE = snapshot.MAX_FILE_SIZE
  })

  it('returns validation errors for unsafe numeric config', () => {
    CONFIG.HTTP_TIMEOUT = 500
    CONFIG.HTTP_MAX_RETRIES = 11
    CONFIG.MAX_FILE_SIZE = 100

    const result = validateConfig()

    expect(result.valid).toBe(false)
    expect(result.errors).toEqual(
      expect.arrayContaining([
        'VITE_HTTP_TIMEOUT 太小，建议 >= 1000',
        'VITE_HTTP_MAX_RETRIES 太大，建议 <= 10',
        'VITE_MAX_FILE_SIZE 太小，建议 >= 1024'
      ])
    )
  })

  it('provides module config with global rust backend gate', () => {
    const moduleConfig = getModuleConfig('RUST_FILE_UPLOAD')

    expect(moduleConfig.featureFlags).toBe(FEATURE_FLAGS)
    expect(moduleConfig.config).toBe(CONFIG)
    expect(typeof moduleConfig.enabled).toBe('boolean')
  })
})
