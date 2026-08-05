<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue';

import type { E2eeAttachmentPart } from '@/e2ee/attachment-crypto';
import { attachmentCacheService } from '@/services/attachment-cache';
import type { CachedBlobEntry } from '@/storage/blob-cache';
import type { MessageAttachment } from '@/types/chat';

const props = defineProps<{
  roomId: string;
  attachment: MessageAttachment;
  e2eeParts?: E2eeAttachmentPart[];
}>();

const entry = ref<CachedBlobEntry | null>(null);
const failed = ref(false);

const objectKey = computed(() => props.attachment.key);
const e2eePart = computed(() =>
  props.e2eeParts?.find((part) => part.objectKey === objectKey.value),
);
const displayName = computed(() => props.attachment.name || objectKey.value || '附件');
const isImage = computed(() => {
  const mime = entry.value?.mimeType || props.attachment.mimeType || '';
  return mime.startsWith('image/');
});

const load = async () => {
  attachmentCacheService.revoke(entry.value);
  entry.value = null;
  failed.value = false;
  if (!props.roomId || !objectKey.value) return;
  try {
    entry.value = e2eePart.value
      ? await attachmentCacheService.loadEncryptedAttachment({
          roomId: props.roomId,
          part: e2eePart.value,
        })
      : await attachmentCacheService.loadAttachment({
          roomId: props.roomId,
          objectKey: objectKey.value,
        });
  } catch {
    failed.value = true;
  }
};

watch(
  () => [props.roomId, objectKey.value, props.e2eeParts],
  () => {
    void load();
  },
  { immediate: true },
);

onBeforeUnmount(() => {
  attachmentCacheService.revoke(entry.value);
});
</script>

<template>
  <a
    v-if="entry"
    class="cached-attachment"
    :href="entry.objectUrl"
    :download="displayName"
    target="_blank"
    rel="noreferrer"
  >
    <img v-if="isImage" :src="entry.objectUrl" :alt="displayName" />
    <span v-else>{{ displayName }}</span>
  </a>
  <span v-else class="cached-attachment cached-attachment--placeholder">
    {{ failed ? '附件加载失败' : displayName }}
  </span>
</template>

<style scoped>
.cached-attachment {
  display: block;
  margin-top: 8px;
  overflow: hidden;
  border-radius: 12px;
  background: rgb(0 0 0 / 5%);
  color: inherit;
  font-size: 13px;
}

.cached-attachment img {
  display: block;
  max-width: 220px;
  max-height: 180px;
  object-fit: cover;
}

.cached-attachment span {
  display: block;
  max-width: 220px;
  overflow: hidden;
  padding: 9px 10px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cached-attachment--placeholder {
  opacity: 0.72;
}
</style>
