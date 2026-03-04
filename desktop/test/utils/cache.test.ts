import { beforeEach, describe, expect, it, vi } from 'vitest'

const { invokeMock } = vi.hoisted(() => ({
  invokeMock: vi.fn(),
}))

vi.mock('@tauri-apps/api/core', () => ({
  invoke: invokeMock,
}))

const loadCacheModule = async (useTauri: boolean) => {
  vi.resetModules()
  if (useTauri) {
    ;(window as any).__TAURI__ = {}
  } else {
    delete (window as any).__TAURI__
  }
  return import('@/utils/cache')
}

const writeEnvelope = (key: string, data: unknown, updatedAt = 1234) => {
  window.localStorage.setItem(
    key,
    JSON.stringify({
      version: 1,
      updatedAt,
      data,
    })
  )
}

describe('cache utils', () => {
  beforeEach(() => {
    invokeMock.mockReset()
    window.localStorage.clear()
    delete (window as any).__TAURI__
  })

  it('saves/loads/removes cache via localStorage fallback', async () => {
    const cache = await loadCacheModule(false)

    await cache.saveCache('cache.messages.room-1', { ids: ['m1'] })

    const snapshot = await cache.loadCache<{ ids: string[] }>('cache.messages.room-1')
    expect(snapshot?.data.ids).toEqual(['m1'])
    expect(snapshot?.updatedAt).toBeTypeOf('number')

    await cache.removeCache('cache.messages.room-1')
    expect(await cache.loadCache('cache.messages.room-1')).toBeNull()
    expect(invokeMock).not.toHaveBeenCalled()
  })

  it('cleans malformed localStorage payload automatically', async () => {
    window.localStorage.setItem('cache.bad', '{bad-json')
    const cache = await loadCacheModule(false)

    const snapshot = await cache.loadCache('cache.bad')

    expect(snapshot).toBeNull()
    expect(window.localStorage.getItem('cache.bad')).toBeNull()
  })

  it('uses tauri cache command when runtime available', async () => {
    invokeMock.mockResolvedValue({ data: { count: 3 }, updatedAt: 777 })
    const cache = await loadCacheModule(true)

    const snapshot = await cache.loadCache<{ count: number }>('cache.chat_list')

    expect(invokeMock).toHaveBeenCalledWith('cache_load_value', {
      key: 'cache.chat_list',
    })
    expect(snapshot).toEqual({ data: { count: 3 }, updatedAt: 777 })
  })

  it('falls back to localStorage when tauri invoke fails', async () => {
    invokeMock.mockRejectedValue(new Error('tauri unavailable'))
    writeEnvelope('cache.friend_requests', { pending: 2 }, 456)

    const cache = await loadCacheModule(true)
    const snapshot = await cache.loadCache<{ pending: number }>('cache.friend_requests')

    expect(snapshot).toEqual({ data: { pending: 2 }, updatedAt: 456 })
  })

  it('removes local cache even when tauri clear command fails', async () => {
    invokeMock.mockRejectedValue(new Error('clear failed'))
    writeEnvelope('cache.contacts', ['u1'])

    const cache = await loadCacheModule(true)
    await cache.removeCache('cache.contacts')

    expect(invokeMock).toHaveBeenCalledWith('cache_clear_value', {
      key: 'cache.contacts',
    })
    expect(window.localStorage.getItem('cache.contacts')).toBeNull()
  })
})
