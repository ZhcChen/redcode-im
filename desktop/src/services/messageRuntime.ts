import { MessagePartType, MessageReactionSummary, MessageStatus, MessageType } from '@/types/models'

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

export interface MessageRuntimeNotice {
  title: string
  description: string
}

export type RuntimeChatSummaryShape = {
  lastMessage: string
  unreadCount: number
  lastMessageId?: string | null
}

export interface RuntimeCachedMessagePartShape {
  type?: string | null
  text?: string | null
}

export interface RuntimeCachedMessageReactionShape extends Pick<MessageReactionSummary, 'reactionKey' | 'count' | 'userIds' | 'hasSelf'> {}

export interface RuntimeCachedMessageShape {
  id?: string | null
  content?: string | null
  type?: string | null
  status?: string | null
  timestamp?: string | number | Date | null
  isSelf?: boolean
  isDeleted?: boolean
  pinnedAt?: string | number | Date | null
  pinnedBy?: string | null
  parts?: RuntimeCachedMessagePartShape[] | null
  reactions?: RuntimeCachedMessageReactionShape[] | null
}

export interface RuntimeMessageUpdatePayload {
  messageId: string
  updateType?: string | null
  isDeleted?: boolean
  content?: string | null
  editedAt?: string | number | Date | null
  deletedAt?: string | number | Date | null
}

export interface RuntimePinnedStatePayload {
  isPinned: boolean
  pinnedAt?: string | number | Date | null
  pinnedBy?: string | null
}

export interface RelayOnlyLocalChatSummary {
  lastMessage: string
  unreadCount: number
  lastMessageId: string | null
  lastMessageTime: Date | null
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

export const getMessageRuntimeNotice = (
  runtime: MessageRuntimeSettings,
): MessageRuntimeNotice => {
  const title = runtime.contentAuditMode === 'e2ee'
    ? '当前配置目标：端到端加密'
    : '当前配置目标：明文可审计'

  if (runtime.serverStorageMode === 'relay_only') {
    return runtime.contentAuditMode === 'e2ee'
      ? {
          title,
          description: '服务器仅做实时转发且不保存聊天记录，按当前配置目标不应被服务端审计。',
        }
      : {
          title,
          description: '服务器仅做实时转发且不保存聊天记录，消息内容仍可被服务端审计。',
        }
  }

  return runtime.contentAuditMode === 'e2ee'
    ? {
        title,
        description: '消息会保存在服务器，按当前配置目标不应被服务端审计。',
      }
    : {
        title,
        description: '消息会保存在服务器，管理员可审计消息内容。',
      }
}

export const sanitizeChatSummaryForRuntime = <T extends RuntimeChatSummaryShape>(
  runtime: MessageRuntimeSettings,
  chat: T,
): T => {
  if (runtime.serverStorageMode !== 'relay_only') {
    return chat
  }

  return {
    ...chat,
    lastMessage: '',
    unreadCount: 0,
    lastMessageId: null,
  }
}

export const sanitizeChatSummariesForRuntime = <T extends RuntimeChatSummaryShape>(
  runtime: MessageRuntimeSettings,
  chats: T[],
): T[] => chats.map((chat) => sanitizeChatSummaryForRuntime(runtime, chat))

export const didEnterRelayOnlyMode = (
  previous: MessageRuntimeSettings,
  next: MessageRuntimeSettings,
): boolean => {
  return previous.serverStorageMode !== 'relay_only' && next.serverStorageMode === 'relay_only'
}

export const getRelayOnlyLocalPreview = (
  message?: RuntimeCachedMessageShape | null,
): string => {
  if (!message) {
    return ''
  }

  if (message.isDeleted) {
    return '[消息已删除]'
  }

  if (Array.isArray(message.parts) && message.parts.length > 0) {
    const segments: string[] = []
    message.parts.forEach((part) => {
      switch (part?.type) {
        case MessagePartType.TEXT:
          if (typeof part?.text === 'string' && part.text.trim()) {
            segments.push(part.text.trim())
          }
          break
        case MessagePartType.IMAGE:
          segments.push('[图片]')
          break
        case MessagePartType.VIDEO:
          segments.push('[视频]')
          break
        case MessagePartType.AUDIO:
          segments.push('[语音]')
          break
        case MessagePartType.FILE:
          segments.push('[附件]')
          break
      }
    })

    if (segments.length > 0) {
      return segments.join(' ')
    }
  }

  switch (message.type) {
    case MessageType.IMAGE:
      return '[图片]'
    case MessageType.VIDEO:
      return '[视频]'
    case MessageType.VOICE:
      return '[语音]'
    case MessageType.FILE:
      return '[附件]'
    case MessageType.SYSTEM:
      return '[系统消息]'
  }

  const text = typeof message.content === 'string' ? message.content.trim() : ''
  if (text.startsWith('[图片]')) return '[图片]'
  if (text.startsWith('[视频]')) return '[视频]'
  if (text.startsWith('[语音]')) return '[语音]'
  if (text.startsWith('[文件]')) return '[附件]'

  return text || '[消息]'
}

export const resolveRelayOnlyLocalChatSummary = (
  messages: RuntimeCachedMessageShape[],
  isFavoriteRoom = false,
): RelayOnlyLocalChatSummary | null => {
  if (!Array.isArray(messages) || messages.length === 0) {
    return null
  }

  const sortedMessages = messages
    .slice()
    .sort((left, right) => new Date(left?.timestamp || 0).getTime() - new Date(right?.timestamp || 0).getTime())

  const latestMessage = sortedMessages[sortedMessages.length - 1]

  return {
    lastMessage: getRelayOnlyLocalPreview(latestMessage),
    unreadCount: isFavoriteRoom
      ? 0
      : sortedMessages.filter((message) =>
          !message?.isSelf &&
          !message?.isDeleted &&
          message?.status !== MessageStatus.READ
        ).length,
    lastMessageId: latestMessage?.id ?? null,
    lastMessageTime: latestMessage?.timestamp ? new Date(latestMessage.timestamp) : null,
  }
}

const normalizeRuntimeReactionSummaries = (
  reactions?: RuntimeCachedMessageReactionShape[] | null,
): RuntimeCachedMessageReactionShape[] => {
  if (!Array.isArray(reactions)) {
    return []
  }

  return reactions.map((reaction) => ({
    reactionKey: reaction.reactionKey,
    count: reaction.count,
    userIds: Array.isArray(reaction.userIds) ? [...reaction.userIds] : [],
    hasSelf: Boolean(reaction.hasSelf),
  }))
}

const updateCachedMessageById = <T extends RuntimeCachedMessageShape>(
  messages: T[],
  messageId: string,
  updater: (message: T) => T,
): T[] => {
  if (!Array.isArray(messages) || messages.length === 0 || !messageId) {
    return Array.isArray(messages) ? messages.slice() : []
  }

  const index = messages.findIndex((message) => message?.id === messageId)
  if (index === -1) {
    return messages.slice()
  }

  const next = messages.slice()
  next[index] = updater(messages[index])
  return next
}

const normalizeRuntimeUpdateTimestamp = (
  value?: string | number | Date | null,
): string | number | Date | null | undefined => {
  if (value == null) {
    return value
  }

  if (value instanceof Date) {
    return value
  }

  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value)
    return Number.isNaN(parsed.getTime()) ? value : parsed
  }

  return value
}

