<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import CachedSticker from '@/components/CachedSticker.vue';
import { appEnv } from '@/config/env';
import { stickerService } from '@/services/sticker-service';
import type { StickerPack } from '@/types/sticker';

const router = useRouter();
const packs = ref<StickerPack[]>([]);
const keyword = ref('');
const loading = ref(false);
const notice = ref('');
const error = ref('');

const load = async () => {
  loading.value = true; error.value = '';
  try { packs.value = appEnv.useMockData ? mockPacks().filter((pack) => pack.name.includes(keyword.value.trim())) : await stickerService.listAvailable(keyword.value); }
  catch (cause) { error.value = cause instanceof Error ? cause.message : '加载贴纸商店失败'; }
  finally { loading.value = false; }
};
const add = async (pack: StickerPack) => {
  try { const count = appEnv.useMockData ? 3 : await stickerService.add(pack); notice.value = pack.packType === 'suite' ? `已添加 ${count} 个贴纸` : '贴纸已添加'; }
  catch (cause) { error.value = cause instanceof Error ? cause.message : '添加贴纸失败'; }
};
onMounted(() => void load());
const mockPacks = (): StickerPack[] => [{ id: 'suite-1', name: '工作日常', iconUrl: null, iconObjectKey: null, description: '常用工作贴纸', packType: 'suite', items: [] }];
</script>

<template><main class="contact-page app-phone-frame"><header class="contact-page__header"><button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'stickers' })">‹</button><div><h1>贴纸商店</h1><p>查找贴纸与贴纸包</p></div></header><section class="contact-page__content"><form class="store-search" @submit.prevent="load"><input v-model="keyword" class="rc-focus-ring" placeholder="搜索贴纸" /><button class="contact-page__primary rc-focus-ring" type="submit">搜索</button></form><p v-if="notice" class="contact-page__notice">{{ notice }}</p><p v-if="error" class="contact-page__notice contact-page__notice--error">{{ error }}</p><p v-if="loading" class="contact-page__empty">正在加载...</p><p v-else-if="packs.length === 0" class="contact-page__empty">没有匹配的贴纸</p><article v-for="pack in packs" :key="pack.id" class="store-row"><button class="store-row__main rc-focus-ring" type="button" @click="router.push({ name: 'sticker-pack', params: { packId: pack.id } })"><CachedSticker :object-key="pack.iconObjectKey" :image-url="pack.iconUrl" :label="pack.name" /><span><h2>{{ pack.name }}</h2><p>{{ pack.description || (pack.packType === 'suite' ? '贴纸包' : '单个贴纸') }}</p></span></button><button class="contact-page__primary rc-focus-ring" type="button" @click="add(pack)">添加</button></article></section></main></template>

<style scoped>
.store-search { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 10px; }.store-search input { min-width: 0; height: 42px; border: 0; border-radius: 8px; background: var(--rc-surface-muted); padding: 0 12px; }
.store-row { display: flex; align-items: center; gap: 10px; min-height: 70px; border-bottom: 1px solid var(--rc-divider); }.store-row__main { display: flex; align-items: center; gap: 12px; min-width: 0; flex: 1; background: transparent; text-align: left; }.store-row h2, .store-row p { margin: 0; }.store-row h2 { font-size: 15px; }.store-row p { margin-top: 5px; color: var(--rc-text-tertiary); font-size: 12px; }
</style>
