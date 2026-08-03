<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';

import { chatSettingsService, type ChatBackground } from '@/services/chat-settings-service';

const router = useRouter();
const background = ref(chatSettingsService.getBackground());
const clearing = ref(false);
const confirming = ref(false);
const notice = ref('');
const options: Array<{ value: ChatBackground; label: string }> = [
  { value: 'default', label: '默认' },
  { value: 'mint', label: '浅绿' },
  { value: 'gray', label: '浅灰' },
];

const selectBackground = (value: ChatBackground) => {
  background.value = value;
  chatSettingsService.setBackground(value);
  notice.value = '聊天背景已更新';
};

const clearCache = async () => {
  clearing.value = true;
  notice.value = '';
  try {
    await chatSettingsService.clearLocalCache();
    confirming.value = false;
    notice.value = '本地缓存已清理';
  } finally {
    clearing.value = false;
  }
};
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header"><button class="settings-back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'settings' })">‹</button><div><p>设置</p><h1>聊天设置</h1></div></header>
    <section class="settings-content">
      <p v-if="notice" class="settings-notice">{{ notice }}</p>
      <section class="settings-card"><h2>聊天背景</h2><div class="background-options"><button v-for="option in options" :key="option.value" class="background-option rc-focus-ring" :class="[`background-option--${option.value}`, { active: background === option.value }]" type="button" @click="selectBackground(option.value)"><span aria-hidden="true" /><strong>{{ option.label }}</strong></button></div></section>
      <section class="settings-card"><h2>本地存储</h2><p class="settings-muted">清理消息索引和媒体缓存，不影响服务端聊天记录。</p><button v-if="!confirming" class="settings-secondary rc-focus-ring" type="button" @click="confirming = true">清理本地缓存</button><div v-else class="confirm-actions"><button class="settings-danger rc-focus-ring" type="button" :disabled="clearing" @click="clearCache">{{ clearing ? '清理中...' : '确认清理' }}</button><button class="settings-secondary rc-focus-ring" type="button" :disabled="clearing" @click="confirming = false">取消</button></div></section>
      <section class="settings-card"><h2>贴纸</h2><p class="settings-muted">管理已添加贴纸，或从贴纸商店添加新内容。</p><button class="settings-secondary rc-focus-ring" type="button" @click="router.push({ name: 'stickers' })">管理贴纸</button></section>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';
.settings-card h2 { margin: 0; font-size: 16px; }
.background-options { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }
.background-option { display: grid; gap: 7px; cursor: pointer; background: transparent; color: var(--rc-text-secondary); font-size: 12px; }
.background-option span { display: block; height: 48px; border: 2px solid transparent; border-radius: 8px; background: var(--rc-background); }
.background-option--mint span { background: #eaf8ef; }
.background-option--gray span { background: #eceff1; }
.background-option.active span { border-color: var(--rc-primary); }
.confirm-actions { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.settings-secondary, .settings-danger { min-height: 42px; border-radius: 8px; cursor: pointer; }
.settings-secondary { background: var(--rc-surface-muted); color: var(--rc-text-primary); }
.settings-danger { background: var(--rc-danger); color: #fff; }
</style>
