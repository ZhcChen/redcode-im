/**
 * 下载设置管理工具
 * 用于管理文件下载目录设置
 * 使用 SQLite 数据库存储，不区分账号（全局设置）
 */

import { invoke } from '@tauri-apps/api/core'
import { saveCache, loadCache } from './cache'

const DOWNLOAD_DIR_CACHE_KEY = 'settings.download_directory'

/**
 * 获取 Chatly 下载目录
 * 默认在用户下载目录下创建 Chatly 子目录
 * 如果下载目录不存在，则在用户桌面创建 Chatly 子目录
 */
export async function getChatlyDownloadDir(): Promise<string> {
  let baseDir: string
  
  try {
    // 先尝试获取用户下载目录
    baseDir = await invoke<string>('get_user_download_dir')
    
    // 检查下载目录是否存在
    const exists = await invoke<boolean>('check_dir_exists', { path: baseDir })
    if (!exists) {
      // 如果下载目录不存在，使用桌面目录
      console.warn('下载目录不存在，使用桌面目录:', baseDir)
      baseDir = await getUserDesktopDir()
    }
  } catch (error) {
    console.error('获取下载目录失败，使用桌面目录:', error)
    // 如果获取失败，返回桌面目录
    try {
      baseDir = await getUserDesktopDir()
    } catch (desktopError) {
      console.error('获取桌面目录也失败:', desktopError)
      throw new Error('无法获取下载目录')
    }
  }
  
  // 在基础目录下创建 Chatly 子目录
  const chatlyDir = `${baseDir}/Chatly`
  
  // 确保 Chatly 目录存在
  try {
    const exists = await invoke<boolean>('check_dir_exists', { path: chatlyDir })
    if (!exists) {
      // 创建目录（通过 Rust 端）
      await invoke('create_dir', { path: chatlyDir, recursive: true })
    }
  } catch (error) {
    console.error('创建 Chatly 目录失败:', error)
    // 如果创建失败，返回基础目录（降级处理）
    return baseDir
  }
  
  return chatlyDir
}

/**
 * 获取默认下载目录（用户目录下的Downloads）
 * @deprecated 使用 getChatlyDownloadDir() 代替
 * macOS: ~/Downloads
 * Windows: C:\Users\用户名\Downloads
 * Linux: ~/Downloads
 */
export async function getDefaultDownloadDir(): Promise<string> {
  return getChatlyDownloadDir()
}

/**
 * 获取用户桌面目录
 */
export async function getUserDesktopDir(): Promise<string> {
  try {
    const result = await invoke<string>('get_user_desktop_dir')
    return result
  } catch (error) {
    console.error('获取桌面目录失败:', error)
    throw new Error('无法获取桌面目录')
  }
}

/**
 * 获取当前设置的下载目录
 * 如果未设置，返回 Chatly 下载目录
 */
export async function getDownloadDir(): Promise<string> {
  try {
    // 从 SQLite 缓存中读取
    const cached = await loadCache<string>(DOWNLOAD_DIR_CACHE_KEY)
    if (cached?.data) {
      const saved = cached.data
      try {
        // 验证目录是否存在
        const exists = await invoke<boolean>('check_dir_exists', { path: saved })
        if (exists) {
          return saved
        }
      } catch (error) {
        console.warn('验证下载目录失败，使用 Chatly 目录:', error)
      }
    }
  } catch (error) {
    console.warn('读取下载目录设置失败:', error)
  }
  
  // 如果未设置或目录不存在，返回 Chatly 下载目录
  return getChatlyDownloadDir()
}

/**
 * 设置下载目录（保存到 SQLite）
 */
export async function setDownloadDir(path: string): Promise<void> {
  try {
    await saveCache(DOWNLOAD_DIR_CACHE_KEY, path)
  } catch (error) {
    console.error('保存下载目录设置失败:', error)
    throw new Error('保存下载目录设置失败')
  }
}

/**
 * 初始化下载目录设置（应用启动时调用）
 * 如果未设置，则设置为默认下载目录
 */
export async function initializeDownloadDir(): Promise<void> {
  try {
    const cached = await loadCache<string>(DOWNLOAD_DIR_CACHE_KEY)
    const saved = cached?.data
    
    if (!saved) {
      try {
        const defaultDir = await getDefaultDownloadDir()
        await setDownloadDir(defaultDir)
        console.log('已初始化下载目录:', defaultDir)
      } catch (error) {
        console.error('初始化下载目录失败:', error)
        // 如果获取默认目录失败，尝试使用桌面目录
        try {
          const desktopDir = await getUserDesktopDir()
          await setDownloadDir(desktopDir)
          console.log('已使用桌面目录作为下载目录:', desktopDir)
        } catch (desktopError) {
          console.error('使用桌面目录也失败:', desktopError)
        }
      }
    } else {
      // 验证已保存的目录是否存在
      try {
        const exists = await invoke<boolean>('check_dir_exists', { path: saved })
        if (!exists) {
          // 如果目录不存在，重置为默认目录
          const defaultDir = await getDefaultDownloadDir()
          await setDownloadDir(defaultDir)
          console.log('已保存的下载目录不存在，重置为默认目录:', defaultDir)
        }
      } catch (error) {
        console.warn('验证下载目录失败:', error)
      }
    }
  } catch (error) {
    console.error('初始化下载目录设置失败:', error)
  }
}

