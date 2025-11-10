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
  }
  unreadCount: number // 未读消息数
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

      state.accounts.push({
        ...account,
        createdAt: Date.now()
      })

      // 如果是第一个账号，自动设为当前账号
      if (state.accounts.length === 1) {
        state.currentAccountId = account.id
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
      const account = state.accounts.find(acc => acc.id === payload.accountId)
      if (account) {
        account.unreadCount = payload.count
      }
    },

    /**
     * 增加账号未读数
     */
    INCREMENT_UNREAD_COUNT(state, accountId: string) {
      const account = state.accounts.find(acc => acc.id === accountId)
      if (account) {
        account.unreadCount++
      }
    },

    /**
     * 清空账号未读数
     */
    CLEAR_UNREAD_COUNT(state, accountId: string) {
      const account = state.accounts.find(acc => acc.id === accountId)
      if (account) {
        account.unreadCount = 0
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

      commit('ADD_ACCOUNT', account)

      // 保存到本地存储
      await saveAccountsToStorage(state.accounts)
    },

    /**
     * 移除账号（异步）
     */
    async removeAccount({ commit, state }, accountId: string) {
      commit('REMOVE_ACCOUNT', accountId)

      // 保存到本地存储
      await saveAccountsToStorage(state.accounts)
    },

    /**
     * 切换账号（异步）
     */
    async switchAccount({ commit, state }, accountId: string) {
      commit('SET_CURRENT_ACCOUNT', accountId)

      // 保存当前账号 ID 到本地存储
      await saveCurrentAccountId(accountId)
    },

    /**
     * 从本地存储恢复账号列表
     */
    async loadAccountsFromStorage({ commit }) {
      try {
        const accounts = await loadAccountsFromStorage()
        const currentAccountId = await loadCurrentAccountId()

        accounts.forEach(account => {
          commit('ADD_ACCOUNT', account)
        })

        if (currentAccountId && accounts.some(acc => acc.id === currentAccountId)) {
          commit('SET_CURRENT_ACCOUNT', currentAccountId)
        }
      } catch (error) {
        console.error('加载账号列表失败:', error)
      }
    },

    /**
     * 登出账号
     */
    async logoutAccount({ dispatch }, accountId: string) {
      // 通知 Rust 后端断开该账号的连接
      try {
        await window.ipc.invoke('logout_account', { account_id: accountId })
      } catch (error) {
        console.error('登出账号失败:', error)
      }

      // 移除账号
      await dispatch('removeAccount', accountId)
    }
  }
}

/**
 * 保存账号列表到本地存储
 */
async function saveAccountsToStorage(accounts: AccountInfo[]): Promise<void> {
  try {
    const accountsData = accounts.map(acc => ({
      id: acc.id,
      token: acc.token,
      userInfo: acc.userInfo,
      unreadCount: acc.unreadCount,
      createdAt: acc.createdAt
    }))

    localStorage.setItem('im_accounts', JSON.stringify(accountsData))
  } catch (error) {
    console.error('保存账号列表失败:', error)
  }
}

/**
 * 从本地存储加载账号列表
 */
async function loadAccountsFromStorage(): Promise<AccountInfo[]> {
  try {
    const data = localStorage.getItem('im_accounts')
    if (!data) return []

    return JSON.parse(data)
  } catch (error) {
    console.error('加载账号列表失败:', error)
    return []
  }
}

/**
 * 保存当前账号 ID 到本地存储
 */
async function saveCurrentAccountId(accountId: string): Promise<void> {
  try {
    localStorage.setItem('im_current_account_id', accountId)
  } catch (error) {
    console.error('保存当前账号 ID 失败:', error)
  }
}

/**
 * 从本地存储加载当前账号 ID
 */
async function loadCurrentAccountId(): Promise<string | null> {
  try {
    return localStorage.getItem('im_current_account_id')
  } catch (error) {
    console.error('加载当前账号 ID 失败:', error)
    return null
  }
}

export default accountsModule
