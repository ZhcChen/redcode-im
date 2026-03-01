import { describe, expect, it, vi } from 'vitest'

const { invokeMock } = vi.hoisted(() => ({
  invokeMock: vi.fn()
}))

vi.mock('@tauri-apps/api/core', () => ({
  invoke: invokeMock
}))

import { WebSocketApi } from '@/api/websocket'

describe('websocket api', () => {
  it('connects with normalized params', async () => {
    await WebSocketApi.connect({ userId: 'u-1', token: 'token-1' }, 'ws://localhost:8010/ws')

    expect(invokeMock).toHaveBeenCalledWith('ws_connect', {
      params: {
        user_id: 'u-1',
        token: 'token-1'
      },
      wsUrl: 'ws://localhost:8010/ws'
    })
  })

  it('forwards join and status commands', async () => {
    invokeMock.mockResolvedValueOnce('authenticated')

    await WebSocketApi.joinRoom('room-1', 'u-1')
    await WebSocketApi.getStatus('u-1')

    expect(invokeMock).toHaveBeenNthCalledWith(1, 'ws_join_room', {
      roomId: 'room-1',
      userId: 'u-1'
    })
    expect(invokeMock).toHaveBeenNthCalledWith(2, 'ws_get_status', {
      userId: 'u-1'
    })
  })
})
