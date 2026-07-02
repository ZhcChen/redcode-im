<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';

import { useAppShellStore, type AppTab } from '@/stores/app-shell';
import { useAuthStore } from '@/stores/auth';
import { formatChatDisplayTime, useChatStore } from '@/stores/chat';
import { useContactsStore } from '@/stores/contacts';
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
const shellStore = useAppShellStore();

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
    key: 'settings',
    label: '设置',
    icon: '⚙',
    activeIcon: '⚙',
    badge: 0,
  },
]);

const title = computed(() => {
  if (shellStore.activeTab === 'contacts') return '联系人';
  if (shellStore.activeTab === 'settings') return '设置';
  return '聊天';
});

const logout = async () => {
  chatStore.dispose();
  authStore.logout();
  await router.replace({ name: 'login' });
};

const openChat = async (roomId: string) => {
  if (!roomId) return;
  await router.push({ name: 'chat-detail', params: { roomId } });
};

const connectionLabel = computed(() => {
  if (chatStore.websocketStatus === 'authenticated') return '实时在线';
  if (chatStore.websocketStatus === 'connecting' || chatStore.websocketStatus === 'connected') {
    return '连接中';
  }
  return '离线模式';
});

const chats = computed(() => chatStore.filteredChats);
const groups = computed(() => chatStore.chats.filter((chat) => chat.type === 'group'));

const displayFriendName = (friend: FriendInfo) =>
  friend.remark?.trim() || friend.user.nickname || friend.user.email || friend.user.username || 'RedCode 用户';

const displayRequestUser = (request: FriendRequestInfo) =>
  request.requester?.nickname || request.requester?.email || request.requesterId || 'RedCode 用户';

const displayUserName = (user: AuthUser) =>
  user.nickname || user.email || user.username || 'RedCode 用户';

const initialOf = (value: string) => value.trim().slice(0, 1).toUpperCase() || 'R';

const openPrivateChat = async (friendUserId: string) => {
  const roomId = await contactsStore.openPrivateChat(friendUserId);
  if (roomId) {
    await router.push({ name: 'chat-detail', params: { roomId } });
  }
};

const createGroup = async () => {
  const roomId = await contactsStore.createGroup();
  if (roomId) {
    await router.push({ name: 'chat-detail', params: { roomId } });
  }
};

const openGroupSettings = async (roomId: string) => {
  await router.push({ name: 'group-settings', params: { roomId } });
};

