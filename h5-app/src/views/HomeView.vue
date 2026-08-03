<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { useAppShellStore, type AppTab } from '@/stores/app-shell';
import { useAuthStore } from '@/stores/auth';
import { formatChatDisplayTime, useChatStore } from '@/stores/chat';
import { useContactsStore } from '@/stores/contacts';
import { useSettingsStore } from '@/stores/settings';
import type { AuthUser } from '@/types/auth';
import type { FriendInfo, FriendRequestInfo } from '@/types/friend';

interface NavItem {
  key: AppTab;
  label: string;
  icon: string;
  activeIcon: string;
  badge: number;
}

const router = useRouter();
const authStore = useAuthStore();
const chatStore = useChatStore();
const contactsStore = useContactsStore();
const settingsStore = useSettingsStore();
const shellStore = useAppShellStore();
const chatMenu = ref<{ roomId: string; x: number; y: number; confirmingDelete: boolean } | null>(null);
let longPressTimer: number | null = null;
let suppressNextChatClick = false;

const navItems = computed<NavItem[]>(() => [
  {
    key: 'chat',
    label: '聊天',
    icon: '···',
    activeIcon: '●●●',
    badge: chatStore.unreadTotal,
  },
  {
    key: 'contacts',
    label: '联系人',
    icon: '○+',
    activeIcon: '●+',
    badge: shellStore.pendingFriends,
  },
  {
    key: 'discover',
    label: '发现',
    icon: '◇',
    activeIcon: '◆',
    badge: 0,
  },
  {
    key: 'mine',
    label: '我的',
    icon: '○',
    activeIcon: '●',
    badge: 0,
  },
]);

const title = computed(() => {
  if (shellStore.activeTab === 'contacts') return '联系人';
  if (shellStore.activeTab === 'discover') return '发现';
  if (shellStore.activeTab === 'mine') return '我的';
  return '聊天';
});

const logout = async () => {
  chatStore.dispose();
  chatStore.$reset();
  contactsStore.dispose();
  contactsStore.$reset();
  settingsStore.$reset();
  await authStore.logout();
  await router.replace({ name: 'login' });
};

const openChat = async (roomId: string) => {
  if (!roomId) return;
  await router.push({ name: 'chat-detail', params: { roomId } });
};

const closeChatMenu = () => {
  chatMenu.value = null;
};

const openChatMenu = (roomId: string, clientX: number, clientY: number) => {
  const chat = chatStore.chats.find((item) => item.roomId === roomId);
  if (!chat || chat.type === 'favorite') return;
  chatMenu.value = {
    roomId,
    x: Math.min(Math.max(clientX, 12), window.innerWidth - 172),
    y: Math.min(Math.max(clientY, 12), window.innerHeight - 150),
    confirmingDelete: false,
  };
};

const startChatLongPress = (event: PointerEvent, roomId: string) => {
  if (event.pointerType === 'mouse' && event.button !== 0) return;
  if (longPressTimer !== null) window.clearTimeout(longPressTimer);
  longPressTimer = window.setTimeout(() => {
    suppressNextChatClick = true;
    openChatMenu(roomId, event.clientX, event.clientY);
  }, 500);
};

const clearChatLongPress = () => {
  if (longPressTimer !== null) window.clearTimeout(longPressTimer);
  longPressTimer = null;
};

const handleChatClick = async (roomId: string) => {
  if (suppressNextChatClick) {
    suppressNextChatClick = false;
    return;
  }
  closeChatMenu();
  await openChat(roomId);
};

const toggleChatPinned = async () => {
  const menu = chatMenu.value;
  const chat = menu && chatStore.chats.find((item) => item.roomId === menu.roomId);
  if (!menu || !chat) return;
  closeChatMenu();
  try {
    await chatStore.pinChat(chat.roomId, !chat.isPinned);
  } catch (error) {
    chatStore.error = error instanceof Error ? error.message : '更新会话置顶失败';
  }
};

const deleteSelectedChat = async () => {
  const roomId = chatMenu.value?.roomId;
  if (!roomId) return;
  closeChatMenu();
  try {
    await chatStore.deleteChat(roomId);
  } catch (error) {
    chatStore.error = error instanceof Error ? error.message : '删除会话失败';
  }
};

