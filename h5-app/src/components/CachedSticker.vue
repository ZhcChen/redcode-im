<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue';

import { emojiCacheService } from '@/services/emoji-cache';
import type { CachedBlobEntry } from '@/storage/blob-cache';

const props = defineProps<{ objectKey?: string | null; imageUrl?: string | null; label: string }>();
const entry = ref<CachedBlobEntry | null>(null);

watch(() => [props.objectKey, props.imageUrl], async () => {
  emojiCacheService.revoke(entry.value);
  entry.value = await emojiCacheService.loadEmoji({ objectKey: props.objectKey, imageUrl: props.imageUrl });
}, { immediate: true });

onBeforeUnmount(() => emojiCacheService.revoke(entry.value));
</script>

<template><span class="cached-sticker"><img v-if="entry" :src="entry.objectUrl" :alt="label" /><span v-else>{{ label.slice(0, 1) }}</span></span></template>

<style scoped>
.cached-sticker { display: grid; place-items: center; width: 52px; height: 52px; overflow: hidden; border-radius: 8px; background: var(--rc-surface-muted); color: var(--rc-text-tertiary); font-weight: 700; }
.cached-sticker img { width: 100%; height: 100%; object-fit: contain; }
</style>
