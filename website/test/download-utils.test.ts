import { describe, expect, it } from 'vitest'

import {
  applyLatestVersionToItem,
  detectPlatformKey,
  formatVersionText,
  markUnavailable,
  resolveChannels,
  resolveLatestDownloadUrlPayload,
  resolvePrimaryDownloadKeys,
  type DownloadItem
} from '../app/utils/download'

const createItem = (overrides: Partial<DownloadItem> = {}): DownloadItem => ({
  key: 'windows',
  kind: 'package',
  label: '下载 Windows 版',
  platform: 'windows',
  channel: 'stable',
  href: '',
  versionText: '',
  unavailable: false,
  ...overrides
})

describe('download utils', () => {
  it('formatVersionText returns formatted text with and without build number', () => {
    expect(formatVersionText({ version: '1.2.3', build_number: 42 })).toBe(
      'v1.2.3 (build 42)'
    )
    expect(formatVersionText({ version: '1.2.3' })).toBe('v1.2.3')
    expect(formatVersionText()).toBe('')
  })

  it('markUnavailable marks item unavailable and clears href', () => {
    const item = createItem({ href: 'https://download.example.com', versionText: 'v1.0.0' })

    markUnavailable(item, '暂无可用版本')

    expect(item.href).toBe('')
    expect(item.versionText).toBe('暂无可用版本')
    expect(item.unavailable).toBe(true)
  })

  it('resolveChannels returns channelCandidates first', () => {
    expect(resolveChannels({ channel: 'stable', channelCandidates: ['stable-a', 'stable-b'] })).toEqual([
      'stable-a',
      'stable-b'
    ])
    expect(resolveChannels({ channel: 'stable' })).toEqual(['stable'])
    expect(resolveChannels({})).toEqual([])
  })

  it('applyLatestVersionToItem updates store item when app store url exists', () => {
    const item = createItem({ key: 'iosStore', kind: 'store', platform: 'ios' })

    applyLatestVersionToItem(
      item,
      { version: '2.0.0', build_number: 10, app_store_url: 'https://apps.apple.com/demo' },
      'stable'
    )

    expect(item.resolvedChannel).toBe('stable')
    expect(item.href).toBe('https://apps.apple.com/demo')
    expect(item.unavailable).toBe(false)
    expect(item.versionText).toBe('v2.0.0 (build 10)')
  })

  it('applyLatestVersionToItem marks package item unavailable when no downloadable target exists', () => {
    const item = createItem({ kind: 'package' })

    applyLatestVersionToItem(
      item,
      { version: '2.0.0', build_number: 11, download_key: '   ', download_url: '' },
      'stable'
    )

    expect(item.unavailable).toBe(true)
    expect(item.versionText).toBe('未配置安装包')
  })

  it('applyLatestVersionToItem marks store item unavailable when app store url missing', () => {
    const item = createItem({ key: 'iosStore', kind: 'store', platform: 'ios' })

    applyLatestVersionToItem(
      item,
      { version: '2.0.1', build_number: 12, app_store_url: null },
      'stable'
    )

    expect(item.unavailable).toBe(true)
    expect(item.href).toBe('')
    expect(item.versionText).toBe('未配置商店链接')
  })

  it('applyLatestVersionToItem keeps package available when download_url exists', () => {
    const item = createItem({ kind: 'package' })

    applyLatestVersionToItem(
      item,
      { version: '2.1.0', build_number: 13, download_url: 'https://example.com/app.pkg' },
      'stable'
    )

    expect(item.unavailable).toBe(false)
    expect(item.href).toBe('')
    expect(item.versionText).toBe('v2.1.0 (build 13)')
  })

  it('resolveLatestDownloadUrlPayload returns success payload with updated version text', () => {
    const result = resolveLatestDownloadUrlPayload({
      success: true,
      download_url: 'https://download.example.com/latest',
      version: { version: '3.0.0', build_number: 99 }
    })

    expect(result).toEqual({
      ok: true,
      downloadUrl: 'https://download.example.com/latest',
      versionText: 'v3.0.0 (build 99)'
    })
  })

  it('resolveLatestDownloadUrlPayload returns error when payload is invalid', () => {
    const result = resolveLatestDownloadUrlPayload({ success: false, message: 'no package' })

    expect(result).toEqual({ ok: false, error: 'no package' })
  })

  it('resolveLatestDownloadUrlPayload uses currentVersionText fallback and default error', () => {
    const successWithFallback = resolveLatestDownloadUrlPayload(
      {
        success: true,
        download_url: 'https://download.example.com/latest'
      },
      'v1.0.0'
    )

    expect(successWithFallback).toEqual({
      ok: true,
      downloadUrl: 'https://download.example.com/latest',
      versionText: 'v1.0.0'
    })

    const defaultError = resolveLatestDownloadUrlPayload({ success: false })
    expect(defaultError).toEqual({ ok: false, error: '暂无可用安装包' })
  })

  it('detectPlatformKey detects common platform variants', () => {
    expect(
      detectPlatformKey({
        userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)'
      })
    ).toBe('ios')

    expect(
      detectPlatformKey({
        userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel)'
      })
    ).toBe('android')

    expect(
      detectPlatformKey({
        userAgent: 'Mozilla/5.0 (Mac OS X 13_5)',
        architecture: 'arm64'
      })
    ).toBe('macosArm')

    expect(
      detectPlatformKey({
        userAgent: 'Mozilla/5.0 (Mac OS X 13_5; Intel Mac OS X)'
      })
    ).toBe('macosIntel')

    expect(
      detectPlatformKey({
        userAgent: 'Mozilla/5.0 (X11; Linux x86_64)'
      })
    ).toBe('linux')

    expect(
      detectPlatformKey({
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      })
    ).toBe('windows')

    expect(detectPlatformKey({ isClient: false })).toBe('windows')
    expect(detectPlatformKey({ userAgent: 'CustomAgent/1.0' })).toBe('windows')
  })

  it('resolvePrimaryDownloadKeys follows expected priority per platform', () => {
    expect(resolvePrimaryDownloadKeys('ios').slice(0, 3)).toEqual([
      'iosStore',
      'iosOnline',
      'android'
    ])

    expect(resolvePrimaryDownloadKeys('macosArm').slice(0, 3)).toEqual([
      'macosArm',
      'macosStore',
      'macosIntel'
    ])

    expect(resolvePrimaryDownloadKeys('windows').slice(0, 2)).toEqual([
      'windows',
      'windows'
    ])

    expect(resolvePrimaryDownloadKeys('linux').slice(0, 3)).toEqual([
      'linux',
      'windows',
      'macosArm'
    ])
  })
})
