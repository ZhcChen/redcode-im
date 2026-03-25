<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import {
  ChatApi,
  mapChatRealtimeEvent,
  type ChatMessage,
  type ChatMessagePart,
  type ChatQuotedMessage,
  type ChatRealtimeEvent,
  type ChatRoomDetail,
  type ChatRoomMember,
  type ChatSummary,
  type ChatWebSocketPush,
} from "@/api/chat";
import { FriendApi, type FriendInfo } from "@/api/friend";
import type { BootstrapSnapshot } from "@/types/bootstrap";
import {
  createAttachmentPreviewUrlStore,
  getInlinePreviewAssetKey,
  shouldInlinePreviewAttachment,
} from "@/utils/chat-attachment-preview";
import { inferAttachmentPartType } from "@/utils/chat-attachment-upload";
import {
  buildOutgoingChatMessageParts,
  uploadAttachmentsAndBuildParts,
} from "@/utils/chat-message-compose";
import {
  formatQuotedMessagePreview,
  getQuotedSenderDisplayName,
} from "@/utils/chat-quoted-message";
import { findCreatedGroupChat } from "@/utils/chat-group-create";
import CreateGroupModal from "./CreateGroupModal.vue";

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

type DesktopRuntimeWithFile = NonNullable<Window["desktopEl"]> & {
  file: {
    saveFromURL(options: {
      url: string;
      filePath: string;
    }): Promise<{ filePath: string }>;
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
const isCreateGroupModalVisible = ref(false);
const createGroupFriends = ref<GroupCreateFriendOption[]>([]);
const draftMessage = ref("");
const attachmentInputRef = ref<HTMLInputElement | null>(null);
const pendingAttachments = ref<PendingComposerAttachment[]>([]);
const attachmentUploadProgress = ref<number | null>(null);
const attachmentUploadProgressById = ref<Record<string, number>>({});
const isLoadingChats = ref(true);
const isLoadingMessages = ref(false);
const isLoadingGroupContext = ref(false);
const isLoadingCreateGroupFriends = ref(false);
const isOpeningPrivateChat = ref(false);
const isCreatingGroup = ref(false);
const isSending = ref(false);
const sendingMode = ref<"text" | "attachment" | null>(null);
const deletingMessageId = ref<string | null>(null);
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
const highlightedQuotedMessageId = ref<string | null>(null);
let groupContextLoadSequence = 0;
const notice = ref(
  "聊天主区已接到 Go core，当前继续恢复附件消息上传、下载与预览闭环。",
);
const attachmentPreviewUrlStore = createAttachmentPreviewUrlStore();

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
const sortedGroupMembers = computed(() => {
  const roleOrder: Record<ChatRoomMember["role"], number> = {
    owner: 0,
    admin: 1,
    member: 2,
  };

  return [...groupMembers.value].sort((left, right) => {
    const roleDiff = roleOrder[left.role] - roleOrder[right.role];
    if (roleDiff !== 0) {
      return roleDiff;
    }

    const leftName = (
      left.nickname ||
      left.username ||
      left.userId
    ).toLowerCase();
    const rightName = (
      right.nickname ||
      right.username ||
      right.userId
    ).toLowerCase();
    return leftName.localeCompare(rightName);
  });
});
const groupOwnerMember = computed(
  () =>
    sortedGroupMembers.value.find(
      (member) =>
        member.role === "owner" || member.userId === groupDetail.value?.ownerId,
    ) || null,
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
  message.parts.filter(
    (part) => part.partType !== "text" && part.attachment?.key,
  );

const getAttachmentActionKey = (message: ChatMessage, part: ChatMessagePart) =>
  `${message.id}:${part.attachment?.key ?? `part-${part.position}`}`;

const getAttachmentPreviewKey = (message: ChatMessage, part: ChatMessagePart) =>
  `${message.roomId}:${getInlinePreviewAssetKey(part) ?? `part-${part.position}`}`;

const getAttachmentPlayableKey = (
  message: ChatMessage,
  part: ChatMessagePart,
) => `${message.roomId}:${part.attachment?.key ?? `playable-${part.position}`}`;

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
    const previewUrl = await attachmentPreviewUrlStore.resolve({
      roomId: message.roomId,
      key: previewAssetKey,
      expiresInSeconds: 900,
    });
    attachmentPreviewUrls.value = {
      ...attachmentPreviewUrls.value,
      [previewKey]: previewUrl,
    };
    return previewUrl;
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
    const playableUrl = await attachmentPreviewUrlStore.resolve({
      roomId: message.roomId,
      key: attachmentKey,
      expiresInSeconds: 900,
    });
    attachmentPlayableUrls.value = {
      ...attachmentPlayableUrls.value,
      [playableKey]: playableUrl,
    };
    return playableUrl;
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
      messages.value = [];
      notice.value = response.message || "消息列表加载失败";
      return;
    }

    messages.value = response.data;
    primeAttachmentPreviews(response.data);
    await markRoomRead(roomId, response.data);
  } catch (error) {
    messages.value = [];
    notice.value = error instanceof Error ? error.message : "消息列表加载失败";
  } finally {
    isLoadingMessages.value = false;
  }
};

