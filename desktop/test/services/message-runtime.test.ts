import { describe, expect, it } from 'vitest'

import {
  DEFAULT_MESSAGE_RUNTIME,
  didEnterRelayOnlyMode,
  getRelayOnlyLocalPreview,
  getMessageRuntimeCapabilities,
  getMessageRuntimeNotice,
  resolveRelayOnlyLocalChatSummary,
  sanitizeChatSummaryForRuntime,
  sanitizeChatSummariesForRuntime,
  resolveGeneralSettingsPayload,
} from '@/services/messageRuntime'

describe('message runtime service', () => {
  it('resolves defaults and legacy app name fallback for general settings payload', () => {
    expect(
      resolveGeneralSettingsPayload(
        {
          app_name: '',
          server_storage_mode: 'relay_only',
          content_audit_mode: 'unknown',
        },
        'Legacy Chatly'
      )
    ).toEqual({
      appName: 'Legacy Chatly',
      messageRuntime: {
        serverStorageMode: 'relay_only',
        contentAuditMode: DEFAULT_MESSAGE_RUNTIME.contentAuditMode,
      },
    })
  })

  it('disables persistence-dependent actions in relay_only mode', () => {
    expect(
      getMessageRuntimeCapabilities({
        serverStorageMode: 'relay_only',
        contentAuditMode: 'plaintext',
      })
    ).toMatchObject({
      isRelayOnly: true,
      isPersist: false,
      isPlaintext: true,
      isE2ee: false,
      canQuote: false,
      canForward: false,
      canPin: false,
      canDelete: false,
      canReact: false,
      canServerSearch: false,
      canServerReadSync: false,
    })
  })



  it('builds runtime notice copy for plaintext and e2ee modes', () => {
    expect(
      getMessageRuntimeNotice({
        serverStorageMode: 'relay_only',
        contentAuditMode: 'plaintext',
      })
    ).toEqual({
      title: '当前配置目标：明文可审计',
      description: '服务器仅做实时转发且不保存聊天记录，消息内容仍可被服务端审计。',
    })

    expect(
      getMessageRuntimeNotice({
        serverStorageMode: 'persist',
        contentAuditMode: 'e2ee',
      })
    ).toEqual({
      title: '当前配置目标：端到端加密',
      description: '消息会保存在服务器，按当前配置目标不应被服务端审计。',
    })
  })

  it('preserves persist plus e2ee combinations', () => {
    expect(
      resolveGeneralSettingsPayload({
        app_name: 'Secure Chatly',
        server_storage_mode: 'persist',
        content_audit_mode: 'e2ee',
      })
    ).toEqual({
      appName: 'Secure Chatly',
      messageRuntime: {
        serverStorageMode: 'persist',
        contentAuditMode: 'e2ee',
      },
    })
  })

  it('sanitizes cached chat summary in relay_only mode', () => {
    expect(
      sanitizeChatSummaryForRuntime(
        {
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        },
        {
          id: 'room-1',
          groupId: 'room-1',
          lastMessage: 'stale summary',
          unreadCount: 9,
          lastMessageId: 'msg-1',
        },
      ),
    ).toMatchObject({
      lastMessage: '',
      unreadCount: 0,
      lastMessageId: null,
    })
  })

  it('sanitizes chat list only when runtime enters relay_only', () => {
    expect(
      didEnterRelayOnlyMode(
        {
          serverStorageMode: 'persist',
          contentAuditMode: 'plaintext',
        },
        {
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        },
      ),
    ).toBe(true)

    expect(
      didEnterRelayOnlyMode(
        {
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        },
        {
          serverStorageMode: 'relay_only',
          contentAuditMode: 'e2ee',
        },
      ),
    ).toBe(false)

    expect(
      sanitizeChatSummariesForRuntime(
        {
          serverStorageMode: 'relay_only',
          contentAuditMode: 'plaintext',
        },
        [
          {
            id: 'room-1',
            groupId: 'room-1',
            lastMessage: 'stale summary',
            unreadCount: 9,
            lastMessageId: 'msg-1',
          },
          {
            id: 'room-2',
            groupId: 'room-2',
            lastMessage: '',
            unreadCount: 0,
            lastMessageId: null,
          },
        ],
      ),
    ).toEqual([
      {
        id: 'room-1',
        groupId: 'room-1',
        lastMessage: '',
        unreadCount: 0,
        lastMessageId: null,
      },
      {
        id: 'room-2',
        groupId: 'room-2',
        lastMessage: '',
        unreadCount: 0,
        lastMessageId: null,
      },
    ])
  })

  it('rebuilds relay_only local summary from cached messages', () => {
    expect(
      getRelayOnlyLocalPreview({
        type: 'image',
        content: '',
      }),
    ).toBe('[图片]')

    expect(
      resolveRelayOnlyLocalChatSummary([
        {
          id: 'msg-1',
          type: 'text',
          content: 'hello',
          status: 'read',
          isSelf: false,
          timestamp: '2026-04-12T12:00:00.000Z',
        },
        {
          id: 'msg-2',
          type: 'image',
          content: '',
          status: 'sent',
          isSelf: false,
          timestamp: '2026-04-12T12:30:00.000Z',
        },
      ]),
    ).toEqual({
      lastMessage: '[图片]',
      unreadCount: 1,
      lastMessageId: 'msg-2',
      lastMessageTime: new Date('2026-04-12T12:30:00.000Z'),
    })
  })
})
