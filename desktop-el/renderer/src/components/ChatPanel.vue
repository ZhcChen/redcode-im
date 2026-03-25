<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import {
  ChatApi,
  type ChatForwardInfo,
  type ChatGroupAdmin,
  type ChatGroupJoinRequest,
  type ChatGroupMute,
  type ChatGroupOperationLog,
  type ChatGroupRule,
  type ChatGroupSettings,
  mapChatRealtimeEvent,
  type ChatMessage,
  type ChatMessageReader,
  type ChatMessagePart,
  type ChatQuotedMessage,
  type ChatRealtimeEvent,
  type ChatRoomDetail,
  type ChatRoomMember,
  type ChatSummary,
  type ChatWebSocketPush,
} from "@/api/chat";
import { FriendApi, type FriendInfo } from "@/api/friend";
import { WebSocketApi } from "@/api/websocket";
import type { BootstrapSnapshot } from "@/types/bootstrap";
import {
  createAttachmentPreviewUrlStore,
  getInlinePreviewAssetKey,
  shouldInlinePreviewAttachment,
} from "@/utils/chat-attachment-preview";
import { inferAttachmentPartType } from "@/utils/chat-attachment-upload";
import {
  uploadAttachmentsAndBuildParts,
} from "@/utils/chat-message-compose";
import {
  formatQuotedMessagePreview,
  getQuotedSenderDisplayName,
} from "@/utils/chat-quoted-message";
import {
  buildForwardSourceSummary,
  canCopyMessage,
  canDeleteMessage,
  canDeleteSelectedMessages,
  canEditMessage,
  canForwardMessage,
  canForwardSelectedMessages,
  canOpenMessageActionMenu as canOpenMessageActionMenuBase,
  canReplyMessage,
  canSelectMessageForMultiSelect,
  canToggleMessagePin,
  canToggleMessageReaction,
  canViewMessageReaders,
  getMessageCopyText,
  getMessageDeleteLabel,
  getSelectedMessages,
  isLocalOnlyMessage,
  pruneSelectedMessageIds,
} from "@/utils/chat-message-actions";
import {
  canResendLocalMessage,
  createLocalComposerMessage,
  createLocalTextMessage,
  markLocalMessageFailed,
  markLocalMessageSending,
  mergeRemoteAndLocalMessages,
  replaceLocalMessage,
} from "@/utils/chat-local-message";
import { resendLocalMessage } from "@/utils/chat-message-retry";
import {
  buildRetryableLocalMessagesStorageKey,
  restoreRetryableLocalMessages,
  saveRetryableLocalMessages,
} from "@/utils/chat-retry-storage";
import { findCreatedGroupChat } from "@/utils/chat-group-create";
import {
  sortGroupMembers,
  summarizeGroupMembers,
} from "@/utils/chat-group-members";
import {
  resolveGroupComposerState,
  resolveGroupManageState,
} from "@/utils/chat-group-permissions";
import { resolveGroupMaxMembersUpdate } from "@/utils/chat-group-settings";
import { getGroupRealtimePlan } from "@/utils/chat-group-realtime";
import {
  AVATAR_INPUT_ACCEPT,
  validateAvatarFile,
} from "@/utils/user-avatar-upload";
import AddGroupMembersModal from "./AddGroupMembersModal.vue";
import CreateGroupModal from "./CreateGroupModal.vue";
import ForwardMessageModal from "./ForwardMessageModal.vue";
import ManageGroupAdminsModal from "./ManageGroupAdminsModal.vue";
import ManageGroupJoinRequestsModal from "./ManageGroupJoinRequestsModal.vue";
import ManageGroupMutesModal from "./ManageGroupMutesModal.vue";
import ManageGroupOperationLogsModal from "./ManageGroupOperationLogsModal.vue";
import ManageGroupRulesModal from "./ManageGroupRulesModal.vue";
import MessageReadersModal from "./MessageReadersModal.vue";
import RemoveGroupMembersModal from "./RemoveGroupMembersModal.vue";
import TransferGroupOwnerModal from "./TransferGroupOwnerModal.vue";
import ViewGroupMembersModal from "./ViewGroupMembersModal.vue";

interface OpenChatRequest {
  requestId: number;
  friendUserId: string;
  displayName: string;
}

interface PendingComposerAttachment {
  id: string;
  file: File;
}

interface GroupCreateFriendOption {
  id: string;
  displayName: string;
  subtitle: string | null;
  avatarUrl: string | null;
}

type GroupSettingActionKey =
  | "joinApprovalRequired"
  | "memberCanInvite"
  | "memberCanAddFriends"
  | "requireAdminToAddFriends"
  | "maxMembers";

type DesktopRuntimeWithFile = NonNullable<Window["desktopEl"]> & {
  file: {
    saveFromURL(options: {
      url: string;
      filePath: string;
    }): Promise<{ filePath: string }>;
    getCachedPath(options: {
      relativePath: string;
    }): Promise<{
      filePath: string;
      fileUrl: string;
    } | null>;
    cacheFromURL(options: {
      url: string;
      relativePath: string;
    }): Promise<{
      filePath: string;
      fileUrl: string;
    }>;
    openPath(path: string): Promise<void>;
  };
};

const props = defineProps<{
  currentUser: LegacyUserInfo;
  hostVersion: string | null;
  lastEvent: string;
  wsStatus: string;
  bootstrap: BootstrapSnapshot | null;
  lastWsPush?: ChatWebSocketPush | null;
  openChatRequest?: OpenChatRequest | null;
}>();

const emit = defineEmits<{
  (event: "chat-request-consumed", requestId: number): void;
}>();

const searchQuery = ref("");
const chats = ref<ChatSummary[]>([]);
const messages = ref<ChatMessage[]>([]);
const selectedChatId = ref<string | null>(null);
const groupDetail = ref<ChatRoomDetail | null>(null);
const groupMembers = ref<ChatRoomMember[]>([]);
const groupAdmins = ref<ChatGroupAdmin[]>([]);
const groupJoinRequests = ref<ChatGroupJoinRequest[]>([]);
const groupMutes = ref<ChatGroupMute[]>([]);
const groupOperationLogs = ref<ChatGroupOperationLog[]>([]);
const groupRules = ref<ChatGroupRule[]>([]);
const groupSettings = ref<ChatGroupSettings | null>(null);
const isCreateGroupModalVisible = ref(false);
const isAddGroupMembersModalVisible = ref(false);
const isManageGroupAdminsModalVisible = ref(false);
const isManageGroupJoinRequestsModalVisible = ref(false);
const isManageGroupMutesModalVisible = ref(false);
const isManageGroupOperationLogsModalVisible = ref(false);
const isManageGroupRulesModalVisible = ref(false);
const isRemoveGroupMembersModalVisible = ref(false);
const isTransferGroupOwnerModalVisible = ref(false);
const isViewGroupMembersModalVisible = ref(false);
const isForwardMessageModalVisible = ref(false);
const isForwardingSelectedMessages = ref(false);
const isMessageReadersModalVisible = ref(false);
const createGroupFriends = ref<GroupCreateFriendOption[]>([]);
const draftMessage = ref("");
const attachmentInputRef = ref<HTMLInputElement | null>(null);
const groupAvatarInputRef = ref<HTMLInputElement | null>(null);
const pendingAttachments = ref<PendingComposerAttachment[]>([]);
const attachmentUploadProgress = ref<number | null>(null);
const attachmentUploadProgressById = ref<Record<string, number>>({});
const isLoadingChats = ref(true);
const isLoadingMessages = ref(false);
const isLoadingGroupContext = ref(false);
const isLoadingGroupAdmins = ref(false);
const isLoadingGroupJoinRequests = ref(false);
const isLoadingGroupMutes = ref(false);
const isLoadingGroupOperationLogs = ref(false);
const isLoadingGroupRules = ref(false);
const isLoadingGroupSettings = ref(false);
const isLoadingCreateGroupFriends = ref(false);
const isOpeningPrivateChat = ref(false);
const isCreatingGroup = ref(false);
const isAddingGroupMembers = ref(false);
const isUpdatingGroupAdmins = ref(false);
const isReviewingGroupJoinRequests = ref(false);
const isUpdatingGroupMutes = ref(false);
const isLoadingMoreGroupOperationLogs = ref(false);
const isUpdatingGroupRules = ref(false);
const isRemovingGroupMembers = ref(false);
const isTransferringGroupOwner = ref(false);
const isForwardingMessage = ref(false);
const isSending = ref(false);
const pinningMessageId = ref<string | null>(null);
const reactingMessageId = ref<string | null>(null);
const reactingReactionKey = ref<string | null>(null);
const activeReactionPickerMessageId = ref<string | null>(null);
const loadingMessageReadersMessageId = ref<string | null>(null);
const isUpdatingGlobalMute = ref(false);
const isUpdatingGroupAvatar = ref(false);
const updatingGroupSettingKey = ref<GroupSettingActionKey | null>(null);
const groupMaxMembersDraft = ref("");
const sendingMode = ref<"text" | "attachment" | null>(null);
const deletingMessageId = ref<string | null>(null);
const isDeletingSelectedMessages = ref(false);
const downloadingAttachmentKeys = ref<Record<string, boolean>>({});
const downloadedAttachmentPaths = ref<Record<string, string>>({});
const loadingAttachmentPreviewKeys = ref<Record<string, boolean>>({});
const failedAttachmentPreviewMessages = ref<Record<string, string>>({});
const attachmentPreviewUrls = ref<Record<string, string>>({});
const attachmentPlayableUrls = ref<Record<string, string>>({});
const lastReadUntilMessageByRoom = ref<Record<string, string>>({});
const mediaPreview = ref<{
  type: "image" | "video";
  url: string;
  name: string;
  meta: string;
} | null>(null);
const replyingMessage = ref<ChatMessage | null>(null);
const forwardingMessage = ref<ChatMessage | null>(null);
const highlightedQuotedMessageId = ref<string | null>(null);
const hasMoreGroupOperationLogs = ref(false);
const messageReaders = ref<ChatMessageReader[]>([]);
const messageReadersTarget = ref<ChatMessage | null>(null);
const activeMessageActionMenuId = ref<string | null>(null);
const editingMessageTarget = ref<ChatMessage | null>(null);
const editingMessageDraft = ref("");
const submittingEditMessageId = ref<string | null>(null);
const localMessagesByRoom = ref<Record<string, ChatMessage[]>>({});
const isMultiSelectMode = ref(false);
const selectedMessageIds = ref<string[]>([]);
const resendingMessageId = ref<string | null>(null);
const typingUsers = ref<Record<string, number>>({});
const typingCleanupTimers = new Map<string, number>();
const localMessageRetryTimers = new Map<string, number>();
const localMessageRetryInFlight = new Set<string>();
const typingStopSendTimer = ref<number | null>(null);
const typingIsTyping = ref(false);
const typingRoomId = ref<string | null>(null);
const lastTypingSentAt = ref(0);
const subscribedRoomId = ref<string | null>(null);
let groupContextLoadSequence = 0;
let groupAdminsLoadSequence = 0;
let groupJoinRequestsLoadSequence = 0;
let groupMutesLoadSequence = 0;
let groupOperationLogsLoadSequence = 0;
let groupRulesLoadSequence = 0;
let groupSettingsLoadSequence = 0;
let messageReadersLoadSequence = 0;
let roomSubscriptionSequence = 0;
const GROUP_OPERATION_LOGS_PAGE_SIZE = 20;
const LOCAL_MESSAGE_RETRY_DELAY_MS = 3000;
const notice = ref(
  "聊天主区已接到 Go core，当前继续恢复附件消息上传、下载与预览闭环。",
);
const attachmentPreviewUrlStore = createAttachmentPreviewUrlStore();
const MESSAGE_REACTION_OPTIONS = ["👍", "❤️", "😂", "🎉", "😮", "😢"] as const;

const filteredChats = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase();
  if (!keyword) {
    return chats.value;
  }

  return chats.value.filter((chat) => {
    const title = chat.title.toLowerCase();
    const subtitle = chat.subtitle?.toLowerCase() ?? "";
    const preview = chat.lastMessagePreview.toLowerCase();
    const friendUsername = chat.friendUsername?.toLowerCase() ?? "";
    return (
      title.includes(keyword) ||
      subtitle.includes(keyword) ||
      preview.includes(keyword) ||
      friendUsername.includes(keyword)
    );
  });
});

const selectedChat = computed(
  () =>
    chats.value.find((chat) => chat.id === selectedChatId.value) ||
    chats.value[0] ||
    null,
);
const isSelectedGroupChat = computed(
  () => selectedChat.value?.roomType === "group",
);
const selectedChatAvatarUrl = computed(() => {
  if (!selectedChat.value) {
    return null;
  }
  if (isSelectedGroupChat.value) {
    return groupDetail.value?.avatarUrl ?? selectedChat.value.avatarUrl ?? null;
  }
  return selectedChat.value.avatarUrl ?? null;
});
const sortedGroupMembers = computed(() =>
  sortGroupMembers(
    groupMembers.value.map((member) => ({
      ...member,
      displayName: getRoomMemberDisplayName(member),
      roleLabel: formatRoomMemberRole(member.role),
      joinedAtLabel: member.joinedAt
        ? `入群于 ${formatDetailTime(member.joinedAt)}`
        : "入群时间待同步",
      isSelf: member.userId === props.currentUser.id,
    })),
  ),
);
const groupMemberStats = computed(() =>
  summarizeGroupMembers(sortedGroupMembers.value),
);
const addableGroupFriends = computed(() => {
  const excludedUserIds = new Set(groupMembers.value.map((member) => member.userId));
  excludedUserIds.add(props.currentUser.id);
  return createGroupFriends.value.filter((friend) => !excludedUserIds.has(friend.id));
});
const forwardableChats = computed(() =>
  chats.value.filter(
    (chat) => Boolean(chat.roomId) && chat.roomId !== selectedChatId.value,
  ),
);
const selectedBatchMessages = computed(() =>
  getSelectedMessages(messages.value, selectedMessageIds.value),
);
const selectedMessagesCount = computed(() => selectedBatchMessages.value.length);
const canForwardSelectedBatchMessages = computed(() =>
  canForwardSelectedMessages(selectedBatchMessages.value),
);
const canDeleteSelectedBatchMessages = computed(() =>
  canDeleteSelectedMessages(selectedBatchMessages.value),
);
const forwardingSourceMessages = computed(() =>
  isForwardingSelectedMessages.value
    ? selectedBatchMessages.value
    : forwardingMessage.value
      ? [forwardingMessage.value]
      : [],
);
const forwardingMessageSummary = computed(() =>
  buildForwardSourceSummary(forwardingSourceMessages.value),
);
const messageReadersSummary = computed(() => {
  if (!messageReadersTarget.value) {
    return null;
  }
  return (
    messageReadersTarget.value.preview ||
    messageReadersTarget.value.content ||
    "[空消息]"
  );
});
const removableGroupMembers = computed(() =>
  sortedGroupMembers.value
    .filter(
      (member) =>
        member.userId !== props.currentUser.id &&
        member.role !== "owner" &&
        member.userId !== (groupDetail.value?.ownerId ?? null),
    )
    .map((member) => ({
      id: member.userId,
      displayName: getRoomMemberDisplayName(member),
      subtitle: `${formatRoomMemberRole(member.role)} / ${member.username}`,
      avatarUrl: member.avatarUrl,
    })),
);
const transferableGroupOwnerMembers = computed(() =>
  sortedGroupMembers.value
    .filter(
      (member) =>
        member.userId !== props.currentUser.id &&
        member.role !== "owner" &&
        member.userId !== (groupDetail.value?.ownerId ?? null),
    )
    .map((member) => ({
      id: member.userId,
      displayName: getRoomMemberDisplayName(member),
      subtitle: `${formatRoomMemberRole(member.role)} / ${member.username}`,
      avatarUrl: member.avatarUrl,
    })),
);
const groupAdminEntries = computed(() =>
  groupAdmins.value.map((admin) => {
    const member = groupMembers.value.find(
      (groupMember) => groupMember.userId === admin.adminId,
    );
    const displayName = member
      ? getRoomMemberDisplayName(member)
      : admin.adminId;
    const subtitleSegments = [];
    if (member?.username && member.username !== displayName) {
      subtitleSegments.push(member.username);
    }
    subtitleSegments.push("管理员");

    return {
      id: admin.id,
      adminId: admin.adminId,
      displayName,
      subtitle: subtitleSegments.join(" / ") || null,
      avatarUrl: member?.avatarUrl ?? null,
      appointedAtLabel: formatDetailTime(admin.appointedAt),
    };
  }),
);
const appointableGroupAdminMembers = computed(() =>
  sortedGroupMembers.value
    .filter(
      (member) =>
        member.role !== "owner" &&
        member.role !== "admin" &&
        member.userId !== (groupDetail.value?.ownerId ?? null),
    )
    .map((member) => ({
      id: member.userId,
      displayName: getRoomMemberDisplayName(member),
      subtitle: member.username ? `成员 / ${member.username}` : "成员",
      avatarUrl: member.avatarUrl,
    })),
);
const sortedGroupJoinRequests = computed(() =>
  [...groupJoinRequests.value].sort((left, right) => {
    if (left.status === "pending" && right.status !== "pending") {
      return -1;
    }
    if (left.status !== "pending" && right.status === "pending") {
      return 1;
    }
    return (right.createdAt?.getTime() ?? 0) - (left.createdAt?.getTime() ?? 0);
  }),
);
const pendingGroupJoinRequestCount = computed(
  () =>
    sortedGroupJoinRequests.value.filter(
      (request) => request.status === "pending",
    ).length,
);
const groupJoinRequestEntries = computed(() =>
  sortedGroupJoinRequests.value.map((request) => ({
    id: request.id,
    applicantId: request.applicantId,
    displayName: request.applicantId,
    subtitle: request.applicantId,
    message: request.message,
    status: request.status,
    createdAtLabel: formatDetailTime(request.createdAt),
    reviewedAtLabel: formatDetailTime(request.reviewedAt),
    reviewMessage: request.reviewMessage,
  })),
);
const sortedGroupMutes = computed(() =>
  [...groupMutes.value]
    .filter((mute) => mute.isActive)
    .sort(
      (left, right) =>
        (right.mutedAt?.getTime() ?? 0) - (left.mutedAt?.getTime() ?? 0),
    ),
);
const activeGroupMuteCount = computed(() => sortedGroupMutes.value.length);
const groupMuteEntries = computed(() =>
  sortedGroupMutes.value.map((mute) => {
    const member = groupMembers.value.find(
      (groupMember) => groupMember.userId === mute.userId,
    );
    const mutedByMember = groupMembers.value.find(
      (groupMember) => groupMember.userId === mute.mutedBy,
    );
    const displayName = member ? getRoomMemberDisplayName(member) : mute.userId;
    const subtitleSegments = [];
    if (member?.username && member.username !== displayName) {
      subtitleSegments.push(member.username);
    }
    subtitleSegments.push(member ? formatRoomMemberRole(member.role) : "成员");
    const mutedByLabel =
      mutedByMember
        ? getRoomMemberDisplayName(mutedByMember)
        : mute.mutedBy === props.currentUser.id
          ? props.currentUser.nickname || props.currentUser.username
          : mute.mutedBy;

    return {
      id: mute.id,
      userId: mute.userId,
      displayName,
      subtitle: subtitleSegments.join(" / ") || null,
      avatarUrl: member?.avatarUrl ?? null,
      reason: mute.reason,
      mutedAtLabel: formatDetailTime(mute.mutedAt),
      muteUntilLabel: formatDetailTime(mute.muteUntil),
      mutedByLabel,
      isPermanent: mute.muteDurationHours === 0,
    };
  }),
);
const muteableGroupMembers = computed(() => {
  const mutedUserIds = new Set(
    sortedGroupMutes.value.map((mute) => mute.userId),
  );

  return sortedGroupMembers.value
    .filter(
      (member) =>
        member.role === "member" &&
        member.userId !== props.currentUser.id &&
        !mutedUserIds.has(member.userId),
    )
    .map((member) => ({
      id: member.userId,
      displayName: getRoomMemberDisplayName(member),
      subtitle: member.username ? `成员 / ${member.username}` : "成员",
      avatarUrl: member.avatarUrl,
    }));
});
const sortedGroupRules = computed(() =>
  [...groupRules.value]
    .filter((rule) => rule.isActive)
    .sort((left, right) => left.orderIndex - right.orderIndex),
);
const activeGroupRuleCount = computed(() => sortedGroupRules.value.length);
const groupRuleEntries = computed(() =>
  sortedGroupRules.value.map((rule) => {
    const creatorMember = groupMembers.value.find(
      (member) => member.userId === rule.creatorId,
    );
    const creatorLabel =
      creatorMember
        ? getRoomMemberDisplayName(creatorMember)
        : rule.creatorId === props.currentUser.id
          ? props.currentUser.nickname || props.currentUser.username
          : rule.creatorId;

    return {
      id: rule.id,
      title: rule.title,
      content: rule.content,
      orderIndex: rule.orderIndex,
      creatorLabel,
      updatedAtLabel: formatDetailTime(rule.updatedAt),
    };
  }),
);
const groupOperationLogEntries = computed(() =>
  groupOperationLogs.value.map((log) => ({
    id: log.id,
    createdAtLabel: formatOperationLogTime(log.createdAt),
    operatorLabel: resolveGroupActorLabel(log.operatorId),
    actionText: formatGroupOperationLogAction(log),
    targetLabel: log.targetUserId ? resolveGroupActorLabel(log.targetUserId) : null,
  })),
);
const groupOwnerMember = computed(
  () =>
    sortedGroupMembers.value.find(
      (member) =>
        member.role === "owner" || member.userId === groupDetail.value?.ownerId,
    ) || null,
);
const isPersonallyMutedInGroup = computed(
  () => groupSettings.value?.myMute?.isMuted === true,
);
const groupManageState = computed(() => {
  if (!isSelectedGroupChat.value) {
    return {
      isOwner: false,
      isAdmin: false,
      canManage: false,
      canManageMembers: false,
      canManageAdmins: false,
      canManageJoinRequests: false,
      canManageMutes: false,
      canManageOperationLogs: false,
      canTransferOwner: false,
      canUpdateSettings: false,
      canUploadAvatar: false,
      canEditRules: false,
      canViewRules: false,
    };
  }

  return resolveGroupManageState({
    currentUserId: props.currentUser.id,
    ownerId: groupDetail.value?.ownerId ?? null,
    members: groupMembers.value,
  });
});
const canManageSelectedGroup = computed(() => groupManageState.value.canManage);
const canManageSelectedGroupMembers = computed(
  () => groupManageState.value.canManageMembers,
);
const canManageSelectedGroupAdmins = computed(
  () => groupManageState.value.canManageAdmins,
);
const canManageSelectedGroupJoinRequests = computed(
  () => groupManageState.value.canManageJoinRequests,
);
const canManageSelectedGroupMutes = computed(
  () => groupManageState.value.canManageMutes,
);
const canManageSelectedGroupOperationLogs = computed(
  () => groupManageState.value.canManageOperationLogs,
);
const canTransferSelectedGroupOwner = computed(
  () => groupManageState.value.canTransferOwner,
);
const canUpdateSelectedGroupSettings = computed(
  () => groupManageState.value.canUpdateSettings,
);
const canUploadSelectedGroupAvatar = computed(
  () => groupManageState.value.canUploadAvatar,
);
const canEditSelectedGroupRules = computed(
  () => groupManageState.value.canEditRules,
);
const groupComposerState = computed(() =>
  resolveGroupComposerState({
    isGroupChat: isSelectedGroupChat.value,
    canManageGroup: canManageSelectedGroup.value,
    groupSettings: groupSettings.value,
  }),
);
const pinnedCount = computed(
  () => chats.value.filter((chat) => chat.isPinned).length,
);
const hasPendingAttachments = computed(
  () => pendingAttachments.value.length > 0,
);
const attachmentProgressPercent = computed(() =>
  attachmentUploadProgress.value === null
    ? null
    : Math.max(
        0,
        Math.min(100, Math.round(attachmentUploadProgress.value * 100)),
      ),
);
const pendingAttachmentSummary = computed(() => {
  if (!pendingAttachments.value.length) {
    return null;
  }

  const totalSize = pendingAttachments.value.reduce(
    (sum, item) => sum + item.file.size,
    0,
  );
  return `${pendingAttachments.value.length} 个附件 / ${formatAttachmentSize(totalSize)}`;
});
const composerStatusText = computed(() => {
  if (isSending.value && sendingMode.value === "attachment") {
    return attachmentProgressPercent.value === null
      ? "附件处理中..."
      : `附件处理中 ${attachmentProgressPercent.value}%`;
  }
  if (isSending.value) {
    return "发送中...";
  }
  if (hasPendingAttachments.value) {
    return "当前版本支持多附件与文本混发";
  }
  return "Enter 发送，Shift+Enter 换行";
});
const sendButtonLabel = computed(() => {
  if (isSending.value && sendingMode.value === "attachment") {
    return attachmentProgressPercent.value === null
      ? "发送中..."
      : `发送中 ${attachmentProgressPercent.value}%`;
  }
  if (isSending.value) {
    return "发送中...";
  }
  if (hasPendingAttachments.value && draftMessage.value.trim()) {
    return "发送消息";
  }
  if (hasPendingAttachments.value) {
    return "发送附件";
  }
  return "发送";
});
const replyingSummary = computed(() => {
  if (!replyingMessage.value) {
    return null;
  }

  return formatQuotedMessagePreview({
    content: replyingMessage.value.content,
    isDeleted: replyingMessage.value.isDeleted,
    parts: replyingMessage.value.parts,
  });
});
const typingIndicatorText = computed(() => {
  const chat = selectedChat.value;
  if (!chat) {
    return "";
  }

  const now = Date.now();
  const activeUserIds = Object.entries(typingUsers.value)
    .filter(([, expiresAt]) => expiresAt > now)
    .map(([userId]) => userId);
  if (!activeUserIds.length) {
    return "";
  }

  if (chat.roomType === "private") {
    return "对方正在输入...";
  }

  const firstUserId = activeUserIds[0];
  const member = groupMembers.value.find((item) => item.userId === firstUserId);
  const displayName = member ? getRoomMemberDisplayName(member) : "有人";
  if (activeUserIds.length === 1) {
    return `${displayName} 正在输入...`;
  }
  return `${displayName} 等${activeUserIds.length}人正在输入...`;
});

