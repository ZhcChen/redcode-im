<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';

import { useSettingsStore } from '@/stores/settings';

const router = useRouter();
const store = useSettingsStore();

const goBack = async () => {
  await router.push({ name: 'settings' });
};

onMounted(() => {
  void store.initialize();
});
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header">
      <button class="settings-back rc-focus-ring" type="button" @click="goBack">‹</button>
      <div>
        <p>账号与安全</p>
        <h1>{{ store.user?.email || 'RedCode 用户' }}</h1>
      </div>
    </header>

    <section class="settings-content">
      <p v-if="store.error" class="settings-notice settings-notice--error">{{ store.error }}</p>
      <p v-if="store.notice" class="settings-notice">{{ store.notice }}</p>

      <form class="settings-card" @submit.prevent="store.changePassword">
        <label class="settings-field">
          <span>当前密码</span>
          <input v-model="store.oldPassword" class="rc-focus-ring" type="password" autocomplete="current-password" />
        </label>
        <label class="settings-field">
          <span>新密码</span>
          <input v-model="store.newPassword" class="rc-focus-ring" type="password" autocomplete="new-password" />
        </label>
        <button
          class="settings-primary rc-focus-ring"
          type="submit"
          :disabled="store.submitting || !store.oldPassword || !store.newPassword"
        >
          修改密码
        </button>
      </form>
      <section class="settings-card">
        <button class="settings-danger rc-focus-ring" type="button" @click="router.push({ name: 'settings-deactivate' })">注销账号</button>
      </section>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';
.settings-danger { min-height: 42px; border-radius: 8px; cursor: pointer; background: transparent; color: var(--rc-danger); font-weight: 700; }
</style>
