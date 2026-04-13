import { beforeEach, describe, expect, it, vi } from 'vitest'

const { invokeMock, saveCacheMock, loadCacheMock } = vi.hoisted(() => ({
  invokeMock: vi.fn(),
  saveCacheMock: vi.fn().mockResolvedValue(undefined),
  loadCacheMock: vi.fn().mockResolvedValue(null),
}))

vi.mock('@tauri-apps/api/core', () => ({
  invoke: invokeMock,
}))

vi.mock('@/utils/cache', async () => {
  const actual = await vi.importActual<typeof import('@/utils/cache')>('@/utils/cache')
  return {
    ...actual,
    saveCache: saveCacheMock,
    loadCache: loadCacheMock,
  }
})

import store, { type ChatItem } from '@/store'
import { CACHE_KEYS } from '@/utils/cache'

const createChat = (overrides: Partial<ChatItem> = {}): ChatItem => ({
  id: 'chat-1',
  roomId: 'room-1',
  name: 'Alice',
  avatar: null,
  avatarLocalPath: null,
  lastMessage: 'hello',
  time: '12:30',
  groupId: 'room-1',
  unreadCount: 3,
  isTop: false,
  groupType: 0,
  ...overrides,
})

describe('chat cache persistence actions', () => {
  beforeEach(() => {
    saveCacheMock.mockClear()
    loadCacheMock.mockReset()
    loadCacheMock.mockResolvedValue(null)

    store.replaceState({
      ...store.state,
      currentChatGroupId: null,
      chatList: {
        ...store.state.chatList,
        list: [],
        loading: false,
        error: null,
        lastUpdateTime: 0,
      },
      accounts: {
        ...store.state.accounts,
        accounts: [],
        currentAccountId: null,
      },
    })
  })

  it('updateChatItem persists updated chat list snapshot', async () => {
    store.commit('SET_CHAT_LIST', [createChat()])

    await store.dispatch('updateChatItem', createChat({
      unreadCount: 0,
      lastMessage: 'updated',
      lastMessageId: 'msg-2',
    }))

    expect(saveCacheMock).toHaveBeenCalledWith(
      CACHE_KEYS.chatList,
      expect.arrayContaining([
        expect.objectContaining({
          id: 'chat-1',
          unreadCount: 0,
          lastMessage: 'updated',
          lastMessageId: 'msg-2',
        }),
      ]),
    )
  })

  it('setChatUnreadCount persists unread changes to chat cache', async () => {
    store.commit('SET_CHAT_LIST', [createChat()])

    await store.dispatch('setChatUnreadCount', {
      groupId: 'room-1',
      unreadCount: 0,
    })

    expect(saveCacheMock).toHaveBeenCalledWith(
      CACHE_KEYS.chatList,
      expect.arrayContaining([
        expect.objectContaining({
          id: 'chat-1',
          unreadCount: 0,
        }),
      ]),
    )
  })
})