const formatTime = (value: Date | null) => {
  if (!value) {
    return "暂无";
  }
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(value);
};

const formatDetailTime = (value: Date | null) => {
  if (!value) {
    return "暂无";
  }
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(value);
};

const formatOperationLogTime = (value: Date | null) => {
  if (!value) {
    return "暂无";
  }
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(value);
};

const formatRoomType = (value: ChatSummary["roomType"]) => {
  switch (value) {
    case "group":
      return "群聊";
    case "favorite":
      return "收藏夹";
    case "public":
      return "公开频道";
    case "private":
    default:
      return "单聊";
  }
};

const getRoomMemberDisplayName = (member: ChatRoomMember) =>
  member.nickname || member.username || member.userId;

const resolveGroupActorLabel = (userId: string) => {
  const member = groupMembers.value.find((item) => item.userId === userId);
  if (member) {
    return getRoomMemberDisplayName(member);
  }
  if (userId === props.currentUser.id) {
    return props.currentUser.nickname || props.currentUser.username;
  }
  return userId;
};

const formatRoomMemberRole = (role: ChatRoomMember["role"]) => {
  switch (role) {
    case "owner":
      return "群主";
    case "admin":
      return "管理员";
    case "member":
    default:
      return "成员";
  }
};

const formatBooleanLabel = (value: boolean) => (value ? "开启" : "关闭");

const operationTextMap: Record<string, string> = {
  appoint_admin: "任命了管理员",
  remove_admin: "撤销了管理员",
  add_members: "添加了成员",
  remove_member: "移除了成员",
  enable_global_mute: "开启了全体禁言",
  disable_global_mute: "关闭了全体禁言",
  mute_user: "禁言了",
  unmute_user: "解除了禁言",
  create_rule: "创建了群规",
  update_rule: "更新了群规",
  delete_rule: "删除了群规",
  create_invitations: "邀请成员入群",
  respond_to_invitation: "响应了群邀请",
  review_join_request: "审核了入群申请",
  update_group_settings: "更新了群设置",
};

const formatGroupOperationLogAction = (log: ChatGroupOperationLog) => {
  if (log.operationType === "review_join_request") {
    const status = log.operationData?.status;
    if (status === "approved") {
      return "通过了入群申请";
    }
    if (status === "rejected") {
      return "拒绝了入群申请";
    }
  }

  if (log.operationType === "mute_user") {
    const durationHours = log.operationData?.duration_hours;
    if (durationHours === 0) {
      return "永久禁言了";
    }
    if (typeof durationHours === "number") {
      return `禁言了 ${durationHours} 小时`;
    }
  }

  return operationTextMap[log.operationType] || log.operationType;
};

const getAvatarFallbackText = (value: string | null | undefined) =>
  value?.slice(0, 1).toUpperCase() || "#";

const mapGroupCreateFriend = (friend: FriendInfo): GroupCreateFriendOption => {
  const remark = friend.friendRemark?.trim() ?? "";
  const nickname = friend.user.nickname?.trim() ?? "";
  const username = friend.user.username.trim();
  const displayName = remark || nickname || username || "未知好友";
  const subtitleSegments = [];
  if (remark && nickname && nickname !== remark) {
    subtitleSegments.push(nickname);
  }
  if (username && username !== displayName) {
    subtitleSegments.push(username);
  }

  return {
    id: friend.user.id,
    displayName,
    subtitle: subtitleSegments.join(" / ") || null,
    avatarUrl: friend.user.avatarUrl,
  };
};

const requireDesktopRuntime = (): DesktopRuntimeWithFile => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl as DesktopRuntimeWithFile;
};

const formatAttachmentType = (partType: ChatMessagePart["partType"]) => {
  switch (partType) {
    case "image":
      return "图片";
    case "video":
      return "视频";
    case "audio":
      return "语音";
    case "file":
    default:
      return "附件";
  }
};

const isMessagePinned = (message: ChatMessage) => Boolean(message.pinnedAt);

const canOpenMessageActionMenu = (message: ChatMessage | null) =>
  Boolean(
    message &&
      (canOpenMessageActionMenuBase(message) ||
        canResendLocalMessage(message) ||
        canSelectMessageForMultiSelect(message)),
  );

const formatForwardSourceName = (forwardInfo: ChatForwardInfo | null) => {
  if (!forwardInfo) {
    return "未知来源";
  }
  return (
    forwardInfo.sourceName ||
    forwardInfo.originSenderName ||
    forwardInfo.sourceId ||
    "未知来源"
  );
};

const formatForwardOriginLabel = (forwardInfo: ChatForwardInfo | null) => {
  if (!forwardInfo?.originSenderName) {
    return null;
  }
  return `原发送者 ${forwardInfo.originSenderName}`;
};

const patchMessagePinState = (payload: {
  messageId: string;
  pinnedAt: Date | null;
  pinnedBy: string | null;
  message?: ChatMessage | null;
}) => {
  const targetIndex = messages.value.findIndex(
    (message) => message.id === payload.messageId,
  );
  if (targetIndex === -1) {
    return;
  }

  const existing = messages.value[targetIndex];
  const nextMessage = payload.message
    ? {
        ...existing,
        ...payload.message,
        pinnedAt: payload.pinnedAt,
        pinnedBy: payload.pinnedBy,
      }
    : {
        ...existing,
        pinnedAt: payload.pinnedAt,
        pinnedBy: payload.pinnedBy,
      };

  messages.value.splice(targetIndex, 1, nextMessage);
};

const patchMessageReactions = (
  messageId: string,
  reactions: ChatMessage["reactions"],
) => {
  const targetIndex = messages.value.findIndex((message) => message.id === messageId);
  if (targetIndex === -1) {
    return;
  }

  messages.value.splice(targetIndex, 1, {
    ...messages.value[targetIndex],
    reactions,
  });
};

const patchMessageEditedState = (payload: {
  messageId: string;
  content: string;
  editedAt: Date | null;
}) => {
  const targetIndex = messages.value.findIndex(
    (message) => message.id === payload.messageId,
  );
  if (targetIndex === -1) {
    return;
  }

  const existing = messages.value[targetIndex];
  messages.value.splice(targetIndex, 1, {
    ...existing,
    content: payload.content,
    preview: payload.content || existing.preview,
    isEdited: Boolean(payload.editedAt),
  });
};

const formatAttachmentSize = (size: number | null) => {
  if (typeof size !== "number" || !Number.isFinite(size) || size <= 0) {
    return "大小未知";
  }

  const units = ["B", "KB", "MB", "GB", "TB"];
  let nextSize = size;
  let unitIndex = 0;
  while (nextSize >= 1024 && unitIndex < units.length - 1) {
    nextSize /= 1024;
    unitIndex += 1;
  }

  const digits = nextSize >= 10 || unitIndex === 0 ? 0 : 1;
  return `${nextSize.toFixed(digits)} ${units[unitIndex]}`;
};

const describePendingAttachment = (file: File) => {
  const typeLabel = formatAttachmentType(inferAttachmentPartType(file));
  const mimeLabel = file.type ? ` / ${file.type}` : "";
  return `${typeLabel} / ${formatAttachmentSize(file.size)}${mimeLabel}`;
};

