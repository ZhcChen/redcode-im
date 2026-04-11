import { describe, expect, it } from 'vitest'

import {
  DEFAULT_MESSAGE_RUNTIME,
  getMessageRuntimeCapabilities,
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
})
