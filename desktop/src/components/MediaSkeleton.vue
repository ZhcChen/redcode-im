<template>
  <div
    class="media-skeleton"
    :class="[`media-skeleton--${type}`, { 'media-skeleton--rounded': rounded }]"
    :style="skeletonStyle"
  >
    <div class="media-skeleton-shimmer"></div>
    <div class="media-skeleton-icon">
      <svg v-if="type === 'image'" width="32" height="32" viewBox="0 0 24 24" fill="none">
        <rect x="3" y="3" width="18" height="18" rx="2" stroke="currentColor" stroke-width="1.5" fill="none"/>
        <circle cx="8.5" cy="8.5" r="1.5" fill="currentColor"/>
        <path d="M21 15l-5-5L5 21" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      <svg v-else-if="type === 'video'" width="32" height="32" viewBox="0 0 24 24" fill="none">
        <rect x="2" y="4" width="20" height="16" rx="2" stroke="currentColor" stroke-width="1.5" fill="none"/>
        <path d="M10 8.5v7l5.5-3.5-5.5-3.5z" fill="currentColor"/>
      </svg>
      <svg v-else-if="type === 'emoji'" width="32" height="32" viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="1.5" fill="none"/>
        <circle cx="9" cy="10" r="1" fill="currentColor"/>
        <circle cx="15" cy="10" r="1" fill="currentColor"/>
        <path d="M8 14s1.5 2 4 2 4-2 4-2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

interface Props {
  type?: 'image' | 'video' | 'emoji'
  width?: number | string
  height?: number | string
  rounded?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  type: 'image',
  width: 200,
  height: 150,
  rounded: true
})

const skeletonStyle = computed(() => {
  const w = typeof props.width === 'number' ? `${props.width}px` : props.width
  const h = typeof props.height === 'number' ? `${props.height}px` : props.height
  return {
    width: w,
    height: h
  }
})
</script>

<style lang="scss" scoped>
@use 'sass:color';

.media-skeleton {
  position: relative;
  background: #e5e7eb;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;

  &--rounded {
    border-radius: 8px;
  }

  &--image {
    .media-skeleton-icon {
      color: #9ca3af;
    }
  }

  &--video {
    .media-skeleton-icon {
      color: #9ca3af;
    }
  }

  &--emoji {
    background: #fef3c7;
    .media-skeleton-icon {
      color: #f59e0b;
    }
  }
}

.media-skeleton-shimmer {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(0, 0, 0, 0.08) 50%,
    transparent 100%
  );
  background-size: 200% 100%;
  animation: skeleton-shimmer 2s ease-in-out infinite;
}

.media-skeleton-icon {
  position: relative;
  z-index: 1;
  opacity: 0.6;
}

@keyframes skeleton-shimmer {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}

// 深色主题适配
@media (prefers-color-scheme: dark) {
  .media-skeleton {
    background: #374151;

    &--emoji {
      background: #451a03;
      .media-skeleton-icon {
        color: #fbbf24;
      }
    }
  }

  .media-skeleton-shimmer {
    background: linear-gradient(
      90deg,
      transparent 0%,
      rgba(255, 255, 255, 0.05) 50%,
      transparent 100%
    );
    background-size: 200% 100%;
  }

  .media-skeleton-icon {
    color: #6b7280;
  }
}
</style>