const formatDuration = (durationMs: number | null) => {
  if (
    typeof durationMs !== "number" ||
    !Number.isFinite(durationMs) ||
    durationMs <= 0
  ) {
    return null;
  }

  const totalSeconds = Math.max(1, Math.round(durationMs / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
};

const getAttachmentName = (part: ChatMessagePart) => {
  const directName = part.attachment?.name?.trim();
  if (directName) {
    return directName;
  }

  const key = part.attachment?.key ?? "";
  const fallback = key.split("/").pop()?.trim();
  return (
    fallback || `${formatAttachmentType(part.partType)}-${part.position + 1}`
  );
};

const getAttachmentMeta = (part: ChatMessagePart) => {
  const segments = [formatAttachmentType(part.partType)];
  if (
    part.partType === "image" &&
    part.attachment?.width &&
    part.attachment?.height
  ) {
    segments.push(`${part.attachment.width} x ${part.attachment.height}`);
  }
  if (
    part.partType === "video" &&
    part.attachment?.width &&
    part.attachment?.height
  ) {
    segments.push(`${part.attachment.width} x ${part.attachment.height}`);
  }
  if (part.partType === "audio") {
    const duration = formatDuration(part.attachment?.durationMs ?? null);
    if (duration) {
      segments.push(duration);
    }
  }
  segments.push(formatAttachmentSize(part.attachment?.size ?? null));
  return segments.join(" / ");
};

const toQuotedMessage = (message: ChatMessage): ChatQuotedMessage => ({
  id: message.id,
  roomId: message.roomId,
  senderId: message.senderId,
  senderUsername: message.senderUsername,
  senderName: message.senderName,
  senderAvatarUrl: message.senderAvatarUrl,
  content: message.content,
  messageType: message.messageType,
  createdAt: message.createdAt,
  isDeleted: message.isDeleted,
  parts: message.parts,
});

const getMessageTextParts = (message: ChatMessage) =>
  message.parts.filter((part) => part.partType === "text" && part.text?.trim());

const getMessageAttachmentParts = (message: ChatMessage) =>
  message.parts.filter((part) => part.partType !== "text" && part.attachment);

const canAccessAttachmentResource = (part: ChatMessagePart) =>
  Boolean(part.attachment?.key);

const getAttachmentActionKey = (message: ChatMessage, part: ChatMessagePart) =>
  `${message.id}:${part.attachment?.key || `part-${part.position}`}`;

const getAttachmentPreviewKey = (message: ChatMessage, part: ChatMessagePart) =>
  `${message.roomId}:${getInlinePreviewAssetKey(part) ?? `part-${part.position}`}`;

const getAttachmentPlayableKey = (
  message: ChatMessage,
  part: ChatMessagePart,
) => `${message.roomId}:${part.attachment?.key || `playable-${part.position}`}`;

const isAttachmentDownloading = (message: ChatMessage, part: ChatMessagePart) =>
  Boolean(
    downloadingAttachmentKeys.value[getAttachmentActionKey(message, part)],
  );

const getAttachmentLocalPath = (message: ChatMessage, part: ChatMessagePart) =>
  downloadedAttachmentPaths.value[getAttachmentActionKey(message, part)] ??
  null;

const getAttachmentPreviewUrl = (message: ChatMessage, part: ChatMessagePart) =>
  attachmentPreviewUrls.value[getAttachmentPreviewKey(message, part)] ?? null;

const getAttachmentPlayableUrl = (
  message: ChatMessage,
  part: ChatMessagePart,
) =>
  attachmentPlayableUrls.value[getAttachmentPlayableKey(message, part)] ?? null;

const normalizeAttachmentCacheKey = (key: string) =>
  key.trim().replace(/^[/\\]+/, "").replace(/\.\.(?=\/|\\|$)/g, "__");

const buildAttachmentCacheRelativePath = (
  kind: "preview" | "playable",
  key: string,
) => `${kind}/${normalizeAttachmentCacheKey(key)}`;

const storeCachedAttachmentAsset = (
  message: ChatMessage,
  part: ChatMessagePart,
  payload: {
    filePath: string;
    fileUrl: string;
    preview?: boolean;
    playable?: boolean;
  },
) => {
  if (payload.preview) {
    attachmentPreviewUrls.value = {
      ...attachmentPreviewUrls.value,
      [getAttachmentPreviewKey(message, part)]: payload.fileUrl,
    };
  }
  if (payload.playable) {
    const actionKey = getAttachmentActionKey(message, part);
    downloadedAttachmentPaths.value = {
      ...downloadedAttachmentPaths.value,
      [actionKey]: payload.filePath,
    };
    attachmentPlayableUrls.value = {
      ...attachmentPlayableUrls.value,
      [getAttachmentPlayableKey(message, part)]: payload.fileUrl,
    };
  }
};

const isAttachmentPreviewLoading = (
  message: ChatMessage,
  part: ChatMessagePart,
) =>
  Boolean(
    loadingAttachmentPreviewKeys.value[getAttachmentPreviewKey(message, part)],
  );

const getAttachmentPreviewFailure = (
  message: ChatMessage,
  part: ChatMessagePart,
) =>
  failedAttachmentPreviewMessages.value[
    getAttachmentPreviewKey(message, part)
  ] ?? null;

const setAttachmentDownloading = (key: string, value: boolean) => {
  const next = { ...downloadingAttachmentKeys.value };
  if (value) {
    next[key] = true;
  } else {
    delete next[key];
  }
  downloadingAttachmentKeys.value = next;
};

const setAttachmentPreviewLoading = (key: string, value: boolean) => {
  const next = { ...loadingAttachmentPreviewKeys.value };
  if (value) {
    next[key] = true;
  } else {
    delete next[key];
  }
  loadingAttachmentPreviewKeys.value = next;
};

const setAttachmentPreviewFailure = (key: string, message: string | null) => {
  const next = { ...failedAttachmentPreviewMessages.value };
  if (message) {
    next[key] = message;
  } else {
    delete next[key];
  }
  failedAttachmentPreviewMessages.value = next;
};

const resetPendingAttachments = () => {
  pendingAttachments.value = [];
  attachmentUploadProgress.value = null;
  attachmentUploadProgressById.value = {};
  if (attachmentInputRef.value) {
    attachmentInputRef.value.value = "";
  }
};

const getLocalMessagesForRoom = (roomId: string | null) =>
  roomId ? localMessagesByRoom.value[roomId] ?? [] : [];

const setLocalMessagesForRoom = (roomId: string, roomMessages: ChatMessage[]) => {
  const next = { ...localMessagesByRoom.value };
  if (roomMessages.length) {
    next[roomId] = roomMessages;
  } else {
    delete next[roomId];
  }
  localMessagesByRoom.value = next;
};

const appendLocalMessage = (roomId: string, message: ChatMessage) => {
  setLocalMessagesForRoom(roomId, [...getLocalMessagesForRoom(roomId), message]);
  if (selectedChatId.value === roomId) {
    messages.value = [...messages.value, message];
  }
};

const updateLocalMessage = (
  roomId: string,
  messageId: string,
  updater: (message: ChatMessage) => ChatMessage,
) => {
  const nextLocalMessages = getLocalMessagesForRoom(roomId).map((message) =>
    message.id === messageId ? updater(message) : message,
  );
  setLocalMessagesForRoom(roomId, nextLocalMessages);
  if (selectedChatId.value === roomId) {
    messages.value = messages.value.map((message) =>
      message.id === messageId ? updater(message) : message,
    );
  }
};

const removeLocalMessage = (roomId: string, messageId: string) => {
  setLocalMessagesForRoom(
    roomId,
    getLocalMessagesForRoom(roomId).filter((message) => message.id !== messageId),
  );
  if (selectedChatId.value === roomId) {
    messages.value = messages.value.filter((message) => message.id !== messageId);
  }
};

const setSelectedMessageIds = (messageIds: Iterable<string>) => {
  selectedMessageIds.value = Array.from(new Set(messageIds));
};

const exitMultiSelectMode = () => {
  isMultiSelectMode.value = false;
  selectedMessageIds.value = [];
  if (isForwardingSelectedMessages.value) {
    isForwardingSelectedMessages.value = false;
    isForwardMessageModalVisible.value = false;
    forwardingMessage.value = null;
  }
};

const enterMultiSelectMode = (message?: ChatMessage) => {
  closeMessageActionMenu();
  activeReactionPickerMessageId.value = null;
  isMultiSelectMode.value = true;

  if (message && canSelectMessageForMultiSelect(message)) {
    setSelectedMessageIds([message.id]);
  }
};

const isMessageSelected = (message: ChatMessage) =>
  selectedMessageIds.value.includes(message.id);

const toggleMessageSelection = (message: ChatMessage) => {
  if (!isMultiSelectMode.value || !canSelectMessageForMultiSelect(message)) {
    return;
  }

  const next = new Set(selectedMessageIds.value);
  if (next.has(message.id)) {
    next.delete(message.id);
  } else {
    next.add(message.id);
  }

  if (!next.size) {
    exitMultiSelectMode();
    return;
  }

  setSelectedMessageIds(next);
};

const syncSelectedMessages = () => {
  const nextSelectedIds = pruneSelectedMessageIds(
    messages.value,
    selectedMessageIds.value,
  );
  const hasChanged =
    selectedMessageIds.value.length !== nextSelectedIds.size ||
    selectedMessageIds.value.some((messageId) => !nextSelectedIds.has(messageId));

  if (!hasChanged) {
    return;
  }

  if (!nextSelectedIds.size) {
    exitMultiSelectMode();
    return;
  }

  setSelectedMessageIds(nextSelectedIds);
};

const handleEnterMultiSelectMode = (message: ChatMessage) => {
  if (!canSelectMessageForMultiSelect(message)) {
    return;
  }

  enterMultiSelectMode(message);
};

const getRetryStorageKey = () =>
  buildRetryableLocalMessagesStorageKey(props.currentUser.id);

const persistRetryableLocalMessages = () => {
  const allLocalMessages = Object.values(localMessagesByRoom.value).flat();
  saveRetryableLocalMessages(allLocalMessages, undefined, getRetryStorageKey());
};

const clearLocalMessageRetry = (messageId: string) => {
  const existingTimer = localMessageRetryTimers.get(messageId);
  if (existingTimer !== undefined) {
    window.clearTimeout(existingTimer);
    localMessageRetryTimers.delete(messageId);
  }
};

const restoreRetryableLocalMessagesFromStorage = () => {
  const restoredMessages = restoreRetryableLocalMessages(
    undefined,
    getRetryStorageKey(),
  );
  if (!restoredMessages.length) {
    persistRetryableLocalMessages();
    return;
  }

  const next = { ...localMessagesByRoom.value };
  for (const message of restoredMessages) {
    const roomMessages = next[message.roomId] ?? [];
    if (roomMessages.some((currentMessage) => currentMessage.id === message.id)) {
      continue;
    }
    next[message.roomId] = [...roomMessages, message];
  }
  localMessagesByRoom.value = next;
  persistRetryableLocalMessages();
};

const scheduleLocalMessageRetry = (
  roomId: string,
  messageId: string,
  delayMs = LOCAL_MESSAGE_RETRY_DELAY_MS,
) => {
  if (
    localMessageRetryTimers.has(messageId) ||
    localMessageRetryInFlight.has(messageId)
  ) {
    return;
  }

  const message = getLocalMessagesForRoom(roomId).find(
    (currentMessage) => currentMessage.id === messageId,
  );
  if (!message || !canResendLocalMessage(message)) {
    return;
  }

  const timerId = window.setTimeout(() => {
    localMessageRetryTimers.delete(messageId);
    void executeLocalMessageRetry(roomId, messageId, {
      manual: false,
    });
  }, delayMs);
  localMessageRetryTimers.set(messageId, timerId);
};

const clearAllLocalMessageRetryTimers = () => {
  localMessageRetryTimers.forEach((timerId) => {
    window.clearTimeout(timerId);
  });
  localMessageRetryTimers.clear();
  localMessageRetryInFlight.clear();
};

const markLocalMessageFailedAndScheduleRetry = (
  roomId: string,
  messageId: string,
  errorMessage: string,
) => {
  updateLocalMessage(roomId, messageId, (message) =>
    markLocalMessageFailed(message, errorMessage),
  );
  scheduleLocalMessageRetry(roomId, messageId);
};

const executeLocalMessageRetry = async (
  roomId: string,
  messageId: string,
  options: {
    manual: boolean;
  },
) => {
  const message = getLocalMessagesForRoom(roomId).find(
    (currentMessage) => currentMessage.id === messageId,
  );
  if (!message || !canResendLocalMessage(message)) {
    clearLocalMessageRetry(messageId);
    if (options.manual) {
      resendingMessageId.value = null;
    }
    return;
  }

  if (localMessageRetryInFlight.has(messageId)) {
    if (options.manual) {
      resendingMessageId.value = null;
    }
    return;
  }

  clearLocalMessageRetry(messageId);
  if (options.manual) {
    updateLocalMessage(roomId, messageId, markLocalMessageSending);
  }

  localMessageRetryInFlight.add(messageId);
  let nextRetryErrorMessage: string | null = null;
  try {
    const response = await resendLocalMessage({
      roomId,
      currentUserId: props.currentUser.id,
      retryPayload: message.retryPayload!,
    });
    if (!response.success || !response.data) {
      nextRetryErrorMessage =
        response.message || "消息发送失败，3 秒后自动重试";
      updateLocalMessage(roomId, messageId, (currentMessage) =>
        markLocalMessageFailed(currentMessage, nextRetryErrorMessage),
      );
      if (options.manual) {
        notice.value = nextRetryErrorMessage;
      }
      return;
    }

    if (selectedChatId.value === roomId) {
      messages.value = replaceLocalMessage(messages.value, messageId, response.data);
    }
    removeLocalMessage(roomId, messageId);
    await loadChats({
      preferredRoomId: selectedChatId.value ?? roomId,
      preserveNotice: true,
      reloadMessages: roomId === selectedChatId.value,
    });
    if (options.manual) {
      notice.value = "消息已重发。";
    }
  } catch (error) {
    const fallbackMessage =
      error instanceof Error ? error.message : "消息发送失败，3 秒后自动重试";
    nextRetryErrorMessage = fallbackMessage;
    updateLocalMessage(roomId, messageId, (currentMessage) =>
      markLocalMessageFailed(currentMessage, fallbackMessage),
    );
    if (options.manual) {
      notice.value = fallbackMessage;
    }
  } finally {
    localMessageRetryInFlight.delete(messageId);
    if (nextRetryErrorMessage) {
      scheduleLocalMessageRetry(roomId, messageId);
    }
    if (options.manual) {
      resendingMessageId.value = null;
    }
  }
};

const clearTypingStopTimer = () => {
  if (typingStopSendTimer.value !== null) {
    window.clearTimeout(typingStopSendTimer.value);
    typingStopSendTimer.value = null;
  }
};

const clearTypingUserTimer = (userId: string) => {
  const existingTimer = typingCleanupTimers.get(userId);
  if (existingTimer !== undefined) {
    window.clearTimeout(existingTimer);
    typingCleanupTimers.delete(userId);
  }
};

const removeTypingUser = (userId: string) => {
  clearTypingUserTimer(userId);
  if (!(userId in typingUsers.value)) {
    return;
  }
  const next = { ...typingUsers.value };
  delete next[userId];
  typingUsers.value = next;
};

const clearTypingUsers = () => {
  typingCleanupTimers.forEach((timerId) => window.clearTimeout(timerId));
  typingCleanupTimers.clear();
  typingUsers.value = {};
};

const canSendTypingForRoom = (roomId: string | null) =>
  Boolean(
    roomId &&
      props.wsStatus === "authenticated" &&
      subscribedRoomId.value === roomId &&
      !groupComposerState.value.disabled &&
      !isSending.value,
  );

const sendTypingState = async (roomId: string, isTyping: boolean) => {
  if (!canSendTypingForRoom(roomId)) {
    if (!isTyping && typingRoomId.value === roomId) {
      typingIsTyping.value = false;
      typingRoomId.value = null;
    }
    return;
  }

  try {
    await ChatApi.sendTyping({
      roomId,
      isTyping,
    });
    if (isTyping) {
      typingIsTyping.value = true;
      typingRoomId.value = roomId;
      lastTypingSentAt.value = Date.now();
      return;
    }
    if (typingRoomId.value === roomId) {
      typingIsTyping.value = false;
      typingRoomId.value = null;
    }
  } catch (error) {
    console.warn("[desktop-el-renderer] chat.typing.send failed", error);
  }
};

const stopTyping = async (roomId?: string | null) => {
  clearTypingStopTimer();

  const targetRoomId = roomId ?? typingRoomId.value ?? selectedChatId.value;
  if (!targetRoomId) {
    typingIsTyping.value = false;
    typingRoomId.value = null;
    return;
  }

  if (!typingIsTyping.value || typingRoomId.value !== targetRoomId) {
    if (typingRoomId.value === targetRoomId) {
      typingIsTyping.value = false;
      typingRoomId.value = null;
    }
    return;
  }

  await sendTypingState(targetRoomId, false);
};

const scheduleTypingFromInput = (value: string) => {
  if (groupComposerState.value.disabled || isSending.value) {
    void stopTyping();
    return;
  }

  const roomId = selectedChatId.value;
  if (!roomId) {
    return;
  }

  if (!value.trim()) {
    void stopTyping(roomId);
    return;
  }

  if (!canSendTypingForRoom(roomId)) {
    return;
  }

  const now = Date.now();
  if (
    !typingIsTyping.value ||
    typingRoomId.value !== roomId ||
    now - lastTypingSentAt.value >= 1200
  ) {
    void sendTypingState(roomId, true);
  }

  clearTypingStopTimer();
  typingStopSendTimer.value = window.setTimeout(() => {
    void stopTyping(roomId);
  }, 1500);
};

const handleComposerBlur = () => {
  void stopTyping();
};

const handleTypingUpdate = (event: Extract<ChatRealtimeEvent, { type: "typing_update" }>) => {
  if (event.roomId !== selectedChatId.value) {
    return;
  }

  const actorUserId = String(event.userId);
  if (actorUserId === props.currentUser.id) {
    return;
  }

  if (event.isTyping) {
    const expiresInMs = Math.max(0, event.expiresInMs);
    const expiresAt = Date.now() + expiresInMs;
    typingUsers.value = {
      ...typingUsers.value,
      [actorUserId]: expiresAt,
    };
    clearTypingUserTimer(actorUserId);
    const timerId = window.setTimeout(() => {
      const currentExpiresAt = typingUsers.value[actorUserId];
      if (currentExpiresAt !== undefined && currentExpiresAt <= Date.now()) {
        removeTypingUser(actorUserId);
      }
    }, expiresInMs + 50);
    typingCleanupTimers.set(actorUserId, timerId);
    return;
  }

  removeTypingUser(actorUserId);
};

const syncRoomSubscription = async (
  targetRoomId: string | null,
  previousRoomId?: string | null,
) => {
  const currentSequence = roomSubscriptionSequence + 1;
  roomSubscriptionSequence = currentSequence;

  if (
    previousRoomId &&
    previousRoomId !== targetRoomId &&
    subscribedRoomId.value === previousRoomId &&
    props.wsStatus === "authenticated"
  ) {
    try {
      await WebSocketApi.leaveRoom(previousRoomId);
    } catch (error) {
      console.warn("[desktop-el-renderer] ws.leave failed", error);
    }

    if (currentSequence !== roomSubscriptionSequence) {
      return;
    }
    if (subscribedRoomId.value === previousRoomId) {
      subscribedRoomId.value = null;
    }
  }

  if (props.wsStatus !== "authenticated" || !targetRoomId) {
    if (currentSequence === roomSubscriptionSequence) {
      subscribedRoomId.value = null;
    }
    return;
  }

  if (subscribedRoomId.value === targetRoomId) {
    if (draftMessage.value.trim()) {
      scheduleTypingFromInput(draftMessage.value);
    }
    return;
  }

  try {
    await WebSocketApi.joinRoom(targetRoomId);
    if (currentSequence !== roomSubscriptionSequence) {
      await WebSocketApi.leaveRoom(targetRoomId).catch(() => undefined);
      return;
    }
    subscribedRoomId.value = targetRoomId;
    if (draftMessage.value.trim()) {
      scheduleTypingFromInput(draftMessage.value);
    }
  } catch (error) {
    if (currentSequence === roomSubscriptionSequence) {
      subscribedRoomId.value = null;
    }
    console.warn("[desktop-el-renderer] ws.join failed", error);
  }
};

const resetGroupAdmins = () => {
  groupAdminsLoadSequence += 1;
  groupAdmins.value = [];
  isLoadingGroupAdmins.value = false;
};

const resetGroupJoinRequests = () => {
  groupJoinRequestsLoadSequence += 1;
  groupJoinRequests.value = [];
  isLoadingGroupJoinRequests.value = false;
};

const resetGroupMutes = () => {
  groupMutesLoadSequence += 1;
  groupMutes.value = [];
  isLoadingGroupMutes.value = false;
};

const resetGroupRules = () => {
  groupRulesLoadSequence += 1;
  groupRules.value = [];
  isLoadingGroupRules.value = false;
};

const resetGroupOperationLogs = () => {
  groupOperationLogsLoadSequence += 1;
  groupOperationLogs.value = [];
  hasMoreGroupOperationLogs.value = false;
  isLoadingGroupOperationLogs.value = false;
  isLoadingMoreGroupOperationLogs.value = false;
};

const patchRoomAvatar = (roomId: string, avatarUrl: string) => {
  chats.value = chats.value.map((chat) =>
    chat.roomId === roomId
      ? {
          ...chat,
          avatarUrl,
        }
      : chat,
  );

  if (groupDetail.value?.roomId === roomId) {
    groupDetail.value = {
      ...groupDetail.value,
      avatarUrl,
    };
  }
};

const removePendingAttachment = (attachmentId: string) => {
  pendingAttachments.value = pendingAttachments.value.filter(
    (item) => item.id !== attachmentId,
  );
  const next = { ...attachmentUploadProgressById.value };
  delete next[attachmentId];
  attachmentUploadProgressById.value = next;
};

const ensureAttachmentPreviewUrl = async (
  message: ChatMessage,
  part: ChatMessagePart,
) => {
  const previewAssetKey = getInlinePreviewAssetKey(part);
  if (!previewAssetKey || !shouldInlinePreviewAttachment(part.partType)) {
    return null;
  }

  const previewKey = getAttachmentPreviewKey(message, part);
  const existing = attachmentPreviewUrls.value[previewKey];
  if (existing) {
    return existing;
  }
  if (loadingAttachmentPreviewKeys.value[previewKey]) {
    return null;
  }

  setAttachmentPreviewLoading(previewKey, true);
  setAttachmentPreviewFailure(previewKey, null);
  try {
    const runtime = requireDesktopRuntime();
    const relativePath = buildAttachmentCacheRelativePath(
      "preview",
      previewAssetKey,
    );
    const cachedAsset = await runtime.file.getCachedPath({
      relativePath,
    });
    if (cachedAsset) {
      storeCachedAttachmentAsset(message, part, {
        filePath: cachedAsset.filePath,
        fileUrl: cachedAsset.fileUrl,
        preview: true,
      });
      return cachedAsset.fileUrl;
    }

    const previewUrl = await attachmentPreviewUrlStore.resolve({
      roomId: message.roomId,
      key: previewAssetKey,
      expiresInSeconds: 900,
    });
    try {
      const cached = await runtime.file.cacheFromURL({
        url: previewUrl,
        relativePath,
      });
      storeCachedAttachmentAsset(message, part, {
        filePath: cached.filePath,
        fileUrl: cached.fileUrl,
        preview: true,
      });
      return cached.fileUrl;
    } catch (cacheError) {
      console.warn(
        "[desktop-el-renderer] attachment preview cache failed, fallback to signed url",
        cacheError,
      );
      attachmentPreviewUrls.value = {
        ...attachmentPreviewUrls.value,
        [previewKey]: previewUrl,
      };
      return previewUrl;
    }
  } catch (error) {
    const fallbackMessage =
      error instanceof Error ? error.message : "加载附件预览失败";
    setAttachmentPreviewFailure(previewKey, fallbackMessage);
    console.warn("[desktop-el-renderer] attachment preview load failed", error);
    return null;
  } finally {
    setAttachmentPreviewLoading(previewKey, false);
  }
};

const ensureAttachmentPlayableUrl = async (
  message: ChatMessage,
  part: ChatMessagePart,
) => {
  const attachmentKey = part.attachment?.key;
  if (!attachmentKey || !shouldInlinePreviewAttachment(part.partType)) {
    return null;
  }

  const playableKey = getAttachmentPlayableKey(message, part);
  const existing = attachmentPlayableUrls.value[playableKey];
  if (existing) {
    return existing;
  }

  try {
    const runtime = requireDesktopRuntime();
    const relativePath = buildAttachmentCacheRelativePath(
      "playable",
      attachmentKey,
    );
    const cachedAsset = await runtime.file.getCachedPath({
      relativePath,
    });
    if (cachedAsset) {
      storeCachedAttachmentAsset(message, part, {
        filePath: cachedAsset.filePath,
        fileUrl: cachedAsset.fileUrl,
        playable: true,
      });
      return cachedAsset.fileUrl;
    }

    const playableUrl = await attachmentPreviewUrlStore.resolve({
      roomId: message.roomId,
      key: attachmentKey,
      expiresInSeconds: 900,
    });
    try {
      const cached = await runtime.file.cacheFromURL({
        url: playableUrl,
        relativePath,
      });
      storeCachedAttachmentAsset(message, part, {
        filePath: cached.filePath,
        fileUrl: cached.fileUrl,
        playable: true,
      });
      return cached.fileUrl;
    } catch (cacheError) {
      console.warn(
        "[desktop-el-renderer] attachment playable cache failed, fallback to signed url",
        cacheError,
      );
      attachmentPlayableUrls.value = {
        ...attachmentPlayableUrls.value,
        [playableKey]: playableUrl,
      };
      return playableUrl;
    }
  } catch (error) {
    const fallbackMessage =
      error instanceof Error ? error.message : "加载附件媒体失败";
    notice.value = fallbackMessage;
    console.warn(
      "[desktop-el-renderer] attachment playable load failed",
      error,
    );
    return null;
  }
};

const primeAttachmentPreviews = (roomMessages: ChatMessage[]) => {
  roomMessages.forEach((message) => {
    getMessageAttachmentParts(message).forEach((part) => {
      if (!shouldInlinePreviewAttachment(part.partType)) {
        return;
      }
      void ensureAttachmentPreviewUrl(message, part);
    });
  });
};

const pickSelectedChatId = (
  list: ChatSummary[],
  preferredRoomId?: string | null,
) => {
  if (preferredRoomId && list.some((chat) => chat.roomId === preferredRoomId)) {
    return preferredRoomId;
  }
  if (
    selectedChatId.value &&
    list.some((chat) => chat.roomId === selectedChatId.value)
  ) {
    return selectedChatId.value;
  }
  return list[0]?.roomId ?? null;
};

const setChatUnreadCount = (roomId: string, unreadCount: number) => {
  chats.value = chats.value.map((chat) =>
    chat.roomId === roomId
      ? {
          ...chat,
          unreadCount,
        }
      : chat,
  );
};

const markRoomRead = async (
  roomId: string | null,
  roomMessages: ChatMessage[],
) => {
  if (!roomId || !roomMessages.length) {
    return;
  }

  const latestMessage = roomMessages[roomMessages.length - 1];
  if (!latestMessage?.id) {
    return;
  }
  if (lastReadUntilMessageByRoom.value[roomId] === latestMessage.id) {
    return;
  }

  try {
    const response = await ChatApi.readUntil({
      roomId,
      messageId: latestMessage.id,
    });
    if (!response.success) {
      return;
    }

    lastReadUntilMessageByRoom.value = {
      ...lastReadUntilMessageByRoom.value,
      [roomId]: latestMessage.id,
    };
    setChatUnreadCount(roomId, 0);
  } catch (error) {
    console.warn("[desktop-el-renderer] chat.read_until failed", error);
  }
};

const loadMessages = async (roomId: string | null) => {
  if (!roomId) {
    messages.value = [];
    return;
  }

  isLoadingMessages.value = true;
  try {
    const response = await ChatApi.listMessages({
      roomId,
      limit: 50,
      currentUserId: props.currentUser.id,
    });
    if (!response.success || !response.data) {
      messages.value = mergeRemoteAndLocalMessages([], getLocalMessagesForRoom(roomId));
      notice.value = response.message || "消息列表加载失败";
      return;
    }

    messages.value = mergeRemoteAndLocalMessages(
      response.data,
      getLocalMessagesForRoom(roomId),
    );
    primeAttachmentPreviews(response.data);
    await markRoomRead(roomId, response.data);
  } catch (error) {
    messages.value = mergeRemoteAndLocalMessages([], getLocalMessagesForRoom(roomId));
    notice.value = error instanceof Error ? error.message : "消息列表加载失败";
  } finally {
    isLoadingMessages.value = false;
  }
};

const resetGroupContext = () => {
  groupContextLoadSequence += 1;
  groupDetail.value = null;
  groupMembers.value = [];
  isViewGroupMembersModalVisible.value = false;
  resetGroupAdmins();
  resetGroupJoinRequests();
  resetGroupMutes();
  resetGroupRules();
  resetGroupOperationLogs();
  isLoadingGroupContext.value = false;
};

const setGroupSettingsState = (settings: ChatGroupSettings | null) => {
  groupSettings.value = settings;
  groupMaxMembersDraft.value = settings ? String(settings.maxMembers) : "";
};

const resetGroupSettings = () => {
  groupSettingsLoadSequence += 1;
  setGroupSettingsState(null);
  isLoadingGroupSettings.value = false;
};

const loadGroupContext = async (roomId: string | null) => {
  const currentChat = chats.value.find((chat) => chat.roomId === roomId);
  if (!roomId || currentChat?.roomType !== "group") {
    resetGroupContext();
    return;
  }

  const currentSequence = groupContextLoadSequence + 1;
  groupContextLoadSequence = currentSequence;
  isLoadingGroupContext.value = true;
  try {
    const [roomResponse, membersResponse] = await Promise.all([
      ChatApi.getRoom({ roomId }),
      ChatApi.listRoomMembers({ roomId }),
    ]);

    if (
      currentSequence !== groupContextLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    if (!roomResponse.success || !roomResponse.data) {
      groupDetail.value = null;
      notice.value = roomResponse.message || "群详情加载失败";
    } else {
      groupDetail.value = roomResponse.data;
    }

    if (!membersResponse.success || !membersResponse.data) {
      groupMembers.value = [];
      if (!roomResponse.success || !roomResponse.data) {
        notice.value = membersResponse.message || "群成员列表加载失败";
      }
    } else {
      groupMembers.value = membersResponse.data;
    }
  } catch (error) {
    if (
      currentSequence !== groupContextLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    groupDetail.value = null;
    groupMembers.value = [];
    notice.value = error instanceof Error ? error.message : "群详情加载失败";
  } finally {
    if (currentSequence === groupContextLoadSequence) {
      isLoadingGroupContext.value = false;
    }
  }
};

const loadGroupAdmins = async (roomId: string | null) => {
  const currentChat = chats.value.find((chat) => chat.roomId === roomId);
  if (!roomId || currentChat?.roomType !== "group") {
    resetGroupAdmins();
    return;
  }

  const currentSequence = groupAdminsLoadSequence + 1;
  groupAdminsLoadSequence = currentSequence;
  isLoadingGroupAdmins.value = true;
  try {
    const response = await ChatApi.listGroupAdmins({ roomId });
    if (
      currentSequence !== groupAdminsLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    if (!response.success || !response.data) {
      groupAdmins.value = [];
      notice.value = response.message || "群管理员列表加载失败";
      return;
    }

    groupAdmins.value = response.data;
  } catch (error) {
    if (
      currentSequence !== groupAdminsLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    groupAdmins.value = [];
    notice.value =
      error instanceof Error ? error.message : "群管理员列表加载失败";
  } finally {
    if (currentSequence === groupAdminsLoadSequence) {
      isLoadingGroupAdmins.value = false;
    }
  }
};

const loadGroupJoinRequests = async (roomId: string | null) => {
  const currentChat = chats.value.find((chat) => chat.roomId === roomId);
  if (!roomId || currentChat?.roomType !== "group") {
    resetGroupJoinRequests();
    return;
  }

  const currentSequence = groupJoinRequestsLoadSequence + 1;
  groupJoinRequestsLoadSequence = currentSequence;
  isLoadingGroupJoinRequests.value = true;
  try {
    const response = await ChatApi.listGroupJoinRequests({ roomId });
    if (
      currentSequence !== groupJoinRequestsLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    if (!response.success || !response.data) {
      groupJoinRequests.value = [];
      notice.value = response.message || "入群申请列表加载失败";
      return;
    }

    groupJoinRequests.value = response.data;
  } catch (error) {
    if (
      currentSequence !== groupJoinRequestsLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    groupJoinRequests.value = [];
    notice.value =
      error instanceof Error ? error.message : "入群申请列表加载失败";
  } finally {
    if (currentSequence === groupJoinRequestsLoadSequence) {
      isLoadingGroupJoinRequests.value = false;
    }
  }
};

const loadGroupMutes = async (roomId: string | null) => {
  const currentChat = chats.value.find((chat) => chat.roomId === roomId);
  if (!roomId || currentChat?.roomType !== "group") {
    resetGroupMutes();
    return;
  }

  const currentSequence = groupMutesLoadSequence + 1;
  groupMutesLoadSequence = currentSequence;
  isLoadingGroupMutes.value = true;
  try {
    const response = await ChatApi.listGroupMutes({ roomId });
    if (
      currentSequence !== groupMutesLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    if (!response.success || !response.data) {
      groupMutes.value = [];
      notice.value = response.message || "群禁言列表加载失败";
      return;
    }

    groupMutes.value = response.data;
  } catch (error) {
    if (
      currentSequence !== groupMutesLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    groupMutes.value = [];
    notice.value = error instanceof Error ? error.message : "群禁言列表加载失败";
  } finally {
    if (currentSequence === groupMutesLoadSequence) {
      isLoadingGroupMutes.value = false;
    }
  }
};

const loadGroupRules = async (roomId: string | null) => {
  const currentChat = chats.value.find((chat) => chat.roomId === roomId);
  if (!roomId || currentChat?.roomType !== "group") {
    resetGroupRules();
    return;
  }

  const currentSequence = groupRulesLoadSequence + 1;
  groupRulesLoadSequence = currentSequence;
  isLoadingGroupRules.value = true;
  try {
    const response = await ChatApi.listGroupRules({ roomId });
    if (
      currentSequence !== groupRulesLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    if (!response.success || !response.data) {
      groupRules.value = [];
      notice.value = response.message || "群规列表加载失败";
      return;
    }

    groupRules.value = response.data;
  } catch (error) {
    if (
      currentSequence !== groupRulesLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    groupRules.value = [];
    notice.value = error instanceof Error ? error.message : "群规列表加载失败";
  } finally {
    if (currentSequence === groupRulesLoadSequence) {
      isLoadingGroupRules.value = false;
    }
  }
};

const loadGroupOperationLogs = async (payload: {
  roomId: string | null;
  append?: boolean;
}) => {
  const { roomId, append = false } = payload;
  const currentChat = chats.value.find((chat) => chat.roomId === roomId);
  if (!roomId || currentChat?.roomType !== "group") {
    resetGroupOperationLogs();
    return;
  }

  const currentSequence = groupOperationLogsLoadSequence + 1;
  groupOperationLogsLoadSequence = currentSequence;
  if (append) {
    isLoadingMoreGroupOperationLogs.value = true;
  } else {
    isLoadingGroupOperationLogs.value = true;
  }

  try {
    const response = await ChatApi.listGroupOperationLogs({
      roomId,
      limit: GROUP_OPERATION_LOGS_PAGE_SIZE,
      offset: append ? groupOperationLogs.value.length : 0,
    });
    if (
      currentSequence !== groupOperationLogsLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    if (!response.success || !response.data) {
      if (!append) {
        groupOperationLogs.value = [];
      }
      notice.value = response.message || "群操作日志加载失败";
      return;
    }

    groupOperationLogs.value = append
      ? [...groupOperationLogs.value, ...response.data.logs]
      : response.data.logs;
    hasMoreGroupOperationLogs.value =
      response.data.logs.length >= GROUP_OPERATION_LOGS_PAGE_SIZE;
  } catch (error) {
    if (
      currentSequence !== groupOperationLogsLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    if (!append) {
      groupOperationLogs.value = [];
    }
    notice.value = error instanceof Error ? error.message : "群操作日志加载失败";
  } finally {
    if (currentSequence === groupOperationLogsLoadSequence) {
      isLoadingGroupOperationLogs.value = false;
      isLoadingMoreGroupOperationLogs.value = false;
    }
  }
};

const loadGroupSettings = async (roomId: string | null) => {
  const currentChat = chats.value.find((chat) => chat.roomId === roomId);
  if (!roomId || currentChat?.roomType !== "group") {
    resetGroupSettings();
    return;
  }

  const currentSequence = groupSettingsLoadSequence + 1;
  groupSettingsLoadSequence = currentSequence;
  isLoadingGroupSettings.value = true;
  try {
    const response = await ChatApi.getGroupSettings({ roomId });
    if (
      currentSequence !== groupSettingsLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    if (!response.success || !response.data) {
      setGroupSettingsState(null);
      notice.value = response.message || "群设置加载失败";
      return;
    }

    setGroupSettingsState(response.data);
  } catch (error) {
    if (
      currentSequence !== groupSettingsLoadSequence ||
      selectedChatId.value !== roomId
    ) {
      return;
    }

    setGroupSettingsState(null);
    notice.value = error instanceof Error ? error.message : "群设置加载失败";
  } finally {
    if (currentSequence === groupSettingsLoadSequence) {
      isLoadingGroupSettings.value = false;
    }
  }
};

const loadChats = async (
  options: {
    preferredRoomId?: string | null;
    preserveNotice?: boolean;
    reloadMessages?: boolean;
  } = {},
) => {
  isLoadingChats.value = true;
  try {
    const response = await ChatApi.list();
    if (!response.success || !response.data) {
      chats.value = [];
      selectedChatId.value = null;
      messages.value = [];
      resetGroupContext();
      resetGroupSettings();
      notice.value = response.message || "会话列表加载失败";
      return;
    }

    const previousSelectedRoomId = selectedChatId.value;
    const nextSelectedRoomId = pickSelectedChatId(
      response.data,
      options.preferredRoomId,
    );
    const nextSelectedChat =
      response.data.find((chat) => chat.roomId === nextSelectedRoomId) || null;
    chats.value = response.data;
    selectedChatId.value = nextSelectedRoomId;
    if (nextSelectedRoomId !== previousSelectedRoomId) {
      activeMessageActionMenuId.value = null;
      activeReactionPickerMessageId.value = null;
      editingMessageTarget.value = null;
      editingMessageDraft.value = "";
    }
    if (!nextSelectedRoomId) {
      messages.value = [];
    } else if (
      options.reloadMessages !== false ||
      nextSelectedRoomId !== previousSelectedRoomId
    ) {
      await loadMessages(nextSelectedRoomId);
    }
    if (nextSelectedChat?.roomType === "group") {
      await loadGroupContext(nextSelectedRoomId);
      await loadGroupSettings(nextSelectedRoomId);
    } else {
      resetGroupContext();
      resetGroupSettings();
    }

    if (!options.preserveNotice) {
      notice.value = `已从 Go core 同步 ${response.data.length} 个会话与最近 50 条历史消息。`;
    }
  } catch (error) {
    chats.value = [];
    selectedChatId.value = null;
    messages.value = [];
    resetGroupContext();
    resetGroupSettings();
    notice.value = error instanceof Error ? error.message : "会话列表加载失败";
  } finally {
    isLoadingChats.value = false;
  }
};

const loadCreateGroupFriends = async () => {
  isLoadingCreateGroupFriends.value = true;
  try {
    const response = await FriendApi.getMyFriendList();
    if (!response.success || !response.data) {
      createGroupFriends.value = [];
      notice.value = response.message || "好友列表加载失败";
      return;
    }

    createGroupFriends.value = response.data.map(mapGroupCreateFriend);
  } catch (error) {
    createGroupFriends.value = [];
    notice.value = error instanceof Error ? error.message : "好友列表加载失败";
  } finally {
    isLoadingCreateGroupFriends.value = false;
  }
};

const handleOpenCreateGroupModal = async () => {
  if (isCreatingGroup.value) {
    return;
  }

  isCreateGroupModalVisible.value = true;
  await loadCreateGroupFriends();
};

const closeCreateGroupModal = () => {
  if (isCreatingGroup.value) {
    return;
  }
  isCreateGroupModalVisible.value = false;
};

const handleOpenAddGroupMembersModal = async () => {
  if (isAddingGroupMembers.value) {
    return;
  }
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupMembers.value) {
    notice.value = "当前账号没有添加群成员的权限。";
    return;
  }

  await loadCreateGroupFriends();
  isAddGroupMembersModalVisible.value = true;
};

const handleOpenManageGroupAdminsModal = async () => {
  if (isUpdatingGroupAdmins.value) {
    return;
  }
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupAdmins.value) {
    notice.value = "只有群主可以管理管理员。";
    return;
  }

  isManageGroupAdminsModalVisible.value = true;
  await loadGroupAdmins(selectedChatId.value);
};

const handleOpenManageGroupJoinRequestsModal = async () => {
  if (isReviewingGroupJoinRequests.value) {
    return;
  }
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupJoinRequests.value) {
    notice.value = "当前账号没有审核入群申请的权限。";
    return;
  }

  isManageGroupJoinRequestsModalVisible.value = true;
  await loadGroupJoinRequests(selectedChatId.value);
};

const handleOpenManageGroupMutesModal = async () => {
  if (isUpdatingGroupMutes.value) {
    return;
  }
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupMutes.value) {
    notice.value = "当前账号没有管理群禁言的权限。";
    return;
  }

  isManageGroupMutesModalVisible.value = true;
  await loadGroupMutes(selectedChatId.value);
};

const handleOpenManageGroupRulesModal = async () => {
  if (isUpdatingGroupRules.value) {
    return;
  }
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }

  isManageGroupRulesModalVisible.value = true;
  await loadGroupRules(selectedChatId.value);
};

const handleOpenManageGroupOperationLogsModal = async () => {
  if (isLoadingGroupOperationLogs.value || isLoadingMoreGroupOperationLogs.value) {
    return;
  }
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupOperationLogs.value) {
    notice.value = "当前账号没有查看群操作日志的权限。";
    return;
  }

  isManageGroupOperationLogsModalVisible.value = true;
  await loadGroupOperationLogs({
    roomId: selectedChatId.value,
  });
};

const handleOpenTransferGroupOwnerModal = async () => {
  if (isTransferringGroupOwner.value) {
    return;
  }
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canTransferSelectedGroupOwner.value) {
    notice.value = "只有群主可以转让群主身份。";
    return;
  }
  if (!groupMembers.value.length) {
    await loadGroupContext(selectedChatId.value);
  }
  if (!transferableGroupOwnerMembers.value.length) {
    notice.value = "当前群暂无可转让的成员。";
    return;
  }

  isTransferGroupOwnerModalVisible.value = true;
};

const closeAddGroupMembersModal = () => {
  if (isAddingGroupMembers.value) {
    return;
  }
  isAddGroupMembersModalVisible.value = false;
};

const closeManageGroupAdminsModal = () => {
  if (isUpdatingGroupAdmins.value) {
    return;
  }
  isManageGroupAdminsModalVisible.value = false;
};

const closeManageGroupJoinRequestsModal = () => {
  if (isReviewingGroupJoinRequests.value) {
    return;
  }
  isManageGroupJoinRequestsModalVisible.value = false;
};

const closeManageGroupMutesModal = () => {
  if (isUpdatingGroupMutes.value) {
    return;
  }
  isManageGroupMutesModalVisible.value = false;
};

const closeManageGroupRulesModal = () => {
  if (isUpdatingGroupRules.value) {
    return;
  }
  isManageGroupRulesModalVisible.value = false;
};

const closeManageGroupOperationLogsModal = () => {
  if (isLoadingMoreGroupOperationLogs.value) {
    return;
  }
  isManageGroupOperationLogsModalVisible.value = false;
};

const closeTransferGroupOwnerModal = () => {
  if (isTransferringGroupOwner.value) {
    return;
  }
  isTransferGroupOwnerModalVisible.value = false;
};

const handleOpenRemoveGroupMembersModal = () => {
  if (isRemovingGroupMembers.value) {
    return;
  }
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupMembers.value) {
    notice.value = "当前账号没有删除群成员的权限。";
    return;
  }

  isRemoveGroupMembersModalVisible.value = true;
};

const closeRemoveGroupMembersModal = () => {
  if (isRemovingGroupMembers.value) {
    return;
  }
  isRemoveGroupMembersModalVisible.value = false;
};

const handleAddGroupMembersModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenAddGroupMembersModal();
    return;
  }
  closeAddGroupMembersModal();
};

const handleManageGroupAdminsModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenManageGroupAdminsModal();
    return;
  }
  closeManageGroupAdminsModal();
};

const handleManageGroupJoinRequestsModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenManageGroupJoinRequestsModal();
    return;
  }
  closeManageGroupJoinRequestsModal();
};

const handleManageGroupMutesModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenManageGroupMutesModal();
    return;
  }
  closeManageGroupMutesModal();
};

const handleManageGroupRulesModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenManageGroupRulesModal();
    return;
  }
  closeManageGroupRulesModal();
};

const handleManageGroupOperationLogsModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenManageGroupOperationLogsModal();
    return;
  }
  closeManageGroupOperationLogsModal();
};

const handleTransferGroupOwnerModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenTransferGroupOwnerModal();
    return;
  }
  closeTransferGroupOwnerModal();
};

const handleOpenViewGroupMembersModal = async () => {
  if (!isSelectedGroupChat.value || !selectedChatId.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!groupMembers.value.length) {
    await loadGroupContext(selectedChatId.value);
  }

  isViewGroupMembersModalVisible.value = true;
};

const closeViewGroupMembersModal = () => {
  isViewGroupMembersModalVisible.value = false;
};

const handleViewGroupMembersModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenViewGroupMembersModal();
    return;
  }
  closeViewGroupMembersModal();
};

const handleOpenAddGroupMembersFromMemberPanel = async () => {
  isViewGroupMembersModalVisible.value = false;
  await handleOpenAddGroupMembersModal();
};

const handleOpenRemoveGroupMembersFromMemberPanel = () => {
  isViewGroupMembersModalVisible.value = false;
  handleOpenRemoveGroupMembersModal();
};

const handleOpenManageGroupAdminsFromMemberPanel = async () => {
  isViewGroupMembersModalVisible.value = false;
  await handleOpenManageGroupAdminsModal();
};

const handleOpenTransferGroupOwnerFromMemberPanel = async () => {
  isViewGroupMembersModalVisible.value = false;
  await handleOpenTransferGroupOwnerModal();
};

const handleLoadMoreGroupOperationLogs = async () => {
  const roomId = selectedChatId.value;
  if (
    !roomId ||
    !isSelectedGroupChat.value ||
    isLoadingGroupOperationLogs.value ||
    isLoadingMoreGroupOperationLogs.value ||
    !hasMoreGroupOperationLogs.value
  ) {
    return;
  }

  await loadGroupOperationLogs({
    roomId,
    append: true,
  });
};

const handleRemoveGroupMembersModalVisibleChange = (visible: boolean) => {
  if (visible) {
    handleOpenRemoveGroupMembersModal();
    return;
  }
  closeRemoveGroupMembersModal();
};

const handleCreateGroupModalVisibleChange = (visible: boolean) => {
  if (visible) {
    void handleOpenCreateGroupModal();
    return;
  }
  closeCreateGroupModal();
};

const resolveCreatedGroupChat = async (createdGroup: {
  roomId: string;
  roomName: string;
}) => {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    await loadChats({
      preferredRoomId: createdGroup.roomId,
      preserveNotice: true,
    });
    const matched = findCreatedGroupChat(chats.value, createdGroup);
    if (matched) {
      return matched;
    }
    if (attempt < 2) {
      await new Promise((resolve) => setTimeout(resolve, 300));
    }
  }

  return null;
};

const selectChat = async (chatId: string) => {
  replyingMessage.value = null;
  selectedChatId.value = chatId;
  await loadMessages(chatId);
  const nextSelectedChat = chats.value.find((chat) => chat.roomId === chatId);
  if (nextSelectedChat?.roomType === "group") {
    await loadGroupContext(chatId);
    await loadGroupSettings(chatId);
    if (isManageGroupRulesModalVisible.value) {
      await loadGroupRules(chatId);
    }
    if (isManageGroupOperationLogsModalVisible.value) {
      await loadGroupOperationLogs({
        roomId: chatId,
      });
    }
    return;
  }
  resetGroupContext();
  resetGroupSettings();
};

const handleOpenChatRequest = async (request: OpenChatRequest) => {
  isOpeningPrivateChat.value = true;
  notice.value = `正在为 ${request.displayName} 打开私聊...`;

  try {
    const response = await ChatApi.ensurePrivateChat({
      friendUserId: request.friendUserId,
    });
    if (!response.success || !response.data) {
      notice.value =
        response.message || `打开 ${request.displayName} 的聊天失败`;
      return;
    }

    await loadChats({
      preferredRoomId: response.data.roomId,
      preserveNotice: true,
    });
    notice.value = `已打开与 ${response.data.friendName} 的聊天，历史消息已同步。`;
  } catch (error) {
    notice.value =
      error instanceof Error
        ? error.message
        : `打开 ${request.displayName} 的聊天失败`;
  } finally {
    isOpeningPrivateChat.value = false;
    emit("chat-request-consumed", request.requestId);
  }
};

const handleCreateGroup = async (payload: {
  name: string;
  memberUserIds: string[];
}) => {
  if (isCreatingGroup.value) {
    return;
  }

  isCreatingGroup.value = true;
  notice.value = `正在创建群聊 ${payload.name}...`;

  try {
    const response = await ChatApi.createGroup({
      name: payload.name,
      memberUserIds: payload.memberUserIds,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "创建群聊失败";
      return;
    }

    const matchedChat = await resolveCreatedGroupChat(response.data);
    if (matchedChat && matchedChat.roomId !== selectedChatId.value) {
      await selectChat(matchedChat.roomId);
    }

    isCreateGroupModalVisible.value = false;
    if (matchedChat) {
      notice.value = `群聊 ${matchedChat.title} 已创建并进入。`;
      return;
    }

    notice.value = `群聊 ${response.data.roomName} 已创建，等待会话列表同步。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "创建群聊失败";
  } finally {
    isCreatingGroup.value = false;
  }
};

const handleAddGroupMembers = async (payload: {
  memberUserIds: string[];
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupMembers.value) {
    notice.value = "当前账号没有添加群成员的权限。";
    return;
  }
  if (!payload.memberUserIds.length) {
    notice.value = "请至少选择 1 位好友。";
    return;
  }

  isAddingGroupMembers.value = true;
  notice.value = `正在向当前群添加 ${payload.memberUserIds.length} 位成员...`;
  try {
    const response = await ChatApi.addGroupMembers({
      roomId,
      userIds: payload.memberUserIds,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "添加群成员失败";
      return;
    }

    isAddGroupMembersModalVisible.value = false;
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
      reloadMessages: false,
    });
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);

    const addedCount = response.data.addedUserIds.length;
    const skippedCount = response.data.skippedUserIds.length;
    if (addedCount > 0 && skippedCount > 0) {
      notice.value = `已添加 ${addedCount} 位成员，跳过 ${skippedCount} 位已在群内成员。`;
    } else if (addedCount > 0) {
      notice.value = `已添加 ${addedCount} 位成员。`;
    } else if (skippedCount > 0) {
      notice.value = `没有新增成员，已跳过 ${skippedCount} 位已在群内成员。`;
    } else {
      notice.value = "本次没有新增成员。";
    }
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "添加群成员失败";
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
  } finally {
    isAddingGroupMembers.value = false;
  }
};

const handleAppointGroupAdmins = async (payload: {
  memberUserIds: string[];
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupAdmins.value) {
    notice.value = "只有群主可以管理管理员。";
    return;
  }
  if (!payload.memberUserIds.length) {
    notice.value = "请至少选择 1 位成员。";
    return;
  }

  isUpdatingGroupAdmins.value = true;
  notice.value = `正在任命 ${payload.memberUserIds.length} 位管理员...`;
  try {
    const results = await Promise.allSettled(
      payload.memberUserIds.map((userId) =>
        ChatApi.appointGroupAdmin({
          roomId,
          userId,
        }),
      ),
    );
    const successCount = results.filter(
      (result) =>
        result.status === "fulfilled" &&
        result.value.success &&
        result.value.data,
    ).length;
    const failedCount = results.length - successCount;

    if (successCount > 0) {
      isManageGroupAdminsModalVisible.value = false;
      await loadChats({
        preferredRoomId: roomId,
        preserveNotice: true,
        reloadMessages: false,
      });
      await loadGroupContext(roomId);
      await loadGroupAdmins(roomId);
      await loadGroupSettings(roomId);
      notice.value =
        failedCount > 0
          ? `已任命 ${successCount} 位管理员，${failedCount} 位任命失败。`
          : `已任命 ${successCount} 位管理员。`;
      return;
    }

    notice.value = "任命管理员失败。";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "任命管理员失败";
    await loadGroupContext(roomId);
    await loadGroupAdmins(roomId);
    await loadGroupSettings(roomId);
  } finally {
    isUpdatingGroupAdmins.value = false;
  }
};

const handleRemoveGroupAdmin = async (payload: {
  adminId: string;
  displayName: string;
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value || isUpdatingGroupAdmins.value) {
    return;
  }
  if (!canManageSelectedGroupAdmins.value) {
    notice.value = "只有群主可以管理管理员。";
    return;
  }

  const confirmed = window.confirm(
    `确定要撤销 ${payload.displayName} 的管理员权限吗？`,
  );
  if (!confirmed) {
    return;
  }

  isUpdatingGroupAdmins.value = true;
  notice.value = `正在撤销 ${payload.displayName} 的管理员权限...`;
  try {
    const response = await ChatApi.removeGroupAdmin({
      roomId,
      adminId: payload.adminId,
    });
    if (!response.success || !response.data?.success) {
      notice.value = response.message || "撤销管理员失败";
      return;
    }

    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
      reloadMessages: false,
    });
    await loadGroupContext(roomId);
    await loadGroupAdmins(roomId);
    await loadGroupSettings(roomId);
    notice.value = `已撤销 ${payload.displayName} 的管理员权限。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "撤销管理员失败";
    await loadGroupContext(roomId);
    await loadGroupAdmins(roomId);
    await loadGroupSettings(roomId);
  } finally {
    isUpdatingGroupAdmins.value = false;
  }
};

const handleReviewGroupJoinRequest = async (payload: {
  requestId: string;
  status: "approved" | "rejected";
  displayName: string;
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value || isReviewingGroupJoinRequests.value) {
    return;
  }
  if (!canManageSelectedGroupJoinRequests.value) {
    notice.value = "当前账号没有审核入群申请的权限。";
    return;
  }

  const actionLabel = payload.status === "approved" ? "通过" : "拒绝";
  const confirmed = window.confirm(
    `确定要${actionLabel} ${payload.displayName} 的入群申请吗？`,
  );
  if (!confirmed) {
    return;
  }

  isReviewingGroupJoinRequests.value = true;
  notice.value = `正在${actionLabel} ${payload.displayName} 的入群申请...`;
  try {
    const response = await ChatApi.reviewGroupJoinRequest({
      roomId,
      requestId: payload.requestId,
      status: payload.status,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "审核入群申请失败";
      return;
    }

    await loadGroupJoinRequests(roomId);
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
      reloadMessages: false,
    });
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
    notice.value =
      payload.status === "approved"
        ? `已通过 ${payload.displayName} 的入群申请。`
        : `已拒绝 ${payload.displayName} 的入群申请。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "审核入群申请失败";
    await loadGroupJoinRequests(roomId);
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
  } finally {
    isReviewingGroupJoinRequests.value = false;
  }
};

const handleMuteGroupMembers = async (payload: {
  memberUserIds: string[];
  durationHours: number;
  reason?: string;
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupMutes.value) {
    notice.value = "当前账号没有管理群禁言的权限。";
    return;
  }
  if (!payload.memberUserIds.length) {
    notice.value = "请至少选择 1 位成员。";
    return;
  }

  isUpdatingGroupMutes.value = true;
  notice.value = `正在禁言 ${payload.memberUserIds.length} 位成员...`;
  try {
    const results = await Promise.allSettled(
      payload.memberUserIds.map((userId) =>
        ChatApi.muteGroupMember({
          roomId,
          userId,
          durationHours: payload.durationHours,
          reason: payload.reason,
        }),
      ),
    );
    const successCount = results.filter(
      (result) =>
        result.status === "fulfilled" &&
        result.value.success &&
        result.value.data,
    ).length;
    const failedCount = results.length - successCount;

    if (successCount > 0) {
      await loadGroupMutes(roomId);
      await loadChats({
        preferredRoomId: roomId,
        preserveNotice: true,
        reloadMessages: false,
      });
      await loadGroupContext(roomId);
      await loadGroupSettings(roomId);
      notice.value =
        failedCount > 0
          ? `已禁言 ${successCount} 位成员，${failedCount} 位禁言失败。`
          : `已禁言 ${successCount} 位成员。`;
      return;
    }

    notice.value = "禁言成员失败。";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "禁言成员失败";
    await loadGroupMutes(roomId);
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
  } finally {
    isUpdatingGroupMutes.value = false;
  }
};

const handleUnmuteGroupMember = async (payload: {
  userId: string;
  displayName: string;
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value || isUpdatingGroupMutes.value) {
    return;
  }
  if (!canManageSelectedGroupMutes.value) {
    notice.value = "当前账号没有管理群禁言的权限。";
    return;
  }

  const confirmed = window.confirm(
    `确定要解除 ${payload.displayName} 的禁言吗？`,
  );
  if (!confirmed) {
    return;
  }

  isUpdatingGroupMutes.value = true;
  notice.value = `正在解除 ${payload.displayName} 的禁言...`;
  try {
    const response = await ChatApi.unmuteGroupMember({
      roomId,
      userId: payload.userId,
    });
    if (!response.success || !response.data?.success) {
      notice.value = response.message || "解除禁言失败";
      return;
    }

    await loadGroupMutes(roomId);
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
      reloadMessages: false,
    });
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
    notice.value = `已解除 ${payload.displayName} 的禁言。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "解除禁言失败";
    await loadGroupMutes(roomId);
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
  } finally {
    isUpdatingGroupMutes.value = false;
  }
};

const handleCreateGroupRule = async (payload: {
  title: string;
  content: string;
  orderIndex: number;
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canEditSelectedGroupRules.value) {
    notice.value = "当前账号没有管理群规的权限。";
    return;
  }

  isUpdatingGroupRules.value = true;
  notice.value = `正在新增群规「${payload.title}」...`;
  try {
    const response = await ChatApi.createGroupRule({
      roomId,
      title: payload.title,
      content: payload.content,
      orderIndex: payload.orderIndex,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "新增群规失败";
      return;
    }

    await loadGroupRules(roomId);
    notice.value = `已新增群规「${payload.title}」。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "新增群规失败";
    await loadGroupRules(roomId);
  } finally {
    isUpdatingGroupRules.value = false;
  }
};

const handleUpdateGroupRule = async (payload: {
  ruleId: string;
  title: string;
  content: string;
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canEditSelectedGroupRules.value) {
    notice.value = "当前账号没有管理群规的权限。";
    return;
  }

  isUpdatingGroupRules.value = true;
  notice.value = `正在更新群规「${payload.title}」...`;
  try {
    const response = await ChatApi.updateGroupRule({
      roomId,
      ruleId: payload.ruleId,
      title: payload.title,
      content: payload.content,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "更新群规失败";
      return;
    }

    await loadGroupRules(roomId);
    notice.value = `已更新群规「${payload.title}」。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "更新群规失败";
    await loadGroupRules(roomId);
  } finally {
    isUpdatingGroupRules.value = false;
  }
};

const handleDeleteGroupRule = async (payload: {
  ruleId: string;
  title: string;
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value || isUpdatingGroupRules.value) {
    return;
  }
  if (!canEditSelectedGroupRules.value) {
    notice.value = "当前账号没有管理群规的权限。";
    return;
  }

  const confirmed = window.confirm(`确定要删除群规「${payload.title}」吗？`);
  if (!confirmed) {
    return;
  }

  isUpdatingGroupRules.value = true;
  notice.value = `正在删除群规「${payload.title}」...`;
  try {
    const response = await ChatApi.deleteGroupRule({
      roomId,
      ruleId: payload.ruleId,
    });
    if (!response.success || !response.data?.success) {
      notice.value = response.message || "删除群规失败";
      return;
    }

    await loadGroupRules(roomId);
    notice.value = `已删除群规「${payload.title}」。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "删除群规失败";
    await loadGroupRules(roomId);
  } finally {
    isUpdatingGroupRules.value = false;
  }
};

const handleRemoveGroupMembers = async (payload: {
  memberUserIds: string[];
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canManageSelectedGroupMembers.value) {
    notice.value = "当前账号没有删除群成员的权限。";
    return;
  }
  if (!payload.memberUserIds.length) {
    notice.value = "请至少选择 1 位成员。";
    return;
  }

  isRemovingGroupMembers.value = true;
  notice.value = `正在移除 ${payload.memberUserIds.length} 位群成员...`;
  try {
    const results = await Promise.allSettled(
      payload.memberUserIds.map((userId) =>
        ChatApi.removeGroupMember({
          roomId,
          userId,
        }),
      ),
    );
    const successCount = results.filter(
      (result) =>
        result.status === "fulfilled" &&
        result.value.success &&
        result.value.data?.success,
    ).length;
    const failedCount = results.length - successCount;

    if (successCount > 0) {
      isRemoveGroupMembersModalVisible.value = false;
      await loadChats({
        preferredRoomId: roomId,
        preserveNotice: true,
        reloadMessages: false,
      });
      await loadGroupContext(roomId);
      await loadGroupSettings(roomId);
      notice.value =
        failedCount > 0
          ? `已移除 ${successCount} 位成员，${failedCount} 位移除失败。`
          : `已移除 ${successCount} 位成员。`;
      return;
    }

    notice.value = "删除成员失败。";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "删除成员失败";
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
  } finally {
    isRemovingGroupMembers.value = false;
  }
};

const handleTransferGroupOwner = async (payload: {
  newOwnerId: string;
  displayName: string;
}) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value) {
    notice.value = "请先选择一个群聊。";
    return;
  }
  if (!canTransferSelectedGroupOwner.value) {
    notice.value = "只有群主可以转让群主身份。";
    return;
  }

  isTransferringGroupOwner.value = true;
  notice.value = `正在将群主转让给 ${payload.displayName}...`;
  try {
    const response = await ChatApi.transferGroupOwner({
      roomId,
      newOwnerId: payload.newOwnerId,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "转让群主失败";
      return;
    }

    isTransferGroupOwnerModalVisible.value = false;
    isManageGroupAdminsModalVisible.value = false;
    isManageGroupOperationLogsModalVisible.value = false;
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
      reloadMessages: false,
    });
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
    notice.value = `已将群主转让给 ${payload.displayName}。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "转让群主失败";
    await loadGroupContext(roomId);
    await loadGroupSettings(roomId);
  } finally {
    isTransferringGroupOwner.value = false;
  }
};

const handleToggleGroupGlobalMute = async () => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value || isUpdatingGlobalMute.value) {
    return;
  }
  if (!canUpdateSelectedGroupSettings.value) {
    notice.value = "当前账号没有修改全员禁言的权限。";
    return;
  }
  if (!groupSettings.value) {
    notice.value = "群设置尚未同步完成，请稍后再试。";
    return;
  }

  const nextEnabled = !groupSettings.value.globalMuteEnabled;
  const confirmed = window.confirm(
    nextEnabled
      ? "确定开启当前群的全员禁言吗？"
      : "确定解除当前群的全员禁言吗？",
  );
  if (!confirmed) {
    return;
  }

  isUpdatingGlobalMute.value = true;
  try {
    const response = await ChatApi.updateGroupGlobalMute({
      roomId,
      enabled: nextEnabled,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "更新全员禁言失败";
      return;
    }

    groupSettings.value = response.data;
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
      reloadMessages: false,
    });
    notice.value = nextEnabled
      ? "已开启当前群全员禁言。"
      : "已解除当前群全员禁言。";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "更新全员禁言失败";
    await loadGroupSettings(roomId);
  } finally {
    isUpdatingGlobalMute.value = false;
  }
};

