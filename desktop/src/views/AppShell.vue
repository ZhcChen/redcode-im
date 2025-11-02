<template>
  <div class="app-shell">
    <aside class="sidebar">
      <header class="sidebar-header">
        <div class="user-meta">
          <div class="avatar" :title="currentUser?.username">
            {{ currentUser?.nickname?.[0] ?? currentUser?.username?.[0] ?? '?' }}
          </div>
          <div class="user-text">
            <span class="user-name">{{ currentUser?.nickname ?? currentUser?.username }}</span>
            <span class="user-sub">{{ currentUser?.email ?? '未绑定邮箱' }}</span>
          </div>
        </div>
        <button class="logout-button" @click="handleLogout">退出</button>
      </header>

      <nav class="sidebar-tabs">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          :class="['tab-button', { active: activePanel === tab.key }]"
          @click="activePanel = tab.key"
        >
          {{ tab.label }}
          <span v-if="tab.key === 'requests' && pendingRequests.length" class="badge">
            {{ pendingRequests.length }}
          </span>
        </button>
      </nav>

      <section class="sidebar-panel">
        <template v-if="activePanel === 'chats'">
          <button class="refresh-button" @click="refreshChats" :disabled="loading">
            刷新会话
          </button>
          <ul class="chat-list">
            <li
              v-for="chat in chats"
              :key="chat.room_id"
              :class="['chat-item', { selected: chat.room_id === selectedChatId }]"
              @click="selectChat(chat.room_id)"
            >
              <div class="chat-avatar">{{ chat.name[0] }}</div>
              <div class="chat-text">
                <div class="chat-title">{{ chat.name }}</div>
                <div class="chat-preview">
                  {{ chat.last_message?.content ?? '暂无消息' }}
                </div>
              </div>
              <span v-if="chat.unread_count > 0" class="badge">{{ chat.unread_count }}</span>
            </li>
          </ul>
        </template>

        <template v-else-if="activePanel === 'contacts'">
          <div class="contact-search">
            <input
              v-model="searchKeyword"
              class="search-input"
              type="text"
              placeholder="搜索用户名或昵称"
              @keyup.enter="handleSearch"
            />
            <button class="search-button" :disabled="searchLoading" @click="handleSearch">
              {{ searchLoading ? '搜索中...' : '搜索' }}
            </button>
            <button
              v-if="hasSearched || searchResults.length"
              type="button"
              class="link-button clear-button"
              @click="resetSearch"
            >
              清除
            </button>
          </div>

          <p v-if="hasSearched && !searchResults.length" class="search-empty">未找到相关用户</p>

          <ul v-if="searchResults.length" class="search-list">
            <li v-for="user in searchResults" :key="user.id" class="search-item">
              <div class="friend-info">
                <div class="friend-avatar">{{ user.nickname?.[0] ?? user.username[0] }}</div>
                <div>
                  <div class="friend-name">{{ user.nickname ?? user.username }}</div>
                  <div class="friend-sub">{{ user.email ?? '未绑定邮箱' }}</div>
                </div>
              </div>
              <div class="search-actions">
                <template v-if="friendStatus(user.id) === 'friend'">
                  <button class="link-button" @click="startChat(user.id)">打开聊天</button>
                  <span class="tag tag-success">好友</span>
                </template>
                <template v-else-if="friendStatus(user.id) === 'outgoing'">
                  <span class="tag tag-info">已发送申请</span>
                </template>
                <template v-else-if="friendStatus(user.id) === 'incoming'">
                  <button class="link-button" @click="respondIncoming(user.id, 'accept')">同意</button>
                  <button class="link-button" @click="respondIncoming(user.id, 'decline')">拒绝</button>
                </template>
                <button
                  v-else
                  class="link-button"
                  :disabled="pendingRequestUserId === user.id"
                  @click="sendFriendRequest(user.id)"
                >
                  {{ pendingRequestUserId === user.id ? '发送中...' : '发送好友申请' }}
                </button>
              </div>
            </li>
          </ul>

          <button class="refresh-button" @click="refreshFriends" :disabled="loading">
            刷新联系人
          </button>
          <ul class="friend-list">
            <li v-for="friend in friends" :key="friend.id" class="friend-item">
              <div class="friend-info">
                <div class="friend-avatar">{{ friend.user.nickname?.[0] ?? friend.user.username[0] }}</div>
                <div>
                  <div class="friend-name">{{ friend.user.nickname ?? friend.user.username }}</div>
                  <div class="friend-sub">{{ friend.user.email ?? '未绑定邮箱' }}</div>
                </div>
              </div>
              <button class="link-button" @click="startChat(friend.user.id)">开始聊天</button>
            </li>
          </ul>
        </template>

        <template v-else>
          <button class="refresh-button" @click="refreshRequests" :disabled="loading">
            刷新申请
          </button>
          <ul class="request-list">
            <li v-for="request in pendingRequests" :key="request.id" class="request-item">
              <div class="request-info">
                <div class="friend-avatar">{{ request.requester.nickname?.[0] ?? request.requester.username[0] }}</div>
                <div>
                  <div class="friend-name">{{ request.requester.nickname ?? request.requester.username }}</div>
                  <div class="friend-sub">{{ formatTime(request.created_at) }}</div>
                </div>
              </div>
              <div class="request-actions">
                <button class="link-button" @click="respond(request.id, 'accept')">同意</button>
                <button class="link-button" @click="respond(request.id, 'decline')">拒绝</button>
              </div>
            </li>
          </ul>
        </template>
      </section>
    </aside>

    <main class="main-panel">
      <header class="main-header">
        <div v-if="activeChat" class="main-header-text">
          <h2>{{ activeChat.name }}</h2>
          <p>{{ activeChat.last_message ? formatTime(activeChat.last_message.created_at) : '暂无历史消息' }}</p>
        </div>
        <div v-else class="main-header-text">
          <h2>选择一个会话</h2>
          <p>开始与团队成员沟通</p>
        </div>
        <button class="refresh-button" @click="refreshMessages" :disabled="loading || !selectedChatId">
          刷新消息
        </button>
      </header>

      <section class="message-container" v-if="activeChat">
        <ul class="message-list" ref="messageListRef">
          <li v-for="message in messages" :key="message.id" class="message-item" :class="{ self: message.sender_id === currentUser?.id }">
            <div class="message-header">
              <span class="message-sender">{{ message.sender_nickname ?? message.sender_username }}</span>
              <span class="message-time">{{ formatTime(message.created_at) }}</span>
            </div>
            <p class="message-body">{{ message.content }}</p>
          </li>
        </ul>
      </section>
      <section v-else class="message-empty">
        <p>选择左侧会话，或挑选联系人开启新的聊天。</p>
      </section>

      <footer class="message-composer" v-if="activeChat">
        <textarea
          v-model="messageText"
          class="composer-input"
          placeholder="输入消息，按 Enter 发送"
          @keydown.enter.prevent="handleSendMessage"
        />
        <button class="submit-button" @click="handleSendMessage" :disabled="!messageText.trim() || sending">
          {{ sending ? '发送中...' : '发送' }}
        </button>
      </footer>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { useStore } from 'vuex';