const resetGroupContext = () => {
  groupContextLoadSequence += 1;
  groupDetail.value = null;
  groupMembers.value = [];
  isLoadingGroupContext.value = false;
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
    } else {
      resetGroupContext();
    }

    if (!options.preserveNotice) {
      notice.value = `已从 Go core 同步 ${response.data.length} 个会话与最近 50 条历史消息。`;
    }
  } catch (error) {
    chats.value = [];
    selectedChatId.value = null;
    messages.value = [];
    resetGroupContext();
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
    return;
  }
  resetGroupContext();
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

const handleSend = async () => {
  const roomId = selectedChatId.value;
  const content = draftMessage.value.trim();
  const attachments = [...pendingAttachments.value];
  const quotedMessageId = replyingMessage.value?.id;
  if (!roomId || isSending.value || (!content && !attachments.length)) {
    return;
  }

  isSending.value = true;
  sendingMode.value = attachments.length ? "attachment" : "text";
  try {
    if (!attachments.length) {
      const response = await ChatApi.sendTextMessage({
        roomId,
        content,
        quotedMessageId,
        currentUserId: props.currentUser.id,
      });
      if (!response.success || !response.data) {
        notice.value = response.message || "消息发送失败";
        return;
      }

      draftMessage.value = "";
      replyingMessage.value = null;
      await loadChats({
        preferredRoomId: roomId,
        preserveNotice: true,
      });
      notice.value = `消息已发送到 ${selectedChat.value?.title || "当前会话"}。`;
      return;
    }

    attachmentUploadProgress.value = 0;
    attachmentUploadProgressById.value = Object.fromEntries(
      attachments.map((item) => [item.id, 0]),
    );
    const attachmentParts = await uploadAttachmentsAndBuildParts({
      roomId,
      files: attachments.map((item) => item.file),
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
    });

    const response = await ChatApi.sendMessage({
      roomId,
      parts: buildOutgoingChatMessageParts({
        text: content,
        attachments: attachmentParts,
      }),
      quotedMessageId,
      currentUserId: props.currentUser.id,
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "消息发送失败";
      return;
    }

    const attachmentCount = attachments.length;
    draftMessage.value = "";
    replyingMessage.value = null;
    resetPendingAttachments();
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
    notice.value = error instanceof Error ? error.message : "消息发送失败";
  } finally {
    isSending.value = false;
    sendingMode.value = null;
  }
};

const handlePickAttachment = () => {
  if (isSending.value || !selectedChatId.value) {
    return;
  }
  attachmentInputRef.value?.click();
};

const handleAttachmentSelected = (event: Event) => {
  const input = event.target as HTMLInputElement | null;
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
  if (message.messageType === "system" || message.isDeleted) {
    return;
  }
  replyingMessage.value = message;
  notice.value = `正在回复 ${message.isSelf ? "我" : message.senderName} 的消息。`;
};

const clearReplyingMessage = () => {
  replyingMessage.value = null;
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

const handleDeleteMessage = async (message: ChatMessage) => {
  const roomId = selectedChatId.value;
  if (!roomId || !message.isSelf || deletingMessageId.value) {
    return;
  }

  deletingMessageId.value = message.id;
  try {
    const response = await ChatApi.deleteMessage({
      roomId,
      messageId: message.id,
    });
    if (!response.success) {
      notice.value = response.message || "删除消息失败";
      return;
    }

    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true,
    });
    notice.value = "消息已删除。";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "删除消息失败";
  } finally {
    deletingMessageId.value = null;
  }
};

