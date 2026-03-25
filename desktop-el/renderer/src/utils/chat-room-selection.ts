interface ChatRoomLike {
  roomId?: string | null;
}

interface PickSelectedChatRoomIdOptions<TChat extends ChatRoomLike> {
  chats: TChat[];
  restoredRoomId?: string | null;
  currentRoomId?: string | null;
  fallbackToFirst?: boolean;
}

export const pickSelectedChatRoomId = <TChat extends ChatRoomLike>(
  options: PickSelectedChatRoomIdOptions<TChat>,
): string | null => {
  const { chats, restoredRoomId = null, currentRoomId = null, fallbackToFirst = true } = options;
  if (!chats.length) {
    return null;
  }

  if (restoredRoomId && chats.some((chat) => chat.roomId === restoredRoomId)) {
    return restoredRoomId;
  }

  if (currentRoomId && chats.some((chat) => chat.roomId === currentRoomId)) {
    return currentRoomId;
  }

  if (!fallbackToFirst) {
    return null;
  }

  return chats[0]?.roomId ?? null;
};
