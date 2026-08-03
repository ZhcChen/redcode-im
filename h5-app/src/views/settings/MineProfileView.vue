<script setup lang="ts">
import { useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();
const auth = useAuthStore();
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header">
      <button class="settings-back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'home' })">‹</button>
      <div><p>我的</p><h1>个人资料</h1></div>
    </header>
    <section class="settings-content">
      <section class="settings-card mine-profile">
        <CachedAvatar v-if="auth.currentUser" kind="user" :entity-id="auth.currentUser.id" :object-key="auth.currentUser.avatarObjectKey" :label="auth.currentUser.nickname || auth.currentUser.email" :size="84" />
        <div><h2>{{ auth.currentUser?.nickname || 'RedCode 用户' }}</h2><p>{{ auth.currentUser?.email || auth.currentUser?.username }}</p></div>
      </section>
      <section class="settings-card">
        <div class="profile-field"><span>账号</span><strong>{{ auth.currentUser?.username || '未设置' }}</strong></div>
        <div class="profile-field"><span>用户 ID</span><strong>{{ auth.currentUser?.id || '未知' }}</strong></div>
        <button class="settings-primary rc-focus-ring" type="button" @click="router.push({ name: 'profile-settings' })">编辑个人资料</button>
      </section>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';
.mine-profile { grid-template-columns: auto minmax(0, 1fr); align-items: center; }
.mine-profile h2, .mine-profile p { margin: 0; }
.mine-profile h2 { font-size: 19px; }
.mine-profile p { margin-top: 6px; color: var(--rc-text-tertiary); font-size: 13px; }
.profile-field { display: flex; align-items: center; justify-content: space-between; gap: 16px; min-height: 38px; color: var(--rc-text-secondary); font-size: 14px; }
.profile-field strong { overflow: hidden; color: var(--rc-text-primary); font-size: 13px; text-overflow: ellipsis; white-space: nowrap; }
</style>
