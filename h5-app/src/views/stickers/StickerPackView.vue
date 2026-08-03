<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import CachedSticker from '@/components/CachedSticker.vue';
import { appEnv } from '@/config/env';
import { stickerService } from '@/services/sticker-service';
import type { StickerPack } from '@/types/sticker';

const route = useRoute(); const router = useRouter(); const packId = computed(() => String(route.params.packId ?? ''));
const pack = ref<StickerPack | null>(null); const children = ref<StickerPack[]>([]); const loading = ref(false); const notice = ref(''); const error = ref('');
const load = async () => { loading.value = true; error.value = ''; try { if (appEnv.useMockData) { pack.value = { id: packId.value, name: '工作日常', iconUrl: null, iconObjectKey: null, description: '常用工作贴纸', packType: 'suite', items: [] }; children.value = []; return; } pack.value = await stickerService.findAvailable(packId.value) ?? (await stickerService.listMine()).find((item) => item.id === packId.value) ?? null; if (pack.value?.packType === 'suite') { try { children.value = await stickerService.listSuiteItems(packId.value); } catch { children.value = []; } } } catch (cause) { error.value = cause instanceof Error ? cause.message : '加载贴纸详情失败'; } finally { loading.value = false; } };
const add = async () => { if (!pack.value) return; try { const count = appEnv.useMockData ? 3 : await stickerService.add(pack.value); notice.value = pack.value.packType === 'suite' ? `已添加 ${count} 个贴纸` : '贴纸已添加'; await load(); } catch (cause) { error.value = cause instanceof Error ? cause.message : '添加贴纸失败'; } };
onMounted(() => void load());
</script>

<template><main class="contact-page app-phone-frame"><header class="contact-page__header"><button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.back()">‹</button><div><h1>贴纸详情</h1><p>{{ pack?.packType === 'suite' ? '贴纸包' : '单个贴纸' }}</p></div></header><section class="contact-page__content"><p v-if="notice" class="contact-page__notice">{{ notice }}</p><p v-if="error" class="contact-page__notice contact-page__notice--error">{{ error }}</p><p v-if="loading" class="contact-page__empty">正在加载...</p><template v-else-if="pack"><section class="pack-hero"><CachedSticker :object-key="pack.iconObjectKey" :image-url="pack.iconUrl" :label="pack.name" /><div><h2>{{ pack.name }}</h2><p>{{ pack.description || '暂无介绍' }}</p></div><button class="contact-page__primary rc-focus-ring" type="button" @click="add">添加</button></section><section v-if="children.length || pack.items.length" class="sticker-grid"><template v-for="child in children.length ? children : [pack]" :key="child.id"><CachedSticker v-for="item in child.items" :key="item.id" :object-key="item.imageObjectKey" :image-url="item.imageUrl" :label="item.name || child.name" /></template></section><p v-else class="contact-page__empty">添加贴纸包后可查看全部内容</p></template><p v-else class="contact-page__empty">贴纸不存在或已下架</p></section></main></template>

<style scoped>
.pack-hero { display: grid; grid-template-columns: auto minmax(0, 1fr) auto; align-items: center; gap: 12px; }.pack-hero h2, .pack-hero p { margin: 0; }.pack-hero h2 { font-size: 17px; }.pack-hero p { margin-top: 6px; color: var(--rc-text-tertiary); font-size: 12px; }.sticker-grid { display: grid; grid-template-columns: repeat(4, 52px); justify-content: space-between; gap: 14px; }
</style>
