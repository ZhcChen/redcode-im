<script setup lang="ts">
import { computed, onMounted, ref, watch } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import {
  ChatApi,
  mapChatRealtimeEvent,
  type ChatMessage,
  type ChatRealtimeEvent,
  type ChatSummary,
  type ChatWebSocketPush
} from "@/api/chat";
import type { BootstrapSnapshot } from "@/types/bootstrap";

interface OpenChatRequest {
  requestId: number;
  friendUserId: string;
  displayName: string;
}

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
const draftMessage = ref("");
const isLoadingChats = ref(true);
const isLoadingMessages = ref(false);
const isOpeningPrivateChat = ref(false);
const isSending = ref(false);
const lastReadUntilMessageByRoom = ref<Record<string, string>>({});
const notice = ref("聊天主区已接到 Go core，当前继续恢复实时消息与已读回写。");

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

const selectedChat = computed(() => chats.value.find((chat) => chat.id === selectedChatId.value) || chats.value[0] || null);
const pinnedCount = computed(() => chats.value.filter((chat) => chat.isPinned).length);

const formatTime = (value: Date | null) => {
  if (!value) {
    return "暂无";
  }
  return new Intl.DateTimeFormat("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
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
    minute: "2-digit"
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

const pickSelectedChatId = (list: ChatSummary[], preferredRoomId?: string | null) => {
  if (preferredRoomId && list.some((chat) => chat.roomId === preferredRoomId)) {
    return preferredRoomId;
  }
  if (selectedChatId.value && list.some((chat) => chat.roomId === selectedChatId.value)) {
    return selectedChatId.value;
  }
  return list[0]?.roomId ?? null;
};

const setChatUnreadCount = (roomId: string, unreadCount: number) => {
  chats.value = chats.value.map((chat) =>
    chat.roomId === roomId
      ? {
          ...chat,
          unreadCount
        }
      : chat
  );
};

const markRoomRead = async (roomId: string | null, roomMessages: ChatMessage[]) => {
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
      messageId: latestMessage.id
    });
    if (!response.success) {
      return;
    }

    lastReadUntilMessageByRoom.value = {
      ...lastReadUntilMessageByRoom.value,
      [roomId]: latestMessage.id
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
      currentUserId: props.currentUser.id
    });
    if (!response.success || !response.data) {
      messages.value = [];
      notice.value = response.message || "消息列表加载失败";
      return;
    }

    messages.value = response.data;
    await markRoomRead(roomId, response.data);
  } catch (error) {
    messages.value = [];
    notice.value = error instanceof Error ? error.message : "消息列表加载失败";
  } finally {
    isLoadingMessages.value = false;
  }
};

const loadChats = async (
  options: { preferredRoomId?: string | null; preserveNotice?: boolean; reloadMessages?: boolean } = {}
) => {
  isLoadingChats.value = true;
  try {
    const response = await ChatApi.list();
    if (!response.success || !response.data) {
      chats.value = [];
      selectedChatId.value = null;
      messages.value = [];
      notice.value = response.message || "会话列表加载失败";
      return;
    }

    const previousSelectedRoomId = selectedChatId.value;
    const nextSelectedRoomId = pickSelectedChatId(response.data, options.preferredRoomId);
    chats.value = response.data;
    selectedChatId.value = nextSelectedRoomId;
    if (!nextSelectedRoomId) {
      messages.value = [];
    } else if (options.reloadMessages !== false || nextSelectedRoomId !== previousSelectedRoomId) {
      await loadMessages(nextSelectedRoomId);
    }

    if (!options.preserveNotice) {
      notice.value = `已从 Go core 同步 ${response.data.length} 个会话与最近 50 条历史消息。`;
    }
  } catch (error) {
    chats.value = [];
    selectedChatId.value = null;
    messages.value = [];
    notice.value = error instanceof Error ? error.message : "会话列表加载失败";
  } finally {
    isLoadingChats.value = false;
  }
};

const selectChat = async (chatId: string) => {
  selectedChatId.value = chatId;
  await loadMessages(chatId);
};

const handleOpenChatRequest = async (request: OpenChatRequest) => {
  isOpeningPrivateChat.value = true;
  notice.value = `正在为 ${request.displayName} 打开私聊...`;

  try {
    const response = await ChatApi.ensurePrivateChat({
      friendUserId: request.friendUserId
    });
    if (!response.success || !response.data) {
      notice.value = response.message || `打开 ${request.displayName} 的聊天失败`;
      return;
    }

    await loadChats({
      preferredRoomId: response.data.roomId,
      preserveNotice: true
    });
    notice.value = `已打开与 ${response.data.friendName} 的聊天，历史消息已同步。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : `打开 ${request.displayName} 的聊天失败`;
  } finally {
    isOpeningPrivateChat.value = false;
    emit("chat-request-consumed", request.requestId);
  }
};

const handleSend = async () => {
  const roomId = selectedChatId.value;
  const content = draftMessage.value.trim();
  if (!roomId || !content || isSending.value) {
    return;
  }

  isSending.value = true;
  try {
    const response = await ChatApi.sendTextMessage({
      roomId,
      content,
      currentUserId: props.currentUser.id
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "消息发送失败";
      return;
    }

    draftMessage.value = "";
    await loadChats({
      preferredRoomId: roomId,
      preserveNotice: true
    });
    notice.value = `消息已发送到 ${selectedChat.value?.title || "当前会话"}。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "消息发送失败";
  } finally {
    isSending.value = false;
  }
};

