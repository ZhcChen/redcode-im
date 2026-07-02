<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';

import { useAppShellStore, type AppTab } from '@/stores/app-shell';
import { useAuthStore } from '@/stores/auth';

interface ChatPreview {
  id: string;
  name: string;
  message: string;
  time: string;
  unread?: number;
  pinned?: boolean;
}

interface NavItem {
  key: AppTab;
  label: string;
  icon: string;
  activeIcon: string;
  badge: number;
}

const router = useRouter();
const authStore = useAuthStore();
const shellStore = useAppShellStore();

const chats: ChatPreview[] = [
  {
    id: 'favorite',
    name: '收藏',
    message: '保存的消息和文件会出现在这里',
    time: '09:30',
    pinned: true,
  },
  {
    id: 'team',
    name: 'RedCode IM 项目组',
    message: 'H5 App 已接入邮箱注册和登录流程',
    time: '刚刚',
    unread: 2,
  },
  {
    id: 'design',
    name: '产品体验',
    message: '样式基线复用 Flutter 移动端视觉语言',
    time: '昨天',
  },
];

const navItems = computed<NavItem[]>(() => [
  {
    key: 'chat',
    label: '聊天',
    icon: '···',
    activeIcon: '●●●',
    badge: shellStore.unreadMessages,
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
  authStore.logout();
  await router.replace({ name: 'login' });
};
</script>

<template>
  <main class="home-page app-phone-frame">
    <section class="home-page__content">
      <header class="home-header">
        <div>
          <p>RedCode IM</p>
          <h1>{{ title }}</h1>
        </div>
        <div class="home-header__avatar" aria-label="当前用户">
          {{ authStore.currentUser?.nickname?.slice(0, 1).toUpperCase() || 'R' }}
        </div>
      </header>

      <section v-if="shellStore.activeTab === 'chat'" class="panel panel--chat">
        <label class="search-box">
          <span class="sr-only">搜索</span>
          <input class="rc-focus-ring" placeholder="搜索" />
        </label>

        <article
          v-for="chat in chats"
          :key="chat.id"
          class="chat-row"
          :class="{ 'chat-row--pinned': chat.pinned }"
        >
          <div class="chat-row__avatar">{{ chat.name.slice(0, 1) }}</div>
          <div class="chat-row__body">
            <div class="chat-row__top">
              <h2>{{ chat.name }}</h2>
              <time>{{ chat.time }}</time>
            </div>
            <p>{{ chat.message }}</p>
          </div>
          <span v-if="chat.unread" class="badge">{{ chat.unread }}</span>
        </article>
      </section>

      <section v-else-if="shellStore.activeTab === 'contacts'" class="panel">
        <article class="work-card">
          <div class="work-card__icon">+</div>
          <div>
            <h2>新的朋友</h2>
            <p>{{ shellStore.pendingFriends }} 条待处理好友请求</p>
          </div>
        </article>
        <article class="work-card">
          <div class="work-card__icon">群</div>
          <div>
            <h2>群聊</h2>
            <p>查看已加入的群组和成员</p>
          </div>
        </article>
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

.panel {
  display: grid;
  gap: 12px;
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
