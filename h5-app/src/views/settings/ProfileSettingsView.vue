<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import CachedAvatar from '@/components/CachedAvatar.vue';
import { useSettingsStore } from '@/stores/settings';

const router = useRouter();
const store = useSettingsStore();
const avatarInput = ref<HTMLInputElement | null>(null);

const goBack = async () => {
  await router.push({ name: 'home' });
};

const chooseAvatar = () => {
  avatarInput.value?.click();
};

const handleAvatarSelected = async (event: Event) => {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0] ?? null;
  input.value = '';
  try {
    await store.uploadAvatar(file);
  } catch {
    // Store state already contains the user-facing error.
  }
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
        <CachedAvatar
          v-if="store.user"
          class="profile-avatar"
          kind="user"
          :entity-id="store.user.id"
          :object-key="store.user.avatarObjectKey"
          :label="store.displayName"
          :size="92"
        />
        <input ref="avatarInput" class="sr-only" type="file" accept="image/*" @change="handleAvatarSelected" />
        <button class="avatar-upload-button rc-focus-ring" type="button" :disabled="store.avatarUploading" @click="chooseAvatar">
          {{ store.avatarUploading ? '上传中...' : '更换头像' }}
        </button>
        <p class="settings-muted">支持 PNG、JPG、WebP 等图片，上传失败会保留当前头像。</p>
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

.avatar-upload-button {
  min-width: 110px;
  height: 38px;
  border-radius: 999px;
  cursor: pointer;
  background: var(--rc-primary);
  color: #fff;
  font-weight: 700;
}

.avatar-upload-button:disabled {
  cursor: not-allowed;
  opacity: 0.58;
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
