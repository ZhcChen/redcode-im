import { invoke } from '@tauri-apps/api/core'

/**
 * 账号信息接口
 */
export interface AccountInfo {
  id: string // 账号唯一标识
  token: string // 认证令牌
  userInfo: {
    id: string
    username: string
    nickname: string
    avatar: string
    avatarObjectKey: string | null
    avatarLocalPath: string | null
  }
  unreadCount: number // 未读消息数
  friendRequestCount: number // 好友请求未读数
  createdAt: number // 添加时间戳
}

/**
 * Accounts 模块状态
 */
export interface AccountsState {
  accounts: AccountInfo[] // 所有账号列表
  currentAccountId: string | null // 当前激活的账号 ID
  maxAccounts: number // 最大账号数量限制
}

const accountsModule = {
  namespaced: true,

  state: (): AccountsState => ({
    accounts: [],
    currentAccountId: null,
    maxAccounts: 10
  }),

  getters: {
    /**
     * 获取当前激活的账号
     */
    currentAccount(state): AccountInfo | null {
      if (!state.currentAccountId) return null
      return state.accounts.find(acc => acc.id === state.currentAccountId) || null
    },

    /**
     * 获取所有账号列表
     */
    allAccounts(state): AccountInfo[] {
      return state.accounts
    },

    /**
     * 判断是否可以添加新账号
     */
    canAddAccount(state): boolean {
      return state.accounts.length < state.maxAccounts
    },

    /**
     * 根据账号 ID 获取账号信息
     */
    getAccountById: (state) => (accountId: string): AccountInfo | undefined => {
      return state.accounts.find(acc => acc.id === accountId)
    },

    /**
     * 获取总未读消息数
     */
    totalUnreadCount(state): number {
      return state.accounts.reduce((sum, acc) => sum + acc.unreadCount, 0)
    }
  },

  mutations: {
    /**
     * 添加账号
     */
    ADD_ACCOUNT(state, account: AccountInfo) {
      if (state.accounts.length >= state.maxAccounts) {
        console.warn(`已达到最大账号数量限制: ${state.maxAccounts}`)
        return
      }

      // 检查账号是否已存在
      const exists = state.accounts.some(acc => acc.id === account.id)
      if (exists) {
        console.warn(`账号 ${account.id} 已存在`)
        return
      }

      const normalizedAccount: AccountInfo = {
        ...account,
        userInfo: {
          ...account.userInfo,
          avatarObjectKey: account.userInfo.avatarObjectKey ?? null,
          avatarLocalPath: account.userInfo.avatarLocalPath ?? null
        }
      }

      state.accounts.push({
        ...normalizedAccount,
        friendRequestCount: normalizedAccount.friendRequestCount || 0,
        createdAt: Date.now()
      })

      // 如果是第一个账号，自动设为当前账号
      if (state.accounts.length === 1) {
        state.currentAccountId = normalizedAccount.id
      }
    },

    /**
     * 移除账号
     */
    REMOVE_ACCOUNT(state, accountId: string) {
      const index = state.accounts.findIndex(acc => acc.id === accountId)
      if (index === -1) return

      state.accounts.splice(index, 1)

      // 如果移除的是当前账号，切换到第一个账号
      if (state.currentAccountId === accountId) {
        state.currentAccountId = state.accounts.length > 0 ? state.accounts[0].id : null
      }
    },

    /**
     * 切换当前账号
     */
    SET_CURRENT_ACCOUNT(state, accountId: string) {
      const account = state.accounts.find(acc => acc.id === accountId)
      if (account) {
        state.currentAccountId = accountId
      } else {
        console.warn(`账号 ${accountId} 不存在`)
      }
    },

    /**
     * 更新账号信息
     */
    UPDATE_ACCOUNT(state, payload: { accountId: string; data: Partial<AccountInfo> }) {
      const account = state.accounts.find(acc => acc.id === payload.accountId)
      if (account) {
        Object.assign(account, payload.data)
      }
    },

    /**
     * 更新账号未读数
     */
    UPDATE_UNREAD_COUNT(state, payload: { accountId: string; count: number }) {
      const index = state.accounts.findIndex(acc => acc.id === payload.accountId)
      if (index !== -1) {
        // 创建新对象以触发 Vue 响应式更新
        state.accounts[index] = {
          ...state.accounts[index],
          unreadCount: payload.count
        }
      }
    },

    /**
     * 增加账号未读数
     */
    INCREMENT_UNREAD_COUNT(state, accountId: string) {
      const index = state.accounts.findIndex(acc => acc.id === accountId)
      if (index !== -1) {
        // 创建新对象以触发 Vue 响应式更新
        state.accounts[index] = {
          ...state.accounts[index],
          unreadCount: state.accounts[index].unreadCount + 1
        }
      }
    },

    /**
     * 清空账号未读数
     */
    CLEAR_UNREAD_COUNT(state, accountId: string) {
      const index = state.accounts.findIndex(acc => acc.id === accountId)
      if (index !== -1) {
        // 创建新对象以触发 Vue 响应式更新
        state.accounts[index] = {
          ...state.accounts[index],
          unreadCount: 0
        }
      }
    },

    /**
     * 更新账号好友请求数
     */
    UPDATE_FRIEND_REQUEST_COUNT(state, payload: { accountId: string; count: number }) {
      const index = state.accounts.findIndex(acc => acc.id === payload.accountId)
      if (index !== -1) {
        // 创建新对象以触发 Vue 响应式更新
        state.accounts[index] = {
          ...state.accounts[index],
          friendRequestCount: payload.count
        }
      }
    },

    /**
     * 清空账号好友请求数
     */
    CLEAR_FRIEND_REQUEST_COUNT(state, accountId: string) {
      const index = state.accounts.findIndex(acc => acc.id === accountId)
      if (index !== -1) {
        // 创建新对象以触发 Vue 响应式更新
        state.accounts[index] = {
          ...state.accounts[index],
          friendRequestCount: 0
        }
      }
    },

    /**
     * 清空所有账号
     */
    CLEAR_ALL_ACCOUNTS(state) {
      state.accounts = []
      state.currentAccountId = null
    },

    /**
     * 设置最大账号数量
     */
    SET_MAX_ACCOUNTS(state, max: number) {
      state.maxAccounts = max
    },

    /**
     * 重新排序账号
     */
    REORDER_ACCOUNTS(state, accountIds: string[]) {
      // 按照新的顺序重新排列账号
      const accountMap = new Map(state.accounts.map(acc => [acc.id, acc]))
      state.accounts = accountIds
        .map(id => accountMap.get(id))
        .filter((acc): acc is AccountInfo => acc !== undefined)
    }
  },

  actions: {
    /**
     * 添加账号（异步）
     */
    async addAccount({ commit, state }, account: AccountInfo) {
      if (state.accounts.length >= state.maxAccounts) {
        throw new Error(`已达到最大账号数量限制: ${state.maxAccounts}`)
      }

      // 添加到 Rust SQLite
      await addAccountToRust(account)

      // 更新本地状态
      commit('ADD_ACCOUNT', account)
    },

    /**
     * 移除账号（异步）
     */
    async removeAccount({ commit, state }, accountId: string) {
      // 从 Rust SQLite 移除
      await removeAccountFromRust(accountId)

      // 更新本地状态
      commit('REMOVE_ACCOUNT', accountId)
    },

    /**
     * 切换账号（异步）
     */
    async switchAccount({ commit, state }, accountId: string) {
      // 设置到 Rust SQLite
      await setCurrentAccountInRust(accountId)

      // 更新本地状态
      commit('SET_CURRENT_ACCOUNT', accountId)
    },

    /**
     * 同步账号资料（头像、昵称等）到内存和 SQLite
     */
    async syncAccountProfile({ state, commit }, payload: { accountId?: string; userInfo?: Partial<AccountInfo['userInfo']>; token?: string }) {
      const targetAccountId = payload.accountId || state.currentAccountId
      if (!targetAccountId) {
        console.warn('syncAccountProfile: 无可用账号ID')
        return
      }

      const account = state.accounts.find(acc => acc.id === targetAccountId)
      if (!account) {
        console.warn(`syncAccountProfile: 账号 ${targetAccountId} 不存在`)
        return
      }

      const nextAccount: AccountInfo = {
        ...account,
        token: payload.token ?? account.token,
        userInfo: {
          ...account.userInfo,
          ...(payload.userInfo || {})
        }
      }

      try {
        await addAccountToRust(nextAccount)
      } catch (error) {
        console.error('同步账号信息到 SQLite 失败:', error)
      }

      commit('UPDATE_ACCOUNT', {
        accountId: targetAccountId,
        data: {
          token: nextAccount.token,
          userInfo: nextAccount.userInfo
        }
      })
    },

    /**
     * 从 Rust SQLite 恢复账号列表
     */
    async loadAccountsFromStorage({ commit }) {
      try {
        // 初始化账号管理器
        await invoke('account_init')

        // 加载所有账号
        const accounts = await loadAccountsFromRust()
        const currentAccountId = await loadCurrentAccountFromRust()

        accounts.forEach(account => {
          commit('ADD_ACCOUNT', account)
        })

        if (currentAccountId && accounts.some(acc => acc.id === currentAccountId)) {
          commit('SET_CURRENT_ACCOUNT', currentAccountId)
        }

        // 注意：头像缓存同步在 App.vue 的 ensureAvatarCacheConsistency 中处理
        // 这里不调用 syncAvatarCache，因为此时 SET_USER 还没有执行，currentUser 可能还没有正确的数据
      } catch (error) {
        console.error('加载账号列表失败:', error)
      }
    },

    /**
     * 登出账号
     */
    async logoutAccount({ dispatch }, accountId: string) {
      // 通知 Rust 后端断开该账号的连接（如果后端有此命令）
      try {
        // 目前 Rust 后端可能没有此命令，暂时注释
        // await invoke('logout_account', { account_id: accountId })
        console.log('登出账号:', accountId)
      } catch (error) {
        console.error('登出账号失败:', error)
      }

      // 移除账号
      await dispatch('removeAccount', accountId)
    },

    /**
     * 重新排序账号（异步）
     */
    async reorderAccounts({ commit, state }, accountIds: string[]) {
      // 验证所有账号 ID 都存在
      const validIds = accountIds.filter(id => 
        state.accounts.some(acc => acc.id === id)
      )

      if (validIds.length !== state.accounts.length) {
        console.warn('重新排序失败: 账号 ID 不匹配')
        return
      }

      // 生成排序值（使用秒级时间戳 + 索引的偏移量）
      // 使用秒级时间戳确保与数据库中的其他时间戳保持一致
      const baseTimestamp = Math.floor(Date.now() / 1000)
      const accountOrders: [string, number][] = validIds.map((id, index) => [
        id,
        baseTimestamp + index * 10  // 每个账号间隔 10 秒，确保顺序明确
      ])

      try {
        // 保存到 Rust SQLite
        await invoke('account_update_order', { accountOrders })
        
        // 更新本地状态
        commit('REORDER_ACCOUNTS', validIds)
      } catch (error) {
        console.error('重新排序账号失败:', error)
        throw error
      }
    },

    /**
     * 同步账号未读数（根据聊天列表计算）
     */
    syncAccountUnreadCount({ commit, state, rootGetters }, accountId: string) {
      // 获取聊天列表的总未读数
      const chatList = rootGetters.chatList || []
      const totalUnread = chatList.reduce((sum: number, chat: any) => {
        return sum + (chat.unreadCount || 0)
      }, 0)

      // 更新账号未读数
      commit('UPDATE_UNREAD_COUNT', {
        accountId,
        count: totalUnread
      })
    },

    /**
     * 同步账号好友请求数（从全局状态同步到当前账号）
     */
    syncAccountFriendRequestCount({ commit, state, rootGetters }, accountId: string) {
      // 从全局状态获取好友请求数
      const friendRequestCount = rootGetters.pendingFriendRequests || 0

      // 更新账号好友请求数
      commit('UPDATE_FRIEND_REQUEST_COUNT', {
        accountId,
        count: friendRequestCount
      })
    },

    /**
     * 刷新所有账号的未读数
     * 用于定期检查非当前账号的未读消息
     */
    async refreshAllAccountsUnreadCount({ commit, state, rootState }) {
      // 保存当前token和账号
      const currentAccountId = state.currentAccountId
      const currentAccount = state.accounts.find(acc => acc.id === currentAccountId)
      if (!currentAccount) {
        return
      }

      // 导入必要的API
      const { GroupApi } = await import('@/api/group')
      const { FriendApi } = await import('@/api/friend')
      const { syncRustBackendToken } = await import('@/api/http')

      // 遍历所有账号（包括当前账号）
      for (const account of state.accounts) {
        try {
          // 暂时切换到目标账号的token
          await syncRustBackendToken(account.token)

          // 获取聊天列表
          const chatResponse = await GroupApi.getMyChatGroupList()
          if (chatResponse.success && Array.isArray(chatResponse.data)) {
            // 计算未读消息总数
            const totalUnread = chatResponse.data.reduce((sum, chat) => {
              return sum + (chat.unreadCount || 0)
            }, 0)

            // 更新账号未读数
            commit('UPDATE_UNREAD_COUNT', {
              accountId: account.id,
              count: totalUnread
            })
          }

          // 获取好友请求数
          const friendRequestResponse = await FriendApi.getPendingFriendRequestCount()
          if (friendRequestResponse.success && typeof friendRequestResponse.data === 'number') {
            // 更新好友请求数
            commit('UPDATE_FRIEND_REQUEST_COUNT', {
              accountId: account.id,
              count: friendRequestResponse.data
            })
          }
        } catch (error) {
          console.error(`刷新账号 ${account.userInfo.nickname} 未读数失败:`, error)
        }
      }

      // 恢复当前账号的token
      await syncRustBackendToken(currentAccount.token)
    }
  }
}

