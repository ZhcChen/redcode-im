import { describe, expect, it, vi } from 'vitest'

const { invokeMock } = vi.hoisted(() => ({
  invokeMock: vi.fn()
}))

vi.mock('@tauri-apps/api/core', () => ({
  invoke: invokeMock
}))

import accountsModule, {
  type AccountInfo,
  type AccountsState,
} from '@/store/modules/accounts'

const createAccount = (id: string): AccountInfo => ({
  id,
  token: `token-${id}`,
  refreshToken: `refresh-${id}`,
  userInfo: {
    id,
    username: `user-${id}`,
    nickname: `nick-${id}`,
    avatar: '',
    avatarObjectKey: null,
    avatarLocalPath: null,
  },
  unreadCount: 0,
  friendRequestCount: 0,
  createdAt: Date.now(),
})

const createState = (...ids: string[]): AccountsState => {
  const state = accountsModule.state()
  state.accounts = ids.map(createAccount)
  state.currentAccountId = ids.length > 0 ? ids[0] : null
  return state
}

describe('accounts module actions', () => {
  it('syncAccountUnreadCount excludes muted chats', () => {
    const commit = vi.fn()
    const state = createState('a1')

    accountsModule.actions.syncAccountUnreadCount(
      {
        commit,
        state,
        rootGetters: {
          chatList: [
            { unreadCount: 5, chatStatus: 0 },
            { unreadCount: 8, chatStatus: 1 },
            { unreadCount: 2 },
          ],
        },
      } as any,
      'a1'
    )

    expect(commit).toHaveBeenCalledWith('UPDATE_UNREAD_COUNT', {
      accountId: 'a1',
      count: 7,
    })
  })

  it('saveCurrentAccountPageState saves routeState only when multi-account', () => {
    const singleCommit = vi.fn()

    accountsModule.actions.saveCurrentAccountPageState(
      {
        commit: singleCommit,
        state: createState('a1'),
        rootState: { currentChatGroupId: 'room-1' },
      } as any,
      {
        path: '/home/chat',
        name: 'Chat',
        params: { roomId: 'room-1' },
        query: { tab: 'all' },
      }
    )

    expect(singleCommit).toHaveBeenCalledWith(
      'SAVE_ACCOUNT_PAGE_STATE',
      expect.objectContaining({ accountId: 'a1' })
    )
    expect(singleCommit).not.toHaveBeenCalledWith(
      'SAVE_ACCOUNT_ROUTE_STATE',
      expect.anything()
    )

    const multiCommit = vi.fn()
    accountsModule.actions.saveCurrentAccountPageState(
      {
        commit: multiCommit,
        state: createState('a1', 'a2'),
        rootState: { currentChatGroupId: null },
      } as any,
      { path: '/home/settings', name: 'Settings', params: {}, query: {} }
    )

    expect(multiCommit).toHaveBeenCalledWith(
      'SAVE_ACCOUNT_PAGE_STATE',
      expect.objectContaining({ accountId: 'a1' })
    )
    expect(multiCommit).toHaveBeenCalledWith(
      'SAVE_ACCOUNT_ROUTE_STATE',
      expect.objectContaining({ accountId: 'a1' })
    )
  })

  it('reorderAccounts ignores invalid ids and commits valid order', async () => {
    const state = createState('a1', 'a2')
    const commit = vi.fn()
    invokeMock.mockReset()
    invokeMock.mockResolvedValue(null)

    await accountsModule.actions.reorderAccounts(
      { commit, state } as any,
      ['a1']
    )

    expect(invokeMock).not.toHaveBeenCalled()
    expect(commit).not.toHaveBeenCalled()

    await accountsModule.actions.reorderAccounts(
      { commit, state } as any,
      ['a2', 'a1']
    )

    expect(invokeMock).toHaveBeenCalledWith(
      'account_update_order',
      expect.objectContaining({
        accountOrders: expect.arrayContaining([
          ['a2', expect.any(Number)],
          ['a1', expect.any(Number)],
        ]),
      })
    )
    expect(commit).toHaveBeenCalledWith('REORDER_ACCOUNTS', ['a2', 'a1'])
  })
})