onMounted(() => {
  void chatStore.initialize();
  void contactsStore.initialize();
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
            {{ authStore.currentUser?.nickname?.slice(0, 1).toUpperCase() || 'R' }}
          </div>
        </div>
      </header>

      <section v-if="shellStore.activeTab === 'chat'" class="panel panel--chat">
        <label class="search-box">
          <span class="sr-only">搜索</span>
          <input
            :value="chatStore.searchKeyword"
            class="rc-focus-ring"
            placeholder="搜索"
            @input="chatStore.setSearchKeyword(($event.target as HTMLInputElement).value)"
          />
        </label>

        <p v-if="chatStore.error" class="chat-notice chat-notice--error">{{ chatStore.error }}</p>
        <p v-else-if="chatStore.isOffline" class="chat-notice">WebSocket 未连接，正在使用本地缓存和 HTTP 刷新。</p>
        <p v-if="chatStore.refreshing && chats.length === 0" class="chat-empty">正在加载会话...</p>
        <p v-else-if="chats.length === 0" class="chat-empty">
          {{ chatStore.searchKeyword ? '没有匹配的会话' : '暂无会话，添加好友或创建群聊后会显示在这里' }}
        </p>

        <button
          v-for="chat in chats"
          :key="chat.id"
          class="chat-row"
          :class="{ 'chat-row--pinned': chat.isPinned }"
          type="button"
          @click="openChat(chat.roomId)"
        >
          <div class="chat-row__avatar">{{ chat.name.slice(0, 1) }}</div>
          <div class="chat-row__body">
            <div class="chat-row__top">
              <h2>{{ chat.name }}</h2>
              <time>{{ chat.type === 'favorite' ? '随时可用' : formatChatDisplayTime(chat.lastMessageTime) }}</time>
            </div>
            <p>{{ chat.lastMessage || (chat.type === 'favorite' ? '保存的消息和文件会出现在这里' : '暂无消息') }}</p>
          </div>
          <span v-if="chat.unreadCount" class="badge">{{ chat.unreadCount }}</span>
        </button>
      </section>

      <section v-else-if="shellStore.activeTab === 'contacts'" class="panel">
        <form class="search-box search-box--with-action" @submit.prevent="contactsStore.searchUsers()">
          <label>
            <span class="sr-only">搜索用户或联系人</span>
            <input
              :value="contactsStore.searchKeyword"
              class="rc-focus-ring"
              placeholder="搜索邮箱 / 昵称"
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
            <div class="contact-row__avatar">{{ initialOf(displayUserName(user)) }}</div>
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
            <div class="contact-row__avatar">{{ initialOf(displayRequestUser(request)) }}</div>
            <div class="contact-row__body">
              <h3>{{ displayRequestUser(request) }}</h3>
              <p>{{ request.message || '请求添加你为好友' }}</p>
            </div>
            <div v-if="request.status === 'pending'" class="contact-row__actions">
              <button class="mini-action rc-focus-ring" type="button" @click="contactsStore.respondRequest(request.id, 'accept')">
                同意
              </button>
              <button class="mini-action mini-action--ghost rc-focus-ring" type="button" @click="contactsStore.respondRequest(request.id, 'reject')">
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
          <p v-else-if="contactsStore.filteredFriends.length === 0" class="chat-empty">暂无联系人，搜索邮箱添加好友。</p>
          <article v-for="friend in contactsStore.filteredFriends" :key="friend.user.id" class="contact-row">
            <div class="contact-row__avatar">{{ initialOf(displayFriendName(friend)) }}</div>
            <div class="contact-row__body">
              <h3>{{ displayFriendName(friend) }}</h3>
              <p>{{ friend.user.email || friend.user.username }}</p>
            </div>
            <button class="mini-action rc-focus-ring" type="button" @click="openPrivateChat(friend.user.id)">
              私聊
            </button>
          </article>
        </section>

        <section class="contact-section">
          <div class="section-title">
            <h2>新建群聊</h2>
            <span>{{ contactsStore.selectedFriendIds.length }} 人已选</span>
          </div>
          <input
            v-model="contactsStore.groupName"
            class="group-input rc-focus-ring"
            placeholder="群名称"
          />
          <div class="group-picker">
            <button
              v-for="friend in contactsStore.friends"
              :key="friend.user.id"
              class="group-chip rc-focus-ring"
              :class="{ 'group-chip--active': contactsStore.selectedFriendIds.includes(friend.user.id) }"
              type="button"
              @click="contactsStore.toggleGroupMember(friend.user.id)"
            >
              {{ displayFriendName(friend) }}
            </button>
          </div>
          <button
            class="primary-action rc-focus-ring"
            type="button"
            :disabled="contactsStore.submitting || !contactsStore.groupName.trim() || contactsStore.selectedFriendIds.length === 0"
            @click="createGroup"
          >
            创建群聊
          </button>
        </section>

        <section v-if="groups.length" class="contact-section">
          <div class="section-title">
            <h2>群聊</h2>
            <span>{{ groups.length }} 个</span>
          </div>
          <article v-for="group in groups" :key="group.roomId" class="contact-row">
            <div class="contact-row__avatar">群</div>
            <div class="contact-row__body">
              <h3>{{ group.name }}</h3>
              <p>{{ group.lastMessage || '暂无消息' }}</p>
            </div>
            <button class="mini-action mini-action--ghost rc-focus-ring" type="button" @click="openGroupSettings(group.roomId)">
              设置
            </button>
          </article>
        </section>
      </section>

      <section v-else class="panel">
        <article class="profile-card">
          <div class="profile-card__avatar">
            {{ authStore.currentUser?.nickname?.slice(0, 1).toUpperCase() || 'R' }}
          </div>
          <div>
            <h2>{{ authStore.currentUser?.nickname || 'RedCode 用户' }}</h2>
            <p>{{ authStore.currentUser?.email }}</p>
          </div>
        </article>

        <button class="settings-row rc-focus-ring" type="button">
          <span>账号安全</span>
          <strong>›</strong>
        </button>
        <button class="settings-row rc-focus-ring" type="button">
          <span>隐私协议</span>
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

.search-box input {
  width: 100%;
  height: 44px;
  border: 0;
  border-radius: 44px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-primary);
  padding: 0 18px;
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
  gap: 6px;
}

.mini-action {
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

.group-input {
  width: 100%;
  height: 42px;
  border: 0;
  border-radius: 14px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-primary);
  padding: 0 12px;
}

.group-picker {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.group-chip {
  border-radius: 999px;
  cursor: pointer;
  background: var(--rc-surface-muted);
  color: var(--rc-text-secondary);
  font-size: 13px;
  padding: 7px 10px;
}

.group-chip--active {
  background: var(--rc-primary-soft);
  color: var(--rc-primary-strong);
  font-weight: 700;
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
