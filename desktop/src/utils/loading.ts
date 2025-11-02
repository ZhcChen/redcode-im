/**
 * 全局加载蒙版工具函数
 */
import { store } from '@/store'

/**
 * 显示全局加载蒙版
 * @param text 加载文字，默认为"加载中..."
 */
export function showGlobalLoading(text: string = '加载中...') {
  store.dispatch('showGlobalLoading', text)
}

/**
 * 隐藏全局加载蒙版
 */
export function hideGlobalLoading() {
  store.dispatch('hideGlobalLoading')
}

/**
 * 更新全局加载文字
 * @param text 新的加载文字
 */
export function updateGlobalLoadingText(text: string) {
  store.dispatch('updateGlobalLoadingText', text)
}

/**
 * 异步操作包装器，自动显示和隐藏加载蒙版
 * @param asyncFn 异步函数
 * @param loadingText 加载时显示的文字
 * @returns Promise
 */
export async function withGlobalLoading<T>(
  asyncFn: () => Promise<T>,
  loadingText: string = '加载中...'
): Promise<T> {
  try {
    showGlobalLoading(loadingText)
    const result = await asyncFn()
    return result
  } finally {
    hideGlobalLoading()
  }
}

/**
 * 延迟隐藏加载蒙版
 * @param delay 延迟时间（毫秒），默认300ms
 */
export function hideGlobalLoadingWithDelay(delay: number = 300) {
  setTimeout(() => {
    hideGlobalLoading()
  }, delay)
}

