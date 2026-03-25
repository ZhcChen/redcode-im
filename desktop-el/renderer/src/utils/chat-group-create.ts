import type { ChatSummary, CreatedGroupChat } from "@/api/chat";

export interface GroupCreatePayload {
  name: string;
  memberUserIds: string[];
}

export type GroupCreateMatchedChat = Pick<
  ChatSummary,
  "id" | "roomId" | "title"
>;

export const validateGroupCreatePayload = (payload: GroupCreatePayload) => {
  const normalizedName = payload.name.trim();
  if (!normalizedName) {
    return "请输入群聊名称";
  }
  if (normalizedName.length > 20) {
    return "群聊名称不能超过 20 个字符";
  }
  if (!payload.memberUserIds.length) {
    return "请至少选择一位好友";
  }
  return null;
};

export const findCreatedGroupChat = (
  chats: GroupCreateMatchedChat[],
  createdGroup: Pick<CreatedGroupChat, "roomId" | "roomName">,
) => {
  const matchedByRoomId = chats.find(
    (chat) => chat.roomId === createdGroup.roomId,
  );
  if (matchedByRoomId) {
    return matchedByRoomId;
  }

  const normalizedRoomName = createdGroup.roomName.trim();
  if (!normalizedRoomName) {
    return null;
  }

  return chats.find((chat) => chat.title.trim() === normalizedRoomName) ?? null;
};