/**
 * Rust 账号输入类型
 */
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
}

/**
 * Rust 账号输出类型
 */
interface RustAccountOutput {
  id: string
  username: string
  nickname: string
  avatar: string | null
  avatar_object_key: string | null
  avatar_local_path: string | null
  mobile: string | null
  email: string | null
  token: string
  created_at: number
  updated_at: number
  sort_order?: number | null
}

/**
 * 添加账号到 Rust SQLite
 */
async function addAccountToRust(account: AccountInfo): Promise<void> {
  try {
    const rustAccount: RustAccountInput = {
      id: account.id,
      username: account.userInfo.username,
      nickname: account.userInfo.nickname,
      avatar: account.userInfo.avatar || null,
      avatar_object_key: account.userInfo.avatarObjectKey || null,
      avatar_local_path: account.userInfo.avatarLocalPath || null,
      mobile: null,
      email: null,
      token: account.token
    }

    await invoke('account_add', { account: rustAccount })
  } catch (error) {
    console.error('添加账号到 Rust 失败:', error)
    throw error
  }
}

/**
 * 从 Rust SQLite 加载所有账号
 */
async function loadAccountsFromRust(): Promise<AccountInfo[]> {
  try {
    const accounts = await invoke<RustAccountOutput[]>('account_get_all')
    return accounts.map(acc => ({
      id: acc.id,
      token: acc.token,
      userInfo: {
        id: acc.id,
        username: acc.username,
        nickname: acc.nickname,
        avatar: acc.avatar || '',
        avatarObjectKey: acc.avatar_object_key || null,
        avatarLocalPath: acc.avatar_local_path || null
      },
      unreadCount: 0, // 暂时设为 0，后续可以从设置中加载
      friendRequestCount: 0, // 暂时设为 0，后续可以从设置中加载
      createdAt: acc.created_at
    }))
  } catch (error) {
    console.error('从 Rust 加载账号列表失败:', error)
    return []
  }
}

/**
 * 设置当前账号到 Rust SQLite
 */
async function setCurrentAccountInRust(accountId: string): Promise<void> {
  try {
    await invoke('account_set_current', { accountId })
  } catch (error) {
    console.error('设置当前账号失败:', error)
    throw error
  }
}

/**
 * 从 Rust SQLite 加载当前账号
 */
async function loadCurrentAccountFromRust(): Promise<string | null> {
  try {
    const account = await invoke<RustAccountOutput | null>('account_get_current')
    return account ? account.id : null
  } catch (error) {
    console.error('加载当前账号失败:', error)
    return null
  }
}

/**
 * 从 Rust SQLite 移除账号
 */
async function removeAccountFromRust(accountId: string): Promise<void> {
  try {
    await invoke('account_remove', { accountId })
  } catch (error) {
    console.error('移除账号失败:', error)
    throw error
  }
}

export default accountsModule