const handleUpdateGroupSettings = async (
  patch: {
    joinApprovalRequired?: boolean;
    memberCanInvite?: boolean;
    memberCanAddFriends?: boolean;
    requireAdminToAddFriends?: boolean;
    maxMembers?: number;
  },
  options: {
    settingKey: GroupSettingActionKey;
    successMessage: string;
  },
) => {
  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value || updatingGroupSettingKey.value) {
    return;
  }
  if (!canUpdateSelectedGroupSettings.value) {
    notice.value = "当前账号没有修改群设置的权限。";
    return;
  }
  if (!groupSettings.value) {
    notice.value = "群设置尚未同步完成，请稍后再试。";
    return;
  }

  updatingGroupSettingKey.value = options.settingKey;
  try {
    const response = await ChatApi.updateGroupSettings({
      roomId,
      ...patch,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "更新群设置失败";
      return;
    }

    setGroupSettingsState(response.data);
    notice.value = options.successMessage;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "更新群设置失败";
    await loadGroupSettings(roomId);
  } finally {
    if (updatingGroupSettingKey.value === options.settingKey) {
      updatingGroupSettingKey.value = null;
    }
  }
};

const handleToggleJoinApproval = async () => {
  if (!groupSettings.value) {
    return;
  }

  const nextValue = !groupSettings.value.joinApprovalRequired;
  await handleUpdateGroupSettings(
    {
      joinApprovalRequired: nextValue,
    },
    {
      settingKey: "joinApprovalRequired",
      successMessage: nextValue ? "已开启入群审批。" : "已关闭入群审批。",
    },
  );
};

const handleToggleMemberInvite = async () => {
  if (!groupSettings.value) {
    return;
  }

  const nextValue = !groupSettings.value.memberCanInvite;
  await handleUpdateGroupSettings(
    {
      memberCanInvite: nextValue,
    },
    {
      settingKey: "memberCanInvite",
      successMessage: nextValue ? "已开启成员邀请。" : "已关闭成员邀请。",
    },
  );
};

const handleToggleMemberCanAddFriends = async () => {
  if (!groupSettings.value) {
    return;
  }

  const nextValue = !groupSettings.value.memberCanAddFriends;
  await handleUpdateGroupSettings(
    {
      memberCanAddFriends: nextValue,
    },
    {
      settingKey: "memberCanAddFriends",
      successMessage: nextValue ? "已开启群内加好友。" : "已关闭群内加好友。",
    },
  );
};

const handleToggleRequireAdminToAddFriends = async () => {
  if (!groupSettings.value) {
    return;
  }

  const nextValue = !groupSettings.value.requireAdminToAddFriends;
  await handleUpdateGroupSettings(
    {
      requireAdminToAddFriends: nextValue,
    },
    {
      settingKey: "requireAdminToAddFriends",
      successMessage: nextValue
        ? "已开启群内加好友管理员审批。"
        : "已关闭群内加好友管理员审批。",
    },
  );
};

const handleOpenGroupAvatarPicker = () => {
  if (
    !isSelectedGroupChat.value ||
    !canUploadSelectedGroupAvatar.value ||
    isUpdatingGroupAvatar.value
  ) {
    return;
  }
  groupAvatarInputRef.value?.click();
};

const handleGroupAvatarSelected = async (event: Event) => {
  const input = event.target as HTMLInputElement | null;
  const file = input?.files?.[0] ?? null;
  if (input) {
    input.value = "";
  }
  if (!file) {
    return;
  }

  const roomId = selectedChatId.value;
  if (!roomId || !isSelectedGroupChat.value) {
    notice.value = "当前未选中群聊，无法上传群头像。";
    return;
  }
  if (!canUploadSelectedGroupAvatar.value) {
    notice.value = "当前账号没有修改群头像的权限。";
    return;
  }

  const validationMessage = validateAvatarFile(file);
  if (validationMessage) {
    notice.value = validationMessage;
    return;
  }

  isUpdatingGroupAvatar.value = true;
  notice.value = `正在上传群头像 ${file.name}...`;
  try {
    const response = await ChatApi.uploadGroupAvatar({
      roomId,
      file,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "群头像上传失败";
      return;
    }

    patchRoomAvatar(roomId, response.data.avatarUrl);
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
      reloadMessages: false,
    });
    await loadGroupContext(roomId);
    notice.value = `群头像 ${file.name} 已上传。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "群头像上传失败";
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
      reloadMessages: false,
    });
    await loadGroupContext(roomId);
  } finally {
    isUpdatingGroupAvatar.value = false;
  }
};

const handleSubmitMaxMembers = async () => {
  if (!groupSettings.value) {
    return;
  }

  const decision = resolveGroupMaxMembersUpdate(
    groupMaxMembersDraft.value,
    groupSettings.value.maxMembers,
  );
  if (decision.errorMessage) {
    notice.value = decision.errorMessage;
    return;
  }

  await handleUpdateGroupSettings(
    {
      maxMembers: decision.nextValue ?? undefined,
    },
    {
      settingKey: "maxMembers",
      successMessage: `已将群最大人数更新为 ${decision.nextValue}。`,
    },
  );
};

const handleSend = async () => {
  const roomId = selectedChatId.value;
  const content = draftMessage.value.trim();
  const attachments = [...pendingAttachments.value];
  const quotedMessageId = replyingMessage.value?.id;
  const quotedMessage = replyingMessage.value
    ? toQuotedMessage(replyingMessage.value)
    : null;
  let localTextMessageId: string | null = null;
  let localAttachmentMessageId: string | null = null;
  if (groupComposerState.value.disabled) {
    notice.value =
      groupComposerState.value.tip || groupComposerState.value.placeholder;
    return;
  }
  if (!roomId || isSending.value || (!content && !attachments.length)) {
    return;
  }

  await stopTyping(roomId);
  isSending.value = true;
  sendingMode.value = attachments.length ? "attachment" : "text";
  try {
    if (!attachments.length) {
      const localMessage = createLocalTextMessage({
        roomId,
        currentUserId: props.currentUser.id,
        currentUsername: props.currentUser.username,
        currentDisplayName:
          props.currentUser.nickname || props.currentUser.username,
        currentAvatarUrl: props.currentUser.avatar,
        content,
        quotedMessage,
      });
      localTextMessageId = localMessage.id;
      appendLocalMessage(roomId, localMessage);
      draftMessage.value = "";
      replyingMessage.value = null;

      const response = await ChatApi.sendTextMessage({
        roomId,
        content,
        quotedMessageId,
        currentUserId: props.currentUser.id,
      });
      if (!response.success || !response.data) {
        markLocalMessageFailedAndScheduleRetry(
          roomId,
          localMessage.id,
          response.message || "消息发送失败，3 秒后自动重试",
        );
        notice.value = response.message || "消息发送失败，3 秒后自动重试";
        return;
      }

      messages.value = replaceLocalMessage(
        messages.value,
        localMessage.id,
        response.data,
      );
      removeLocalMessage(roomId, localMessage.id);
      await loadChats({
        preferredRoomId: roomId,
        preserveNotice: true,
      });
      notice.value = `消息已发送到 ${selectedChat.value?.title || "当前会话"}。`;
      return;
    }

    attachmentUploadProgress.value = 0;
    const localMessage = createLocalComposerMessage({
      roomId,
      currentUserId: props.currentUser.id,
      currentUsername: props.currentUser.username,
      currentDisplayName:
        props.currentUser.nickname || props.currentUser.username,
      currentAvatarUrl: props.currentUser.avatar,
      content,
      quotedMessage,
      attachments: attachments.map((item) => item.file),
    });
    localAttachmentMessageId = localMessage.id;
    appendLocalMessage(roomId, localMessage);
    draftMessage.value = "";
    replyingMessage.value = null;
    resetPendingAttachments();

    attachmentUploadProgressById.value = Object.fromEntries(
      attachments.map((item) => [item.id, 0]),
    );
    const response = await resendLocalMessage(
      {
        roomId,
        currentUserId: props.currentUser.id,
        retryPayload: localMessage.retryPayload ?? {
          content,
          quotedMessageId,
          attachments: attachments.map((item) => item.file),
        },
      },
      {
        uploadAttachmentsAndBuildParts: ({ roomId: targetRoomId, files }) =>
          uploadAttachmentsAndBuildParts({
            roomId: targetRoomId,
            files,
            onFileProgress: (index, progress) => {
              const attachment = attachments[index];
              if (!attachment) {
                return;
              }
              attachmentUploadProgressById.value = {
                ...attachmentUploadProgressById.value,
                [attachment.id]: progress,
              };
            },
            onOverallProgress: (progress) => {
              attachmentUploadProgress.value = progress;
            },
          }),
      },
    );
    if (!response.success || !response.data) {
      markLocalMessageFailedAndScheduleRetry(
        roomId,
        localMessage.id,
        response.message || "消息发送失败，3 秒后自动重试",
      );
      notice.value = response.message || "消息发送失败，3 秒后自动重试";
      return;
    }

    messages.value = replaceLocalMessage(messages.value, localMessage.id, response.data);
    removeLocalMessage(roomId, localMessage.id);
    const attachmentCount = attachments.length;
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
    });
    if (content) {
      notice.value = `已发送文本和 ${attachmentCount} 个附件到 ${selectedChat.value?.title || "当前会话"}。`;
    } else if (attachmentCount === 1) {
      notice.value = `附件 ${attachments[0].file.name} 已发送到 ${selectedChat.value?.title || "当前会话"}。`;
    } else {
      notice.value = `已发送 ${attachmentCount} 个附件到 ${selectedChat.value?.title || "当前会话"}。`;
    }
  } catch (error) {
    if (!attachments.length && localTextMessageId) {
      const localMessage = getLocalMessagesForRoom(roomId).find(
        (message) => message.id === localTextMessageId,
      );
      if (localMessage?.clientStatus === "sending") {
        markLocalMessageFailedAndScheduleRetry(
          roomId,
          localTextMessageId,
          error instanceof Error
            ? error.message
            : "消息发送失败，3 秒后自动重试",
        );
      }
    }
    if (attachments.length && localAttachmentMessageId) {
      const localMessage = getLocalMessagesForRoom(roomId).find(
        (message) => message.id === localAttachmentMessageId,
      );
      if (localMessage?.clientStatus === "sending") {
        markLocalMessageFailedAndScheduleRetry(
          roomId,
          localAttachmentMessageId,
          error instanceof Error
            ? error.message
            : "消息发送失败，3 秒后自动重试",
        );
      }
    }
    notice.value =
      error instanceof Error ? error.message : "消息发送失败，3 秒后自动重试";
  } finally {
    isSending.value = false;
    sendingMode.value = null;
  }
};

const handleResendMessage = async (message: ChatMessage) => {
  if (!canResendLocalMessage(message) || resendingMessageId.value) {
    return;
  }

  const retryPayload = message.retryPayload;
  if (
    !retryPayload ||
    (!retryPayload.content.trim() && !retryPayload.attachments?.length)
  ) {
    return;
  }

  closeMessageActionMenu();
  clearLocalMessageRetry(message.id);
  resendingMessageId.value = message.id;
  await executeLocalMessageRetry(message.roomId, message.id, {
    manual: true,
  });
};

const closeMessageActionMenu = () => {
  activeMessageActionMenuId.value = null;
};

const handleGlobalKeydown = (event: KeyboardEvent) => {
  if (event.key !== "Escape") {
    return;
  }

  if (isMultiSelectMode.value) {
    exitMultiSelectMode();
  }
};

const handleToggleMessageActionMenu = (message: ChatMessage) => {
  if (!canOpenMessageActionMenu(message)) {
    return;
  }

  activeReactionPickerMessageId.value = null;
  activeMessageActionMenuId.value =
    activeMessageActionMenuId.value === message.id ? null : message.id;
};

const closeEditMessageDialog = () => {
  if (submittingEditMessageId.value) {
    return;
  }
  editingMessageTarget.value = null;
  editingMessageDraft.value = "";
};

const handleCopyMessage = async (message: ChatMessage) => {
  const text = getMessageCopyText(message);
  if (!text) {
    return;
  }

  closeMessageActionMenu();
  if (!window.navigator?.clipboard) {
    notice.value = "当前环境暂不支持复制。";
    return;
  }

  try {
    await window.navigator.clipboard.writeText(text);
    notice.value = "消息内容已复制。";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "复制消息失败";
  }
};

const handleStartEditMessage = (message: ChatMessage) => {
  if (!canEditMessage(message)) {
    return;
  }

  closeMessageActionMenu();
  editingMessageTarget.value = message;
  editingMessageDraft.value = getMessageCopyText(message);
};

const handleSubmitEditMessage = async () => {
  const message = editingMessageTarget.value;
  if (!message || !canEditMessage(message) || submittingEditMessageId.value) {
    return;
  }

  const content = editingMessageDraft.value.trim();
  if (!content) {
    notice.value = "消息内容不能为空。";
    return;
  }
  if (content.length > 10000) {
    notice.value = "消息内容不能超过 10000 字。";
    return;
  }

  submittingEditMessageId.value = message.id;
  try {
    const response = await ChatApi.editMessage({
      roomId: message.roomId,
      messageId: message.id,
      content,
      currentUserId: props.currentUser.id,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "编辑消息失败";
      return;
    }

    const targetIndex = messages.value.findIndex((item) => item.id === message.id);
    if (targetIndex !== -1) {
      messages.value.splice(targetIndex, 1, {
        ...messages.value[targetIndex],
        ...response.data,
      });
    }
    await loadChats({
      preferredRoomId: selectedChatId.value,
      preserveNotice: true,
      reloadMessages: false,
    });
    notice.value = "消息已编辑。";
    editingMessageTarget.value = null;
    editingMessageDraft.value = "";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "编辑消息失败";
  } finally {
    submittingEditMessageId.value = null;
  }
};

const handlePickAttachment = () => {
  if (isSending.value || !selectedChatId.value) {
    return;
  }
  if (groupComposerState.value.disabled) {
    notice.value =
      groupComposerState.value.tip || groupComposerState.value.placeholder;
    return;
  }
  attachmentInputRef.value?.click();
};

const handleAttachmentSelected = (event: Event) => {
  const input = event.target as HTMLInputElement | null;
  if (groupComposerState.value.disabled) {
    if (input) {
      input.value = "";
    }
    notice.value =
      groupComposerState.value.tip || groupComposerState.value.placeholder;
    return;
  }
  const files = Array.from(input?.files ?? []);
  if (!files.length) {
    return;
  }

  const nextAttachments = files.map((file, index) => ({
    id: `${Date.now()}-${index}-${file.name}-${file.size}`,
    file,
  }));
  pendingAttachments.value = [...pendingAttachments.value, ...nextAttachments];
  attachmentUploadProgress.value = null;
  attachmentUploadProgressById.value = {};
  notice.value =
    files.length === 1
      ? `已添加附件 ${files[0].name}，可直接发送，也可继续输入文本混发。`
      : `已添加 ${files.length} 个附件，可直接发送，也可继续输入文本混发。`;

  if (input) {
    input.value = "";
  }
};

const handleComposerKeydown = (event: KeyboardEvent) => {
  if (event.key !== "Enter" || event.shiftKey) {
    return;
  }
  event.preventDefault();
  void handleSend();
};

const handleReplyToMessage = (message: ChatMessage) => {
  if (
    message.messageType === "system" ||
    message.isDeleted ||
    isLocalOnlyMessage(message)
  ) {
    return;
  }
  closeMessageActionMenu();
  replyingMessage.value = message;
  notice.value = `正在回复 ${message.isSelf ? "我" : message.senderName} 的消息。`;
};

const clearReplyingMessage = () => {
  replyingMessage.value = null;
};

const resetMessageReadersState = () => {
  messageReadersLoadSequence += 1;
  isMessageReadersModalVisible.value = false;
  loadingMessageReadersMessageId.value = null;
  messageReaders.value = [];
  messageReadersTarget.value = null;
};

const handleMessageReadersModalVisibleChange = (visible: boolean) => {
  if (visible) {
    isMessageReadersModalVisible.value = true;
    return;
  }
  resetMessageReadersState();
};

const handleOpenMessageReadersModal = async (message: ChatMessage) => {
  if (!canViewMessageReaders(message) || loadingMessageReadersMessageId.value) {
    return;
  }

  const roomId = selectedChatId.value;
  if (!roomId || roomId !== message.roomId) {
    notice.value = "当前消息不在已选会话中，无法加载已读成员。";
    return;
  }

  const currentSequence = messageReadersLoadSequence + 1;
  messageReadersLoadSequence = currentSequence;
  closeMessageActionMenu();
  isMessageReadersModalVisible.value = true;
  loadingMessageReadersMessageId.value = message.id;
  messageReadersTarget.value = message;
  messageReaders.value = [];

  try {
    const response = await ChatApi.getMessageReaders({
      roomId,
      messageId: message.id,
    });
    if (
      currentSequence !== messageReadersLoadSequence ||
      selectedChatId.value !== roomId ||
      messageReadersTarget.value?.id !== message.id
    ) {
      return;
    }

    if (!response.success || !response.data) {
      messageReaders.value = [];
      notice.value = response.message || "加载消息已读成员失败";
      return;
    }

    messageReaders.value = response.data;
  } catch (error) {
    if (
      currentSequence !== messageReadersLoadSequence ||
      messageReadersTarget.value?.id !== message.id
    ) {
      return;
    }

    messageReaders.value = [];
    notice.value = error instanceof Error ? error.message : "加载消息已读成员失败";
  } finally {
    if (currentSequence === messageReadersLoadSequence) {
      loadingMessageReadersMessageId.value = null;
    }
  }
};

const handleForwardMessageModalVisibleChange = (visible: boolean) => {
  if (!visible) {
    forwardingMessage.value = null;
    isForwardingSelectedMessages.value = false;
  }
  isForwardMessageModalVisible.value = visible;
};

const handleOpenForwardMessageModal = (message: ChatMessage) => {
  if (!canForwardMessage(message)) {
    notice.value = "当前消息暂不支持转发。";
    return;
  }
  if (!forwardableChats.value.length) {
    notice.value = "暂无可转发目标，请先创建或进入其他会话。";
    return;
  }

  closeMessageActionMenu();
  isForwardingSelectedMessages.value = false;
  forwardingMessage.value = message;
  isForwardMessageModalVisible.value = true;
};

const handleOpenBatchForwardMessageModal = () => {
  if (!selectedBatchMessages.value.length) {
    notice.value = "请先选择要转发的消息。";
    return;
  }
  if (!canForwardSelectedBatchMessages.value) {
    notice.value = "当前选择中包含暂不支持转发的消息。";
    return;
  }
  if (!forwardableChats.value.length) {
    notice.value = "暂无可转发目标，请先创建或进入其他会话。";
    return;
  }

  isForwardingSelectedMessages.value = true;
  forwardingMessage.value = null;
  isForwardMessageModalVisible.value = true;
};

const scrollToQuotedMessage = (quoted: ChatQuotedMessage | null) => {
  if (!quoted?.id) {
    return;
  }
  const target = document.querySelector<HTMLElement>(
    `[data-message-id="${quoted.id}"]`,
  );
  if (!target) {
    return;
  }

  target.scrollIntoView({
    behavior: "smooth",
    block: "center",
  });
  highlightedQuotedMessageId.value = quoted.id;
  window.setTimeout(() => {
    if (highlightedQuotedMessageId.value === quoted.id) {
      highlightedQuotedMessageId.value = null;
    }
  }, 2400);
};

const handleForwardMessage = async (payload: {
  targetRoomId: string;
  targetTitle: string;
}) => {
  const sourceMessages = forwardingSourceMessages.value;
  const currentRoomId = selectedChatId.value;
  if (!sourceMessages.length || !currentRoomId || isForwardingMessage.value) {
    return;
  }
  if (
    isForwardingSelectedMessages.value &&
    !canForwardSelectedBatchMessages.value
  ) {
    notice.value = "当前选择中包含暂不支持转发的消息。";
    return;
  }

  isForwardingMessage.value = true;
  try {
    for (const sourceMessage of sourceMessages) {
      const response = await ChatApi.forwardMessage({
        roomId: payload.targetRoomId,
        originalMessageId: sourceMessage.id,
        currentUserId: props.currentUser.id,
      });
      if (!response.success || !response.data) {
        notice.value = response.message || "转发消息失败";
        return;
      }
    }

    await loadChats({
      preferredRoomId: currentRoomId,
      preserveNotice: true,
      reloadMessages: payload.targetRoomId === currentRoomId,
    });
    isForwardMessageModalVisible.value = false;
    forwardingMessage.value = null;
    isForwardingSelectedMessages.value = false;
    if (isMultiSelectMode.value) {
      exitMultiSelectMode();
    }
    notice.value =
      sourceMessages.length > 1
        ? `已将 ${sourceMessages.length} 条消息转发到 ${payload.targetTitle}。`
        : `已转发到 ${payload.targetTitle}。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "转发消息失败";
  } finally {
    isForwardingMessage.value = false;
  }
};

const handleTogglePinMessage = async (message: ChatMessage) => {
  const roomId = selectedChatId.value;
  if (
    !roomId ||
    message.isDeleted ||
    message.messageType === "system" ||
    isLocalOnlyMessage(message) ||
    pinningMessageId.value
  ) {
    return;
  }

  closeMessageActionMenu();
  pinningMessageId.value = message.id;
  const nextPinned = !isMessagePinned(message);
  try {
    const response = nextPinned
      ? await ChatApi.pinMessage({
          roomId,
          messageId: message.id,
          currentUserId: props.currentUser.id,
        })
      : await ChatApi.unpinMessage({
          roomId,
          messageId: message.id,
          currentUserId: props.currentUser.id,
        });
    if (!response.success || !response.data) {
      notice.value = response.message || (nextPinned ? "置顶消息失败" : "取消置顶失败");
      return;
    }

    patchMessagePinState({
      messageId: message.id,
      pinnedAt: response.data.isPinned ? response.data.pinnedAt : null,
      pinnedBy: response.data.isPinned ? response.data.pinnedBy : null,
      message: response.data.message,
    });
    notice.value = nextPinned ? "消息已置顶。" : "消息已取消置顶。";
  } catch (error) {
    notice.value =
      error instanceof Error
        ? error.message
        : nextPinned
          ? "置顶消息失败"
          : "取消置顶失败";
  } finally {
    pinningMessageId.value = null;
  }
};

const handleToggleReactionPicker = (message: ChatMessage) => {
  if (
    message.isDeleted ||
    message.messageType === "system" ||
    isLocalOnlyMessage(message)
  ) {
    return;
  }
  closeMessageActionMenu();
  activeReactionPickerMessageId.value =
    activeReactionPickerMessageId.value === message.id ? null : message.id;
};

const toggleMessageReaction = async (
  message: ChatMessage,
  reactionKey: string,
  options: {
    closePicker?: boolean;
  } = {},
) => {
  const roomId = selectedChatId.value;
  if (!roomId || reactingMessageId.value) {
    return;
  }

  reactingMessageId.value = message.id;
  reactingReactionKey.value = reactionKey;
  try {
    const existingReaction = message.reactions?.find(
      (reaction) => reaction.reactionKey === reactionKey,
    );
    const hasSelf = existingReaction?.hasSelf === true;

    const response = hasSelf
      ? await ChatApi.removeReaction({
          roomId,
          messageId: message.id,
          reactionKey,
        })
      : await ChatApi.addReaction({
          roomId,
          messageId: message.id,
          reactionKey,
        });
    if (!response.success || !response.data) {
      notice.value = response.message || "更新消息反应失败";
      return;
    }

    patchMessageReactions(message.id, response.data.summaries);
    if (options.closePicker !== false) {
      activeReactionPickerMessageId.value = null;
    }
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "更新消息反应失败";
  } finally {
    reactingMessageId.value = null;
    reactingReactionKey.value = null;
  }
};

const handleReactionOptionClick = async (
  message: ChatMessage,
  reactionKey: string,
) => {
  await toggleMessageReaction(message, reactionKey, {
    closePicker: true,
  });
};

const handleReactionTagClick = async (
  message: ChatMessage,
  reactionKey: string,
) => {
  await toggleMessageReaction(message, reactionKey, {
    closePicker: false,
  });
};

const deleteMessageInCurrentRoom = async (roomId: string, message: ChatMessage) => {
  if (!canDeleteMessage(message)) {
    throw new Error("当前消息不支持删除。");
  }

  if (isLocalOnlyMessage(message)) {
    clearLocalMessageRetry(message.id);
    removeLocalMessage(roomId, message.id);
    return;
  }

  const response = await ChatApi.deleteMessage({
    roomId,
    messageId: message.id,
  });
  if (!response.success) {
    throw new Error(response.message || "撤回消息失败");
  }
};

