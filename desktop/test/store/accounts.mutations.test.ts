import { describe, expect, it } from 'vitest'

import accountsModule, {
  type AccountInfo,
  type AccountsState
} from '@/store/modules/accounts'

const createAccount = (id: string): AccountInfo => ({
  id,
  token: `token-${id}`,
  refreshToken: null,
  userInfo: {
    id,
    username: `user-${id}`,
    nickname: `nick-${id}`,
    avatar: '',
    avatarObjectKey: null,
    avatarLocalPath: null
  },
  unreadCount: 0,
  friendRequestCount: 0,
  createdAt: Date.now()
})

const createState = (): AccountsState => accountsModule.state()

describe('accounts module mutations', () => {
  it('adds first account and sets it as current account', () => {
    const state = createState()

    accountsModule.mutations.ADD_ACCOUNT(state, createAccount('a1'))

    expect(state.accounts).toHaveLength(1)
    expect(state.currentAccountId).toBe('a1')
  })

  it('prevents duplicate account id and keeps current account stable', () => {
    const state = createState()

    accountsModule.mutations.ADD_ACCOUNT(state, createAccount('a1'))
    accountsModule.mutations.ADD_ACCOUNT(state, createAccount('a1'))

    expect(state.accounts).toHaveLength(1)
    expect(state.currentAccountId).toBe('a1')
  })

  it('removes current account and switches to next account', () => {
    const state = createState()

    accountsModule.mutations.ADD_ACCOUNT(state, createAccount('a1'))
    accountsModule.mutations.ADD_ACCOUNT(state, createAccount('a2'))

    accountsModule.mutations.REMOVE_ACCOUNT(state, 'a1')

    expect(state.accounts.map((account) => account.id)).toEqual(['a2'])
    expect(state.currentAccountId).toBe('a2')
  })

  it('saves page and route state for account', () => {
    const state = createState()

    accountsModule.mutations.ADD_ACCOUNT(state, createAccount('a1'))

    accountsModule.mutations.SAVE_ACCOUNT_PAGE_STATE(state, {
      accountId: 'a1',
      pageState: {
        route: {
          path: '/home/privacy',
          name: 'Privacy',
          params: {},
          query: {}
        },
        pageState: {
          currentChatGroupId: null
        }
      }
    })

    accountsModule.mutations.SAVE_ACCOUNT_ROUTE_STATE(state, {
      accountId: 'a1',
      routeState: {
        path: '/home/settings',
        name: 'Settings',
        params: {},
        query: {}
      }
    })

    expect(state.accounts[0].pageState?.route.path).toBe('/home/privacy')
    expect(state.accounts[0].routeState?.path).toBe('/home/settings')
  })
})
