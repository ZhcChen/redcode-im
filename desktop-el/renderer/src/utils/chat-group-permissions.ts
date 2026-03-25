import type { ChatGroupSettings, ChatRoomMember } from "@/api/chat";

type GroupManageMember = Pick<ChatRoomMember, "userId" | "role">;
type GroupManageState = {
  isOwner: boolean;
  isAdmin: boolean;
  canManage: boolean;
  canManageMembers: boolean;
  canManageAdmins: boolean;
  canManageJoinRequests: boolean;
  canManageMutes: boolean;
  canManageOperationLogs: boolean;
  canTransferOwner: boolean;
  canUpdateSettings: boolean;
  canUploadAvatar: boolean;
  canEditRules: boolean;
  canViewRules: boolean;
};
type GroupComposerState = {
  disabled: boolean;
  placeholder: string;
  tip: string | null;
};

const DEFAULT_GROUP_COMPOSER_STATE: GroupComposerState = {
  disabled: false,
  placeholder: "输入一条文本消息...",
  tip: null,
};

export const resolveGroupManageState = (payload: {
  currentUserId: string;
  ownerId: string | null;
  members: GroupManageMember[];
}): GroupManageState => {
  const { currentUserId, ownerId, members } = payload;
  const currentMember = members.find((member) => member.userId === currentUserId);
  const isOwner =
    ownerId === currentUserId || currentMember?.role === "owner";
  const isAdmin = currentMember?.role === "admin";

  return {
    isOwner,
    isAdmin,
    canManage: isOwner || isAdmin,
    canManageMembers: isOwner || isAdmin,
    canManageAdmins: isOwner,
    canManageJoinRequests: isOwner || isAdmin,
    canManageMutes: isOwner || isAdmin,
    canManageOperationLogs: isOwner,
    canTransferOwner: isOwner,
    canUpdateSettings: isOwner || isAdmin,
    canUploadAvatar: isOwner || isAdmin,
    canEditRules: isOwner || isAdmin,
    canViewRules: true,
  };
};

export const resolveGroupComposerState = (payload: {
  isGroupChat: boolean;
  canManageGroup: boolean;
  groupSettings: Pick<ChatGroupSettings, "globalMuteEnabled" | "myMute"> | null;
}): GroupComposerState => {
  const { isGroupChat, canManageGroup, groupSettings } = payload;
  if (!isGroupChat) {
    return DEFAULT_GROUP_COMPOSER_STATE;
  }

  if (groupSettings?.myMute?.isMuted) {
    return {
      disabled: true,
      placeholder: "你已被禁言",
      tip: "你已在当前群被禁言，暂时无法发送消息。",
    };
  }

  if (groupSettings?.globalMuteEnabled && !canManageGroup) {
    return {
      disabled: true,
      placeholder: "当前群已开启全员禁言",
      tip: "当前群已开启全员禁言，仅群主或管理员可发送消息。",
    };
  }

  return DEFAULT_GROUP_COMPOSER_STATE;
};