import type { RootState } from '@/store';
import { toast } from '@/utils';
import type { AuthUser } from '@/api/system';

const store = useStore<RootState>();
const router = useRouter();

const tabs = [
  { key: 'chats' as const, label: '会话' },
  { key: 'contacts' as const, label: '联系人' },
  { key: 'requests' as const, label: '好友申请' },
];

const activePanel = ref<(typeof tabs)[number]['key']>('chats');
const selectedChatId = ref<string | null>(null);
const messageText = ref('');
const sending = ref(false);
const loading = ref(false);
const messageListRef = ref<HTMLUListElement | null>(null);
const searchKeyword = ref('');
const searchLoading = ref(false);
const hasSearched = ref(false);
const pendingRequestUserId = ref<string | null>(null);

const currentUser = computed(() => store.getters.currentUser as RootState['user']);
const chats = computed(() => store.state.chats);
const friends = computed(() => store.state.friends);
const allFriendRequests = computed(() => store.state.friendRequests);
const pendingRequests = computed(() =>
  allFriendRequests.value.filter((request) => request.status === 'Pending')
);
const messages = computed(() => (selectedChatId.value ? store.getters.messagesByRoom(selectedChatId.value) : []));
const activeChat = computed(() => (selectedChatId.value ? store.getters.chatById(selectedChatId.value) : undefined));
const searchResults = computed<ReadonlyArray<AuthUser>>(
  () => store.getters.userSearchResults as AuthUser[]
);

