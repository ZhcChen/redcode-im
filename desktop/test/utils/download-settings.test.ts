import { beforeEach, describe, expect, it, vi } from 'vitest'

const { invokeMock, cache } = vi.hoisted(() => ({
  invokeMock: vi.fn(),
  cache: new Map<string, unknown>()
}))

vi.mock('@tauri-apps/api/core', () => ({
  invoke: invokeMock
}))

vi.mock('@/utils/cache', () => ({
  loadCache: vi.fn(async (key: string) => {
    if (!cache.has(key)) {
      return null
    }
    return { data: cache.get(key), updatedAt: Date.now() }
  }),
  saveCache: vi.fn(async (key: string, value: unknown) => {
    cache.set(key, value)
  })
}))

import {
  getDownloadDir,
  getChatlyDownloadDir,
  setDownloadDir
} from '@/utils/download-settings'

describe('download settings', () => {
  beforeEach(() => {
    cache.clear()

    invokeMock.mockImplementation(async (command: string, args?: Record<string, any>) => {
      if (command === 'get_user_download_dir') {
        return '/Users/test/Downloads'
      }
      if (command === 'get_user_desktop_dir') {
        return '/Users/test/Desktop'
      }
      if (command === 'check_dir_exists') {
        const path = args?.path || ''
        return path === '/Users/test/Downloads/Chatly' || path === '/Users/test/custom'
      }
      if (command === 'create_dir') {
        return null
      }
      return null
    })
  })

  it('returns saved download dir when it still exists', async () => {
    await setDownloadDir('/Users/test/custom')

    const resolved = await getDownloadDir()

    expect(resolved).toBe('/Users/test/custom')
  })

  it('falls back to Chatly default dir when saved path no longer exists', async () => {
    await setDownloadDir('/Users/test/missing')

    const resolved = await getDownloadDir()

    expect(resolved).toBe('/Users/test/Desktop/Chatly')
  })

  it('returns Chatly download dir and creates it when needed', async () => {
    invokeMock.mockImplementation(async (command: string, args?: Record<string, any>) => {
      if (command === 'get_user_download_dir') {
        return '/Users/test/Downloads'
      }
      if (command === 'check_dir_exists') {
        const path = args?.path || ''
        return path === '/Users/test/Downloads'
      }
      if (command === 'create_dir') {
        return null
      }
      return null
    })

    const resolved = await getChatlyDownloadDir()

    expect(resolved).toBe('/Users/test/Downloads/Chatly')
    expect(invokeMock).toHaveBeenCalledWith('create_dir', {
      path: '/Users/test/Downloads/Chatly',
      recursive: true
    })
  })
})
