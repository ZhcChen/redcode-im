<template>
  <OverlayScrollbarsComponent
    ref="scrollbarRef"
    :class="['scroll-container', containerClass]"
    :options="scrollOptions"
    v-bind="$attrs"
  >
    <slot></slot>
  </OverlayScrollbarsComponent>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { OverlayScrollbarsComponent } from 'overlayscrollbars-vue'
import 'overlayscrollbars/styles/overlayscrollbars.css'

interface Props {
  /** 自定义类名 */
  containerClass?: string
  /** 滚动条宽度：normal(12px) | thin(8px) */
  size?: 'normal' | 'thin'
}

const props = withDefaults(defineProps<Props>(), {
  containerClass: '',
  size: 'normal'
})

// 暴露 OverlayScrollbars 组件引用
const scrollbarRef = ref<InstanceType<typeof OverlayScrollbarsComponent> | null>(null)

// 统一的滚动条配置
const scrollOptions = {
  scrollbars: {
    visibility: 'visible',
    autoHide: 'leave',
    autoHideDelay: 0,
    autoHideSuspend: true,
    dragScroll: true,
    clickScroll: true
  }
}

// 暴露滚动方法给父组件
defineExpose({
  scrollToBottom: (instant = true) => {
    const instance = scrollbarRef.value?.osInstance()
    if (instance) {
      const { viewport } = instance.elements()
      if (viewport) {
        viewport.scrollTo({
          top: viewport.scrollHeight,
          behavior: instant ? 'instant' : 'smooth'
        })
        return true
      }
    }
    return false
  },
  getViewport: () => {
    const instance = scrollbarRef.value?.osInstance()
    if (instance) {
      const { viewport } = instance.elements()
      return viewport
    }
    return null
  }
})
</script>

<style lang="scss" scoped>
.scroll-container {
  height: 100%;
}
</style>

<!-- 非 scoped 样式块：OverlayScrollbars 统一样式 -->
<style lang="scss">
.scroll-container {
  .os-viewport {
    overscroll-behavior: contain;
  }

  .os-scrollbar {
    --os-padding-perpendicular: 2px;
    --os-padding-axis: 2px;
    --os-track-border-radius: 10px;
    --os-track-bg: transparent;
    --os-track-bg-hover: transparent;
    --os-track-bg-active: transparent;
    --os-handle-border-radius: 10px;
    --os-handle-bg: rgba(0, 0, 0, 0.3);
    --os-handle-bg-hover: rgba(0, 0, 0, 0.3);
    --os-handle-bg-active: rgba(0, 0, 0, 0.3);
    --os-handle-min-size: 40px;
    --os-handle-max-size: none;
    --os-handle-perpendicular-size: 60%;
    --os-handle-perpendicular-size-hover: 60%;
    --os-handle-perpendicular-size-active: 60%;
    --os-handle-interactive-area-offset: 4px;
  }

  .os-scrollbar-hidden {
    opacity: 0;
    transition: opacity 0.1s ease;
  }

  .os-scrollbar-visible {
    opacity: 1;
    transition: opacity 0.1s ease;
  }

  .os-scrollbar-track {
    background: transparent !important;
    border-radius: 6px !important;

    &:hover {
      background: transparent !important;
    }

    &:active {
      background: transparent !important;
    }
  }

  .os-scrollbar-handle {
    background: rgba(0, 0, 0, 0.3) !important;
    border-radius: 10px !important;
    border: none !important;
    box-shadow: none !important;

    &:hover {
      background: rgba(0, 0, 0, 0.3) !important;
    }

    &:active {
      background: rgba(0, 0, 0, 0.3) !important;
    }
  }

  .os-scrollbar-horizontal {
    display: none !important;
  }

  // 默认尺寸 (normal: 12px)
  .os-scrollbar {
    --os-size: 12px;
  }

  .os-scrollbar-vertical {
    right: 4px;
    top: 4px;
    bottom: 4px;
    width: 12px !important;

    .os-scrollbar-track {
      width: 12px !important;
    }

    .os-scrollbar-handle {
      width: 8px !important;
      min-height: 40px !important;
      transition: none !important;

      &:hover {
        width: 8px !important;
      }

      &:active {
        width: 8px !important;
      }
    }
  }
}

// thin 尺寸变体 (8px，用于侧边菜单等窄容器)
.scroll-container.scroll-container--thin {
  .os-scrollbar {
    --os-size: 8px;
  }

  .os-scrollbar-vertical {
    right: 2px;
    width: 8px !important;

    .os-scrollbar-track {
      width: 8px !important;
    }

    .os-scrollbar-handle {
      width: 6px !important;

      &:hover {
        width: 6px !important;
      }

      &:active {
        width: 6px !important;
      }
    }
  }
}

// 暗色主题支持
[data-theme="dark"] .scroll-container {
  .os-scrollbar {
    --os-track-bg: transparent;
    --os-track-bg-hover: transparent;
    --os-track-bg-active: transparent;
    --os-handle-bg: rgba(255, 255, 255, 0.3);
    --os-handle-bg-hover: rgba(255, 255, 255, 0.3);
    --os-handle-bg-active: rgba(255, 255, 255, 0.3);
  }

  .os-scrollbar-track {
    background: transparent !important;

    &:hover {
      background: transparent !important;
    }
  }

  .os-scrollbar-handle {
    background: rgba(255, 255, 255, 0.3) !important;

    &:hover {
      background: rgba(255, 255, 255, 0.3) !important;
    }

    &:active {
      background: rgba(255, 255, 255, 0.3) !important;
    }
  }
}
</style>
