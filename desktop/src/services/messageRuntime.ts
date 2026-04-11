export type ServerStorageMode = 'persist' | 'relay_only'
export type ContentAuditMode = 'plaintext' | 'e2ee'

export interface MessageRuntimeSettings {
  serverStorageMode: ServerStorageMode
  contentAuditMode: ContentAuditMode
}

export interface GeneralSettingsPayload {
  app_name?: string | null
  server_storage_mode?: string | null
  content_audit_mode?: string | null
}

export interface ResolvedGeneralSettingsPayload {
  appName: string
  messageRuntime: MessageRuntimeSettings
}

export interface MessageRuntimeCapabilities {
  isRelayOnly: boolean
  isPersist: boolean
  isPlaintext: boolean
  isE2ee: boolean
  canQuote: boolean
  canForward: boolean
  canPin: boolean
  canDelete: boolean
  canReact: boolean
  canServerSearch: boolean
  canServerReadSync: boolean
}

export const DEFAULT_APP_NAME = 'Chatly'

export const DEFAULT_MESSAGE_RUNTIME: MessageRuntimeSettings = Object.freeze({
  serverStorageMode: 'persist',
  contentAuditMode: 'plaintext',
})

const normalizeServerStorageMode = (value?: string | null): ServerStorageMode => {
  return value === 'relay_only' ? 'relay_only' : DEFAULT_MESSAGE_RUNTIME.serverStorageMode
}

const normalizeContentAuditMode = (value?: string | null): ContentAuditMode => {
  return value === 'e2ee' ? 'e2ee' : DEFAULT_MESSAGE_RUNTIME.contentAuditMode
}

const normalizeAppName = (primary?: string | null, fallback?: string | null): string => {
  const preferred = typeof primary === 'string' ? primary.trim() : ''
  if (preferred) {
    return preferred
  }

  const backup = typeof fallback === 'string' ? fallback.trim() : ''
  if (backup) {
    return backup
  }

  return DEFAULT_APP_NAME
}

export const resolveGeneralSettingsPayload = (
  payload?: GeneralSettingsPayload | null,
  fallbackAppName?: string | null,
): ResolvedGeneralSettingsPayload => {
  return {
    appName: normalizeAppName(payload?.app_name, fallbackAppName),
    messageRuntime: {
      serverStorageMode: normalizeServerStorageMode(payload?.server_storage_mode),
      contentAuditMode: normalizeContentAuditMode(payload?.content_audit_mode),
    },
  }
}

export const serializeGeneralSettingsPayload = (
  payload: ResolvedGeneralSettingsPayload,
): GeneralSettingsPayload => {
  return {
    app_name: payload.appName,
    server_storage_mode: payload.messageRuntime.serverStorageMode,
    content_audit_mode: payload.messageRuntime.contentAuditMode,
  }
}

export const getMessageRuntimeCapabilities = (
  runtime: MessageRuntimeSettings,
): MessageRuntimeCapabilities => {
  const isRelayOnly = runtime.serverStorageMode === 'relay_only'
  const isPersist = runtime.serverStorageMode === 'persist'
  const isPlaintext = runtime.contentAuditMode === 'plaintext'
  const isE2ee = runtime.contentAuditMode === 'e2ee'

  return {
    isRelayOnly,
    isPersist,
    isPlaintext,
    isE2ee,
    canQuote: isPersist,
    canForward: isPersist,
    canPin: isPersist,
    canDelete: isPersist,
    canReact: isPersist,
    canServerSearch: isPersist,
    canServerReadSync: isPersist,
  }
}
