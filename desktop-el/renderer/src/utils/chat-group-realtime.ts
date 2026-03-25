import type { ChatRealtimeEvent } from "@/api/chat";

export interface GroupRealtimePlan {
  shouldReloadChats: boolean;
  shouldReloadGroupContext: boolean;
  shouldReloadGroupSettings: boolean;
  notice: string | null;
}

const buildCurrentUserGroupMemberNotice = (
  event: Extract<ChatRealtimeEvent, { type: "group_member_changed" }>,
  activeRoomId: string | null,
  currentUserId: string,
) => {
  if (event.roomId !== activeRoomId || event.memberId !== currentUserId) {
    return null;
  }

  switch (event.changeType) {
    case "muted":
      return "你已在当前群被禁言";
    case "unmuted":
      return "你已在当前群解除禁言";
    default:
      return null;
  }
};

export const getGroupRealtimePlan = (payload: {
  event: ChatRealtimeEvent;
  activeRoomId: string | null;
  currentUserId: string;
}): GroupRealtimePlan | null => {
  const { event, activeRoomId, currentUserId } = payload;

  switch (event.type) {
    case "group_settings_updated":
      return {
        shouldReloadChats: true,
        shouldReloadGroupContext: false,
        shouldReloadGroupSettings: event.roomId === activeRoomId,
        notice: null,
      };
    case "group_dissolved":
      return {
        shouldReloadChats: true,
        shouldReloadGroupContext: false,
        shouldReloadGroupSettings: false,
        notice:
          event.roomId === activeRoomId ? "当前群聊已解散" : null,
      };
    case "group_member_changed":
      return {
        shouldReloadChats: true,
        shouldReloadGroupContext: event.roomId === activeRoomId,
        shouldReloadGroupSettings: event.roomId === activeRoomId,
        notice: buildCurrentUserGroupMemberNotice(
          event,
          activeRoomId,
          currentUserId,
        ),
      };
    default:
      return null;
  }
};
