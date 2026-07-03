import { beforeEach, describe, expect, it, vi } from 'vitest'

const { postMock } = vi.hoisted(() => ({
  postMock: vi.fn()
}))

vi.mock('@/api/http', () => ({
  get: vi.fn(),
  post: postMock
}))

import { SystemApi } from '@/api/system'

describe('system auth api', () => {
  beforeEach(() => {
    postMock.mockReset()
  })

  it('register posts username/password without captcha code', async () => {
    postMock.mockResolvedValue({
      success: true,
      data: {
        id: 'user-1',
        username: 'alice',
        email: 'alice@account.redcode.local',
        nickname: 'Alice',
        avatar_url: null,
        avatar_object_key: null,
        status: 'active'
      }
    })

    await SystemApi.register({
      username: 'alice',
      password: 'pass123456',
      nickname: 'Alice'
    })

    expect(postMock).toHaveBeenCalledWith('/auth/register', {
      username: 'alice',
      password: 'pass123456',
      nickname: 'Alice'
    })
  })
})
