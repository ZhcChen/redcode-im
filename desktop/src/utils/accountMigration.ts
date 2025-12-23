import { invoke } from '@tauri-apps/api/core'

/**
 * 账号数据迁移工具
 * 用于将 localStorage 中的账号数据迁移到 Rust SQLite
 */

interface LegacyAccountData {
  id: string
  token: string
  userInfo: {
    id: string
    username: string
    nickname: string
    avatar: string
    avatarObjectKey?: string | null
    avatarLocalPath?: string | null
  }
  unreadCount: number
  createdAt: number
}

interface RustAccountInput {
  id: string
  username: string
  nickname: string
  avatar: string | null
  avatar_object_key: string | null
  avatar_local_path: string | null
  mobile: string | null
  email: string | null
  token: string
  refresh_token?: string | null
}

/**
 * 检查是否需要迁移
 */
export async function needsMigration(): Promise<boolean> {
  try {
    // 检查 localStorage 是否有旧数据
    const legacyData = localStorage.getItem('im_accounts')
    if (!legacyData) {
      return false
    }

    // 检查 Rust SQLite 是否有数据
    await invoke('account_init')
    const accounts = await invoke<any[]>('account_get_all')

    // 如果 localStorage 有数据但 SQLite 没有，则需要迁移
    return accounts.length === 0
  } catch (error) {
    return false
  }
}

/**
 * 执行数据迁移
 */
export async function migrateAccounts(): Promise<{ success: boolean; message: string; migratedCount: number }> {
  try {
    // 1. 从 localStorage 读取旧数据
    const legacyDataStr = localStorage.getItem('im_accounts')
    if (!legacyDataStr) {
      return {
        success: true,
        message: '没有需要迁移的数据',
        migratedCount: 0
      }
    }

    const legacyAccounts: LegacyAccountData[] = JSON.parse(legacyDataStr)
    if (legacyAccounts.length === 0) {
      return {
        success: true,
        message: '没有需要迁移的数据',
        migratedCount: 0
      }
    }


    // 2. 初始化 Rust 账号管理器
    await invoke('account_init')

    // 3. 逐个迁移账号
    let migratedCount = 0
    for (const account of legacyAccounts) {
      try {
        const rustAccount: RustAccountInput = {
          id: account.id,
          username: account.userInfo.username,
          nickname: account.userInfo.nickname,
          avatar: account.userInfo.avatar || null,
          avatar_object_key: account.userInfo.avatarObjectKey ?? null,
          avatar_local_path: account.userInfo.avatarLocalPath ?? null,
          mobile: null,
          email: null,
          token: account.token,
          refresh_token: null
        }

        await invoke('account_add', { account: rustAccount })
        migratedCount++
      } catch (error) {
      }
    }

    // 4. 迁移当前账号 ID
    const currentAccountId = localStorage.getItem('im_current_account_id')
    if (currentAccountId) {
      try {
        await invoke('account_set_current', { accountId: currentAccountId })
      } catch (error) {
      }
    }

    // 5. 清理 localStorage（备份后）
    try {
      // 备份到 localStorage 的另一个 key
      localStorage.setItem('im_accounts_backup', legacyDataStr)
      if (currentAccountId) {
        localStorage.setItem('im_current_account_id_backup', currentAccountId)
      }

      // 删除旧数据
      localStorage.removeItem('im_accounts')
      localStorage.removeItem('im_current_account_id')

    } catch (error) {
    }

    return {
      success: true,
      message: `成功迁移 ${migratedCount} 个账号`,
      migratedCount
    }
  } catch (error) {
    return {
      success: false,
      message: `迁移失败: ${error}`,
      migratedCount: 0
    }
  }
}

/**
 * 回滚迁移（从备份恢复）
 */
export async function rollbackMigration(): Promise<boolean> {
  try {
    const backupData = localStorage.getItem('im_accounts_backup')
    const backupCurrentId = localStorage.getItem('im_current_account_id_backup')

    if (backupData) {
      localStorage.setItem('im_accounts', backupData)
    }

    if (backupCurrentId) {
      localStorage.setItem('im_current_account_id', backupCurrentId)
    }

    return true
  } catch (error) {
    return false
  }
}

/**
 * 删除备份数据
 */
export function clearBackup(): void {
  localStorage.removeItem('im_accounts_backup')
  localStorage.removeItem('im_current_account_id_backup')
}
