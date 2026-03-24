import type { ChatMessagePartInput } from "@/api/chat";
import { uploadAttachmentAndBuildPart } from "./chat-attachment-send";

export interface UploadAttachmentsAndBuildPartsOptions {
  roomId: string;
  files: File[];
  onFileProgress?: (index: number, progress: number) => void;
  onOverallProgress?: (progress: number) => void;
}

export interface UploadAttachmentsAndBuildPartsDependencies {
  uploadAttachmentAndBuildPart?: typeof uploadAttachmentAndBuildPart;
}

export const buildOutgoingChatMessageParts = (options: {
  text?: string;
  attachments?: ChatMessagePartInput[];
}): ChatMessagePartInput[] => {
  const parts: ChatMessagePartInput[] = [];
  const text = options.text?.trim() ?? "";
  if (text) {
    parts.push({
      type: "text",
      text
    });
  }

  if (options.attachments?.length) {
    parts.push(...options.attachments);
  }

  return parts;
};

export const uploadAttachmentsAndBuildParts = async (
  options: UploadAttachmentsAndBuildPartsOptions,
  dependencies: UploadAttachmentsAndBuildPartsDependencies = {}
): Promise<ChatMessagePartInput[]> => {
  const uploadSingleAttachment = dependencies.uploadAttachmentAndBuildPart ?? uploadAttachmentAndBuildPart;
  const uploadedParts: ChatMessagePartInput[] = [];
  const totalFiles = options.files.length;
  const progressByFile = new Array(totalFiles).fill(0);

  for (let index = 0; index < totalFiles; index += 1) {
    const file = options.files[index];
    const uploadedPart = await uploadSingleAttachment({
      roomId: options.roomId,
      file,
      onProgress: (progress) => {
        progressByFile[index] = progress;
        options.onFileProgress?.(index, progress);
        const aggregateProgress = progressByFile.reduce((sum, current) => sum + current, 0) / totalFiles;
        options.onOverallProgress?.(aggregateProgress);
      }
    });
    uploadedParts.push(uploadedPart);
  }

  return uploadedParts;
};