const handleDeleteMessage = async (message: ChatMessage) => {
  const roomId = selectedChatId.value;
  if (!roomId || !message.isSelf || deletingMessageId.value) {
    return;
  }

  if (isLocalOnlyMessage(message)) {
    await deleteMessageInCurrentRoom(roomId, message);
    notice.value = "本地失败消息已移除。";
    return;
  }

  deletingMessageId.value = message.id;
  try {
    closeMessageActionMenu();
    await deleteMessageInCurrentRoom(roomId, message);
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
    });
    notice.value = "消息已撤回。";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "撤回消息失败";
  } finally {
    deletingMessageId.value = null;
  }
};

const handleDeleteSelectedMessages = async () => {
  const roomId = selectedChatId.value;
  if (
    !roomId ||
    isDeletingSelectedMessages.value ||
    !selectedBatchMessages.value.length
  ) {
    return;
  }
  if (!canDeleteSelectedBatchMessages.value) {
    notice.value = "当前选择中包含不可删除的消息。";
    return;
  }

  isDeletingSelectedMessages.value = true;
  try {
    const selectedMessages = [...selectedBatchMessages.value];
    for (const message of selectedMessages) {
      await deleteMessageInCurrentRoom(roomId, message);
    }

    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
    });
    exitMultiSelectMode();
    notice.value = `已处理 ${selectedMessages.length} 条消息。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "批量删除消息失败";
  } finally {
    isDeletingSelectedMessages.value = false;
  }
};

const handleOpenAttachment = async (
  message: ChatMessage,
  part: ChatMessagePart,
) => {
  try {
    let localPath = getAttachmentLocalPath(message, part);
    if (!localPath) {
      await ensureAttachmentPlayableUrl(message, part);
      localPath = getAttachmentLocalPath(message, part);
    }
    if (!localPath) {
      await handleDownloadAttachment(message, part);
      return;
    }

    await requireDesktopRuntime().file.openPath(localPath);
    notice.value = `${getAttachmentName(part)} 已打开。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "打开附件失败";
  }
};

const handleOpenAttachmentPreview = async (
  message: ChatMessage,
  part: ChatMessagePart,
) => {
  if (part.partType !== "image" && part.partType !== "video") {
    return;
  }

  const mediaUrl =
    getAttachmentPlayableUrl(message, part) ??
    (part.partType === "video"
      ? await ensureAttachmentPlayableUrl(message, part)
      : (getAttachmentPreviewUrl(message, part) ??
        (await ensureAttachmentPlayableUrl(message, part))));
  if (!mediaUrl) {
    notice.value =
      getAttachmentPreviewFailure(message, part) || "附件预览加载失败";
    return;
  }

  mediaPreview.value = {
    type: part.partType,
    url: mediaUrl,
    name: getAttachmentName(part),
    meta: getAttachmentMeta(part),
  };
};

const closeMediaPreview = () => {
  mediaPreview.value = null;
};