const friendIdSet = computed(() => new Set(friends.value.map((friend) => friend.user.id)));
const pendingRequestMaps = computed(() => {
  const incoming = new Map<string, (typeof allFriendRequests.value)[number]>();
  const outgoing = new Map<string, (typeof allFriendRequests.value)[number]>();
  allFriendRequests.value.forEach((request) => {
    if (request.status !== 'Pending') return;
    if (request.is_incoming) {
      incoming.set(request.requester.id, request);
    } else {
      outgoing.set(request.addressee.id, request);
    }
  });
  return { incoming, outgoing };
});

const scrollToBottom = async () => {
  await nextTick();
  const container = messageListRef.value;
  if (container) {
    container.scrollTop = container.scrollHeight;
  }
};

const friendStatus = (userId: string): 'friend' | 'outgoing' | 'incoming' | 'none' => {
  if (friendIdSet.value.has(userId)) return 'friend';
  if (pendingRequestMaps.value.outgoing.has(userId)) return 'outgoing';
  if (pendingRequestMaps.value.incoming.has(userId)) return 'incoming';
  return 'none';
};

const handleSearch = async () => {
  const keyword = searchKeyword.value.trim();
  if (!keyword) {
    hasSearched.value = false;
    await store.dispatch('clearUserSearch');
    return;
  }
  searchLoading.value = true;
  try {
    const response = await store.dispatch('searchUsers', { keyword, limit: 20 });
    hasSearched.value = true;
    if (!response.success) {
      toast.error(response.message || '搜索失败');
    }
  } catch (error) {
    toast.error((error as Error).message || '搜索失败');
  } finally {
    searchLoading.value = false;
  }
};

const resetSearch = async () => {
  searchKeyword.value = '';
  hasSearched.value = false;
  await store.dispatch('clearUserSearch');
};

const sendFriendRequest = async (userId: string) => {
  if (friendStatus(userId) !== 'none') return;
  pendingRequestUserId.value = userId;
  try {
    const response = await store.dispatch('createFriendRequest', { targetUserId: userId });
    if (response.success) {
      toast.success('好友申请已发送');
    } else {
      toast.error(response.message || '发送好友申请失败');
    }
  } catch (error) {
    toast.error((error as Error).message || '发送好友申请失败');
  } finally {
    pendingRequestUserId.value = null;
  }
};

const respondIncoming = async (userId: string, action: 'accept' | 'decline') => {
  const request = pendingRequestMaps.value.incoming.get(userId);
  if (!request) return;
  await respond(request.id, action);
};

const selectChat = async (roomId: string) => {
  if (selectedChatId.value === roomId) return;
  selectedChatId.value = roomId;
};

watch(selectedChatId, async (roomId) => {
  if (!roomId) return;
  loading.value = true;
  try {
    await store.dispatch('fetchMessages', roomId);
    await scrollToBottom();
  } finally {
    loading.value = false;
  }
});

watch(messages, () => {
  scrollToBottom();
});

const refreshChats = async () => {
  loading.value = true;
  try {
    await store.dispatch('fetchChats');
    if (!selectedChatId.value && store.state.chats.length > 0) {
      selectedChatId.value = store.state.chats[0].room_id;
    }
  } finally {
    loading.value = false;
  }
};

