<template>
  <div class="cos-image-container" :style="containerStyle">
    <img v-if="url" :src="url" v-bind="$attrs" @error="handleError" />
    <slot v-else-if="!loading" name="fallback"></slot>
    <div v-if="loading" class="cos-image-loading">
      <a-spin :size="16" />
    </div>
  </div>
</template>

<script setup lang="ts">
  import { computed } from 'vue';
  import useCosUrl from '@/hooks/use-cos-url';

  const props = defineProps<{
    /** COS 对象键 */
    objectKey?: string | null;
    /** 初始 URL（可选，可能已过期） */
    initialUrl?: string | null;
    /** 容器宽度 */
    width?: string | number;
    /** 容器高度 */
    height?: string | number;
  }>();

  const { url, loading, refresh } = useCosUrl(
    props.objectKey,
    props.initialUrl
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
    // 如果图片加载失败，且我们有 key，尝试强制刷新一次 URL
    if (props.objectKey) {
      console.warn(
        `[CosImage] Image load failed for key: ${props.objectKey}, retrying...`
      );
      refresh();
    }
  };
</script>

<style scoped>
  .cos-image-container {
    overflow: hidden;
  }

  .cos-image-loading {
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>
