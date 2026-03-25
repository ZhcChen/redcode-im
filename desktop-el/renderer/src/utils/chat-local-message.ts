import type {
  ChatMessage,
  ChatMessageAttachment,
  ChatMessagePart,
  ChatMessageRetryPayload,
  ChatQuotedMessage,
} from "@/api/chat";
import { inferAttachmentPartType } from "./chat-attachment-upload";

interface CreateLocalComposerMessageParams {
  roomId: string;
  currentUserId: string;
  currentUsername: string;
  currentDisplayName: string;
  currentAvatarUrl?: string | null;
  content?: string;
  quotedMessage?: ChatQuotedMessage | null;
  attachments?: File[];
}

const buildLocalMessageID = () =>
  `local-message-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

export const createLocalTextMessage = (
  params: CreateLocalComposerMessageParams & {
    content: string;
  },
): ChatMessage =>
  createLocalComposerMessage(params);

const buildLocalAttachment = (file: File): ChatMessageAttachment => ({
  key: "",
  name: file.name,
  mime: file.type || null,
  size: file.size,
  width: null,
  height: null,
  durationMs: null,
  thumbnailKey: null,
});

const buildLocalAttachmentPart = (
  file: File,
  position: number,
): ChatMessagePart => ({
  position,
  partType: inferAttachmentPartType(file),
  text: null,
  attachment: buildLocalAttachment(file),
});

const resolveLocalMessageType = (
  content: string,
  attachmentParts: ChatMessagePart[],
): ChatMessage["messageType"] => {
  if (!attachmentParts.length) {
    return "text";
  }
  if (content || attachmentParts.length > 1) {
    return "mixed";
  }
  return attachmentParts[0].partType;
};

const buildLocalPreview = (
  content: string,
  attachmentParts: ChatMessagePart[],
): string => {
  if (content) {
    return content;
  }
  if (!attachmentParts.length) {
    return "";
  }

  if (attachmentParts.length === 1) {
    const attachment = attachmentParts[0].attachment;
    switch (attachmentParts[0].partType) {
      case "image":
        return `[图片] ${attachment?.name ?? ""}`.trim();
      case "audio":
        return `[语音] ${attachment?.name ?? ""}`.trim();
      case "video":
        return `[视频] ${attachment?.name ?? ""}`.trim();
      case "file":
      default:
        return attachment?.name?.trim() || "[附件]";
    }
  }

  return `[${attachmentParts.length} 个附件]`;
};

const buildRetryPayload = (
  content: string,
  quotedMessage: ChatQuotedMessage | null | undefined,
  attachments: File[],
): ChatMessageRetryPayload => {
  const payload: ChatMessageRetryPayload = {
    content,
    quotedMessageId: quotedMessage?.id ?? null,
  };
  if (attachments.length) {
    payload.attachments = [...attachments];
  }
  return payload;
};

export const createLocalComposerMessage = (
  params: CreateLocalComposerMessageParams,
): ChatMessage => {
  const content = params.content?.trim() ?? "";
  const attachments = [...(params.attachments ?? [])];
  const textParts: ChatMessagePart[] = content
    ? [
        {
          position: 0,
          partType: "text",
          text: content,
          attachment: null,
        },
      ]
    : [];
  const attachmentParts = attachments.map((file, index) =>
    buildLocalAttachmentPart(file, textParts.length + index),
  );
  const parts = [...textParts, ...attachmentParts];

  return {
    id: buildLocalMessageID(),
    roomId: params.roomId,
    senderId: params.currentUserId,
    senderUsername: params.currentUsername,
    senderName: params.currentDisplayName,
    senderAvatarUrl: params.currentAvatarUrl ?? null,
    content,
    preview: buildLocalPreview(content, attachmentParts),
    messageType: resolveLocalMessageType(content, attachmentParts),
    deliveryStatus: null,
    createdAt: new Date(),
    isDeleted: false,
    isEdited: false,
    isSelf: true,
    pinnedAt: null,
    pinnedBy: null,
    forwardInfo: null,
    quotedMessage: params.quotedMessage ?? null,
    parts,
    clientStatus: "sending",
    retryPayload: buildRetryPayload(content, params.quotedMessage, attachments),
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
  const retryPayload = message.retryPayload;
  const hasContent = Boolean(retryPayload?.content.trim());
  const hasAttachments = Boolean(retryPayload?.attachments?.length);
  if (
    !message.isSelf ||
    message.isDeleted ||
    message.clientStatus !== "failed" ||
    (!hasContent && !hasAttachments)
  ) {
    return false;
  }

  return true;
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
