import { describe, expect, it, vi } from 'vitest'

const { getMock } = vi.hoisted(() => ({
  getMock: vi.fn()
}))

vi.mock('@/api/http', () => ({
  get: getMock
}))

import { searchMessagesFromServer } from '@/api/message-search'

describe('message search api', () => {
  it('maps server response and converts timestamp params to seconds', async () => {
    getMock.mockResolvedValue({
      success: true,
      data: {
        results: [
          {
            id: 'm1',
            room_id: 'r1',
            room_name: '测试群',
            sender_id: 'u1',
            sender_name: 'alice',
            content: 'hello world',
            message_type: 'text',
            timestamp: '2026-03-01T12:00:00Z',
            matched_text: 'hello',
            relevance_score: 0.9
          }
        ],
        stats: {
          total_results: 1,
          search_time_ms: 12,
          query: 'hello'
        },
        has_more: false
      }
    })

    const result = await searchMessagesFromServer({
      query: 'hello',
      roomId: 'r1',
      dateFrom: 1_700_000_000_000,
      dateTo: 1_700_000_600_000,
      limit: 20,
      offset: 0
    })

    expect(getMock).toHaveBeenCalledWith('/messages/search', {
      query: 'hello',
      limit: 20,
      offset: 0,
      room_id: 'r1',
      date_from: 1_700_000_000,
      date_to: 1_700_000_600
    })

    expect(result.results[0]).toMatchObject({
      id: 'm1',
      roomId: 'r1',
      senderName: 'alice',
      matchedText: 'hello'
    })
    expect(result.stats.totalResults).toBe(1)
    expect(result.hasMore).toBe(false)
  })

  it('falls back to Date.now when server timestamp is invalid', async () => {
    const nowSpy = vi.spyOn(Date, 'now').mockReturnValue(1_700_123_456_789)

    getMock.mockResolvedValue({
      success: true,
      data: {
        results: [
          {
            id: 'm2',
            room_id: 'r2',
            room_name: '测试群2',
            sender_id: 'u2',
            sender_name: 'bob',
            content: 'invalid ts',
            message_type: 'text',
            timestamp: 'not-a-date',
            relevance_score: 0.8
          }
        ],
        stats: {
          total_results: 1,
          search_time_ms: 10,
          query: 'invalid'
        },
        has_more: true
      }
    })

    const result = await searchMessagesFromServer({
      query: 'invalid',
      limit: 10,
      offset: 0
    })

    expect(result.results[0].timestamp).toBe(1_700_123_456_789)
    expect(result.hasMore).toBe(true)

    nowSpy.mockRestore()
  })

  it('throws when server response is unsuccessful', async () => {
    getMock.mockResolvedValue({
      success: false,
      message: 'search failed',
      data: null
    })

    await expect(
      searchMessagesFromServer({
        query: 'hello',
        limit: 10,
        offset: 0
      })
    ).rejects.toThrow('search failed')
  })
})