const openMessageSearch = async () => {
  await router.push({ name: 'message-search' });
};

const connectionLabel = computed(() => {
  if (chatStore.websocketStatus === 'authenticated') return '实时在线';
  if (chatStore.websocketStatus === 'connecting' || chatStore.websocketStatus === 'connected') {
    return '连接中';
  }
  return '离线模式';
});

const chats = computed(() => chatStore.filteredChats);

const displayFriendName = (friend: FriendInfo) =>
  friend.remark?.trim() || friend.user.nickname || friend.user.email || friend.user.username || 'RedCode 用户';

const displayRequestUser = (request: FriendRequestInfo) =>
  request.requester?.nickname || request.requester?.email || request.requesterId || 'RedCode 用户';

const displayUserName = (user: AuthUser) =>
  user.nickname || user.email || user.username || 'RedCode 用户';

const openPrivateChat = async (friendUserId: string) => {
  const roomId = await contactsStore.openPrivateChat(friendUserId);
  if (roomId) {
    await router.push({ name: 'chat-detail', params: { roomId } });
  }
};

const openContactPage = async (name: 'contact-requests' | 'contact-add' | 'contact-profile', userId?: string) => {
  await router.push({ name, ...(userId ? { params: { userId } } : {}) });
};


onMounted(() => {
  document.addEventListener('click', closeChatMenu);
  void chatStore.initialize();
  void contactsStore.initialize();
});

onBeforeUnmount(() => {
  clearChatLongPress();
  document.removeEventListener('click', closeChatMenu);
});
</script>

