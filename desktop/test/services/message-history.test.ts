import { describe, expect, it } from 'vitest'

import type { Message, MessageStatus, MessageType } from '@/types/models'
import {
  resolveMessageHistoryForRuntime,
  shouldUseLocalOnlyMessageHistory,
} from '@/services/messageHistory'

const buildMessage = (id: string): Message => ({
  id,
  roomId: 'room-1',
  senderId: 'user-1',
  senderUsername: 'alice',
  senderName: 'Alice',
  content: id,
  type: 'text' as MessageType,
  status: 'sent' as MessageStatus,
  timestamp: new Date('2026-04-11T00:00:00.000Z'),
  isSelf: false,
  isDeleted: false,
  parts: [],
})

describe('message history runtime helpers', () => {
  it('uses local-only history strategy in relay_only mode', () => {
    expect(
      shouldUseLocalOnlyMessageHistory({
        serverStorageMode: 'relay_only',
        contentAuditMode: 'plaintext',
      })
    ).toBe(true)

    expect(
      shouldUseLocalOnlyMessageHistory({
        serverStorageMode: 'persist',
        contentAuditMode: 'plaintext',
      })
    ).toBe(false)
  })

  it('prefers cached messages when relay_only mode disables server history', () => {
    const cached = [buildMessage('cached-1')]
    const server = [buildMessage('server-1')]

    expect(
      resolveMessageHistoryForRuntime(
        {
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        },
        server,
        cached,
      )
    ).toEqual(cached)

    expect(
      resolveMessageHistoryForRuntime(
        {
          serverStorageMode: 'persist',
          contentAuditMode: 'plaintext',
        },
        server,
        cached,
      )
    ).toEqual(server)
  })
})
