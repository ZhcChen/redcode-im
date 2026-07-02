<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { useSettingsStore } from '@/stores/settings';

const route = useRoute();
const router = useRouter();
const store = useSettingsStore();

const kind = computed(() => (route.name === 'user-agreement' ? 'agreement' : 'privacy'));
const document = computed(() => (kind.value === 'privacy' ? store.privacyPolicy : store.userAgreement));
const title = computed(() => document.value?.title || (kind.value === 'privacy' ? '隐私协议' : '用户协议'));
const contentText = computed(() => htmlToText(document.value?.content || '暂无内容'));

const goBack = async () => {
  await router.push({ name: 'home' });
};

onMounted(() => {
  void store.loadDocument(kind.value);
});

const htmlToText = (value: string) =>
  value
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .trim();
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header">
      <button class="settings-back rc-focus-ring" type="button" @click="goBack">‹</button>
      <div>
        <p>{{ kind === 'privacy' ? 'Privacy' : 'Terms' }}</p>
        <h1>{{ title }}</h1>
      </div>
    </header>

    <section class="settings-content">
      <p v-if="store.error" class="settings-notice settings-notice--error">{{ store.error }}</p>
      <p v-if="store.loading" class="settings-notice">正在加载内容...</p>
      <article v-else class="settings-card document-card">
        <h2>{{ title }}</h2>
        <p v-if="document?.updatedAt" class="settings-muted">更新于 {{ document.updatedAt }}</p>
        <pre>{{ contentText }}</pre>
      </article>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';

.document-card h2 {
  margin: 0;
  color: var(--rc-text-primary);
  font-size: 20px;
}

.document-card pre {
  margin: 0;
  color: var(--rc-text-primary);
  font-family: inherit;
  font-size: 15px;
  line-height: 1.65;
  white-space: pre-wrap;
}
</style>
