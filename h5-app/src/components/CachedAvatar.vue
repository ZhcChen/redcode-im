<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';

import { avatarCacheService } from '@/services/avatar-cache';
import type { CachedBlobEntry } from '@/storage/blob-cache';

const props = withDefaults(defineProps<{
  kind: 'user' | 'room';
  entityId: string;
  objectKey?: string | null;
  label?: string | null;
  size?: number;
}>(), {
  objectKey: null,
  label: '',
  size: 42,
});

const entry = ref<CachedBlobEntry | null>(null);
const failed = ref(false);

const initial = computed(() => (props.label || 'R').trim().slice(0, 1).toUpperCase() || 'R');
const sizePx = computed(() => `${props.size}px`);

const load = async () => {
  avatarCacheService.revoke(entry.value);
  entry.value = null;
  failed.value = false;
  if (!props.entityId || !props.objectKey) return;
  try {
    entry.value = props.kind === 'room'
      ? await avatarCacheService.loadRoomAvatar({ roomId: props.entityId, objectKey: props.objectKey })
      : await avatarCacheService.loadUserAvatar({ userId: props.entityId, objectKey: props.objectKey });
  } catch {
    failed.value = true;
  }
};

watch(
  () => [props.kind, props.entityId, props.objectKey],
  () => {
    void load();
  },
  { immediate: true },
);

onBeforeUnmount(() => {
  avatarCacheService.revoke(entry.value);
});
</script>

<template>
  <span class="cached-avatar" :style="{ width: sizePx, height: sizePx }" :title="label || undefined">
    <img v-if="entry && !failed" :src="entry.objectUrl" :alt="label || 'avatar'" />
    <span v-else>{{ initial }}</span>
  </span>
</template>

<style scoped>
.cached-avatar {
  display: inline-grid;
  place-items: center;
  flex: 0 0 auto;
  overflow: hidden;
  border-radius: 999px;
  background: var(--rc-primary-soft);
  color: var(--rc-primary-strong);
  font-weight: 800;
}

.cached-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
