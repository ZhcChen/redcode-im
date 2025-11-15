/**
 * Tauri 相关工具函数
 */
import { invoke } from '@tauri-apps/api/core'

/**
 * 设置窗口标题
 * @param title 窗口标题
 */
export async function setWindowTitle(title: string): Promise<void> {
  try {
    await invoke('set_window_title', { title })
  } catch (error) {
    throw error // 重新抛出错误以便上层捕获
  }
}

/**
 * 根据用户信息生成窗口标题
 * @param userInfo 用户信息
 * @param appName 应用名称（从 store 获取）
 * @returns 格式化的窗口标题
 */
export function generateWindowTitle(userInfo?: { mobile?: string; nickname?: string; username?: string }, appName?: string): string {
  const baseTitle = appName || 'Chatly'
  
  if (!userInfo?.mobile) {
    return baseTitle
  }
  
  // 完整显示手机号，不进行脱敏处理
  return `${baseTitle} - ${userInfo.mobile}`
}

/**
 * 更新窗口标题（根据用户登录状态）
 * @param userInfo 用户信息，如果为空则显示默认标题
 * @param appName 应用名称（从 store 获取）
 */
export async function updateWindowTitle(userInfo?: { mobile?: string; nickname?: string; username?: string }, appName?: string): Promise<void> {
  const title = generateWindowTitle(userInfo, appName)
  await setWindowTitle(title)
}