export const applyMessageUpdateToCachedMessages = <T extends RuntimeCachedMessageShape>(
  messages: T[],
  payload: RuntimeMessageUpdatePayload,
): T[] => {
  const normalizedType = typeof payload.updateType === 'string'
    ? payload.updateType.trim().toLowerCase()
    : ''
  const isDeleteUpdate = payload.isDeleted === true || normalizedType === 'deleted'
  const isEditUpdate = !isDeleteUpdate && (normalizedType === 'edited' || payload.editedAt != null)

  return updateCachedMessageById(messages, payload.messageId, (target) => {
    const updated = {
      ...(target as T & Record<string, unknown>),
    } as T
    const mutableUpdated = updated as Record<string, unknown>

    if (isDeleteUpdate) {
      updated.isDeleted = true
      if (payload.deletedAt != null) {
        mutableUpdated['deletedAt'] = normalizeRuntimeUpdateTimestamp(payload.deletedAt)
      }
    } else if (isEditUpdate) {
      if (typeof payload.content === 'string') {
        updated.content = payload.content
      }
      mutableUpdated['isEdited'] = true
      if (payload.editedAt != null) {
        mutableUpdated['editedAt'] = normalizeRuntimeUpdateTimestamp(payload.editedAt)
      }
    }

    return updated as T
  })
}

export const applyMessageReactionsToCachedMessages = <T extends RuntimeCachedMessageShape>(
  messages: T[],
  messageId: string,
  reactions?: RuntimeCachedMessageReactionShape[] | null,
): T[] => {
  return updateCachedMessageById(messages, messageId, (target) => ({
    ...(target as T & Record<string, unknown>),
    reactions: normalizeRuntimeReactionSummaries(reactions),
  } as T))
}

export const applyMessagePinnedStateToCachedMessages = <T extends RuntimeCachedMessageShape>(
  messages: T[],
  messageId: string,
  payload: RuntimePinnedStatePayload,
): T[] => {
  return updateCachedMessageById(messages, messageId, (target) => ({
    ...(target as T & Record<string, unknown>),
    pinnedAt: payload.isPinned
      ? (normalizeRuntimeUpdateTimestamp(payload.pinnedAt ?? new Date()) ?? new Date())
      : null,
    pinnedBy: payload.isPinned ? (payload.pinnedBy ?? null) : null,
  } as T))
}