const handleComposerKeydown = (event: KeyboardEvent) => {
  if (event.key !== "Enter" || event.shiftKey) {
    return;
  }
  event.preventDefault();
  void handleSend();
};

const handleRealtimeEvent = async (event: ChatRealtimeEvent) => {
  const activeRoomId = selectedChatId.value;

  if (event.type === "message") {
    const isCurrentRoom = event.message.roomId === activeRoomId;
    await loadChats({
      preferredRoomId: activeRoomId,
      preserveNotice: true,
      reloadMessages: isCurrentRoom
    });
    return;
  }

  if (event.readerId === props.currentUser.id && event.roomId && event.messageId) {
    lastReadUntilMessageByRoom.value = {
      ...lastReadUntilMessageByRoom.value,
      [event.roomId]: event.messageId
    };
  }

  await loadChats({
    preferredRoomId: activeRoomId,
    preserveNotice: true,
    reloadMessages: event.roomId === activeRoomId
  });
};

watch(
  () => props.openChatRequest?.requestId,
  (requestId, previousRequestId) => {
    if (!requestId || requestId === previousRequestId || !props.openChatRequest) {
      return;
    }
    void handleOpenChatRequest(props.openChatRequest);
  }
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
  }
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
          <div>
            <h2>会话</h2>
            <p>先恢复旧 desktop 的会话列表与联系人发起聊天链路。</p>
          </div>
          <input v-model="searchQuery" class="chat-panel__search" placeholder="搜索会话..." />
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
            <span class="chat-row__avatar">{{ chat.title.slice(0, 1).toUpperCase() }}</span>
            <span class="chat-row__copy">
              <span class="chat-row__topline">
                <strong>{{ chat.title }}</strong>
                <small>{{ formatTime(chat.lastMessageAt) }}</small>
              </span>
              <span class="chat-row__bottomline">
                <small>{{ chat.lastMessagePreview || "暂无消息" }}</small>
                <span v-if="chat.unreadCount > 0" class="chat-row__badge">{{ chat.unreadCount }}</span>
              </span>
            </span>
          </button>
        </div>
      </aside>

      <article class="chat-panel__detail">
        <template v-if="selectedChat">
          <div class="chat-hero">
            <span class="chat-hero__avatar">{{ selectedChat.title.slice(0, 1).toUpperCase() }}</span>
            <div>
              <h3>{{ selectedChat.title }}</h3>
              <p>{{ selectedChat.subtitle || selectedChat.lastMessagePreview || "会话详情迁移中" }}</p>
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
              <dd>{{ selectedChat.isPinned ? "已置顶" : "未置顶" }} / {{ selectedChat.isMuted ? "已静音" : "正常提醒" }}</dd>
            </div>
            <div>
              <dt>当前账号</dt>
              <dd>{{ props.currentUser.nickname || props.currentUser.username }}</dd>
            </div>
          </dl>

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
                  'message-card--system': message.messageType === 'system'
                }"
              >
                <div class="message-card__meta">
                  <strong>{{ message.isSelf ? "我" : message.senderName }}</strong>
                  <span>{{ formatDetailTime(message.createdAt) }}</span>
                </div>
                <p class="message-card__body">{{ message.preview || message.content || "[空消息]" }}</p>
                <small class="message-card__footer">
                  {{ message.messageType }}
                  <template v-if="message.isEdited"> / 已编辑</template>
                  <template v-if="message.deliveryStatus"> / {{ message.deliveryStatus }}</template>
                </small>
              </article>
            </div>
          </section>

          <section class="composer-panel">
            <div class="composer-panel__header">
              <h4>发送消息</h4>
              <small>{{ isSending ? "发送中..." : "Enter 发送，Shift+Enter 换行" }}</small>
            </div>
            <textarea
              v-model="draftMessage"
              class="composer-panel__input"
              rows="4"
              placeholder="输入一条文本消息..."
              :disabled="isSending"
              @keydown="handleComposerKeydown"
            />
            <div class="composer-panel__actions">
              <button
                type="button"
                class="composer-panel__button"
                :disabled="isSending || !draftMessage.trim()"
                @click="void handleSend()"
              >
                {{ isSending ? "发送中..." : "发送" }}
              </button>
            </div>
          </section>

          <div class="chat-placeholder">
            <strong>联系人发起聊天、历史消息、文本发送、实时刷新都已经接回 Go core</strong>
            <p>当前会话现在会通过 stdio RPC 接收 `ws.push`，并在进入会话或收到新消息后回写 `read_until`；后续再继续补消息操作与更细的状态展示。</p>
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
  background: linear-gradient(180deg, rgba(0, 194, 179, 0.12), rgba(255, 255, 255, 0.98));
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
  background: linear-gradient(135deg, rgba(0, 194, 179, 0.12), rgba(255, 255, 255, 0.96));
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

.message-card__footer {
  color: var(--text-secondary);
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

.composer-panel__actions {
  display: flex;
  justify-content: flex-end;
}

.composer-panel__button {
  height: 42px;
  padding: 0 20px;
  border-radius: 999px;
  background: rgba(0, 194, 179, 0.14);
  color: var(--primary-color-strong);
  cursor: pointer;
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

@media (max-width: 1080px) {
  .chat-panel__layout {
    grid-template-columns: 1fr;
  }
}
</style>
