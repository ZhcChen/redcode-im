import type { ChatMessage, ChatQuotedMessage } from "@/api/chat";
import { canResendLocalMessage } from "./chat-local-message";

export const RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY =
  "desktop-el.retryable-local-messages";

export const buildRetryableLocalMessagesStorageKey = (userId?: string) =>
  userId
    ? `${RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY}:${userId}`
    : RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY;

type StorageLike = Pick<Storage, "getItem" | "setItem" | "removeItem">;

interface PersistedQuotedMessage
  extends Omit<ChatQuotedMessage, "createdAt"> {
  createdAt: string | null;
}

interface PersistedRetryableLocalMessage
  extends Omit<ChatMessage, "createdAt" | "quotedMessage" | "retryPayload"> {
  createdAt: string | null;
  quotedMessage: PersistedQuotedMessage | null;
  retryPayload: {
    content: string;
    quotedMessageId?: string | null;
  } | null;
}

const getDefaultStorage = (): StorageLike | null => {
  if (typeof window === "undefined") {
    return null;
  }
  return window.localStorage;
};

const serializeQuotedMessage = (
  message: ChatQuotedMessage | null,
): PersistedQuotedMessage | null => {
  if (!message) {
    return null;
  }

  return {
    ...message,
    createdAt: message.createdAt?.toISOString() ?? null,
  };
};

const deserializeQuotedMessage = (
  message: PersistedQuotedMessage | null,
): ChatQuotedMessage | null => {
  if (!message) {
    return null;
  }

  return {
    ...message,
    createdAt: message.createdAt ? new Date(message.createdAt) : null,
  };
};

const isPersistableRetryableLocalMessage = (
  message: ChatMessage,
): boolean =>
  canResendLocalMessage(message) &&
  message.clientStatus === "failed" &&
  !message.retryPayload?.attachments?.length;

const serializeRetryableLocalMessage = (
  message: ChatMessage,
): PersistedRetryableLocalMessage | null => {
  if (!isPersistableRetryableLocalMessage(message)) {
    return null;
  }

  return {
    ...message,
    createdAt: message.createdAt?.toISOString() ?? null,
    quotedMessage: serializeQuotedMessage(message.quotedMessage),
    retryPayload: message.retryPayload
      ? {
          content: message.retryPayload.content,
          quotedMessageId: message.retryPayload.quotedMessageId ?? null,
        }
      : null,
  };
};

export const saveRetryableLocalMessages = (
  messages: ChatMessage[],
  storage: StorageLike | null = getDefaultStorage(),
  storageKey: string = RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY,
) => {
  if (!storage) {
    return;
  }

  const payload = messages
    .map(serializeRetryableLocalMessage)
    .filter(Boolean) as PersistedRetryableLocalMessage[];

  if (!payload.length) {
    storage.removeItem(storageKey);
    return;
  }

  try {
    storage.setItem(storageKey, JSON.stringify(payload));
  } catch {
    // Ignore storage write failures.
  }
};

export const restoreRetryableLocalMessages = (
  storage: StorageLike | null = getDefaultStorage(),
  storageKey: string = RETRYABLE_LOCAL_MESSAGES_STORAGE_KEY,
): ChatMessage[] => {
  if (!storage) {
    return [];
  }

  try {
    const raw = storage.getItem(storageKey);
    if (!raw) {
      return [];
    }

    const payload = JSON.parse(raw) as PersistedRetryableLocalMessage[];
    return payload
      .map((message) => ({
        ...message,
        createdAt: message.createdAt ? new Date(message.createdAt) : null,
        quotedMessage: deserializeQuotedMessage(message.quotedMessage),
        retryPayload: message.retryPayload
          ? {
              content: message.retryPayload.content,
              quotedMessageId: message.retryPayload.quotedMessageId ?? null,
            }
          : null,
      }))
      .filter((message) => canResendLocalMessage(message));
  } catch {
    return [];
  }
};
