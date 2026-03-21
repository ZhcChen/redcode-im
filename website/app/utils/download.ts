export type DownloadKind = 'store' | 'package'

export type PlatformKey =
  | 'ios'
  | 'android'
  | 'macosArm'
  | 'macosIntel'
  | 'windows'
  | 'linux'

export interface DownloadVersion {
  version?: string
  build_number?: number
  app_store_url?: string | null
  download_key?: string | null
  download_url?: string | null
}

export interface DownloadItem {
  key: string
  kind: DownloadKind
  label: string
  platform: string
  channel?: string
  channelCandidates?: string[]
  resolvedChannel?: string
  href: string
  versionText: string
  unavailable: boolean
}

export interface LatestDownloadUrlPayload {
  success?: boolean
  download_url?: string
  version?: DownloadVersion
  message?: string
}

export interface LatestDownloadResolveResult {
  ok: boolean
  downloadUrl?: string
  versionText?: string
  error?: string
}

export interface DetectPlatformInput {
  isClient?: boolean
  userAgent?: string
  architecture?: string
}

export const formatVersionText = (version?: DownloadVersion | null): string => {
  if (!version?.version) {
    return ''
  }
  const build = version.build_number
  return build ? `v${version.version} (build ${build})` : `v${version.version}`
}

export const markUnavailable = (
  item: DownloadItem,
  reason = '暂无可用版本'
): void => {
  item.href = ''
  item.versionText = reason
  item.unavailable = true
}

export const resolveChannels = (item: {
  channel?: string
  channelCandidates?: string[]
}): string[] => {
  if (item.channelCandidates && item.channelCandidates.length > 0) {
    return item.channelCandidates
  }
  return item.channel ? [item.channel] : []
}

const hasPackageDownload = (version: DownloadVersion): boolean => {
  const hasDownloadKey =
    typeof version.download_key === 'string' &&
    version.download_key.trim().length > 0
  const hasDownloadUrl =
    typeof version.download_url === 'string' &&
    version.download_url.trim().length > 0
  return hasDownloadKey || hasDownloadUrl
}

export const applyLatestVersionToItem = (
  item: DownloadItem,
  version: DownloadVersion,
  channel: string
): void => {
  item.resolvedChannel = channel
  item.href = ''
  item.versionText = formatVersionText(version)

  if (item.kind === 'store') {
    if (version.app_store_url) {
      item.href = version.app_store_url
      item.unavailable = false
      return
    }
    markUnavailable(item, '未配置商店链接')
    return
  }

  if (hasPackageDownload(version)) {
    item.unavailable = false
    return
  }

  markUnavailable(item, '未配置安装包')
}

export const resolveLatestDownloadUrlPayload = (
  data: LatestDownloadUrlPayload,
  currentVersionText = ''
): LatestDownloadResolveResult => {
  if (data?.success && data.download_url) {
    return {
      ok: true,
      downloadUrl: data.download_url,
      versionText: formatVersionText(data.version) || currentVersionText
    }
  }

  return {
    ok: false,
    error: data?.message || '暂无可用安装包'
  }
}

export const detectPlatformKey = ({
  isClient = true,
  userAgent = '',
  architecture = ''
}: DetectPlatformInput = {}): PlatformKey => {
  if (!isClient) {
    return 'windows'
  }

  const ua = userAgent.toLowerCase()
  const arch = architecture.toLowerCase()

  if (/iphone|ipad|ipod/.test(ua)) {
    return 'ios'
  }
  if (/android/.test(ua)) {
    return 'android'
  }
  if (/mac os x/.test(ua)) {
    if ((arch && arch.includes('arm')) || /arm|aarch64|apple silicon/.test(ua)) {
      return 'macosArm'
    }
    return 'macosIntel'
  }
  if (/linux/.test(ua)) {
    return 'linux'
  }
  if (/win/.test(ua)) {
    return 'windows'
  }
  return 'windows'
}

export const resolvePrimaryDownloadKeys = (detected: PlatformKey): string[] => {
  if (detected === 'ios') {
    return [
      'iosStore',
      'iosOnline',
      'android',
      'windows',
      'macosArm',
      'macosIntel',
      'linux'
    ]
  }

  if (detected === 'macosArm') {
    return ['macosArm', 'macosStore', 'macosIntel', 'windows', 'linux']
  }

  if (detected === 'macosIntel') {
    return ['macosIntel', 'macosStore', 'macosArm', 'windows', 'linux']
  }

  if (detected === 'android') {
    return ['android', 'windows', 'macosArm', 'macosIntel', 'linux']
  }

  return [
    detected,
    'windows',
    'macosArm',
    'macosIntel',
    'linux',
    'android',
    'iosStore',
    'iosOnline'
  ]
}
