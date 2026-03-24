import type { ChatQuotedMessage } from "@/api/chat";

export const getQuotedSenderDisplayName = (
  quoted: Pick<ChatQuotedMessage, "senderName" | "senderUsername" | "senderId">
) => quoted.senderName || quoted.senderUsername || quoted.senderId || "引用";

export const formatQuotedMessagePreview = (
  quoted: Pick<ChatQuotedMessage, "content" | "isDeleted" | "parts">
) => {
  if (quoted.isDeleted) {
    return "[消息已删除]";
  }

  const textPart = quoted.parts.find((part) => part.partType === "text" && part.text?.trim());
  if (textPart?.text) {
    return textPart.text.trim();
  }

  const firstAttachment = quoted.parts.find((part) => part.partType !== "text");
  if (firstAttachment) {
    switch (firstAttachment.partType) {
      case "image":
        return "[图片]";
      case "video":
        return "[视频]";
      case "audio":
        return "[语音]";
      case "file":
        return "[附件]";
      default:
        break;
    }
  }

  if (quoted.content?.trim()) {
    return quoted.content.trim();
  }

  return "[引用消息]";
};
