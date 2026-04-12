import { describe, expect, it } from 'vitest'

import { getMessageHistoryLocateMissNotice } from '@/services/messageHistory'

describe('message history notices', () => {
  it('returns relay_only-specific locate miss notice', () => {
    expect(
      getMessageHistoryLocateMissNotice({
        serverStorageMode: 'relay_only',
        contentAuditMode: 'plaintext',
      })
    ).toBe('当前模式不保存聊天记录，只能定位本地缓存中的消息')
  })

  it('returns generic locate miss notice for persisted history', () => {
    expect(
      getMessageHistoryLocateMissNotice({
        serverStorageMode: 'persist',
        contentAuditMode: 'plaintext',
      })
    ).toBe('当前未加载到该消息，可能已被删除或尚未同步')
  })
})
