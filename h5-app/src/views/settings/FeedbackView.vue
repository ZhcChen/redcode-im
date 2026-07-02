<script setup lang="ts">
import { useRouter } from 'vue-router';

import { useSettingsStore } from '@/stores/settings';

const router = useRouter();
const store = useSettingsStore();

const goBack = async () => {
  await router.push({ name: 'about' });
};
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header">
      <button class="settings-back rc-focus-ring" type="button" @click="goBack">‹</button>
      <div>
        <p>意见反馈</p>
        <h1>告诉我们你的想法</h1>
      </div>
    </header>

    <section class="settings-content">
      <p v-if="store.error" class="settings-notice settings-notice--error">{{ store.error }}</p>
      <p v-if="store.notice" class="settings-notice">{{ store.notice }}</p>

      <form class="settings-card" @submit.prevent="store.submitFeedback">
        <label class="settings-field">
          <span>反馈内容</span>
          <textarea v-model="store.feedbackContent" class="rc-focus-ring" placeholder="请输入问题、建议或复现步骤" />
        </label>
        <label class="settings-field">
          <span>联系方式（选填）</span>
          <input v-model="store.feedbackContact" class="rc-focus-ring" placeholder="邮箱 / 电话 / IM" />
        </label>
        <button class="settings-primary rc-focus-ring" type="submit" :disabled="store.submitting || !store.feedbackContent.trim()">
          提交反馈
        </button>
      </form>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';
</style>
