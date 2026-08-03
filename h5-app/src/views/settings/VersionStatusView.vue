<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';

import { useSettingsStore } from '@/stores/settings';
import { appVersion } from '@/config/version';

const router = useRouter();
const store = useSettingsStore();
const statusLabel = computed(() => {
  if (store.loading) return '正在检查';
  if (store.error) return '检查失败';
  if (store.versionStatus?.hasUpdate) return store.versionStatus.mandatory ? '有重要更新' : '有可用更新';
  if (!store.versionStatus?.latestVersion) return '暂无该平台发布记录';
  return '已是最新版本';
});

onMounted(() => void store.checkVersion());
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header"><button class="settings-back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'about' })">‹</button><div><p>关于</p><h1>版本状态</h1></div></header>
    <section class="settings-content">
      <p v-if="store.error" class="settings-notice settings-notice--error">{{ store.error }}</p>
      <section class="settings-card version-summary"><div class="version-logo">R</div><div><p>当前 H5 版本</p><h2>{{ store.versionStatus?.currentVersion || appVersion }}</h2></div><strong>{{ statusLabel }}</strong></section>
      <section v-if="store.versionStatus?.latestVersion" class="settings-card"><div class="version-field"><span>设备平台</span><strong>{{ store.versionStatus.platform }}</strong></div><div class="version-field"><span>客户端最新版本</span><strong>{{ store.versionStatus.latestVersion }}</strong></div><p v-if="store.versionStatus.releaseNotes" class="release-notes">{{ store.versionStatus.releaseNotes }}</p></section>
      <section class="settings-card"><p class="web-notice">H5 会自动随站点发布更新。此处仅展示当前设备平台的客户端版本，不在浏览器内下载或安装原生应用。</p><button class="settings-primary rc-focus-ring" type="button" :disabled="store.loading" @click="store.checkVersion">重新检查</button></section>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';
.version-summary { grid-template-columns: auto minmax(0, 1fr) auto; align-items: center; }
.version-logo { display: grid; place-items: center; width: 52px; height: 52px; border-radius: 8px; background: var(--rc-primary); color: #fff; font-size: 24px; font-weight: 800; }
.version-summary p, .version-summary h2, .release-notes, .web-notice { margin: 0; }
.version-summary p { color: var(--rc-text-tertiary); font-size: 12px; }
.version-summary h2 { margin-top: 4px; font-size: 18px; }
.version-summary > strong { color: var(--rc-primary-strong); font-size: 12px; }
.version-field { display: flex; justify-content: space-between; gap: 12px; color: var(--rc-text-secondary); font-size: 14px; }
.version-field strong { color: var(--rc-text-primary); }
.release-notes, .web-notice { color: var(--rc-text-secondary); font-size: 13px; line-height: 1.6; }
</style>
