import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const { getMock, postMock } = vi.hoisted(() => ({
  getMock: vi.fn(),
  postMock: vi.fn()
}))

vi.mock('@/api/http', () => ({
  get: getMock,
  post: postMock
}))

import {
  VersionApi,
  collectClientDetails,
  detectPlatform
} from '@/api/version'

describe('version api', () => {
  beforeEach(() => {
    getMock.mockResolvedValue({ success: true, data: {} })
    postMock.mockResolvedValue({ success: true, data: {} })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('detects platform from user agent', () => {
    vi.stubGlobal('navigator', { userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5)' } as Navigator)
    expect(detectPlatform()).toBe('macos')

    vi.stubGlobal('navigator', { userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } as Navigator)
    expect(detectPlatform()).toBe('windows')

    vi.stubGlobal('navigator', { userAgent: 'Mozilla/5.0 (X11; Linux x86_64)' } as Navigator)
    expect(detectPlatform()).toBe('linux')
  })

  it('requests latest version with detected platform and query params', async () => {
    vi.stubGlobal('navigator', { userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' } as Navigator)

    await VersionApi.getLatestVersion({
      channel: 'stable',
      currentVersion: '1.0.0'
    })

    expect(getMock).toHaveBeenCalledWith('/versions/latest', {
      platform: 'windows',
      channel: 'stable',
      current_version: '1.0.0'
    })
  })

  it('collects client details and includes them when reporting update event', async () => {
    vi.stubGlobal(
      'navigator',
      {
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        platform: 'Win32',
        language: 'zh-CN',
        cookieEnabled: true,
        connection: { effectiveType: 'wifi' }
      } as Navigator
    )

    const details = collectClientDetails()
    expect(details.client_type).toBe('desktop')
    expect(details.device_info).toContain('platform:Win32')

    await VersionApi.reportUpdateEvent({
      platform: 'windows',
      channel: 'stable',
      base_version: '1.0.0',
      patch_version: '1.0.1',
      event_type: 'download_success'
    })

    expect(postMock).toHaveBeenCalledTimes(1)
    const [, payload] = postMock.mock.calls[0]
    expect(payload.client_type).toBe('desktop')
    expect(payload.trigger_source).toBe('manual')
    expect(payload.platform).toBe('windows')
  })
})
