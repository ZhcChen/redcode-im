import { EmojiCache, type EmojiCacheResult } from '../utils/emoji-cache'
import { rustHttp } from './rust-http'
import { base64ToUint8Array } from '../utils/binary'
import { EmojiPackApi } from './emoji-pack'

/**
 * 表情项服务
 */
export class EmojiItemApi {
  /**
   * 加载并缓存表情图片
   * @param imageUrl 表情图片 URL（私有 COS 链接，不可直接访问）
   * @param objectKey COS 对象键，用于获取临时下载地址
   * @returns Promise<string | null> 返回缓存的 blob URL，失败返回 null（组件会使用原始 URL）
   */
  static async loadAndCacheEmoji(imageUrl: string, objectKey?: string | null): Promise<string | null> {
    if (!imageUrl || imageUrl.trim() === '') {
      return null
    }

    // 先检查本地缓存（使用 imageUrl 作为缓存键）
    const cached = await EmojiCache.resolve(imageUrl)
    if (cached) {
      return cached.webPath
    }

    const extractCosObjectKeyFromUrl = (url: string): string | null => {
      try {
        const parsed = new URL(url)
        const host = parsed.hostname || ''
        // 仅在典型 COS 域名下尝试提取对象键，避免误处理非 COS URL
        if (!host.includes('cos.') && !host.includes('myqcloud.com')) {
          return null
        }
        const pathname = parsed.pathname || ''
        const key = pathname.startsWith('/') ? pathname.slice(1) : pathname
        return key || null
      } catch {
        return null
      }
    }

    try {
      // 获取下载地址：优先使用 objectKey 获取临时下载地址
      let downloadUrl = imageUrl
      let resolvedObjectKey: string | null = objectKey || null

      // 若未显式提供 objectKey，尝试从 URL 中解析（兼容旧数据）
      if (!resolvedObjectKey) {
        resolvedObjectKey = extractCosObjectKeyFromUrl(imageUrl)
      }

      if (resolvedObjectKey) {
        console.log('使用 objectKey 获取表情临时下载地址:', resolvedObjectKey)
        const tempUrl = await EmojiPackApi.getEmojiDownloadUrl(resolvedObjectKey)
        if (tempUrl) {
          downloadUrl = tempUrl
          console.log('获取到表情临时下载地址:', tempUrl)
        } else {
          console.warn('获取临时下载地址失败，尝试使用原始 URL')
        }
      }

      // 使用 Rust HTTP 客户端下载图片（绕过 CORS）
      const response = await rustHttp.requestRaw<{ base64?: string; headers?: Record<string, string> }>({
        path: downloadUrl,
        method: 'GET',
        responseType: 'binary',
        injectToken: false // 临时下载地址已包含签名，不需要 token
      })

      if (!response.success || !response.data || !response.data.base64) {
        console.warn('表情下载失败，将使用原始 URL:', imageUrl, response.message)
        return null
      }

      // 将 base64 转换为 Uint8Array
      const bytes = base64ToUint8Array(response.data.base64)

      // 获取 content type
      const contentType = response.data.headers?.['content-type'] || response.data.headers?.['Content-Type'] || 'image/png'

      // 保存到缓存（使用原始 imageUrl 作为缓存键，确保下次能命中缓存）
      const saved = await EmojiCache.save({
        imageUrl,
        data: bytes,
        contentType
      })

      return saved.webPath
    } catch (error) {
      console.error('加载表情失败:', error)
      return null
    }
  }
}
