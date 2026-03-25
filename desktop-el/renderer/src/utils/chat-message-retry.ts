import { ChatApi, type ChatMessage, type ChatMessageRetryPayload } from "@/api/chat";
import {
  buildOutgoingChatMessageParts,
  uploadAttachmentsAndBuildParts,
} from "./chat-message-compose";

export interface ResendLocalMessageOptions {
  roomId: string;
  currentUserId?: string;
  retryPayload: ChatMessageRetryPayload;
}

export interface ResendLocalMessageDependencies {
  sendTextMessage?: typeof ChatApi.sendTextMessage;
  sendMessage?: typeof ChatApi.sendMessage;
  uploadAttachmentsAndBuildParts?: typeof uploadAttachmentsAndBuildParts;
}

export const resendLocalMessage = async (
  options: ResendLocalMessageOptions,
  dependencies: ResendLocalMessageDependencies = {},
): Promise<{
  code: number;
  success: boolean;
  message: string;
  data: ChatMessage | null;
}> => {
  const sendTextMessage =
    dependencies.sendTextMessage ?? ChatApi.sendTextMessage;
  const sendMessage = dependencies.sendMessage ?? ChatApi.sendMessage;
  const uploadAttachments =
    dependencies.uploadAttachmentsAndBuildParts ?? uploadAttachmentsAndBuildParts;
  const content = options.retryPayload.content.trim();
  const attachments = options.retryPayload.attachments ?? [];
  const quotedMessageId = options.retryPayload.quotedMessageId ?? undefined;

  if (!content && !attachments.length) {
    throw new Error("缺少可重发的消息内容");
  }

  if (!attachments.length) {
    return sendTextMessage({
      roomId: options.roomId,
      content,
      quotedMessageId,
      currentUserId: options.currentUserId,
    });
  }

  const uploadedParts = await uploadAttachments({
    roomId: options.roomId,
    files: attachments,
  });

  return sendMessage({
    roomId: options.roomId,
    parts: buildOutgoingChatMessageParts({
      text: content,
      attachments: uploadedParts,
    }),
    quotedMessageId,
    currentUserId: options.currentUserId,
  });
};