const refreshFriends = async () => {
  loading.value = true;
  try {
    await store.dispatch('fetchFriends');
  } finally {
    loading.value = false;
  }
};

const refreshRequests = async () => {
  loading.value = true;
  try {
    await store.dispatch('fetchFriendRequests');
  } finally {
    loading.value = false;
  }
};

const refreshMessages = async () => {
  if (!selectedChatId.value) return;
  await store.dispatch('fetchMessages', selectedChatId.value);
  await scrollToBottom();
};


const handleSendMessage = async () => {
  if (!messageText.value.trim() || !selectedChatId.value) return;
  sending.value = true;
  try {
    const response = await store.dispatch('sendMessage', {
      roomId: selectedChatId.value,
      data: { content: messageText.value.trim() },
    });
    if (response.success) {
      messageText.value = '';
      await scrollToBottom();
    } else {
      toast.error(response.message || '发送消息失败');
    }
  } finally {
    sending.value = false;
  }
};

const startChat = async (friendUserId: string) => {
  const response = await store.dispatch('ensurePrivateChat', friendUserId);
  if (response.success && response.data?.room_id) {
    await refreshChats();
    selectedChatId.value = response.data.room_id;
    activePanel.value = 'chats';
  } else {
    toast.error(response.message || '创建聊天失败');
  }
};

const respond = async (requestId: string, action: 'accept' | 'decline') => {
  const response = await store.dispatch('respondFriendRequest', { requestId, action });
  if (response.success) {
    toast.success(action === 'accept' ? '已同意好友申请' : '已拒绝好友申请');
  } else {
    toast.error(response.message || '处理好友申请失败');
  }
};

const handleLogout = () => {
  store.dispatch('logout');
  router.replace({ name: 'Login' });
};

const formatTime = (iso: string | undefined) => {
  if (!iso) return '';
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return `${date.getMonth() + 1}月${date.getDate()}日 ${date.getHours().toString().padStart(2, '0')}:${date
    .getMinutes()
    .toString()
    .padStart(2, '0')}`;
};

onMounted(async () => {
  await Promise.all([refreshChats(), refreshFriends(), refreshRequests()]);
});
</script>

<style scoped>
.app-shell {
  display: grid;
  grid-template-columns: 300px 1fr;
  height: 100vh;
  background: #f7f8fb;
  color: #1f2933;
}

.sidebar {
  display: flex;
  flex-direction: column;
  border-right: 1px solid #e3e8ee;
  background: #ffffff;
}

.sidebar-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 18px;
  border-bottom: 1px solid #e3e8ee;
}

.user-meta {
  display: flex;
  align-items: center;
  gap: 12px;
}

.avatar {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: linear-gradient(135deg, #4ecdc4, #45b7d1);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  color: #fff;
}

.user-text {
  display: flex;
  flex-direction: column;
}

.user-name {
  font-size: 16px;
  font-weight: 600;
}

.user-sub {
  font-size: 12px;
  color: #6b7a8f;
}

.logout-button {
  border: none;
  background: #f05252;
  color: #fff;
  padding: 8px 12px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13px;
}

.sidebar-tabs {
  display: flex;
  border-bottom: 1px solid #e3e8ee;
}

.tab-button {
  flex: 1;
  padding: 12px;
  border: none;
  background: transparent;
  cursor: pointer;
  font-size: 14px;
  color: #61738a;
  position: relative;
}

.tab-button.active {
  color: #2c3a4b;
  font-weight: 600;
  background: rgba(76, 205, 196, 0.12);
}

.badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  margin-left: 6px;
  min-width: 18px;
  padding: 2px 6px;
  border-radius: 999px;
  background: #ff9f43;
  color: #fff;
  font-size: 12px;
}

.sidebar-panel {
  flex: 1;
  overflow: auto;
  padding: 12px 16px;
}

.contact-search {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
}

.search-input {
  flex: 1;
  padding: 10px 12px;
  border: 1px solid #d0d7df;
  border-radius: 10px;
  font-size: 14px;
}

