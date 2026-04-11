import type { Message } from '@/types/models'

import type { MessageRuntimeSettings } from './messageRuntime'

export const shouldUseLocalOnlyMessageHistory = (
  runtime: MessageRuntimeSettings,
): boolean => runtime.serverStorageMode === 'relay_only'

const mergeMessagesWithCache = (
  backendMessages: Message[],
  cachedMessages: Message[],
): Message[] => {
  if (!cachedMessages || cachedMessages.length === 0) {
    return backendMessages
  }

  const cacheMap = new Map<string, Message>()
  cachedMessages.forEach((msg) => {
    cacheMap.set(msg.id, msg)
  })

  return backendMessages.map((backendMsg) => {
    const cachedMsg = cacheMap.get(backendMsg.id)
    if (!cachedMsg) {
      return backendMsg
    }

    if (Array.isArray(backendMsg.parts) && Array.isArray(cachedMsg.parts)) {
      const mergedParts = backendMsg.parts.map((backendPart, index) => {
        const cachedPart = cachedMsg.parts?.[index]
        if (!cachedPart?.attachment || !backendPart?.attachment) {
          return backendPart
        }

        const mergedAttachment = {
          ...cachedPart.attachment,
          key: backendPart.attachment.key,
          name: backendPart.attachment.name,
          mime: backendPart.attachment.mime,
          size: backendPart.attachment.size,
          width: backendPart.attachment.width,
          height: backendPart.attachment.height,
          durationMs: backendPart.attachment.durationMs,
          thumbnailKey: backendPart.attachment.thumbnailKey,
          localPath: cachedPart.attachment.localPath,
          downloadUrl: cachedPart.attachment.downloadUrl,
          uploadProgress: cachedPart.attachment.uploadProgress,
          downloadProgress: cachedPart.attachment.downloadProgress,
        }

        return {
          ...backendPart,
          attachment: mergedAttachment,
        }
      })

      return {
        ...backendMsg,
        parts: mergedParts,
      }
    }

    return backendMsg
  })
}

export const resolveMessageHistoryForRuntime = (
  runtime: MessageRuntimeSettings,
  backendMessages: Message[],
  cachedMessages: Message[],
): Message[] => {
  if (shouldUseLocalOnlyMessageHistory(runtime)) {
    return cachedMessages
  }

  return mergeMessagesWithCache(backendMessages, cachedMessages)
}
