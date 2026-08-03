<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import CachedSticker from '@/components/CachedSticker.vue';
import { appEnv } from '@/config/env';
import { stickerService } from '@/services/sticker-service';
import type { StickerPack } from '@/types/sticker';

const router = useRouter();
const packs = ref<StickerPack[]>([]);
const loading = ref(false);
const error = ref('');
const confirming = ref('');

const load = async () => {
  loading.value = true;
  error.value = '';
  try { packs.value = appEnv.useMockData ? mockPacks() : await stickerService.listMine(); }
  catch (cause) { error.value = cause instanceof Error ? cause.message : '加载贴纸失败'; }
  finally { loading.value = false; }
};

const remove = async (packId: string) => {
  try {
    if (!appEnv.useMockData) await stickerService.remove(packId);
    packs.value = packs.value.filter((pack) => pack.id !== packId);
    confirming.value = '';
  } catch (cause) { error.value = cause instanceof Error ? cause.message : '移除贴纸失败'; }
};

onMounted(() => void load());

const mockPacks = (): StickerPack[] => [{ id: 'suite-1', name: '工作日常', iconUrl: null, iconObjectKey: null, description: '常用工作贴纸', packType: 'suite', items: [] }];
</script>

<template>
  <main class="contact-page app-phone-frame"><header class="contact-page__header"><button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'chat-settings' })">‹</button><div><h1>我的贴纸</h1><p>{{ packs.length }} 个</p></div><button class="contact-page__action rc-focus-ring" type="button" @click="router.push({ name: 'sticker-store' })">商店</button></header><section class="contact-page__content"><p v-if="error" class="contact-page__notice contact-page__notice--error">{{ error }}</p><p v-if="loading" class="contact-page__empty">正在加载贴纸...</p><p v-else-if="packs.length === 0" class="contact-page__empty">暂无贴纸</p><article v-for="pack in packs" :key="pack.id" class="sticker-row"><button class="sticker-row__main rc-focus-ring" type="button" @click="router.push({ name: 'sticker-pack', params: { packId: pack.id } })"><CachedSticker :object-key="pack.iconObjectKey" :image-url="pack.iconUrl" :label="pack.name" /><span><h2>{{ pack.name }}</h2><p>{{ pack.packType === 'suite' ? '贴纸包' : `${pack.items.length} 个表情` }}</p></span></button><button v-if="confirming !== pack.id" class="contact-page__action rc-focus-ring" type="button" @click="confirming = pack.id">移除</button><button v-else class="contact-page__action contact-page__danger rc-focus-ring" type="button" @click="remove(pack.id)">确认</button></article></section></main>
</template>

<style scoped>
.sticker-row { display: flex; align-items: center; gap: 10px; min-height: 68px; border-bottom: 1px solid var(--rc-divider); }
.sticker-row__main { display: flex; align-items: center; gap: 12px; min-width: 0; flex: 1; background: transparent; text-align: left; }
.sticker-row h2, .sticker-row p { margin: 0; }
.sticker-row h2 { font-size: 15px; }.sticker-row p { margin-top: 5px; color: var(--rc-text-tertiary); font-size: 12px; }
</style>
