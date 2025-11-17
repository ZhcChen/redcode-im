import { EmojiCache, type EmojiCacheResult } from '../utils/emoji-cache'

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

    // 在 Tauri 环境中，fetch 可能因为 CORS 失败
    // 如果失败，返回 null，让组件直接使用原始 URL（img 标签的 CORS 限制比 fetch 宽松）
    const isTauri = typeof window !== 'undefined' && (window as any).__TAURI__

    try {
      // 尝试使用 fetch 下载（在非 Tauri 环境或 CORS 允许的情况下）
      const response = await fetch(imageUrl, {
        mode: 'cors', // 明确指定 CORS 模式
        credentials: 'omit' // 不发送凭证
      })

      if (!response.ok) {
        // 如果响应不成功，在 Tauri 环境中直接返回 null
        if (isTauri) {
          console.warn('表情下载失败，将使用原始 URL:', imageUrl)
          return null
        }
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
      // 在 Tauri 环境中，CORS 错误很常见，直接返回 null 让组件使用原始 URL
      if (isTauri) {
        console.warn('表情缓存失败（可能是 CORS 问题），将使用原始 URL:', imageUrl, error)
        return null
      }
      console.error('加载表情失败:', error)
      return null
    }
  }
}

