import { describe, expect, it, vi } from 'vitest'

const {
  indexMessageMock,
  indexMessagesMock,
  removeMessageIndexMock,
  clearAllIndicesMock,
  searchMessagesMock,
  getSearchSuggestionsMock,
  getSearchStatsMock,
  optimizeSearchDbMock
} = vi.hoisted(() => ({
  indexMessageMock: vi.fn(),
  indexMessagesMock: vi.fn().mockResolvedValue(undefined),
  removeMessageIndexMock: vi.fn().mockResolvedValue(undefined),
  clearAllIndicesMock: vi.fn().mockResolvedValue(undefined),
  searchMessagesMock: vi.fn(),
  getSearchSuggestionsMock: vi.fn(),
  getSearchStatsMock: vi.fn(),
  optimizeSearchDbMock: vi.fn()
}))

vi.mock('@/api/search', () => ({
  SearchApi: {
    indexMessage: indexMessageMock,
    indexMessages: indexMessagesMock,
    removeMessageIndex: removeMessageIndexMock,
    clearAllIndices: clearAllIndicesMock,
    searchMessages: searchMessagesMock,
    getSearchSuggestions: getSearchSuggestionsMock,
    getSearchStats: getSearchStatsMock,
    optimizeSearchDb: optimizeSearchDbMock
  },
  SearchUtils: {
    messageToIndex: (message: any, roomName: string, roomId?: string) => ({
      id: message.id,
      roomName,
      roomId
    })
  }
}))

import { MessageSearchService } from '@/services/messageSearchService'

describe('message search service', () => {
  it('indexes messages in batches', async () => {
    const service = MessageSearchService.getInstance()
    const messages = Array.from({ length: 120 }, (_, index) => ({
      id: `m-${index}`
    }))

    await service.indexMessages(messages as any, '群聊', 'room-1')

    expect(indexMessagesMock).toHaveBeenCalledTimes(2)
    expect(indexMessagesMock.mock.calls[0][0]).toHaveLength(100)
    expect(indexMessagesMock.mock.calls[1][0]).toHaveLength(20)
  })

  it('removes and clears index via api bridge', async () => {
    const service = MessageSearchService.getInstance()

    await service.removeMessageIndex('m-1')
    await service.clearAllIndices()

    expect(removeMessageIndexMock).toHaveBeenCalledWith('m-1')
    expect(clearAllIndicesMock).toHaveBeenCalledTimes(1)
  })
})