const handleOpenAttachment = async (
  message: ChatMessage,
  part: ChatMessagePart,
) => {
  const localPath = getAttachmentLocalPath(message, part);
  if (!localPath) {
    await handleDownloadAttachment(message, part);
    return;
  }

  try {
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
    await loadChats({
      preferredRoomId: activeRoomId,
      preserveNotice: true,
      reloadMessages: event.roomId === activeRoomId,
    });
    return;
  }
};

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
  () => selectedChatId.value,
  (nextRoomId, previousRoomId) => {
    if (nextRoomId && previousRoomId && nextRoomId !== previousRoomId) {
      replyingMessage.value = null;
    }
  },
);

onMounted(() => {
  if (props.openChatRequest) {
    void handleOpenChatRequest(props.openChatRequest);
    return;
  }
  void loadChats();
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
            <span class="chat-row__avatar">{{
              chat.title.slice(0, 1).toUpperCase()
            }}</span>
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
            <span class="chat-hero__avatar">{{
              selectedChat.title.slice(0, 1).toUpperCase()
            }}</span>
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
              <h4>群详情</h4>
              <small v-if="isLoadingGroupContext">同步中...</small>
              <small v-else>{{
                groupMembers.length
                  ? `${groupMembers.length} 名成员`
                  : "成员列表待同步"
              }}</small>
            </div>

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

              <p
                v-if="sortedGroupMembers.length > 8"
                class="group-panel__member-more"
              >
                已展示前 8 位成员，剩余
                {{ sortedGroupMembers.length - 8 }} 位成员待后续迁移更完整面板。
              </p>
            </template>
          </section>

          <section class="message-stage">
            <div class="message-stage__header">
              <h4>历史消息</h4>
              <small v-if="isOpeningPrivateChat">正在准备私聊房间...</small>
              <small v-else>{{ messages.length }} 条</small>
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
                <div class="message-card__meta">
                  <strong>{{
                    message.isSelf ? "我" : message.senderName
                  }}</strong>
                  <span>{{ formatDetailTime(message.createdAt) }}</span>
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
                          part.partType === 'image' || part.partType === 'video'
                        "
                        type="button"
                        class="attachment-card__action attachment-card__action--secondary"
                        @click="void handleOpenAttachmentPreview(message, part)"
                      >
                        预览
                      </button>
                      <button
                        v-if="getAttachmentLocalPath(message, part)"
                        type="button"
                        class="attachment-card__action attachment-card__action--secondary"
                        @click="void handleOpenAttachment(message, part)"
                      >
                        打开
                      </button>
                      <button
                        v-else
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
                  v-if="message.messageType !== 'system'"
                  class="message-card__actions"
                >
                  <button
                    type="button"
                    class="message-card__action message-card__action--secondary"
                    :disabled="message.isDeleted"
                    @click="handleReplyToMessage(message)"
                  >
                    引用
                  </button>
                  <button
                    v-if="message.isSelf"
                    type="button"
                    class="message-card__action"
                    :disabled="deletingMessageId === message.id"
                    @click="void handleDeleteMessage(message)"
                  >
                    {{
                      deletingMessageId === message.id ? "删除中..." : "删除"
                    }}
                  </button>
                </div>
                <small class="message-card__footer">
                  {{ message.messageType }}
                  <template v-if="message.isEdited"> / 已编辑</template>
                  <template v-if="message.deliveryStatus">
                    / {{ message.deliveryStatus }}</template
                  >
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
              :disabled="isSending"
              @change="handleAttachmentSelected"
            />
            <textarea
              v-model="draftMessage"
              class="composer-panel__input"
              rows="4"
              placeholder="输入一条文本消息..."
              :disabled="isSending"
              @keydown="handleComposerKeydown"
            />
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
                :disabled="isSending || !selectedChat"
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
                  isSending || (!draftMessage.trim() && !hasPendingAttachments)
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

    <CreateGroupModal
      :visible="isCreateGroupModalVisible"
      :friends="createGroupFriends"
      :is-loading="isLoadingCreateGroupFriends"
      :is-submitting="isCreatingGroup"
      @update:visible="handleCreateGroupModalVisibleChange"
      @submit="void handleCreateGroup($event)"
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

.message-card__meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  color: var(--text-secondary);
  font-size: 12px;
}

.message-card__meta strong {
  color: var(--text-primary);
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
.composer-panel__attachment-tip {
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
}
</style>
