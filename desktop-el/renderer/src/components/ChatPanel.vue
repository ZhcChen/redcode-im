<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import type { LegacyUserInfo } from "@/api/system";
import { ChatApi, type ChatSummary } from "@/api/chat";
import type { BootstrapSnapshot } from "@/types/bootstrap";

const props = defineProps<{
  currentUser: LegacyUserInfo;
  hostVersion: string | null;
  lastEvent: string;
  wsStatus: string;
  bootstrap: BootstrapSnapshot | null;
}>();

const searchQuery = ref("");
const chats = ref<ChatSummary[]>([]);
const selectedChatId = ref<string | null>(null);
const isLoading = ref(true);
const notice = ref("聊天主区已接到 Go core，当前先恢复真实会话列表与摘要。");

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

const selectedChat = computed(() =>
  filteredChats.value.find((chat) => chat.id === selectedChatId.value) || filteredChats.value[0] || null
);

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

const loadChats = async () => {
  isLoading.value = true;
  try {
    const response = await ChatApi.list();
    if (!response.success || !response.data) {
      notice.value = response.message || "会话列表加载失败";
      chats.value = [];
      selectedChatId.value = null;
      return;
    }

    chats.value = response.data;
    selectedChatId.value = response.data[0]?.id ?? null;
    notice.value = `已从 Go core 同步 ${response.data.length} 个会话，下一批继续接消息详情。`;
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "会话列表加载失败";
    chats.value = [];
    selectedChatId.value = null;
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
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
            <p>先恢复旧 desktop 的聊天列表信息架构。</p>
          </div>
          <input v-model="searchQuery" class="chat-panel__search" placeholder="搜索会话..." />
        </div>

        <div v-if="isLoading" class="chat-empty">
          <strong>加载中</strong>
          <p>正在通过 Go core 同步 `/chats` 会话摘要。</p>
        </div>

        <div v-else-if="!filteredChats.length" class="chat-empty">
          <strong>暂无会话</strong>
          <p>当前账号还没有会话，后续会继续接“发起聊天”和消息详情。</p>
        </div>

        <div v-else class="chat-list">
          <button
            v-for="chat in filteredChats"
            :key="chat.id"
            type="button"
            class="chat-row"
            :class="{ 'chat-row--active': selectedChat?.id === chat.id }"
            @click="selectedChatId = chat.id"
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
              <dd>{{ formatTime(selectedChat.lastMessageAt) }}</dd>
            </div>
            <div>
              <dt>消息预览</dt>
              <dd>{{ selectedChat.lastMessagePreview || "暂无消息" }}</dd>
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

          <div class="chat-placeholder">
            <strong>会话摘要已经通过 stdio RPC 落到 renderer</strong>
            <p>下一批继续接消息列表、会话详情和发送链路，仍然保持业务核心在 Go core，不回退到 renderer 直连业务接口。</p>
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
          <p>会话列表可用后，这里会继续承接消息详情和输入区。</p>
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
.chat-hero h3 {
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