.search-button {
  padding: 10px 16px;
  border: none;
  border-radius: 10px;
  background: linear-gradient(135deg, #4ecdc4, #1f8efa);
  color: #fff;
  font-size: 13px;
  cursor: pointer;
}

.search-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.clear-button {
  color: #6b7a8f;
  font-size: 12px;
}

.search-empty {
  margin: 0 0 12px;
  color: #6b7a8f;
  font-size: 13px;
}

.search-list {
  list-style: none;
  margin: 0 0 16px;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.search-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 12px;
  border-radius: 12px;
  background: #eef3fb;
}

.search-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.tag {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 12px;
}

.tag-success {
  background: rgba(76, 205, 196, 0.15);
  color: #2b9c8e;
}

.tag-info {
  background: rgba(31, 142, 250, 0.15);
  color: #1f8efa;
}

.refresh-button {
  width: 100%;
  padding: 10px;
  margin-bottom: 12px;
  border: 1px solid #d0d7df;
  border-radius: 10px;
  background: #fff;
  cursor: pointer;
  font-size: 13px;
}

.chat-list,
.friend-list,
.request-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  list-style: none;
  margin: 0;
  padding: 0;
}

.chat-item,
.friend-item,
.request-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border-radius: 12px;
  background: #f4f6fb;
  cursor: pointer;
  transition: background 0.2s ease;
}

.chat-item.selected {
  background: linear-gradient(135deg, rgba(78, 205, 196, 0.18), rgba(69, 183, 209, 0.18));
}

.chat-avatar,
.friend-avatar {
  width: 38px;
  height: 38px;
  border-radius: 12px;
  background: linear-gradient(135deg, #45b7d1, #5cddbd);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
}

.chat-text {
  flex: 1;
}

.chat-title {
  font-size: 15px;
  font-weight: 600;
}

.chat-preview,
.friend-sub {
  font-size: 13px;
  color: #6b7a8f;
}

.friend-info,
.request-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.friend-name {
  font-weight: 600;
}

.link-button {
  background: none;
  border: none;
  color: #1f8efa;
  font-size: 13px;
  cursor: pointer;
}

.main-panel {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.main-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 24px;
  border-bottom: 1px solid #e3e8ee;
  background: #fff;
}

.main-header-text h2 {
  margin: 0;
  font-size: 22px;
}

.main-header-text p {
  margin: 4px 0 0;
  color: #6b7a8f;
  font-size: 13px;
}

.message-container {
  flex: 1;
  overflow-y: auto;
  padding: 24px 32px;
  background: linear-gradient(180deg, #f8fafc 0%, #eef2f5 100%);
}

.message-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
  list-style: none;
  margin: 0;
  padding: 0;
}

.message-item {
  max-width: 60%;
  padding: 12px 16px;
  border-radius: 16px;
  background: #fff;
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.08);
}

.message-item.self {
  align-self: flex-end;
  background: linear-gradient(135deg, #4ecdc4, #1f8efa);
  color: #fff;
}

.message-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 6px;
  font-size: 12px;
  color: inherit;
  opacity: 0.8;
}

.message-body {
  margin: 0;
  font-size: 15px;
  line-height: 1.5;
  white-space: pre-wrap;
}

.message-empty {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #6b7a8f;
  font-size: 15px;
  background: linear-gradient(180deg, #f8fafc 0%, #eef2f5 100%);
}

.message-composer {
  display: flex;
  align-items: flex-end;
  gap: 12px;
  padding: 20px 24px;
  border-top: 1px solid #e3e8ee;
  background: #fff;
}

.composer-input {
  flex: 1;
  min-height: 60px;
  max-height: 180px;
  padding: 12px 14px;
  border-radius: 12px;
  border: 1px solid #d0d7df;
  resize: vertical;
  font-size: 15px;
}

.submit-button {
  padding: 12px 24px;
  border: none;
  border-radius: 12px;
  background: linear-gradient(135deg, #4ecdc4, #1f8efa);
  color: #fff;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
}

.submit-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