<template>
  <main class="home-page app-phone-frame">
    <section class="home-page__content">
      <header class="home-header">
        <div>
          <p>RedCode IM</p>
          <h1>{{ title }}</h1>
        </div>
        <div class="home-header__right">
          <span v-if="shellStore.activeTab === 'chat'" class="connection-pill">
            {{ connectionLabel }}
          </span>
          <div class="home-header__avatar" aria-label="当前用户">
            <CachedAvatar
              v-if="authStore.currentUser"
              kind="user"
              :entity-id="authStore.currentUser.id"
              :object-key="authStore.currentUser.avatarObjectKey"
              :label="authStore.currentUser.nickname || authStore.currentUser.email"
              :size="42"
            />
          </div>
        </div>
      </header>

      <section v-if="shellStore.activeTab === 'chat'" class="panel panel--chat">
        <div class="chat-search-row">
          <label class="search-box">
            <span class="sr-only">搜索</span>
            <input
              :value="chatStore.searchKeyword"
              class="rc-focus-ring"
              placeholder="搜索会话"
              @input="chatStore.setSearchKeyword(($event.target as HTMLInputElement).value)"
            />
          </label>
          <button class="message-search-entry rc-focus-ring" type="button" @click="openMessageSearch">
            搜消息
          </button>
        </div>

        <p v-if="chatStore.error" class="chat-notice chat-notice--error">{{ chatStore.error }}</p>
        <p v-else-if="chatStore.isOffline" class="chat-notice">WebSocket 未连接，正在使用本地缓存和 HTTP 刷新。</p>
        <p v-if="chatStore.refreshing && chats.length === 0" class="chat-empty">正在加载会话...</p>
        <p v-else-if="chats.length === 0" class="chat-empty">
          {{ chatStore.searchKeyword ? '没有匹配的会话' : '暂无会话，添加好友或创建群聊后会显示在这里' }}
        </p>

        <article
          v-for="chat in chats"
          :key="chat.id"
          class="chat-row"
          :class="{ 'chat-row--pinned': chat.isPinned }"
          role="button"
          tabindex="0"
          @click.stop="handleChatClick(chat.roomId)"
          @keydown.enter.prevent="openChat(chat.roomId)"
          @keydown.space.prevent="openChat(chat.roomId)"
          @pointerdown="startChatLongPress($event, chat.roomId)"
          @pointerup="clearChatLongPress"
          @pointercancel="clearChatLongPress"
          @pointerleave="clearChatLongPress"
          @contextmenu.prevent.stop="openChatMenu(chat.roomId, $event.clientX, $event.clientY)"
        >
          <CachedAvatar
            class="chat-row__avatar"
            :kind="chat.type === 'group' ? 'room' : 'user'"
            :entity-id="chat.type === 'group' ? chat.roomId : String(chat.raw?.friend_user_id ?? chat.roomId)"
            :object-key="chat.type === 'group' ? chat.avatarObjectKey : String(chat.raw?.friend_avatar_object_key ?? chat.avatarObjectKey ?? '')"
            :label="chat.name"
            :size="48"
          />
          <div class="chat-row__body">
            <div class="chat-row__top">
              <h2>{{ chat.name }}</h2>
              <time>{{ chat.type === 'favorite' ? '随时可用' : formatChatDisplayTime(chat.lastMessageTime) }}</time>
            </div>
            <p>{{ chat.lastMessage || (chat.type === 'favorite' ? '保存的消息和文件会出现在这里' : '暂无消息') }}</p>
          </div>
          <span v-if="chat.unreadCount" class="badge">{{ chat.unreadCount }}</span>
        </article>
        <div
          v-if="chatMenu"
          class="chat-context-menu"
          role="menu"
          :style="{ left: `${chatMenu.x}px`, top: `${chatMenu.y}px` }"
          @click.stop
        >
          <template v-if="!chatMenu.confirmingDelete">
            <button class="rc-focus-ring" type="button" role="menuitem" @click="toggleChatPinned">
              {{ chatStore.chats.find((item) => item.roomId === chatMenu?.roomId)?.isPinned ? '取消置顶' : '置顶会话' }}
            </button>
            <button class="chat-context-menu__danger rc-focus-ring" type="button" role="menuitem" @click="chatMenu.confirmingDelete = true">删除会话</button>
          </template>
          <template v-else>
            <button class="chat-context-menu__danger rc-focus-ring" type="button" role="menuitem" @click="deleteSelectedChat">确认删除</button>
            <button class="rc-focus-ring" type="button" role="menuitem" @click="closeChatMenu">取消</button>
          </template>
        </div>
      </section>

      <section v-else-if="shellStore.activeTab === 'contacts'" class="panel">
        <div class="contact-shortcuts">
          <button class="work-card rc-focus-ring" type="button" @click="openContactPage('contact-requests')">
            <span>好友申请</span><strong>{{ contactsStore.pendingIncomingCount }}</strong>
          </button>
          <button class="work-card rc-focus-ring" type="button" @click="openContactPage('contact-add')">
            <span>添加好友</span><strong>+</strong>
          </button>
          <button class="work-card rc-focus-ring" type="button" @click="router.push({ name: 'group-directory' })">
            <span>群聊</span><strong>›</strong>
          </button>
          <button class="work-card rc-focus-ring" type="button" @click="router.push({ name: 'group-invitations' })">
            <span>群通知</span><strong>›</strong>
          </button>
        </div>
        <form class="search-box search-box--with-action" @submit.prevent="contactsStore.searchUsers()">
          <label>
            <span class="sr-only">搜索用户或联系人</span>
            <input
              :value="contactsStore.searchKeyword"
              class="rc-focus-ring"
              placeholder="搜索账号 / 昵称"
              @input="contactsStore.setSearchKeyword(($event.target as HTMLInputElement).value)"
            />
          </label>
          <button class="inline-action rc-focus-ring" type="submit" :disabled="contactsStore.searching">
            搜索
          </button>
        </form>

        <p v-if="contactsStore.error" class="chat-notice chat-notice--error">{{ contactsStore.error }}</p>

        <section v-if="contactsStore.searchResults.length" class="contact-section">
          <div class="section-title">
            <h2>搜索结果</h2>
            <span>{{ contactsStore.searchResults.length }} 个用户</span>
          </div>
          <article v-for="user in contactsStore.searchResults" :key="user.id" class="contact-row">
            <CachedAvatar class="contact-row__avatar" kind="user" :entity-id="user.id" :object-key="user.avatarObjectKey" :label="displayUserName(user)" />
            <div class="contact-row__body">
              <h3>{{ displayUserName(user) }}</h3>
              <p>{{ user.email || user.username }}</p>
            </div>
            <button class="mini-action rc-focus-ring" type="button" @click="contactsStore.sendFriendRequest(user.id)">
              添加
            </button>
          </article>
        </section>

        <section class="contact-section">
          <div class="section-title">
            <h2>新的朋友</h2>
            <span>{{ contactsStore.pendingIncomingCount }} 条待处理</span>
          </div>
          <p v-if="contactsStore.incomingRequests.length === 0" class="chat-empty">暂无好友请求。</p>
          <article
            v-for="request in contactsStore.incomingRequests"
            :key="request.id"
            class="contact-row contact-row--request"
          >
            <CachedAvatar
              class="contact-row__avatar"
              kind="user"
              :entity-id="request.requesterId"
              :object-key="request.requester?.avatarObjectKey"
              :label="displayRequestUser(request)"
            />
            <div class="contact-row__body">
              <h3>{{ displayRequestUser(request) }}</h3>
              <p>{{ request.message || '请求添加你为好友' }}</p>
            </div>
            <div v-if="request.status === 'pending'" class="contact-row__actions">
              <button class="mini-action rc-focus-ring" type="button" @click="contactsStore.respondRequest(request.id, 'accept')">
                同意
              </button>
              <button class="mini-action mini-action--ghost rc-focus-ring" type="button" @click="contactsStore.respondRequest(request.id, 'decline')">
                拒绝
              </button>
            </div>
            <span v-else class="status-pill">{{ request.status }}</span>
          </article>
        </section>

        <section class="contact-section">
          <div class="section-title">
            <h2>联系人</h2>
            <span>{{ contactsStore.filteredFriends.length }} 人</span>
          </div>
          <p v-if="contactsStore.refreshing && contactsStore.friends.length === 0" class="chat-empty">正在加载联系人...</p>
          <p v-else-if="contactsStore.filteredFriends.length === 0" class="chat-empty">暂无联系人，搜索账号添加好友。</p>
          <article v-for="friend in contactsStore.filteredFriends" :key="friend.user.id" class="contact-row">
            <CachedAvatar class="contact-row__avatar" kind="user" :entity-id="friend.user.id" :object-key="friend.user.avatarObjectKey" :label="displayFriendName(friend)" />
            <div class="contact-row__body">
              <h3>{{ displayFriendName(friend) }}</h3>
              <p>{{ friend.user.email || friend.user.username }}</p>
            </div>
            <div class="contact-row__actions">
              <button class="mini-action mini-action--ghost rc-focus-ring" type="button" @click="openContactPage('contact-profile', friend.user.id)">资料</button>
              <button class="mini-action rc-focus-ring" type="button" @click="openPrivateChat(friend.user.id)">私聊</button>
            </div>
          </article>
        </section>

      </section>

      <section v-else-if="shellStore.activeTab === 'discover'" class="panel">
        <p class="discover-empty">暂无可用功能</p>
      </section>

      <section v-else class="panel">
        <button class="profile-card rc-focus-ring" type="button" @click="router.push({ name: 'mine-profile' })">
          <div class="profile-card__avatar">
            <CachedAvatar
              v-if="authStore.currentUser"
              kind="user"
              :entity-id="authStore.currentUser.id"
              :object-key="authStore.currentUser.avatarObjectKey"
              :label="authStore.currentUser.nickname || authStore.currentUser.email"
              :size="48"
            />
          </div>
          <div>
            <h2>{{ authStore.currentUser?.nickname || 'RedCode 用户' }}</h2>
            <p>{{ authStore.currentUser?.email }}</p>
          </div>
        </button>

        <button class="settings-row rc-focus-ring" type="button" @click="router.push({ name: 'settings' })">
          <span>设置</span>
          <strong>›</strong>
        </button>
        <button class="settings-row settings-row--danger rc-focus-ring" type="button" @click="logout">
          退出登录
        </button>
      </section>
    </section>

    <nav class="tabbar" aria-label="主导航">
      <button
        v-for="item in navItems"
        :key="item.key"
        class="tabbar__item rc-focus-ring"
        :class="{ 'tabbar__item--active': shellStore.activeTab === item.key }"
        type="button"
        @click="shellStore.switchTab(item.key)"
      >
        <span class="tabbar__icon">
          {{ shellStore.activeTab === item.key ? item.activeIcon : item.icon }}
          <em v-if="item.badge">{{ item.badge }}</em>
        </span>
        <span>{{ item.label }}</span>
      </button>
    </nav>
  </main>
