import { invoke } from '@tauri-apps/api/core'
import { apiConfig } from '@/api/config'

/**
 * 账号页面状态接口
 */
export interface AccountPageState {
  route: {
    path: string // 路由路径，如 '/home/chat', '/home/settings'
    name: string | null // 路由名称
    params: Record<string, any> // 路由参数
    query: Record<string, any> // 查询参数
  }
  pageState: {
    currentChatGroupId: string | null // 当前选中的聊天群组ID
    [key: string]: any // 其他页面特定状态
  }
}

/**
 * 账号路由状态接口
 */
export interface AccountRouteState {
  path: string // 路由路径，如 '/home/chat', '/home/settings'
  name: string | null // 路由名称
  params: Record<string, any> // 路由参数
  query: Record<string, any> // 查询参数
}

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
  pageState?: AccountPageState // 账号页面状态（可选，用于向后兼容）
  routeState?: AccountRouteState // 账号路由状态（用于多实例页面架构）
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
        return
      }

      // 检查账号是否已存在
      const exists = state.accounts.some(acc => acc.id === account.id)
      if (exists) {
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
    },

    /**
     * 保存账号页面状态
     */
    SAVE_ACCOUNT_PAGE_STATE(state, payload: { accountId: string; pageState: AccountPageState }) {
      const account = state.accounts.find(acc => acc.id === payload.accountId)
      if (account) {
        // 创建新对象以触发 Vue 响应式更新
        state.accounts = state.accounts.map(acc => {
          if (acc.id === payload.accountId) {
            return {
              ...acc,
              pageState: payload.pageState
            }
          }
          return acc
        })
      }
    },

    /**
     * 清除账号页面状态
     */
    CLEAR_ACCOUNT_PAGE_STATE(state, accountId: string) {
      const account = state.accounts.find(acc => acc.id === accountId)
      if (account) {
        state.accounts = state.accounts.map(acc => {
          if (acc.id === accountId) {
            const { pageState, ...rest } = acc
            return rest as AccountInfo
          }
          return acc
        })
      }
    },

    /**
     * 保存账号路由状态
     */
    SAVE_ACCOUNT_ROUTE_STATE(state, payload: { accountId: string; routeState: AccountRouteState }) {
      const account = state.accounts.find(acc => acc.id === payload.accountId)
      if (account) {
        // 创建新对象以触发 Vue 响应式更新
        state.accounts = state.accounts.map(acc => {
          if (acc.id === payload.accountId) {
            return {
              ...acc,
              routeState: payload.routeState
            }
          }
          return acc
        })
      }
    },

    /**
     * 清除账号路由状态
     */
    CLEAR_ACCOUNT_ROUTE_STATE(state, accountId: string) {
      const account = state.accounts.find(acc => acc.id === accountId)
      if (account) {
        state.accounts = state.accounts.map(acc => {
          if (acc.id === accountId) {
            const { routeState, ...rest } = acc
            return rest as AccountInfo
          }
          return acc
        })
      }
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
        return
      }

      const account = state.accounts.find(acc => acc.id === targetAccountId)
      if (!account) {
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
      } catch (error) {
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
        throw error
      }
    },

    /**
     * 同步账号未读数（根据聊天列表计算）
     * 注意：免打扰状态（chatStatus === 1）的聊天不计入未读数，不触发 Tab 闪烁提醒
     */
    syncAccountUnreadCount({ commit, state, rootGetters }, accountId: string) {
      // 获取聊天列表的总未读数（排除免打扰的聊天）
      const chatList = rootGetters.chatList || []
      const totalUnread = chatList.reduce((sum: number, chat: any) => {
        // chatStatus === 1 表示免打扰状态，不计入账号未读数
        if (chat.chatStatus === 1) {
          return sum
        }
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
     * 保存当前账号的页面状态
     */
    saveCurrentAccountPageState({ commit, state, rootState }, route: any) {
      if (!state.currentAccountId) {
        return
      }

      const pageState: AccountPageState = {
        route: {
          path: route.path || '/home/chat',
          name: route.name || null,
          params: route.params || {},
          query: route.query || {}
        },
        pageState: {
          currentChatGroupId: rootState.currentChatGroupId || null
        }
      }

      commit('SAVE_ACCOUNT_PAGE_STATE', {
        accountId: state.currentAccountId,
        pageState
      })

      // 同时保存路由状态（用于 AccountHome 组件，仅在多账号模式下需要）
      // 只有在有多个账号时才保存 routeState，避免单账号模式下的干扰
      if (state.accounts.length > 1) {
        const routeState: AccountRouteState = {
          path: route.path || '/home/chat',
          name: route.name || null,
          params: route.params || {},
          query: route.query || {}
        }

        commit('SAVE_ACCOUNT_ROUTE_STATE', {
          accountId: state.currentAccountId,
          routeState
        })
      }
    },

    /**
     * 恢复账号的页面状态
     */
    async restoreAccountPageState({ state }, accountId: string): Promise<AccountPageState | null> {
      const account = state.accounts.find(acc => acc.id === accountId)
      if (account && account.pageState) {
        return account.pageState
      }
      return null
    },

    /**
     * 保存账号路由状态
     */
    saveAccountRouteState({ commit, state }, payload: { accountId: string; routeState: AccountRouteState }) {
      commit('SAVE_ACCOUNT_ROUTE_STATE', payload)
    },

    /**
     * 获取账号路由状态
     */
    getAccountRouteState({ state }, accountId: string): AccountRouteState | null {
      const account = state.accounts.find(acc => acc.id === accountId)
      if (account && account.routeState) {
        return account.routeState
      }
      // 如果没有保存的路由状态，返回 null，让调用方决定使用默认值
      return null
    },

    /**
     * 更新当前账号的路由状态
     */
    updateCurrentAccountRouteState({ commit, state }, route: any) {
      if (!state.currentAccountId) {
        return
      }

      const routeState: AccountRouteState = {
        path: route.path || '/home/chat',
        name: route.name || null,
        params: route.params || {},
        query: route.query || {}
      }

      commit('SAVE_ACCOUNT_ROUTE_STATE', {
        accountId: state.currentAccountId,
        routeState
      })
    },

    /**
     * 刷新所有账号的未读数
     * 用于定期检查非当前账号的未读消息
     */
    async refreshAllAccountsUnreadCount({ commit, state, rootState }) {
      if (state.accounts.length === 0) {
        return
      }

      await Promise.all(
        state.accounts.map(async account => {
          try {
            // 使用 Rust 命令并行加载聊天列表和好友请求
            const loadResult = await invoke<{
              chats: any[];
              friend_requests: any[];
            }>('account_load_data', { token: account.token })
            const [chats, friendRequests] = [loadResult.chats, loadResult.friend_requests]

            // 处理聊天列表
            if (Array.isArray(chats)) {
              const totalUnread = chats.reduce((sum: number, chat: any) => {
                return sum + (chat.unread_count ?? chat.unreadCount ?? 0)
              }, 0)

              commit('UPDATE_UNREAD_COUNT', {
                accountId: account.id,
                count: totalUnread
              })
            }

            // 处理好友请求
            if (Array.isArray(friendRequests)) {
              const pendingCount = friendRequests.length
              commit('UPDATE_FRIEND_REQUEST_COUNT', {
                accountId: account.id,
                count: pendingCount
              })

              if (state.currentAccountId === account.id) {
                commit('SET_PENDING_FRIEND_REQUESTS', pendingCount, { root: true })
              }
            }
          } catch (error) {
          }
        })
      )
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
    throw error
  }
}

export default accountsModule
