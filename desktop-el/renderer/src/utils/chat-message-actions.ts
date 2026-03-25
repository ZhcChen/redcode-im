import type { ChatMessage } from "@/api/chat";

export const isLocalOnlyMessage = (message: ChatMessage) =>
  message.clientStatus === "sending" || message.clientStatus === "failed";

export const getMessageCopyText = (message: ChatMessage | null) => {
  if (!message) {
    return "";
  }

  const partText = message.parts
    .filter((part) => part.partType === "text" && part.text?.trim())
    .map((part) => part.text?.trim() ?? "")
    .filter(Boolean)
    .join("\n")
    .trim();
  if (partText) {
    return partText;
  }

  return message.content.trim();
};

export const canCopyMessage = (message: ChatMessage | null) =>
  Boolean(
    message &&
      message.messageType !== "system" &&
      !message.isDeleted &&
      getMessageCopyText(message),
  );

export const canEditMessage = (message: ChatMessage | null) =>
  Boolean(
    message &&
      message.isSelf &&
      !message.isDeleted &&
      !isLocalOnlyMessage(message) &&
      message.messageType === "text" &&
      getMessageCopyText(message),
  );

export const canReplyMessage = (message: ChatMessage | null) =>
  Boolean(
    message &&
      message.messageType !== "system" &&
      !message.isDeleted &&
      !isLocalOnlyMessage(message),
  );

export const canToggleMessagePin = (message: ChatMessage | null) =>
  Boolean(
    message &&
      message.messageType !== "system" &&
      !message.isDeleted &&
      !isLocalOnlyMessage(message),
  );

export const canToggleMessageReaction = (message: ChatMessage | null) =>
  Boolean(
    message &&
      message.messageType !== "system" &&
      !message.isDeleted &&
      !isLocalOnlyMessage(message),
  );

export const canForwardMessage = (message: ChatMessage | null) => {
  if (
    !message ||
    message.isDeleted ||
    message.messageType === "system" ||
    isLocalOnlyMessage(message)
  ) {
    return false;
  }
  if (message.content.trim()) {
    return true;
  }

  return message.parts.some((part) =>
    part.partType === "text"
      ? Boolean(part.text?.trim())
      : Boolean(part.attachment?.key),
  );
};

export const canViewMessageReaders = (message: ChatMessage | null) =>
  Boolean(
    message &&
      message.isSelf &&
      !message.isDeleted &&
      message.messageType !== "system" &&
      !isLocalOnlyMessage(message),
  );

export const canDeleteMessage = (message: ChatMessage | null) =>
  Boolean(
    message && message.isSelf && (!message.isDeleted || isLocalOnlyMessage(message)),
  );

export const getMessageDeleteLabel = (message: ChatMessage) =>
  isLocalOnlyMessage(message) ? "移除" : "撤回";

export const canSelectMessageForMultiSelect = (message: ChatMessage | null) =>
  Boolean(message && message.messageType !== "system");

export const getSelectedMessages = (
  messages: ChatMessage[],
  selectedMessageIds: Iterable<string>,
) => {
  const selectedIds = new Set(selectedMessageIds);
  return messages.filter((message) => selectedIds.has(message.id));
};

export const pruneSelectedMessageIds = (
  messages: ChatMessage[],
  selectedMessageIds: Iterable<string>,
) => {
  const selectableIds = new Set(
    messages
      .filter((message) => canSelectMessageForMultiSelect(message))
      .map((message) => message.id),
  );

  return new Set(
    Array.from(selectedMessageIds).filter((messageId) =>
      selectableIds.has(messageId),
    ),
  );
};

export const canForwardSelectedMessages = (messages: ChatMessage[]) =>
  messages.length > 0 && messages.every((message) => canForwardMessage(message));

export const canDeleteSelectedMessages = (messages: ChatMessage[]) =>
  messages.length > 0 && messages.every((message) => canDeleteMessage(message));

export const buildForwardSourceSummary = (messages: ChatMessage[]) => {
  if (!messages.length) {
    return null;
  }
  if (messages.length > 1) {
    return `已选择 ${messages.length} 条消息`;
  }

  return messages[0].preview || messages[0].content || "[空消息]";
};

export const buildDragSelectedMessageIds = (
  messages: ChatMessage[],
  anchorMessageId: string | null,
  currentMessageId: string | null,
) => {
  if (!anchorMessageId || !currentMessageId) {
    return [];
  }

  const anchorIndex = messages.findIndex(
    (message) => message.id === anchorMessageId,
  );
  const currentIndex = messages.findIndex(
    (message) => message.id === currentMessageId,
  );
  if (anchorIndex === -1 || currentIndex === -1) {
    return [];
  }

  const startIndex = Math.min(anchorIndex, currentIndex);
  const endIndex = Math.max(anchorIndex, currentIndex);
  return messages
    .slice(startIndex, endIndex + 1)
    .filter((message) => canSelectMessageForMultiSelect(message))
    .map((message) => message.id);
};

export const canOpenMessageActionMenu = (message: ChatMessage | null) =>
  Boolean(
    message &&
      (canCopyMessage(message) ||
        canReplyMessage(message) ||
        canForwardMessage(message) ||
        canToggleMessagePin(message) ||
        canToggleMessageReaction(message) ||
        canViewMessageReaders(message) ||
        canEditMessage(message) ||
        canDeleteMessage(message)),
  );
