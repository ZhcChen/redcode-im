import { EmojiCache, type EmojiCacheResult } from '../utils/emoji-cache'
import { rustHttp } from './rust-http'
import { base64ToUint8Array } from '../utils/binary'

/**
 * 表情项服务
 */
export class EmojiItemApi {
  /**
   * 加载并缓存表情图片
   * @param imageUrl 表情图片 URL
   * @returns Promise<string | null> 返回缓存的 blob URL，失败返回 null（组件会使用原始 URL）
   */
  static async loadAndCacheEmoji(imageUrl: string): Promise<string | null> {
    if (!imageUrl || imageUrl.trim() === '') {
      return null
    }

    // 先检查本地缓存
    const cached = await EmojiCache.resolve(imageUrl)
    if (cached) {
      return cached.webPath
    }

    try {
      // 使用 Rust HTTP 客户端下载图片（绕过 CORS）
      const response = await rustHttp.requestRaw<{ base64?: string; headers?: Record<string, string> }>({
        path: imageUrl,
        method: 'GET',
        responseType: 'binary',
        injectToken: false // 表情 URL 是公开的，不需要 token
      })

      if (!response.success || !response.data || !response.data.base64) {
        console.warn('表情下载失败，将使用原始 URL:', imageUrl, response.message)
        return null
      }

      // 将 base64 转换为 Uint8Array
      const bytes = base64ToUint8Array(response.data.base64)
      
      // 获取 content type
      const contentType = response.data.headers?.['content-type'] || response.data.headers?.['Content-Type'] || 'image/png'

      // 保存到缓存
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

