import { describe, expect, it, vi } from 'vitest'

const { postMock } = vi.hoisted(() => ({
  postMock: vi.fn(),
}))

vi.mock('@/api/http', () => ({
  post: postMock,
  get: vi.fn(),
  patch: vi.fn(),
  del: vi.fn(),
}))

import { MessageApi, transformBackendMessage } from '@/api/message'

const buildBackendMessage = (overrides: Record<string, unknown> = {}) => ({
  id: 'msg-1',
  room_id: 'room-1',
  sender_id: 'u-1',
  sender_username: 'alice',
  sender_nickname: ' Alice ',
  sender_avatar_url: 'avatars/alice.png',
  content: 'hello',
  message_type: 'text',
  status: 'sent',
  created_at: '2026-03-05T00:00:00Z',
  ...overrides,
})

describe('message api transform and send', () => {
  it('transformBackendMessage maps relative avatar key and invalid timestamp fallback', () => {
    const before = Date.now()

    const transformed = transformBackendMessage(
      buildBackendMessage({ created_at: 'invalid-date' }) as any,
      'u-1'
    )

    expect(transformed.senderName).toBe('Alice')
    expect(transformed.senderAvatarObjectKey).toBe('avatars/alice.png')
    expect(transformed.senderAvatar).toBeUndefined()
    expect(transformed.isSelf).toBe(true)
    expect(Number.isNaN(transformed.timestamp.getTime())).toBe(false)
    expect(transformed.timestamp.getTime()).toBeGreaterThanOrEqual(before)
  })

  it('sendMessage blocks empty payload before request', async () => {
    postMock.mockReset()

    const result = await MessageApi.sendMessage({
      groupId: 'room-1',
      content: '   ',
    })

    expect(result.success).toBe(false)
    expect(result.code).toBe(400)
    expect(result.message).toBe('消息内容不能为空')
    expect(postMock).not.toHaveBeenCalled()
  })

  it('sendMessage returns backend error when success flag is false in payload', async () => {
    postMock.mockResolvedValue({
      code: 200,
      success: true,
      message: 'ok',
      data: {
        success: false,
        message: 'content blocked',
      },
    })

    const result = await MessageApi.sendMessage({
      groupId: 'room-1',
      content: 'hello',
    })

    expect(result.success).toBe(false)
    expect(result.message).toBe('content blocked')
    expect(result.data).toBeNull()
  })

  it('sendMessage reports incomplete payload when response has no message id', async () => {
    postMock.mockResolvedValue({
      code: 200,
      success: true,
      message: 'ok',
      data: {
        message: {
          content: 'hello',
        },
      },
    })

    const result = await MessageApi.sendMessage({
      groupId: 'room-1',
      content: 'hello',
    })

    expect(result.success).toBe(false)
    expect(result.message).toBe('消息发送结果不完整')
    expect(result.data).toBeNull()
  })

  it('sendMessage unwraps backend message payload on success', async () => {
    postMock.mockResolvedValue({
      code: 200,
      success: true,
      message: 'sent',
      data: {
        message: buildBackendMessage({ id: 'msg-2', sender_id: 'u-2' }),
      },
    })

    const result = await MessageApi.sendMessage({
      groupId: 'room-1',
      content: 'hello world',
      currentUserId: 'u-1',
    })

    expect(result.success).toBe(true)
    expect(result.data?.id).toBe('msg-2')
    expect(result.data?.isSelf).toBe(false)
    expect(result.data?.senderAvatarObjectKey).toBe('avatars/alice.png')
  })
})