</template>

<style scoped>
.home-page {
  position: relative;
  min-height: 100dvh;
  overflow-x: hidden;
  padding-bottom: calc(76px + var(--rc-safe-bottom));
}

.home-page__content {
  padding: calc(var(--rc-safe-top) + 18px) 16px 24px;
}

.home-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 2px 18px;
}

.home-header__right {
  display: flex;
  align-items: center;
  gap: 8px;
}

.home-header p {
  margin: 0 0 4px;
  color: var(--rc-text-secondary);
  font-size: 13px;
}

.home-header h1 {
  margin: 0;
  color: var(--rc-text-black);
  font-size: 28px;
  font-weight: 700;
  letter-spacing: -0.03em;
}

.home-header__avatar,
.chat-row__avatar,
.profile-card__avatar {
  display: grid;
  place-items: center;
  border-radius: 999px;
  background: linear-gradient(180deg, #00db4d 0%, #00c27b 100%);
  color: #fff;
  font-weight: 700;
}

.home-header__avatar {
  width: 42px;
  height: 42px;
}

.connection-pill {
  border-radius: 999px;
  background: var(--rc-primary-soft);
  color: var(--rc-primary-strong);
  font-size: 12px;
  font-weight: 700;
  padding: 5px 9px;
}

.panel {
  display: grid;
  gap: 12px;
}

.panel > * {
  min-width: 0;
}

.discover-empty {
  margin: 24px 0 0;
  color: var(--rc-text-tertiary);
  text-align: center;
  font-size: 14px;
}

.search-box input {
  width: 100%;
  height: 44px;
  border: 0;
  border-radius: 44px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-primary);
  padding: 0 18px;
}

