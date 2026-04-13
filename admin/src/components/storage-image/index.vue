<template>
  <div class="storage-image-container" :style="containerStyle">
    <img v-if="url" :src="url" v-bind="$attrs" @error="handleError" />
    <slot v-else-if="!loading" name="fallback"></slot>
    <div v-if="loading" class="storage-image-loading">
      <a-spin :size="16" />
    </div>
  </div>
</template>

<script setup lang="ts">
  import { computed } from 'vue';
  import useStorageUrl from '@/hooks/use-storage-url';

  const props = defineProps<{
    /** 对象存储对象键 */
    objectKey?: string | null;
    /** 初始 URL（可选，可能已过期） */
    initialUrl?: string | null;
    /** 存储提供商 ID（可选，如不传则使用默认存储提供商） */
    providerId?: string | null;
    /** 容器宽度 */
    width?: string | number;
    /** 容器高度 */
    height?: string | number;
  }>();

  const { url, loading, refresh } = useStorageUrl(
    props.objectKey,
    props.initialUrl,
    props.providerId
  );

  const containerStyle = computed(() => ({
    width: typeof props.width === 'number' ? `${props.width}px` : props.width,
    height:
      typeof props.height === 'number' ? `${props.height}px` : props.height,
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative' as const,
  }));

  const handleError = () => {
    if (props.objectKey) {
      console.warn(
        `[StorageImage] Image load failed for key: ${props.objectKey}, retrying...`
      );
      refresh();
    }
  };
</script>

<style scoped>
  .storage-image-container {
    overflow: hidden;
  }

  .storage-image-loading {
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>
