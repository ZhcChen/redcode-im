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
const supportedSizes = new Set([34, 38, 42, 44, 46, 48, 72, 84, 92]);

const initial = computed(() => (props.label || 'R').trim().slice(0, 1).toUpperCase() || 'R');
const sizeClass = computed(() => `cached-avatar--${supportedSizes.has(props.size) ? props.size : 42}`);

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
  <span class="cached-avatar" :class="sizeClass" :title="label || undefined">
    <img v-if="entry && !failed" :src="entry.objectUrl" :alt="label || 'avatar'" @error="failed = true" />
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

.cached-avatar--34 {
  width: 34px;
  height: 34px;
}

.cached-avatar--38 {
  width: 38px;
  height: 38px;
}

.cached-avatar--42 {
  width: 42px;
  height: 42px;
}

.cached-avatar--44 {
  width: 44px;
  height: 44px;
}

.cached-avatar--46 {
  width: 46px;
  height: 46px;
}

.cached-avatar--48 {
  width: 48px;
  height: 48px;
}

.cached-avatar--72 {
  width: 72px;
  height: 72px;
}

.cached-avatar--84 {
  width: 84px;
  height: 84px;
}

.cached-avatar--92 {
  width: 92px;
  height: 92px;
}
</style>
