/**
 * 头像临时下载地址缓存
 *
 * 功能:
 * 1. 缓存头像临时下载地址(带有效期)
 * 2. 基于 avatarObjectKey 检测头像是否变化
 * 3. 自动清理过期缓存
 */

const CACHE_KEY = 'avatar_url_cache_v1'
const DEFAULT_TTL = 3600 * 1000 // 1小时(毫秒)

interface AvatarUrlRecord {
  userId: string
  avatarObjectKey: string
  downloadUrl: string
  expiresAt: number // 过期时间戳(毫秒)
}

type AvatarUrlCache = Record<string, AvatarUrlRecord>

/**
 * 读取缓存索引
 */
function readCache(): AvatarUrlCache {
  if (typeof window === 'undefined' || !window.localStorage) {
    return {}
  }
  try {
    const raw = window.localStorage.getItem(CACHE_KEY)
    if (!raw) {
      return {}
    }
    return JSON.parse(raw) as AvatarUrlCache
  } catch (error) {
    console.warn('[AvatarUrlCache] 读取缓存失败，已重置:', error)
    return {}
  }
}

/**
 * 写入缓存索引
 */
function writeCache(cache: AvatarUrlCache) {
  if (typeof window === 'undefined' || !window.localStorage) {
    return
  }
  try {
    window.localStorage.setItem(CACHE_KEY, JSON.stringify(cache))
  } catch (error) {
    console.warn('[AvatarUrlCache] 写入缓存失败:', error)
  }
}

/**
 * 清理过期缓存
 */
function cleanExpired() {
  const cache = readCache()
  const now = Date.now()
  let hasExpired = false

  for (const [userId, record] of Object.entries(cache)) {
    if (record.expiresAt < now) {
      delete cache[userId]
      hasExpired = true
    }
  }

  if (hasExpired) {
    writeCache(cache)
  }
}

export const AvatarUrlCache = {
  /**
   * 获取缓存的头像下载地址
   *
   * @param userId - 用户 ID
   * @param avatarObjectKey - 头像 object key
   * @returns 如果缓存有效且 key 匹配，返回下载地址；否则返回 null
   */
  get(userId: string, avatarObjectKey: string | null | undefined): string | null {
    if (!avatarObjectKey) {
      return null
    }

    const cache = readCache()
    const record = cache[userId]

    if (!record) {
      return null
    }

    // 检查 objectKey 是否匹配(头像是否变化)
    if (record.avatarObjectKey !== avatarObjectKey) {
      return null
    }

    // 检查是否过期
    if (record.expiresAt < Date.now()) {
      delete cache[userId]
      writeCache(cache)
      return null
    }

    return record.downloadUrl
  },

  /**
   * 设置头像下载地址缓存
   *
   * @param userId - 用户 ID
   * @param avatarObjectKey - 头像 object key
   * @param downloadUrl - 临时下载地址
   * @param ttlMs - 有效期(毫秒)，默认 1 小时
   */
  set(
    userId: string,
    avatarObjectKey: string,
    downloadUrl: string,
    ttlMs: number = DEFAULT_TTL
  ): void {
    const cache = readCache()
    const expiresAt = Date.now() + ttlMs

    cache[userId] = {
      userId,
      avatarObjectKey,
      downloadUrl,
      expiresAt
    }

    writeCache(cache)
  },

  /**
   * 删除指定用户的缓存
   */
  delete(userId: string): void {
    const cache = readCache()
    if (cache[userId]) {
      delete cache[userId]
      writeCache(cache)
    }
  },

  /**
   * 清空所有缓存
   */
  clear(): void {
    if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.removeItem(CACHE_KEY)
    }
  },

  /**
   * 清理过期缓存
   */
  cleanExpired
}