.chat-search-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px;
}

.message-search-entry {
  min-width: 74px;
  border-radius: 999px;
  cursor: pointer;
  background: var(--rc-primary);
  color: #fff;
  font-weight: 700;
}

.search-box--with-action {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 10px;
  width: 100%;
  min-width: 0;
}

.search-box--with-action label {
  min-width: 0;
}

.inline-action,
.mini-action,
.primary-action {
  border-radius: 999px;
  cursor: pointer;
  font-weight: 700;
}

.inline-action {
  min-width: 62px;
  background: var(--rc-primary);
  color: #fff;
}

.inline-action:disabled,
.primary-action:disabled {
  cursor: not-allowed;
  opacity: 0.58;
}

.chat-row,
.work-card,
.profile-card,
.settings-row {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  border-radius: 0;
  background: var(--rc-surface);
  color: var(--rc-text-primary);
}

.chat-row {
  position: relative;
  min-height: 72px;
  padding: 12px 8px;
  cursor: pointer;
  text-align: left;
  transition: background 140ms ease, transform 140ms ease;
}

.chat-row:hover {
  background: var(--rc-surface-muted);
}

.chat-row:active {
  transform: scale(0.99);
}

.chat-row + .chat-row {
  border-top: 1px solid var(--rc-divider);
}

.chat-context-menu {
  position: fixed;
  z-index: 50;
  display: grid;
  width: 160px;
  overflow: hidden;
  border: 1px solid var(--rc-divider);
  border-radius: 8px;
  background: var(--rc-surface);
  box-shadow: 0 8px 24px rgb(0 0 0 / 16%);
}

.chat-context-menu button {
  min-height: 44px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-primary);
  font-size: 14px;
  text-align: left;
  padding: 0 14px;
}

.chat-context-menu button + button {
  border-top: 1px solid var(--rc-divider);
}

.chat-context-menu .chat-context-menu__danger {
  color: var(--rc-danger);
}

.chat-row__avatar,
.profile-card__avatar {
  width: 48px;
  height: 48px;
  flex: 0 0 auto;
}

.chat-row__body {
  min-width: 0;
  flex: 1;
}

.chat-row__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.chat-row h2,
.work-card h2,
.profile-card h2 {
  margin: 0;
  color: var(--rc-text-primary);
  font-size: 16px;
  font-weight: 600;
}

