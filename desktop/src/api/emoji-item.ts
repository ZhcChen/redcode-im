import { EmojiCache, type EmojiCacheResult } from '../utils/emoji-cache'

/**
 * 表情项服务
 */
export class EmojiItemApi {
  /**
   * 加载并缓存表情图片
   * @param imageUrl 表情图片 URL
   * @returns Promise<string | null> 返回缓存的 blob URL，失败返回 null
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
      // 使用 fetch 直接下载（表情 URL 可能是公开的，不需要 token）
      const response = await fetch(imageUrl)
      if (!response.ok) {
        return null
      }

      // 获取二进制数据
      const arrayBuffer = await response.arrayBuffer()
      const bytes = new Uint8Array(arrayBuffer)

      // 获取 content type
      const contentType = response.headers.get('content-type') || 'image/png'

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

