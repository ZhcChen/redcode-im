<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';

import { useSettingsStore } from '@/stores/settings';

const router = useRouter();
const store = useSettingsStore();

const goBack = async () => {
  await router.push({ name: 'home' });
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
        <p>个人资料</p>
        <h1>{{ store.displayName }}</h1>
      </div>
    </header>

    <section class="settings-content">
      <p v-if="store.error" class="settings-notice settings-notice--error">{{ store.error }}</p>
      <p v-if="store.notice" class="settings-notice">{{ store.notice }}</p>

      <section class="settings-card settings-card--center">
        <div class="profile-avatar">{{ store.avatarInitial }}</div>
        <p class="settings-muted">头像上传将在媒体缓存单元接入浏览器文件能力。</p>
      </section>

      <form class="settings-card" @submit.prevent="store.updateNickname">
        <label class="settings-field">
          <span>昵称</span>
          <input v-model="store.nicknameDraft" class="rc-focus-ring" maxlength="20" placeholder="输入昵称" />
        </label>
        <label class="settings-field">
          <span>邮箱</span>
          <input :value="store.user?.email" disabled />
        </label>
        <button class="settings-primary rc-focus-ring" type="submit" :disabled="store.submitting || !store.nicknameDraft.trim()">
          保存资料
        </button>
      </form>
    </section>
  </main>
</template>

<style scoped>
.settings-page {
  min-height: 100dvh;
  background: var(--rc-background);
}

.settings-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: calc(var(--rc-safe-top) + 10px) 16px 14px;
  background: var(--rc-surface);
  box-shadow: 0 1px 0 var(--rc-divider);
}

.settings-back {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 999px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-primary);
  font-size: 34px;
  line-height: 1;
}

.settings-header p,
.settings-muted {
  margin: 0;
  color: var(--rc-text-tertiary);
  font-size: 12px;
}

.settings-header h1 {
  margin: 3px 0 0;
  color: var(--rc-text-primary);
  font-size: 19px;
}

.settings-content {
  display: grid;
  gap: 12px;
  padding: 16px;
}

.settings-card {
  display: grid;
  gap: 14px;
  border-radius: 20px;
  background: var(--rc-surface);
  padding: 16px;
}

.settings-card--center {
  justify-items: center;
  text-align: center;
}

.profile-avatar {
  display: grid;
  place-items: center;
  width: 92px;
  height: 92px;
  border-radius: 999px;
  background: linear-gradient(180deg, #00db4d 0%, #00c27b 100%);
  color: #fff;
  font-size: 34px;
  font-weight: 800;
}

.settings-field {
  display: grid;
  gap: 8px;
  color: var(--rc-text-secondary);
  font-size: 13px;
}

.settings-field input {
  height: 42px;
  border: 0;
  border-radius: 14px;
  background: var(--rc-surface-muted);
  color: var(--rc-text-primary);
  padding: 0 12px;
}

.settings-primary {
  height: 42px;
  border-radius: 14px;
  cursor: pointer;
  background: var(--rc-primary);
  color: #fff;
  font-weight: 700;
}

.settings-primary:disabled {
  cursor: not-allowed;
  opacity: 0.58;
}

.settings-notice {
  margin: 0;
  border-radius: 14px;
  background: var(--rc-surface);
  color: var(--rc-text-secondary);
  font-size: 13px;
  padding: 12px;
}

.settings-notice--error {
  background: #feeceb;
  color: var(--rc-danger);
}
</style>