.chat-row time {
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.chat-row p,
.work-card p,
.profile-card p {
  margin: 6px 0 0;
  overflow: hidden;
  color: var(--rc-text-secondary);
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-notice,
.chat-empty {
  margin: 0;
  border-radius: 16px;
  background: var(--rc-surface);
  color: var(--rc-text-secondary);
  font-size: 13px;
  line-height: 1.5;
  padding: 12px 14px;
}

.chat-notice--error {
  background: #feeceb;
  color: var(--rc-danger);
}

.contact-section {
  display: grid;
  gap: 10px;
  min-width: 0;
  border-radius: 20px;
  background: var(--rc-surface);
  padding: 14px;
}

.contact-shortcuts {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.contact-shortcuts .work-card {
  justify-content: space-between;
  min-height: 52px;
  border-radius: 8px;
  cursor: pointer;
  padding: 0 14px;
  font-size: 14px;
  font-weight: 700;
}

.contact-shortcuts strong {
  color: var(--rc-primary);
  font-size: 18px;
}

.section-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.section-title h2 {
  margin: 0;
  color: var(--rc-text-primary);
  font-size: 16px;
  font-weight: 700;
}

.section-title span {
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.contact-row {
  display: flex;
  align-items: center;
  gap: 11px;
  min-width: 0;
  min-height: 58px;
  padding: 6px 0;
}

.contact-row + .contact-row {
  border-top: 1px solid var(--rc-divider);
}

.contact-row__avatar {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  flex: 0 0 auto;
  border-radius: 999px;
  background: var(--rc-primary-soft);
  color: var(--rc-primary-strong);
  font-weight: 700;
}

.contact-row__body {
  min-width: 0;
  flex: 1;
}

.contact-row__body h3 {
  margin: 0;
  overflow: hidden;
  color: var(--rc-text-primary);
  font-size: 15px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.contact-row__body p {
  margin: 5px 0 0;
  overflow: hidden;
  color: var(--rc-text-secondary);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.contact-row__actions {
  display: flex;
  flex: 0 0 auto;
  gap: 6px;
}

.mini-action {
  flex: 0 0 auto;
  min-width: 48px;
  height: 32px;
  background: var(--rc-primary);
  color: #fff;
  font-size: 12px;
}

.mini-action--ghost {
  background: var(--rc-surface-muted);
  color: var(--rc-text-secondary);
}

.status-pill {
  border-radius: 999px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-tertiary);
  font-size: 12px;
  padding: 5px 9px;
}

.primary-action {
  height: 42px;
  background: var(--rc-primary);
  color: #fff;
}

.badge,
.tabbar__icon em {
  display: grid;
  place-items: center;
  min-width: 18px;
  height: 18px;
  border-radius: 999px;
  background: var(--rc-danger);
  color: #fff;
  font-size: 11px;
  font-style: normal;
  font-weight: 700;
}

.work-card,
.profile-card,
.settings-row {
  min-height: 64px;
  border: 0;
  border-radius: 16px;
  padding: 14px 16px;
  text-align: left;
}

.work-card__icon {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  border-radius: 999px;
  background: var(--rc-primary);
  color: #fff;
  font-weight: 700;
}

.settings-row {
  cursor: pointer;
  justify-content: space-between;
  font-size: 15px;
}

.settings-row--danger {
  justify-content: center;
  background: #feeceb;
  color: var(--rc-danger);
  font-weight: 700;
}

.tabbar {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 10;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  width: min(100%, 430px);
  margin: 0 auto;
  padding: 8px 16px calc(8px + var(--rc-safe-bottom));
  background: var(--rc-surface);
  box-shadow: var(--rc-shadow-nav);
}

.tabbar__item {
  display: grid;
  place-items: center;
  gap: 4px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-quaternary);
  font-size: 12px;
}

.tabbar__item--active {
  color: var(--rc-primary);
  font-weight: 700;
}

.tabbar__icon {
  position: relative;
  min-width: 28px;
  height: 28px;
  font-size: 17px;
  line-height: 28px;
  text-align: center;
}

.tabbar__icon em {
  position: absolute;
  right: -12px;
  top: -5px;
}
</style>
