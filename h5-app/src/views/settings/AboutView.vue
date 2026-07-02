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
        <p>关于</p>
        <h1>{{ store.general?.appName || 'RedCode IM' }}</h1>
      </div>
    </header>

    <section class="settings-content">
      <section class="settings-card about-hero">
        <div class="about-logo">R</div>
        <h2>{{ store.general?.appName || 'RedCode IM' }}</h2>
        <p>H5 App · Version 0.1.0</p>
      </section>

      <section class="settings-card">
        <button class="about-row rc-focus-ring" type="button" @click="router.push({ name: 'feedback' })">
          <span>意见反馈</span>
          <strong>›</strong>
        </button>
        <button class="about-row rc-focus-ring" type="button">
          <span>消息存储模式</span>
          <strong>{{ store.general?.messageRuntime.serverStorageMode || 'persist' }}</strong>
        </button>
        <button class="about-row rc-focus-ring" type="button">
          <span>内容审计模式</span>
          <strong>{{ store.general?.messageRuntime.contentAuditMode || 'plaintext' }}</strong>
        </button>
      </section>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';

.about-hero {
  justify-items: center;
  text-align: center;
}

.about-logo {
  display: grid;
  place-items: center;
  width: 82px;
  height: 82px;
  border-radius: 24px;
  background: linear-gradient(180deg, #00db4d 0%, #00c27b 100%);
  color: #fff;
  font-size: 38px;
  font-weight: 900;
}

.about-hero h2 {
  margin: 0;
  color: var(--rc-text-primary);
  font-size: 20px;
}

.about-hero p {
  margin: 0;
  color: var(--rc-text-tertiary);
  font-size: 13px;
}

.about-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 42px;
  cursor: pointer;
  background: transparent;
  color: var(--rc-text-primary);
  font-size: 15px;
}

.about-row strong {
  color: var(--rc-text-tertiary);
  font-size: 13px;
}
</style>
