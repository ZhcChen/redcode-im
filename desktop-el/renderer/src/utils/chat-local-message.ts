import type { ChatMessage, ChatQuotedMessage } from "@/api/chat";

interface CreateLocalTextMessageParams {
  roomId: string;
  currentUserId: string;
  currentUsername: string;
  currentDisplayName: string;
  currentAvatarUrl?: string | null;
  content: string;
  quotedMessage?: ChatQuotedMessage | null;
}

const buildLocalMessageID = () =>
  `local-message-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

export const createLocalTextMessage = (
  params: CreateLocalTextMessageParams,
): ChatMessage => {
  const content = params.content.trim();
  const quotedMessageId = params.quotedMessage?.id ?? null;

  return {
    id: buildLocalMessageID(),
    roomId: params.roomId,
    senderId: params.currentUserId,
    senderUsername: params.currentUsername,
    senderName: params.currentDisplayName,
    senderAvatarUrl: params.currentAvatarUrl ?? null,
    content,
    preview: content,
    messageType: "text",
    deliveryStatus: null,
    createdAt: new Date(),
    isDeleted: false,
    isEdited: false,
    isSelf: true,
    pinnedAt: null,
    pinnedBy: null,
    forwardInfo: null,
    quotedMessage: params.quotedMessage ?? null,
    parts: [
      {
        position: 0,
        partType: "text",
        text: content,
        attachment: null,
      },
    ],
    clientStatus: "sending",
    retryPayload: {
      content,
      quotedMessageId,
    },
    errorMessage: null,
  };
};

export const markLocalMessageFailed = (
  message: ChatMessage,
  errorMessage?: string | null,
): ChatMessage => ({
  ...message,
  clientStatus: "failed",
  errorMessage: errorMessage ?? "消息发送失败",
});

export const markLocalMessageSending = (message: ChatMessage): ChatMessage => ({
  ...message,
  clientStatus: "sending",
  errorMessage: null,
});

export const canResendLocalMessage = (message: ChatMessage): boolean => {
  if (
    !message.isSelf ||
    message.isDeleted ||
    message.clientStatus !== "failed" ||
    !message.retryPayload?.content.trim()
  ) {
    return false;
  }

  return message.parts.every((part) => part.partType === "text");
};

export const replaceLocalMessage = (
  messages: ChatMessage[],
  localMessageID: string,
  remoteMessage: ChatMessage,
): ChatMessage[] =>
  messages.map((message) =>
    message.id === localMessageID ? remoteMessage : message,
  );

export const mergeRemoteAndLocalMessages = (
  remoteMessages: ChatMessage[],
  localMessages: ChatMessage[],
): ChatMessage[] => [...remoteMessages, ...localMessages];