const handleDownloadAttachment = async (
  message: ChatMessage,
  part: ChatMessagePart,
) => {
  const attachment = part.attachment;
  if (!attachment?.key) {
    notice.value = "附件信息不完整，无法下载。";
    return;
  }

  const actionKey = getAttachmentActionKey(message, part);
  if (isAttachmentDownloading(message, part)) {
    return;
  }

  setAttachmentDownloading(actionKey, true);
  try {
    const response = await ChatApi.getAttachmentDownloadUrl({
      roomId: message.roomId,
      key: attachment.key,
      expiresInSeconds: 900,
    });
    if (!response.success || !response.data?.downloadUrl) {
      notice.value = response.message || "获取附件下载链接失败";
      return;
    }

    const runtime = requireDesktopRuntime();
    const fileName = getAttachmentName(part);
    const saveResult = await runtime.dialog.save({
      title: `保存${formatAttachmentType(part.partType)}`,
      defaultPath: fileName,
      buttonLabel: "保存",
    });
    if (saveResult.canceled || !saveResult.filePath) {
      notice.value = `已取消保存 ${fileName}。`;
      return;
    }

    const saved = await runtime.file.saveFromURL({
      url: response.data.downloadUrl,
      filePath: saveResult.filePath,
    });

    downloadedAttachmentPaths.value = {
      ...downloadedAttachmentPaths.value,
      [actionKey]: saved.filePath,
    };

    await runtime.file.openPath(saved.filePath);
    notice.value = `${fileName} 已保存并打开。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "下载附件失败";
  } finally {
    setAttachmentDownloading(actionKey, false);
  }
};

const handleRealtimeEvent = async (event: ChatRealtimeEvent) => {
  const activeRoomId = selectedChatId.value;

  if (event.type === "message") {
    const isCurrentRoom = event.message.roomId === activeRoomId;
    if (isCurrentRoom && !event.message.isSelf) {
      removeTypingUser(event.message.senderId);
    }
    await loadChats({
      preferredRoomId: activeRoomId,
      preserveNotice: true,
      reloadMessages: isCurrentRoom,
    });
    return;
  }

  if (event.type === "room_created" || event.type === "room_updated") {
    await loadChats({
      preferredRoomId: activeRoomId,
      preserveNotice: true,
      reloadMessages: event.roomId === activeRoomId,
    });
    if (event.roomId === selectedChatId.value) {
      await loadGroupContext(event.roomId);
    }
    return;
  }

  const groupRealtimePlan = getGroupRealtimePlan({
    event,
    activeRoomId,
    currentUserId: props.currentUser.id,
  });
  if (groupRealtimePlan) {
    if (groupRealtimePlan.shouldReloadChats) {
      await loadChats({
        preferredRoomId: activeRoomId,
        preserveNotice: true,
        reloadMessages: false,
      });
    }
    if (event.roomId === selectedChatId.value) {
      if (groupRealtimePlan.shouldReloadGroupContext) {
        await loadGroupContext(event.roomId);
        if (isManageGroupAdminsModalVisible.value) {
          await loadGroupAdmins(event.roomId);
        }
        if (isManageGroupJoinRequestsModalVisible.value) {
          await loadGroupJoinRequests(event.roomId);
        }
        if (isManageGroupMutesModalVisible.value) {
          await loadGroupMutes(event.roomId);
        }
      }
      if (groupRealtimePlan.shouldReloadGroupSettings) {
        await loadGroupSettings(event.roomId);
      }
    }
    if (groupRealtimePlan.notice) {
      notice.value = groupRealtimePlan.notice;
    }
    return;
  }

  if (event.type === "message_read") {
    if (
      event.readerId === props.currentUser.id &&
      event.roomId &&
      event.messageId
    ) {
      lastReadUntilMessageByRoom.value = {
        ...lastReadUntilMessageByRoom.value,
        [event.roomId]: event.messageId,
      };
    }

    await loadChats({
      preferredRoomId: activeRoomId,
      preserveNotice: true,
      reloadMessages: event.roomId === activeRoomId,
    });
    return;
  }

  if (event.type === "message_update") {
    if (
      !event.isDeleted &&
      event.roomId === activeRoomId &&
      event.editedAt &&
      event.content !== null
    ) {
      patchMessageEditedState({
        messageId: event.messageId,
        content: event.content,
        editedAt: event.editedAt,
      });
    }
    await loadChats({
      preferredRoomId: activeRoomId,
      preserveNotice: true,
      reloadMessages: event.isDeleted && event.roomId === activeRoomId,
    });
    return;
  }

  if (event.type === "pin_update") {
    if (event.roomId === activeRoomId && event.messageId) {
      patchMessagePinState({
        messageId: event.messageId,
        pinnedAt: event.isPinned ? event.pinnedAt : null,
        pinnedBy: event.isPinned ? event.pinnedBy : null,
      });
    }
    return;
  }

  if (event.type === "reaction_update") {
    if (event.roomId === activeRoomId) {
      try {
        const response = await ChatApi.getReactions({
          roomId: event.roomId,
          messageId: event.messageId,
        });
        if (response.success && response.data) {
          patchMessageReactions(event.messageId, response.data.summaries);
        }
      } catch {
        // reaction 局部刷新失败不影响主消息流
      }
    }
    return;
  }

  if (event.type === "typing_update") {
    handleTypingUpdate(event);
  }
};

watch(
  () => localMessagesByRoom.value,
  () => {
    persistRetryableLocalMessages();
  },
  { deep: true },
);

watch(
  () => messages.value.map((message) => message.id),
  () => {
    syncSelectedMessages();
  },
);

watch(
  () => props.openChatRequest?.requestId,
  (requestId, previousRequestId) => {
    if (
      !requestId ||
      requestId === previousRequestId ||
      !props.openChatRequest
    ) {
      return;
    }
    void handleOpenChatRequest(props.openChatRequest);
  },
);

watch(
  () => props.lastWsPush,
  (push, previousPush) => {
    if (!push || push === previousPush) {
      return;
    }

    const event = mapChatRealtimeEvent(push, props.currentUser.id);
    if (!event) {
      return;
    }

    void handleRealtimeEvent(event);
  },
);

watch(
  () => draftMessage.value,
  (value) => {
    scheduleTypingFromInput(value);
  },
);

watch(
  () => selectedChatId.value,
  (nextRoomId, previousRoomId) => {
    if (nextRoomId !== previousRoomId) {
      if (previousRoomId) {
        void stopTyping(previousRoomId);
      }
      clearTypingUsers();
      exitMultiSelectMode();
      replyingMessage.value = null;
      forwardingMessage.value = null;
      isForwardingSelectedMessages.value = false;
      isForwardMessageModalVisible.value = false;
      activeReactionPickerMessageId.value = null;
      resetMessageReadersState();
    }
  },
);

watch(
  () => groupComposerState.value.disabled,
  (disabled) => {
    if (disabled) {
      void stopTyping();
    }
  },
);

watch(
  () => [selectedChatId.value, props.wsStatus] as const,
  (currentValue, previousValue) => {
    const [nextRoomId, nextWsStatus] = currentValue;
    const [previousRoomId, previousWsStatus] = previousValue ?? [null, null];
    if (
      nextRoomId === previousRoomId &&
      nextWsStatus === previousWsStatus
    ) {
      return;
    }

    if (
      nextWsStatus !== "authenticated" &&
      previousWsStatus === "authenticated"
    ) {
      subscribedRoomId.value = null;
      void stopTyping(typingRoomId.value ?? nextRoomId ?? previousRoomId);
      clearTypingUsers();
      return;
    }

    void syncRoomSubscription(nextRoomId, previousRoomId);
  },
  { immediate: true },
);

onMounted(() => {
  window.addEventListener("keydown", handleGlobalKeydown);
  restoreRetryableLocalMessagesFromStorage();
  Object.entries(localMessagesByRoom.value).forEach(([roomId, roomMessages]) => {
    roomMessages.forEach((message) => {
      if (!message.retryPayload?.attachments?.length) {
        scheduleLocalMessageRetry(roomId, message.id);
      }
    });
  });
  if (props.openChatRequest) {
    void handleOpenChatRequest(props.openChatRequest);
    return;
  }
  void loadChats();
});

onBeforeUnmount(() => {
  window.removeEventListener("keydown", handleGlobalKeydown);
  persistRetryableLocalMessages();
  clearAllLocalMessageRetryTimers();
  const roomId = subscribedRoomId.value;
  void stopTyping(roomId ?? typingRoomId.value);
  clearTypingUsers();
  subscribedRoomId.value = null;
  roomSubscriptionSequence += 1;
  if (roomId && props.wsStatus === "authenticated") {
    void WebSocketApi.leaveRoom(roomId).catch((error) => {
      console.warn("[desktop-el-renderer] ws.leave during cleanup failed", error);
    });
  }
});
</script>

<template>
  <section class="chat-panel">
    <div class="chat-panel__notice">
      <span>{{ notice }}</span>
      <small>{{ chats.length }} 个会话 / {{ pinnedCount }} 个置顶</small>
    </div>

    <div class="chat-panel__layout">
      <aside class="chat-panel__sidebar">
        <div class="chat-panel__header">
          <div class="chat-panel__header-top">
            <div>
              <h2>会话</h2>
              <p>先恢复旧 desktop 的会话列表与联系人发起聊天链路。</p>
            </div>
            <button
              type="button"
              class="chat-panel__header-action"
              :disabled="isCreatingGroup"
              @click="void handleOpenCreateGroupModal()"
            >
              {{ isCreatingGroup ? "创建中..." : "创建群聊" }}
            </button>
          </div>
          <input
            v-model="searchQuery"
            class="chat-panel__search"
            placeholder="搜索会话..."
          />
        </div>

        <div v-if="isLoadingChats" class="chat-empty">
          <strong>加载中</strong>
          <p>正在通过 Go core 同步 `/chats`。</p>
        </div>

        <div v-else-if="!filteredChats.length" class="chat-empty">
          <strong>暂无会话</strong>
          <p>当前账号还没有会话，先去联系人页发起一条新的私聊。</p>
        </div>

        <div v-else class="chat-list">
          <button
            v-for="chat in filteredChats"
            :key="chat.id"
            type="button"
            class="chat-row"
            :class="{ 'chat-row--active': selectedChat?.id === chat.id }"
            @click="void selectChat(chat.id)"
          >
            <span class="chat-row__avatar">
              <img
                v-if="chat.avatarUrl"
                :src="chat.avatarUrl"
                :alt="chat.title"
                class="chat-row__avatar-image"
              />
              <template v-else>{{
                getAvatarFallbackText(chat.title)
              }}</template>
            </span>
            <span class="chat-row__copy">
              <span class="chat-row__topline">
                <strong>{{ chat.title }}</strong>
                <small>{{ formatTime(chat.lastMessageAt) }}</small>
              </span>
              <span class="chat-row__bottomline">
                <small>{{ chat.lastMessagePreview || "暂无消息" }}</small>
                <span v-if="chat.unreadCount > 0" class="chat-row__badge">{{
                  chat.unreadCount
                }}</span>
              </span>
            </span>
          </button>
        </div>
      </aside>

      <article class="chat-panel__detail">
        <template v-if="selectedChat">
          <div class="chat-hero">
            <span class="chat-hero__avatar">
              <img
                v-if="selectedChatAvatarUrl"
                :src="selectedChatAvatarUrl"
                :alt="selectedChat.title"
                class="chat-hero__avatar-image"
              />
              <template v-else>{{
                getAvatarFallbackText(selectedChat.title)
              }}</template>
            </span>
            <div>
              <h3>{{ selectedChat.title }}</h3>
              <p>
                {{
                  selectedChat.subtitle ||
                  selectedChat.lastMessagePreview ||
                  "会话详情迁移中"
                }}
              </p>
            </div>
          </div>

          <dl class="chat-detail-list">
            <div>
              <dt>会话类型</dt>
              <dd>{{ formatRoomType(selectedChat.roomType) }}</dd>
            </div>
            <div>
              <dt>未读消息</dt>
              <dd>{{ selectedChat.unreadCount }}</dd>
            </div>
            <div>
              <dt>最后活动</dt>
              <dd>{{ formatDetailTime(selectedChat.lastMessageAt) }}</dd>
            </div>
            <div>
              <dt>置顶 / 免打扰</dt>
              <dd>
                {{ selectedChat.isPinned ? "已置顶" : "未置顶" }} /
                {{ selectedChat.isMuted ? "已静音" : "正常提醒" }}
              </dd>
            </div>
            <div>
              <dt>当前账号</dt>
              <dd>
                {{ props.currentUser.nickname || props.currentUser.username }}
              </dd>
            </div>
          </dl>

          <section v-if="isSelectedGroupChat" class="group-panel">
            <div class="group-panel__header">
              <div class="group-panel__header-copy">
                <h4>群详情</h4>
                <small v-if="isLoadingGroupContext">同步中...</small>
                <small v-else>{{
                  groupMembers.length
                    ? `${groupMembers.length} 名成员`
                    : "成员列表待同步"
                }}</small>
              </div>
              <div class="group-panel__header-actions">
                <button
                  type="button"
                  class="group-panel__action"
                  :disabled="isLoadingGroupRules || isUpdatingGroupRules"
                  @click="void handleOpenManageGroupRulesModal()"
                >
                  {{
                    isLoadingGroupRules || isUpdatingGroupRules
                      ? "同步中..."
                      : activeGroupRuleCount > 0
                        ? `群规(${activeGroupRuleCount})`
                        : "群规"
                  }}
                </button>
                <button
                  v-if="canManageSelectedGroupAdmins"
                  type="button"
                  class="group-panel__action"
                  :disabled="isUpdatingGroupAdmins"
                  @click="void handleOpenManageGroupAdminsModal()"
                >
                  {{ isUpdatingGroupAdmins ? "处理中..." : "管理员" }}
                </button>
                <button
                  type="button"
                  class="group-panel__action"
                  :disabled="
                    isLoadingGroupOperationLogs || isLoadingMoreGroupOperationLogs
                  "
                  @click="void handleOpenManageGroupOperationLogsModal()"
                >
                  {{
                    isLoadingGroupOperationLogs || isLoadingMoreGroupOperationLogs
                      ? "同步中..."
                      : "操作日志"
                  }}
                </button>
                <button
                  v-if="canTransferSelectedGroupOwner"
                  type="button"
                  class="group-panel__action"
                  :disabled="
                    isTransferringGroupOwner ||
                    !transferableGroupOwnerMembers.length
                  "
                  @click="void handleOpenTransferGroupOwnerModal()"
                >
                  {{
                    isTransferringGroupOwner ? "转让中..." : "转让群主"
                  }}
                </button>
                <button
                  v-if="canManageSelectedGroupJoinRequests"
                  type="button"
                  class="group-panel__action"
                  :disabled="isReviewingGroupJoinRequests"
                  @click="void handleOpenManageGroupJoinRequestsModal()"
                >
                  {{
                    isReviewingGroupJoinRequests
                      ? "审核中..."
                      : pendingGroupJoinRequestCount > 0
                        ? `入群审核(${pendingGroupJoinRequestCount})`
                        : "入群审核"
                  }}
                </button>
                <button
                  v-if="canManageSelectedGroupMutes"
                  type="button"
                  class="group-panel__action"
                  :disabled="isUpdatingGroupMutes"
                  @click="void handleOpenManageGroupMutesModal()"
                >
                  {{
                    isUpdatingGroupMutes
                      ? "处理中..."
                      : activeGroupMuteCount > 0
                        ? `禁言管理(${activeGroupMuteCount})`
                        : "禁言管理"
                  }}
                </button>
                <button
                  v-if="canManageSelectedGroupMembers"
                  type="button"
                  class="group-panel__action"
                  :disabled="isAddingGroupMembers"
                  @click="void handleOpenAddGroupMembersModal()"
                >
                  {{ isAddingGroupMembers ? "添加中..." : "添加成员" }}
                </button>
                <button
                  v-if="canManageSelectedGroupMembers"
                  type="button"
                  class="group-panel__action"
                  :disabled="
                    isRemovingGroupMembers ||
                    removableGroupMembers.length === 0
                  "
                  @click="handleOpenRemoveGroupMembersModal"
                >
                  {{
                    isRemovingGroupMembers
                      ? "移除中..."
                      : "删除成员"
                  }}
                </button>
                <button
                  v-if="canUploadSelectedGroupAvatar"
                  type="button"
                  class="group-panel__action"
                  :disabled="isUpdatingGroupAvatar"
                  @click="handleOpenGroupAvatarPicker"
                >
                  {{ isUpdatingGroupAvatar ? "上传中..." : "上传群头像" }}
                </button>
              </div>
            </div>
            <input
              ref="groupAvatarInputRef"
              class="group-panel__file-input"
              type="file"
              :accept="AVATAR_INPUT_ACCEPT"
              @change="handleGroupAvatarSelected"
            />

            <div
              v-if="
                isLoadingGroupContext &&
                !groupDetail &&
                !sortedGroupMembers.length
              "
              class="group-panel__empty"
            >
              <strong>加载中</strong>
              <p>正在同步群资料与成员列表。</p>
            </div>

            <template v-else>
              <dl class="group-panel__detail-list">
                <div>
                  <dt>群名</dt>
                  <dd>{{ groupDetail?.roomName || selectedChat.title }}</dd>
                </div>
                <div>
                  <dt>群简介</dt>
                  <dd>
                    {{
                      groupDetail?.description ||
                      selectedChat.description ||
                      "暂无群简介"
                    }}
                  </dd>
                </div>
                <div>
                  <dt>群主</dt>
                  <dd>
                    {{
                      groupOwnerMember
                        ? getRoomMemberDisplayName(groupOwnerMember)
                        : (groupDetail?.ownerId ?? "未同步")
                    }}
                  </dd>
                </div>
                <div>
                  <dt>成员数</dt>
                  <dd>{{ groupMembers.length || "未同步" }}</dd>
                </div>
                <div>
                  <dt>创建时间</dt>
                  <dd>
                    {{ formatDetailTime(groupDetail?.createdAt ?? null) }}
                  </dd>
                </div>
              </dl>

              <div class="group-panel__section">
                <div class="group-panel__section-header">
                  <h5>群设置</h5>
                  <div class="group-panel__section-actions">
                    <small>{{
                      isLoadingGroupSettings
                        ? "同步中..."
                        : canUpdateSelectedGroupSettings
                          ? "可管理"
                          : "只读视图"
                    }}</small>
                    <button
                      v-if="canUpdateSelectedGroupSettings"
                      type="button"
                      class="group-panel__action"
                      :disabled="
                        isLoadingGroupSettings ||
                        isUpdatingGlobalMute ||
                        !groupSettings
                      "
                      @click="void handleToggleGroupGlobalMute()"
                    >
                      {{
                        isUpdatingGlobalMute
                          ? "提交中..."
                          : groupSettings?.globalMuteEnabled
                            ? "解除全员禁言"
                            : "开启全员禁言"
                      }}
                    </button>
                  </div>
                </div>

                <dl class="group-panel__detail-list">
                  <div>
                    <dt>全员禁言</dt>
                    <dd>
                      {{
                        groupSettings
                          ? formatBooleanLabel(groupSettings.globalMuteEnabled)
                          : "未同步"
                      }}
                    </dd>
                  </div>
                  <div>
                    <dt>禁言原因</dt>
                    <dd>{{ groupSettings?.globalMuteReason || "暂无" }}</dd>
                  </div>
                  <div>
                    <dt>禁言截止</dt>
                    <dd>
                      {{
                        groupSettings
                          ? formatDetailTime(groupSettings.globalMuteUntil)
                          : "未同步"
                      }}
                    </dd>
                  </div>
                  <div>
                    <dt>入群审批</dt>
                    <dd>
                      {{
                        groupSettings
                          ? formatBooleanLabel(
                              groupSettings.joinApprovalRequired,
                            )
                          : "未同步"
                      }}
                    </dd>
                  </div>
                  <div>
                    <dt>成员邀请</dt>
                    <dd>
                      {{
                        groupSettings
                          ? formatBooleanLabel(groupSettings.memberCanInvite)
                          : "未同步"
                      }}
                    </dd>
                  </div>
                  <div>
                    <dt>群内加好友</dt>
                    <dd>
                      {{
                        groupSettings
                          ? formatBooleanLabel(
                              groupSettings.memberCanAddFriends,
                            )
                          : "未同步"
                      }}
                    </dd>
                  </div>
                  <div>
                    <dt>加好友管理员审批</dt>
                    <dd>
                      {{
                        groupSettings
                          ? formatBooleanLabel(
                              groupSettings.requireAdminToAddFriends,
                            )
                          : "未同步"
                      }}
                    </dd>
                  </div>
                  <div>
                    <dt>最大人数</dt>
                    <dd>{{ groupSettings?.maxMembers ?? "未同步" }}</dd>
                  </div>
                  <div>
                    <dt>我的禁言</dt>
                    <dd>
                      {{
                        groupSettings
                          ? isPersonallyMutedInGroup
                            ? "已禁言"
                            : "正常"
                          : "未同步"
                      }}
                    </dd>
                  </div>
                  <div>
                    <dt>我的禁言截止</dt>
                    <dd>
                      {{
                        groupSettings
                          ? formatDetailTime(groupSettings.myMute?.muteUntil ?? null)
                          : "未同步"
                      }}
                    </dd>
                  </div>
                </dl>

                <div
                  v-if="canUpdateSelectedGroupSettings"
                  class="group-panel__action-row"
                >
                  <button
                    type="button"
                    class="group-panel__action"
                    :disabled="
                      isLoadingGroupSettings ||
                      !groupSettings ||
                      updatingGroupSettingKey !== null
                    "
                    @click="void handleToggleJoinApproval()"
                  >
                    {{
                      updatingGroupSettingKey === "joinApprovalRequired"
                        ? "提交中..."
                        : groupSettings?.joinApprovalRequired
                          ? "关闭入群审批"
                          : "开启入群审批"
                    }}
                  </button>
                  <button
                    type="button"
                    class="group-panel__action"
                    :disabled="
                      isLoadingGroupSettings ||
                      !groupSettings ||
                      updatingGroupSettingKey !== null
                    "
                    @click="void handleToggleMemberInvite()"
                  >
                    {{
                      updatingGroupSettingKey === "memberCanInvite"
                        ? "提交中..."
                        : groupSettings?.memberCanInvite
                          ? "关闭成员邀请"
                          : "开启成员邀请"
                    }}
                  </button>
                  <button
                    type="button"
                    class="group-panel__action"
                    :disabled="
                      isLoadingGroupSettings ||
                      !groupSettings ||
                      updatingGroupSettingKey !== null
                    "
                    @click="void handleToggleMemberCanAddFriends()"
                  >
                    {{
                      updatingGroupSettingKey === "memberCanAddFriends"
                        ? "提交中..."
                        : groupSettings?.memberCanAddFriends
                          ? "关闭群内加好友"
                          : "开启群内加好友"
                    }}
                  </button>
                  <button
                    type="button"
                    class="group-panel__action"
                    :disabled="
                      isLoadingGroupSettings ||
                      !groupSettings ||
                      updatingGroupSettingKey !== null
                    "
                    @click="void handleToggleRequireAdminToAddFriends()"
                  >
                    {{
                      updatingGroupSettingKey ===
                      "requireAdminToAddFriends"
                        ? "提交中..."
                        : groupSettings?.requireAdminToAddFriends
                          ? "关闭加好友审批"
                          : "开启加好友审批"
                    }}
                  </button>
                </div>

                <div
                  v-if="canUpdateSelectedGroupSettings"
                  class="group-panel__inline-form"
                >
                  <label class="group-panel__input-field">
                    <span>群最大人数</span>
                    <input
                      v-model="groupMaxMembersDraft"
                      class="group-panel__input"
                      type="number"
                      min="1"
                      step="1"
                      inputmode="numeric"
                      :disabled="
                        isLoadingGroupSettings ||
                        !groupSettings ||
                        updatingGroupSettingKey !== null
                      "
                      @keydown.enter.prevent="void handleSubmitMaxMembers()"
                    />
                  </label>
                  <button
                    type="button"
                    class="group-panel__action"
                    :disabled="
                      isLoadingGroupSettings ||
                      !groupSettings ||
                      updatingGroupSettingKey !== null
                    "
                    @click="void handleSubmitMaxMembers()"
                  >
                    {{
                      updatingGroupSettingKey === "maxMembers"
                        ? "保存中..."
                        : "保存人数上限"
                    }}
                  </button>
                </div>
              </div>

              <div
                v-if="sortedGroupMembers.length"
                class="group-panel__member-list"
              >
                <article
                  v-for="member in sortedGroupMembers.slice(0, 8)"
                  :key="member.userId"
                  class="group-panel__member"
                >
                  <span class="group-panel__member-avatar">{{
                    getRoomMemberDisplayName(member).slice(0, 1).toUpperCase()
                  }}</span>
                  <div class="group-panel__member-copy">
                    <strong>{{ getRoomMemberDisplayName(member) }}</strong>
                    <small>
                      {{ formatRoomMemberRole(member.role) }} /
                      {{ member.username }}
                    </small>
                  </div>
                </article>
              </div>

              <div
                v-if="sortedGroupMembers.length"
                class="group-panel__member-more"
              >
                <span>
                  已展示前 {{ Math.min(sortedGroupMembers.length, 8) }} 位成员，
                  当前群共 {{ groupMemberStats.total }} 人。
                </span>
                <button
                  type="button"
                  class="group-panel__action"
                  :disabled="isLoadingGroupContext"
                  @click="void handleOpenViewGroupMembersModal()"
                >
                  {{ isLoadingGroupContext ? "同步中..." : "查看全部成员" }}
                </button>
              </div>
            </template>
          </section>

          <section class="message-stage">
            <div class="message-stage__header">
              <h4>历史消息</h4>
              <small v-if="isOpeningPrivateChat">正在准备私聊房间...</small>
              <small v-else>{{ messages.length }} 条</small>
            </div>
            <div
              v-if="typingIndicatorText"
              class="message-stage__typing"
            >
              {{ typingIndicatorText }}
            </div>
            <div
              v-if="isMultiSelectMode"
              class="message-stage__multi-select-bar"
            >
              <strong>已选择 {{ selectedMessagesCount }} 条消息</strong>
              <div class="message-stage__multi-select-actions">
                <button
                  type="button"
                  class="message-card__action message-card__action--secondary"
                  :disabled="
                    isForwardingMessage || !canForwardSelectedBatchMessages
                  "
                  @click="handleOpenBatchForwardMessageModal()"
                >
                  {{ isForwardingMessage ? "转发中..." : "批量转发" }}
                </button>
                <button
                  type="button"
                  class="message-card__action"
                  :disabled="
                    isDeletingSelectedMessages || !canDeleteSelectedBatchMessages
                  "
                  @click="void handleDeleteSelectedMessages()"
                >
                  {{
                    isDeletingSelectedMessages ? "删除中..." : "批量删除"
                  }}
                </button>
                <button
                  type="button"
                  class="message-card__action message-card__action--secondary"
                  @click="exitMultiSelectMode()"
                >
                  退出多选
                </button>
              </div>
            </div>

            <div v-if="isLoadingMessages" class="chat-empty">
              <strong>加载中</strong>
              <p>正在拉取最近消息。</p>
            </div>

            <div v-else-if="!messages.length" class="chat-empty">
              <strong>暂无消息</strong>
              <p>这个会话还没有历史消息，可以先从联系人页发起新的聊天。</p>
            </div>

            <div v-else class="message-feed">
              <article
                v-for="message in messages"
                :key="message.id"
                class="message-card"
                :class="{
                  'message-card--self': message.isSelf,
                  'message-card--system': message.messageType === 'system',
                  'message-card--quoted-highlight':
                    highlightedQuotedMessageId === message.id,
                }"
                :data-message-id="message.id"
              >
                <div
                  v-if="isMultiSelectMode && canSelectMessageForMultiSelect(message)"
                  class="message-card__selection"
                >
                  <button
                    type="button"
                    class="message-card__select-toggle"
                    :class="{
                      'message-card__select-toggle--active': isMessageSelected(message),
                    }"
                    @click="toggleMessageSelection(message)"
                  >
                    {{ isMessageSelected(message) ? "已选" : "选择" }}
                  </button>
                </div>
                <div class="message-card__meta">
                  <strong>{{
                    message.isSelf ? "我" : message.senderName
                  }}</strong>
                  <span class="message-card__meta-trailing">
                    <span
                      v-if="isMessagePinned(message)"
                      class="message-card__pin-badge"
                    >
                      已置顶
                    </span>
                    <span>{{ formatDetailTime(message.createdAt) }}</span>
                  </span>
                </div>
                <div v-if="message.forwardInfo" class="forward-block">
                  <strong
                    >转发自
                    {{ formatForwardSourceName(message.forwardInfo) }}</strong
                  >
                  <small>{{
                    formatForwardOriginLabel(message.forwardInfo) ||
                    "当前消息由其他会话转发而来"
                  }}</small>
                </div>
                <button
                  v-if="message.quotedMessage"
                  type="button"
                  class="quoted-block"
                  @click="scrollToQuotedMessage(message.quotedMessage)"
                >
                  <strong>{{
                    getQuotedSenderDisplayName(message.quotedMessage)
                  }}</strong>
                  <small>{{
                    formatQuotedMessagePreview(message.quotedMessage)
                  }}</small>
                </button>
                <template v-if="message.isDeleted || !message.parts.length">
                  <p class="message-card__body">
                    {{ message.preview || message.content || "[空消息]" }}
                  </p>
                </template>
                <template v-else>
                  <p
                    v-for="part in getMessageTextParts(message)"
                    :key="`${message.id}-text-${part.position}`"
                    class="message-card__body"
                  >
                    {{ part.text }}
                  </p>

                  <div
                    v-for="part in getMessageAttachmentParts(message)"
                    :key="`${message.id}-attachment-${part.position}`"
                    class="attachment-card"
                    :class="`attachment-card--${part.partType}`"
                  >
                    <button
                      v-if="
                        part.partType === 'image' &&
                        getAttachmentPreviewUrl(message, part)
                      "
                      type="button"
                      class="attachment-card__media-button"
                      @click="void handleOpenAttachmentPreview(message, part)"
                    >
                      <img
                        :src="getAttachmentPreviewUrl(message, part) || ''"
                        :alt="getAttachmentName(part)"
                        class="attachment-card__media attachment-card__media--image"
                      />
                    </button>
                    <button
                      v-else-if="
                        part.partType === 'video' &&
                        part.attachment?.thumbnailKey &&
                        getAttachmentPreviewUrl(message, part)
                      "
                      type="button"
                      class="attachment-card__media-button attachment-card__media-button--video"
                      @click="void handleOpenAttachmentPreview(message, part)"
                    >
                      <img
                        :src="getAttachmentPreviewUrl(message, part) || ''"
                        :alt="getAttachmentName(part)"
                        class="attachment-card__media attachment-card__media--video-thumb"
                      />
                      <span class="attachment-card__play-badge">播放</span>
                    </button>
                    <video
                      v-else-if="
                        part.partType === 'video' &&
                        getAttachmentPreviewUrl(message, part)
                      "
                      class="attachment-card__media attachment-card__media--video"
                      :src="getAttachmentPreviewUrl(message, part) || undefined"
                      controls
                      preload="metadata"
                    />
                    <audio
                      v-else-if="
                        part.partType === 'audio' &&
                        (getAttachmentPlayableUrl(message, part) ||
                          getAttachmentPreviewUrl(message, part))
                      "
                      class="attachment-card__audio"
                      :src="
                        getAttachmentPlayableUrl(message, part) ||
                        getAttachmentPreviewUrl(message, part) ||
                        undefined
                      "
                      controls
                      preload="none"
                    />
                    <div
                      v-else-if="
                        part.partType !== 'file' &&
                        isAttachmentPreviewLoading(message, part)
                      "
                      class="attachment-card__preview-state"
                    >
                      正在加载{{ formatAttachmentType(part.partType) }}预览...
                    </div>
                    <div
                      v-else-if="
                        part.partType !== 'file' &&
                        getAttachmentPreviewFailure(message, part)
                      "
                      class="attachment-card__preview-state attachment-card__preview-state--error"
                    >
                      {{ getAttachmentPreviewFailure(message, part) }}
                    </div>
                    <div class="attachment-card__badge">
                      {{ formatAttachmentType(part.partType) }}
                    </div>
                    <div class="attachment-card__copy">
                      <strong>{{ getAttachmentName(part) }}</strong>
                      <small>{{ getAttachmentMeta(part) }}</small>
                    </div>
                    <div class="attachment-card__actions">
                      <button
                        v-if="
                          canAccessAttachmentResource(part) &&
                          (part.partType === 'image' || part.partType === 'video')
                        "
                        type="button"
                        class="attachment-card__action attachment-card__action--secondary"
                        @click="void handleOpenAttachmentPreview(message, part)"
                      >
                        预览
                      </button>
                      <button
                        v-if="canAccessAttachmentResource(part)"
                        type="button"
                        class="attachment-card__action attachment-card__action--secondary"
                        :disabled="isAttachmentDownloading(message, part)"
                        @click="void handleOpenAttachment(message, part)"
                      >
                        {{
                          isAttachmentDownloading(message, part)
                            ? "准备中..."
                            : "打开"
                        }}
                      </button>
                      <button
                        v-if="canAccessAttachmentResource(part)"
                        type="button"
                        class="attachment-card__action"
                        :disabled="isAttachmentDownloading(message, part)"
                        @click="void handleDownloadAttachment(message, part)"
                      >
                        {{
                          isAttachmentDownloading(message, part)
                            ? "下载中..."
                            : "下载"
                        }}
                      </button>
                    </div>
                  </div>

                  <p
                    v-if="
                      !getMessageTextParts(message).length &&
                      !getMessageAttachmentParts(message).length
                    "
                    class="message-card__body"
                  >
                    {{ message.preview || message.content || "[空消息]" }}
                  </p>
                </template>
                <div
                  v-if="!isMultiSelectMode && canOpenMessageActionMenu(message)"
                  class="message-card__actions"
                >
                  <button
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    @click="handleToggleMessageActionMenu(message)"
                  >
                    {{
                      activeMessageActionMenuId === message.id
                        ? "收起更多"
                        : "更多"
                    }}
                  </button>
                </div>
                <div
                  v-if="
                    !isMultiSelectMode &&
                    activeMessageActionMenuId === message.id
                  "
                  class="message-action-menu"
                >
                  <button
                    v-if="canCopyMessage(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    @click="void handleCopyMessage(message)"
                  >
                    复制
                  </button>
                  <button
                    v-if="canReplyMessage(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    @click="handleReplyToMessage(message)"
                  >
                    引用
                  </button>
                  <button
                    v-if="canForwardMessage(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    :disabled="isForwardingMessage"
                    @click="void handleOpenForwardMessageModal(message)"
                  >
                    {{ isForwardingMessage ? "转发中..." : "转发" }}
                  </button>
                  <button
                    v-if="canToggleMessagePin(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    :disabled="pinningMessageId === message.id"
                    @click="void handleTogglePinMessage(message)"
                  >
                    {{
                      pinningMessageId === message.id
                        ? isMessagePinned(message)
                          ? "取消中..."
                          : "置顶中..."
                        : isMessagePinned(message)
                          ? "取消置顶"
                          : "置顶"
                    }}
                  </button>
                  <button
                    v-if="canToggleMessageReaction(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    :disabled="reactingMessageId === message.id"
                    @click="handleToggleReactionPicker(message)"
                  >
                    {{
                      reactingMessageId === message.id
                        ? "处理中..."
                        : activeReactionPickerMessageId === message.id
                          ? "收起反应"
                          : "添加反应"
                    }}
                  </button>
                  <button
                    v-if="canViewMessageReaders(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    :disabled="loadingMessageReadersMessageId === message.id"
                    @click="void handleOpenMessageReadersModal(message)"
                  >
                    {{
                      loadingMessageReadersMessageId === message.id
                        ? "加载中..."
                        : "已读成员"
                    }}
                  </button>
                  <button
                    v-if="canEditMessage(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    :disabled="submittingEditMessageId === message.id"
                    @click="handleStartEditMessage(message)"
                  >
                    {{
                      submittingEditMessageId === message.id ? "编辑中..." : "编辑"
                    }}
                  </button>
                  <button
                    v-if="canResendLocalMessage(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    :disabled="resendingMessageId === message.id"
                    @click="void handleResendMessage(message)"
                  >
                    {{
                      resendingMessageId === message.id ? "重发中..." : "重发"
                    }}
                  </button>
                  <button
                    v-if="canSelectMessageForMultiSelect(message)"
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    @click="handleEnterMultiSelectMode(message)"
                  >
                    多选
                  </button>
                  <button
                    v-if="canDeleteMessage(message)"
                    type="button"
                    class="message-card__action"
                    :disabled="deletingMessageId === message.id"
                    @click="void handleDeleteMessage(message)"
                  >
                    {{
                      deletingMessageId === message.id
                        ? isLocalOnlyMessage(message)
                          ? "移除中..."
                          : "撤回中..."
                        : getMessageDeleteLabel(message)
                    }}
                  </button>
                </div>
                <div
                  v-if="
                    !isMultiSelectMode &&
                    activeReactionPickerMessageId === message.id
                  "
                  class="message-reaction-picker"
                >
                  <button
                    v-for="reactionKey in MESSAGE_REACTION_OPTIONS"
                    :key="`${message.id}-${reactionKey}`"
                    type="button"
                    class="message-reaction-picker__option"
                    :disabled="
                      reactingMessageId === message.id &&
                      reactingReactionKey === reactionKey
                    "
                    @click="void handleReactionOptionClick(message, reactionKey)"
                  >
                    {{ reactionKey }}
                  </button>
                </div>
                <div
                  v-if="message.reactions && message.reactions.length > 0"
                  class="message-reactions"
                >
                  <button
                    v-for="reaction in message.reactions"
                    :key="`${message.id}-${reaction.reactionKey}`"
                    type="button"
                    class="message-reactions__tag"
                    :class="{
                      'message-reactions__tag--self': reaction.hasSelf,
                    }"
                    :disabled="reactingMessageId === message.id"
                    @click="
                      void handleReactionTagClick(message, reaction.reactionKey)
                    "
                  >
                    <span class="message-reactions__emoji">{{
                      reaction.reactionKey
                    }}</span>
                    <span class="message-reactions__count">{{
                      reaction.count
                    }}</span>
                  </button>
                </div>
                <small class="message-card__footer">
                  {{ message.messageType }}
                  <template v-if="message.isEdited"> / 已编辑</template>
                  <template v-if="isMessagePinned(message)"> / 已置顶</template>
                  <template v-if="message.clientStatus === 'sending'">
                    / 发送中</template
                  >
                  <template v-else-if="message.clientStatus === 'failed'">
                    / 发送失败</template
                  >
                  <template v-if="message.deliveryStatus">
                    / {{ message.deliveryStatus }}</template
                  >
                </small>
                <small
                  v-if="message.clientStatus === 'failed' && message.errorMessage"
                  class="message-card__error"
                >
                  {{ message.errorMessage }}
                </small>
              </article>
            </div>
          </section>

          <section class="composer-panel">
            <div class="composer-panel__header">
              <h4>发送消息</h4>
              <small>{{ composerStatusText }}</small>
            </div>
            <input
              ref="attachmentInputRef"
              class="composer-panel__file-input"
              type="file"
              multiple
              :disabled="isSending || groupComposerState.disabled"
              @change="handleAttachmentSelected"
            />
            <textarea
              v-model="draftMessage"
              class="composer-panel__input"
              rows="4"
              :placeholder="groupComposerState.placeholder"
              :disabled="isSending || groupComposerState.disabled"
              @keydown="handleComposerKeydown"
              @blur="handleComposerBlur"
            />
            <p
              v-if="groupComposerState.tip"
              class="composer-panel__mute-tip"
            >
              {{ groupComposerState.tip }}
            </p>
            <div v-if="replyingMessage" class="reply-bar">
              <div class="reply-bar__copy">
                <strong
                  >回复
                  {{
                    replyingMessage.isSelf ? "我" : replyingMessage.senderName
                  }}</strong
                >
                <small>{{ replyingSummary }}</small>
              </div>
              <button
                type="button"
                class="reply-bar__close"
                :disabled="isSending"
                @click="clearReplyingMessage"
              >
                取消
              </button>
            </div>
            <div
              v-if="hasPendingAttachments"
              class="composer-panel__attachments"
            >
              <div class="composer-panel__attachments-summary">
                {{ pendingAttachmentSummary }}
              </div>
              <div
                v-for="item in pendingAttachments"
                :key="item.id"
                class="composer-panel__attachment"
              >
                <div class="composer-panel__attachment-copy">
                  <strong>{{ item.file.name }}</strong>
                  <small>{{ describePendingAttachment(item.file) }}</small>
                </div>
                <button
                  type="button"
                  class="composer-panel__attachment-remove"
                  :disabled="isSending"
                  @click="removePendingAttachment(item.id)"
                >
                  移除
                </button>
                <div
                  v-if="
                    isSending &&
                    attachmentUploadProgressById[item.id] !== undefined
                  "
                  class="composer-panel__progress"
                >
                  <span
                    :style="{
                      width: `${Math.max(0, Math.min(100, Math.round((attachmentUploadProgressById[item.id] || 0) * 100)))}%`,
                    }"
                  />
                </div>
              </div>
              <div
                v-if="attachmentProgressPercent !== null"
                class="composer-panel__progress composer-panel__progress--overall"
              >
                <span :style="{ width: `${attachmentProgressPercent}%` }" />
              </div>
              <p class="composer-panel__attachment-tip">
                当前版本支持多附件与文本混发，附件会按选择顺序依次上传。
              </p>
            </div>
            <div class="composer-panel__actions">
              <button
                type="button"
                class="composer-panel__button composer-panel__button--secondary"
                :disabled="
                  isSending || !selectedChat || groupComposerState.disabled
                "
                @click="handlePickAttachment"
              >
                选择附件
              </button>
              <button
                type="button"
                class="composer-panel__button"
                :class="{
                  'composer-panel__button--primary': hasPendingAttachments,
                }"
                :disabled="
                  isSending ||
                  groupComposerState.disabled ||
                  (!draftMessage.trim() && !hasPendingAttachments)
                "
                @click="void handleSend()"
              >
                {{ sendButtonLabel }}
              </button>
            </div>
          </section>

          <div class="chat-placeholder">
            <strong
              >联系人发起聊天、历史消息、文本发送、实时刷新与附件收发都已经接回
              Go core</strong
            >
            <p>
              当前会话会通过 stdio RPC 接收
              `ws.push`，并在进入会话或收到新消息后回写
              `read_until`；附件消息现在支持多附件与文本混发、signed URL 直传
              multipart/direct upload、commit
              后发送，以及图片放大预览、视频缩略图预览、语音内联播放与本地保存打开。
            </p>
          </div>

          <dl class="chat-runtime-list">
            <div>
              <dt>API</dt>
              <dd>{{ props.bootstrap?.config.api_base_url ?? "未同步" }}</dd>
            </div>
            <div>
              <dt>WS</dt>
              <dd>{{ props.wsStatus }}</dd>
            </div>
            <div>
              <dt>Host</dt>
              <dd>{{ props.hostVersion ?? "unknown" }}</dd>
            </div>
            <div>
              <dt>最后事件</dt>
              <dd>{{ props.lastEvent }}</dd>
            </div>
          </dl>
        </template>

        <div v-else class="chat-empty chat-empty--detail">
          <strong>暂无选中的会话</strong>
          <p>去联系人页点“发消息”，或者从左侧已有会话进入。</p>
        </div>
      </article>
    </div>

    <div
      v-if="mediaPreview"
      class="media-preview"
      @click.self="closeMediaPreview"
    >
      <div class="media-preview__dialog">
        <div class="media-preview__header">
          <div>
            <strong>{{ mediaPreview.name }}</strong>
            <small>{{ mediaPreview.meta }}</small>
          </div>
          <button
            type="button"
            class="media-preview__close"
            @click="closeMediaPreview"
          >
            关闭
          </button>
        </div>
        <img
          v-if="mediaPreview.type === 'image'"
          :src="mediaPreview.url"
          :alt="mediaPreview.name"
          class="media-preview__image"
        />
        <video
          v-else
          class="media-preview__video"
          :src="mediaPreview.url"
          controls
          autoplay
        />
      </div>
    </div>

    <div
      v-if="editingMessageTarget"
      class="message-edit-dialog"
      @click.self="closeEditMessageDialog"
    >
      <div class="message-edit-dialog__panel">
        <div class="message-edit-dialog__header">
          <div>
            <strong>编辑消息</strong>
            <small>仅支持自己发送的纯文本消息。</small>
          </div>
          <button
            type="button"
            class="message-edit-dialog__close"
            :disabled="submittingEditMessageId !== null"
            @click="closeEditMessageDialog"
          >
            关闭
          </button>
        </div>
        <textarea
          v-model="editingMessageDraft"
          class="message-edit-dialog__input"
          rows="5"
          maxlength="10000"
          :disabled="submittingEditMessageId !== null"
        />
        <div class="message-edit-dialog__footer">
          <small>{{ editingMessageDraft.trim().length }} / 10000</small>
          <div class="message-edit-dialog__actions">
            <button
              type="button"
              class="message-edit-dialog__button message-edit-dialog__button--secondary"
              :disabled="submittingEditMessageId !== null"
              @click="closeEditMessageDialog"
            >
              取消
            </button>
            <button
              type="button"
              class="message-edit-dialog__button"
              :disabled="
                submittingEditMessageId !== null || !editingMessageDraft.trim()
              "
              @click="void handleSubmitEditMessage()"
            >
              {{
                submittingEditMessageId !== null ? "保存中..." : "保存修改"
              }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <CreateGroupModal
      :visible="isCreateGroupModalVisible"
      :friends="createGroupFriends"
      :is-loading="isLoadingCreateGroupFriends"
      :is-submitting="isCreatingGroup"
      @update:visible="handleCreateGroupModalVisibleChange"
      @submit="void handleCreateGroup($event)"
    />
    <ForwardMessageModal
      :visible="isForwardMessageModalVisible"
      :chats="forwardableChats"
      :source-summary="forwardingMessageSummary"
      :is-submitting="isForwardingMessage"
      @update:visible="handleForwardMessageModalVisibleChange"
      @submit="void handleForwardMessage($event)"
    />
    <MessageReadersModal
      :visible="isMessageReadersModalVisible"
      :readers="messageReaders"
      :is-loading="loadingMessageReadersMessageId !== null"
      :message-preview="messageReadersSummary"
      @update:visible="handleMessageReadersModalVisibleChange"
    />
    <AddGroupMembersModal
      :visible="isAddGroupMembersModalVisible"
      :friends="addableGroupFriends"
      :is-loading="isLoadingCreateGroupFriends"
      :is-submitting="isAddingGroupMembers"
      @update:visible="handleAddGroupMembersModalVisibleChange"
      @submit="void handleAddGroupMembers($event)"
    />
    <ManageGroupAdminsModal
      :visible="isManageGroupAdminsModalVisible"
      :admins="groupAdminEntries"
      :candidates="appointableGroupAdminMembers"
      :is-loading="isLoadingGroupAdmins || isLoadingGroupContext"
      :is-submitting="isUpdatingGroupAdmins"
      @update:visible="handleManageGroupAdminsModalVisibleChange"
      @appoint="void handleAppointGroupAdmins($event)"
      @remove="void handleRemoveGroupAdmin($event)"
    />
    <ManageGroupJoinRequestsModal
      :visible="isManageGroupJoinRequestsModalVisible"
      :requests="groupJoinRequestEntries"
      :is-loading="isLoadingGroupJoinRequests"
      :is-submitting="isReviewingGroupJoinRequests"
      @update:visible="handleManageGroupJoinRequestsModalVisibleChange"
      @review="void handleReviewGroupJoinRequest($event)"
    />
    <ManageGroupMutesModal
      :visible="isManageGroupMutesModalVisible"
      :mutes="groupMuteEntries"
      :candidates="muteableGroupMembers"
      :is-loading="isLoadingGroupMutes || isLoadingGroupContext"
      :is-submitting="isUpdatingGroupMutes"
      @update:visible="handleManageGroupMutesModalVisibleChange"
      @mute="void handleMuteGroupMembers($event)"
      @unmute="void handleUnmuteGroupMember($event)"
    />
    <ManageGroupRulesModal
      :visible="isManageGroupRulesModalVisible"
      :rules="groupRuleEntries"
      :can-manage="canEditSelectedGroupRules"
      :is-loading="isLoadingGroupRules"
      :is-submitting="isUpdatingGroupRules"
      @update:visible="handleManageGroupRulesModalVisibleChange"
      @create="void handleCreateGroupRule($event)"
      @update="void handleUpdateGroupRule($event)"
      @delete="void handleDeleteGroupRule($event)"
    />
    <ManageGroupOperationLogsModal
      :visible="isManageGroupOperationLogsModalVisible"
      :logs="groupOperationLogEntries"
      :is-loading="isLoadingGroupOperationLogs"
      :is-loading-more="isLoadingMoreGroupOperationLogs"
      :has-more="hasMoreGroupOperationLogs"
      @update:visible="handleManageGroupOperationLogsModalVisibleChange"
      @load-more="void handleLoadMoreGroupOperationLogs()"
    />
    <RemoveGroupMembersModal
      :visible="isRemoveGroupMembersModalVisible"
      :members="removableGroupMembers"
      :is-submitting="isRemovingGroupMembers"
      @update:visible="handleRemoveGroupMembersModalVisibleChange"
      @submit="void handleRemoveGroupMembers($event)"
    />
    <TransferGroupOwnerModal
      :visible="isTransferGroupOwnerModalVisible"
      :members="transferableGroupOwnerMembers"
      :is-loading="isLoadingGroupContext"
      :is-submitting="isTransferringGroupOwner"
      @update:visible="handleTransferGroupOwnerModalVisibleChange"
      @submit="void handleTransferGroupOwner($event)"
    />
    <ViewGroupMembersModal
      :visible="isViewGroupMembersModalVisible"
      :members="sortedGroupMembers"
      :stats="groupMemberStats"
      :is-loading="isLoadingGroupContext"
      :can-manage-members="canManageSelectedGroupMembers"
      :can-manage-admins="canManageSelectedGroupAdmins"
      :can-transfer-owner="canTransferSelectedGroupOwner"
      @update:visible="handleViewGroupMembersModalVisibleChange"
      @open-add-members="void handleOpenAddGroupMembersFromMemberPanel()"
      @open-remove-members="handleOpenRemoveGroupMembersFromMemberPanel"
      @open-manage-admins="void handleOpenManageGroupAdminsFromMemberPanel()"
      @open-transfer-owner="void handleOpenTransferGroupOwnerFromMemberPanel()"
    />
  </section>
</template>

<style scoped>
.chat-panel {
  display: grid;
  gap: 18px;
}

.chat-panel__notice {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 18px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.84);
  color: var(--text-secondary);
}

.chat-panel__notice span {
  color: var(--text-primary);
  font-weight: 600;
}

.chat-panel__layout {
  display: grid;
  grid-template-columns: minmax(280px, 360px) minmax(0, 1fr);
  gap: 18px;
  min-height: 0;
}

.chat-panel__sidebar,
.chat-panel__detail {
  display: grid;
  gap: 18px;
  padding: 22px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 28px;
  background: rgba(255, 255, 255, 0.86);
  box-shadow: 0 28px 60px rgba(15, 23, 42, 0.08);
}

.chat-panel__header {
  display: grid;
  gap: 14px;
}

.chat-panel__header-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.chat-panel__header h2,
.chat-hero h3,
.message-stage__header h4 {
  margin: 0;
  color: var(--text-primary);
}

.chat-panel__header p,
.chat-hero p,
.chat-empty p,
.chat-placeholder p {
  margin: 0;
  color: var(--text-secondary);
}

.chat-panel__header-action {
  height: 42px;
  padding: 0 16px;
  border-radius: 999px;
  border: 1px solid rgba(0, 155, 143, 0.2);
  background: rgba(0, 194, 179, 0.1);
  color: var(--primary-color-strong);
  font-weight: 700;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease;
}

.chat-panel__header-action:hover {
  transform: translateY(-1px);
  border-color: rgba(0, 155, 143, 0.36);
  background: rgba(0, 194, 179, 0.16);
}

.chat-panel__header-action:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

.chat-panel__search {
  width: 100%;
  padding: 12px 14px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 16px;
  background: rgba(241, 245, 249, 0.92);
  color: var(--text-primary);
}

.chat-list {
  display: grid;
  gap: 10px;
}

.chat-row {
  display: grid;
  grid-template-columns: 52px minmax(0, 1fr);
  gap: 14px;
  align-items: center;
  padding: 14px;
  border: 1px solid transparent;
  border-radius: 20px;
  background: rgba(241, 245, 249, 0.68);
  text-align: left;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease;
}

.chat-row:hover {
  transform: translateY(-1px);
  border-color: rgba(0, 155, 143, 0.2);
}

.chat-row--active {
  border-color: rgba(0, 155, 143, 0.34);
  background: linear-gradient(
    180deg,
    rgba(0, 194, 179, 0.12),
    rgba(255, 255, 255, 0.98)
  );
}

.chat-row__avatar,
.chat-hero__avatar {
  position: relative;
  overflow: hidden;
  display: grid;
  place-items: center;
  width: 52px;
  height: 52px;
  border-radius: 18px;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  font-size: 20px;
  font-weight: 700;
}

.chat-row__avatar-image,
.chat-hero__avatar-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.chat-row__copy,
.chat-row__topline,
.chat-row__bottomline {
  display: grid;
  gap: 6px;
}

.chat-row__topline,
.chat-row__bottomline {
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
}

.chat-row__copy strong,
.chat-row__copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-row__copy strong {
  color: var(--text-primary);
}

.chat-row__copy small {
  color: var(--text-secondary);
}

.chat-row__badge {
  min-width: 22px;
  padding: 2px 7px;
  border-radius: 999px;
  background: #ef4444;
  color: #ffffff;
  font-size: 12px;
  font-weight: 700;
  text-align: center;
}

.chat-hero {
  display: grid;
  grid-template-columns: 64px minmax(0, 1fr);
  gap: 18px;
  align-items: center;
  padding: 20px;
  border-radius: 24px;
  background: linear-gradient(
    135deg,
    rgba(0, 194, 179, 0.12),
    rgba(255, 255, 255, 0.96)
  );
}

.chat-hero__avatar {
  width: 64px;
  height: 64px;
  border-radius: 22px;
}

.chat-detail-list,
.chat-runtime-list {
  display: grid;
  gap: 12px;
  margin: 0;
}

.chat-detail-list div,
.chat-runtime-list div {
  display: grid;
  grid-template-columns: 120px minmax(0, 1fr);
  gap: 12px;
}

.chat-detail-list dt,
.chat-runtime-list dt {
  color: var(--text-secondary);
}

.chat-detail-list dd,
.chat-runtime-list dd {
  margin: 0;
  color: var(--text-primary);
  word-break: break-word;
}

.group-panel {
  display: grid;
  gap: 14px;
  padding: 18px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 24px;
  background: rgba(241, 245, 249, 0.72);
}

.group-panel__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.group-panel__header-copy {
  display: grid;
  gap: 4px;
}

.group-panel__header-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
}

.group-panel__header h4 {
  margin: 0;
  color: var(--text-primary);
}

.group-panel__header small,
.group-panel__member-copy small,
.group-panel__member-more,
.group-panel__empty p {
  color: var(--text-secondary);
}

.group-panel__detail-list {
  display: grid;
  gap: 10px;
  margin: 0;
}

.group-panel__file-input {
  display: none;
}

.group-panel__detail-list div {
  display: grid;
  grid-template-columns: 96px minmax(0, 1fr);
  gap: 12px;
}

.group-panel__detail-list dt {
  color: var(--text-secondary);
}

.group-panel__detail-list dd {
  margin: 0;
  color: var(--text-primary);
  word-break: break-word;
}

.group-panel__section {
  display: grid;
  gap: 10px;
}

.group-panel__section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.group-panel__section-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}

.group-panel__section-header h5 {
  margin: 0;
  color: var(--text-primary);
}

.group-panel__action {
  padding: 8px 12px;
  border: none;
  border-radius: 999px;
  background: #0f172a;
  color: #ffffff;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}

.group-panel__action:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.group-panel__action-row {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.group-panel__inline-form {
  display: flex;
  flex-wrap: wrap;
  align-items: end;
  gap: 12px;
}

.group-panel__input-field {
  display: grid;
  gap: 6px;
  flex: 1 1 220px;
  min-width: 0;
  color: var(--text-secondary);
  font-size: 12px;
}

.group-panel__input {
  width: 100%;
  min-height: 42px;
  padding: 10px 12px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.95);
  color: var(--text-primary);
  font: inherit;
}

.group-panel__input:disabled {
  cursor: not-allowed;
  opacity: 0.7;
}

.group-panel__member-list {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 10px;
}

.group-panel__member {
  display: grid;
  grid-template-columns: 40px minmax(0, 1fr);
  gap: 10px;
  align-items: center;
  padding: 12px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.9);
}

.group-panel__member-avatar {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: 14px;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  font-weight: 700;
}

.group-panel__member-copy {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.group-panel__member-copy strong,
.group-panel__member-copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.group-panel__empty {
  display: grid;
  gap: 6px;
  place-items: center;
  min-height: 120px;
  text-align: center;
}

.group-panel__empty strong {
  color: var(--text-primary);
}

.group-panel__member-more {
  margin: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
  font-size: 13px;
}

.message-stage {
  display: grid;
  gap: 14px;
}

.message-stage__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.message-stage__header small {
  color: var(--text-secondary);
}

.message-stage__typing {
  margin: -2px 0 0;
  color: var(--primary-color-strong);
  font-size: 13px;
  font-weight: 600;
}

.message-stage__multi-select-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px 14px;
  border-radius: 18px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.76);
}

.message-stage__multi-select-bar strong {
  color: var(--text-primary);
  font-size: 13px;
}

.message-stage__multi-select-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
}

.message-feed {
  display: grid;
  gap: 12px;
  max-height: 420px;
  overflow-y: auto;
  padding-right: 6px;
}

.message-card {
  display: grid;
  gap: 8px;
  max-width: 78%;
  padding: 14px 16px;
  border-radius: 20px;
  background: rgba(241, 245, 249, 0.88);
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.message-card--self {
  justify-self: end;
  background: rgba(0, 194, 179, 0.12);
  border-color: rgba(0, 155, 143, 0.16);
}

.message-card--system {
  justify-self: center;
  max-width: 100%;
  background: rgba(15, 23, 42, 0.06);
}

.message-card__selection {
  display: flex;
  justify-content: flex-end;
}

.message-card__select-toggle {
  height: 28px;
  padding: 0 12px;
  border-radius: 999px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.72);
  color: var(--text-primary);
  font-size: 12px;
  cursor: pointer;
}

.message-card__select-toggle--active {
  border-color: rgba(0, 155, 143, 0.18);
  background: rgba(0, 194, 179, 0.16);
  color: var(--primary-color-strong);
}

.message-card__meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: var(--text-secondary);
  font-size: 12px;
}

.message-card__meta-trailing {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.message-card__meta strong {
  color: var(--text-primary);
}

.message-card__pin-badge {
  display: inline-flex;
  align-items: center;
  height: 22px;
  padding: 0 10px;
  border-radius: 999px;
  background: rgba(245, 158, 11, 0.16);
  color: #92400e;
  font-weight: 600;
}

.message-card__body {
  margin: 0;
  color: var(--text-primary);
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

.quoted-block {
  display: grid;
  gap: 4px;
  padding: 10px 12px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.64);
  text-align: left;
  cursor: pointer;
}

.quoted-block strong {
  color: var(--text-primary);
  font-size: 12px;
}

.quoted-block small {
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.forward-block {
  display: grid;
  gap: 4px;
  padding: 10px 12px;
  border-radius: 14px;
  border: 1px solid rgba(14, 116, 144, 0.14);
  background: rgba(224, 242, 254, 0.7);
}

.forward-block strong {
  color: var(--text-primary);
  font-size: 12px;
}

.forward-block small {
  color: var(--text-secondary);
}

.attachment-card {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-radius: 18px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.82);
}

.attachment-card--image {
  border-color: rgba(14, 116, 144, 0.18);
}

.attachment-card--video {
  border-color: rgba(249, 115, 22, 0.18);
}

.attachment-card--audio {
  border-color: rgba(16, 185, 129, 0.18);
}

.attachment-card__media-button {
  grid-column: 1 / -1;
  position: relative;
  padding: 0;
  border: none;
  background: transparent;
  cursor: pointer;
}

.attachment-card__media,
.attachment-card__audio,
.attachment-card__preview-state {
  grid-column: 1 / -1;
}

.attachment-card__media {
  width: 100%;
  max-height: 260px;
  border-radius: 16px;
  object-fit: cover;
  background: rgba(15, 23, 42, 0.06);
}

.attachment-card__media-button--video::after {
  content: "";
  position: absolute;
  inset: 0;
  border-radius: 16px;
  background: linear-gradient(
    180deg,
    rgba(15, 23, 42, 0.02),
    rgba(15, 23, 42, 0.3)
  );
}

.attachment-card__audio {
  width: 100%;
}

.attachment-card__play-badge {
  position: absolute;
  right: 14px;
  bottom: 14px;
  z-index: 1;
  padding: 6px 12px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.72);
  color: #ffffff;
  font-size: 12px;
  font-weight: 600;
}

.attachment-card__preview-state {
  padding: 10px 12px;
  border-radius: 14px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-secondary);
  font-size: 13px;
}

.attachment-card__preview-state--error {
  background: rgba(220, 38, 38, 0.08);
  color: var(--error-color);
}

.attachment-card__badge {
  min-width: 48px;
  padding: 6px 10px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-secondary);
  font-size: 12px;
  text-align: center;
}

.attachment-card__copy {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.attachment-card__copy strong {
  color: var(--text-primary);
  font-size: 14px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.attachment-card__copy small {
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.attachment-card__actions {
  display: flex;
  justify-content: flex-end;
}

.attachment-card__action {
  height: 30px;
  padding: 0 12px;
  border: none;
  border-radius: 999px;
  background: rgba(0, 194, 179, 0.16);
  color: var(--primary-color-strong);
  cursor: pointer;
}

.attachment-card__action--secondary {
  background: rgba(15, 23, 42, 0.08);
  color: var(--text-primary);
}

.attachment-card__action:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.message-card__actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.message-action-menu {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 8px;
}

.message-card__action {
  height: 28px;
  padding: 0 10px;
  border-radius: 999px;
  border: 1px solid rgba(220, 38, 38, 0.12);
  background: rgba(220, 38, 38, 0.08);
  color: var(--error-color);
  font-size: 12px;
  cursor: pointer;
}

.message-card__action--secondary {
  border-color: rgba(15, 23, 42, 0.08);
  background: rgba(15, 23, 42, 0.04);
  color: var(--text-primary);
}

.message-card__action:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.message-card__footer {
  color: var(--text-secondary);
}

.message-card__error {
  color: var(--error-color);
}

.message-reaction-picker {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.message-reaction-picker__option,
.message-reactions__tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-height: 32px;
  padding: 0 12px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.82);
  color: var(--text-primary);
  cursor: pointer;
}

.message-reaction-picker__option:disabled,
.message-reactions__tag:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.message-reactions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.message-reactions__tag--self {
  border-color: rgba(0, 155, 143, 0.24);
  background: rgba(0, 194, 179, 0.12);
  color: var(--primary-color-strong);
}

.message-reactions__emoji {
  font-size: 16px;
  line-height: 1;
}

.message-reactions__count {
  font-size: 12px;
  font-weight: 600;
}

.message-card--quoted-highlight {
  box-shadow: 0 0 0 3px rgba(0, 194, 179, 0.2);
}

.composer-panel {
  display: grid;
  gap: 12px;
  padding: 18px;
  border-radius: 24px;
  background: rgba(241, 245, 249, 0.72);
  border: 1px solid rgba(15, 23, 42, 0.08);
}

.composer-panel__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.composer-panel__header h4 {
  margin: 0;
  color: var(--text-primary);
}

.composer-panel__header small {
  color: var(--text-secondary);
}

.composer-panel__file-input {
  display: none;
}

.composer-panel__input {
  width: 100%;
  min-height: 110px;
  resize: vertical;
  padding: 14px 16px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.92);
  color: var(--text-primary);
  outline: none;
}

.composer-panel__input:focus {
  border-color: rgba(0, 155, 143, 0.28);
  box-shadow: 0 0 0 4px rgba(0, 194, 179, 0.08);
}

.reply-bar {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px 12px;
  align-items: center;
  padding: 12px 14px;
  border-radius: 16px;
  border: 1px solid rgba(0, 155, 143, 0.16);
  background: rgba(255, 255, 255, 0.9);
}

.reply-bar__copy {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.reply-bar__copy strong,
.reply-bar__copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.reply-bar__copy strong {
  color: var(--text-primary);
  font-size: 13px;
}

.reply-bar__copy small {
  color: var(--text-secondary);
}

.reply-bar__close {
  height: 32px;
  padding: 0 12px;
  border-radius: 999px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(15, 23, 42, 0.04);
  color: var(--text-primary);
  cursor: pointer;
}

.reply-bar__close:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.composer-panel__attachments {
  display: grid;
  gap: 10px;
}

.composer-panel__attachments-summary {
  color: var(--text-secondary);
  font-size: 13px;
}

.composer-panel__attachment {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px 12px;
  padding: 14px 16px;
  border-radius: 18px;
  border: 1px solid rgba(0, 155, 143, 0.16);
  background: rgba(255, 255, 255, 0.92);
}

.composer-panel__attachment-copy {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.composer-panel__attachment-copy strong,
.composer-panel__attachment-copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.composer-panel__attachment-copy strong {
  color: var(--text-primary);
}

.composer-panel__attachment-copy small,
.composer-panel__attachment-tip,
.composer-panel__mute-tip {
  color: var(--text-secondary);
}

.composer-panel__attachment-remove {
  height: 32px;
  padding: 0 12px;
  border-radius: 999px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(15, 23, 42, 0.04);
  color: var(--text-primary);
  cursor: pointer;
}

.composer-panel__attachment-remove:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.composer-panel__progress {
  grid-column: 1 / -1;
  height: 8px;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.08);
}

.composer-panel__progress span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #00c2b3, #009b8f);
  transition: width 0.2s ease;
}

.composer-panel__progress--overall {
  margin-top: 4px;
}

.composer-panel__attachment-tip {
  grid-column: 1 / -1;
  margin: 0;
  font-size: 12px;
}

.composer-panel__mute-tip {
  margin: 0;
  font-size: 13px;
}

.composer-panel__actions {
  display: flex;
  justify-content: flex-end;
  flex-wrap: wrap;
  gap: 10px;
}

.composer-panel__button {
  height: 42px;
  padding: 0 20px;
  border: 1px solid transparent;
  border-radius: 999px;
  background: rgba(0, 194, 179, 0.14);
  color: var(--primary-color-strong);
  cursor: pointer;
}

.composer-panel__button--secondary {
  background: rgba(15, 23, 42, 0.05);
  color: var(--text-primary);
}

.composer-panel__button--primary {
  background: linear-gradient(
    135deg,
    rgba(0, 194, 179, 0.18),
    rgba(0, 155, 143, 0.18)
  );
}

.composer-panel__button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.chat-placeholder,
.chat-empty {
  display: grid;
  gap: 8px;
  padding: 22px;
  border: 1px dashed rgba(15, 23, 42, 0.12);
  border-radius: 22px;
  background: rgba(241, 245, 249, 0.7);
}

.chat-empty strong,
.chat-placeholder strong {
  color: var(--text-primary);
}

.chat-empty--detail {
  align-content: center;
  min-height: 100%;
}

.media-preview {
  position: fixed;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 28px;
  background: rgba(15, 23, 42, 0.56);
  backdrop-filter: blur(10px);
  z-index: 1000;
}

.media-preview__dialog {
  width: min(960px, 100%);
  max-height: calc(100vh - 56px);
  display: grid;
  gap: 16px;
  padding: 18px;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 28px 60px rgba(15, 23, 42, 0.24);
}

.media-preview__header {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: flex-start;
}

.media-preview__header div {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.media-preview__header strong,
.media-preview__header small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.media-preview__header strong {
  color: var(--text-primary);
}

.media-preview__header small {
  color: var(--text-secondary);
}

.media-preview__close {
  height: 34px;
  padding: 0 14px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.04);
  color: var(--text-primary);
  cursor: pointer;
}

.media-preview__image,
.media-preview__video {
  width: 100%;
  max-height: calc(100vh - 180px);
  border-radius: 18px;
  object-fit: contain;
  background: rgba(15, 23, 42, 0.06);
}

.message-edit-dialog {
  position: fixed;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 24px;
  background: rgba(15, 23, 42, 0.42);
  backdrop-filter: blur(8px);
  z-index: 1001;
}

.message-edit-dialog__panel {
  width: min(560px, 100%);
  display: grid;
  gap: 14px;
  padding: 20px;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.98);
  box-shadow: 0 28px 60px rgba(15, 23, 42, 0.22);
}

.message-edit-dialog__header {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: flex-start;
}

.message-edit-dialog__header div {
  display: grid;
  gap: 4px;
}

.message-edit-dialog__header strong {
  color: var(--text-primary);
}

.message-edit-dialog__header small,
.message-edit-dialog__footer small {
  color: var(--text-secondary);
}

.message-edit-dialog__close,
.message-edit-dialog__button {
  height: 34px;
  padding: 0 14px;
  border-radius: 999px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(0, 155, 143, 0.12);
  color: var(--primary-color-strong);
  cursor: pointer;
}

.message-edit-dialog__button--secondary,
.message-edit-dialog__close {
  background: rgba(15, 23, 42, 0.04);
  color: var(--text-primary);
}

.message-edit-dialog__close:disabled,
.message-edit-dialog__button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.message-edit-dialog__input {
  width: 100%;
  min-height: 132px;
  resize: vertical;
  padding: 14px 16px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 18px;
  background: rgba(248, 250, 252, 0.9);
  color: var(--text-primary);
  outline: none;
}

.message-edit-dialog__input:focus {
  border-color: rgba(0, 155, 143, 0.28);
  box-shadow: 0 0 0 4px rgba(0, 194, 179, 0.08);
}

.message-edit-dialog__footer {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
}

.message-edit-dialog__actions {
  display: flex;
  gap: 10px;
}

@media (max-width: 1080px) {
  .chat-panel__layout {
    grid-template-columns: 1fr;
  }

  .chat-panel__header-top {
    flex-direction: column;
    align-items: stretch;
  }

  .chat-panel__header-action {
    width: 100%;
  }

  .group-panel__detail-list div {
    grid-template-columns: 1fr;
    gap: 4px;
  }

  .group-panel__inline-form {
    align-items: stretch;
  }

  .group-panel__input-field {
    flex-basis: 100%;
  }
}
</style>
