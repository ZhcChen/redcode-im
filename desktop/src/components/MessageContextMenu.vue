<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="message-context-menu"
      :style="{ left: position.x + 'px', top: position.y + 'px' }"
      @click.stop
    >
      <div class="menu-item" :class="{ disabled: !canCopy }" @click="handleAction('copy', canCopy)">
        <span class="menu-label">复制</span>
      </div>

      <div class="menu-item" :class="{ disabled: !canQuote }" @click="handleAction('quote', canQuote)">
        <span class="menu-label">引用</span>
      </div>

      <div class="menu-item" :class="{ disabled: !canForward }" @click="handleAction('forward', canForward)">
        <span class="menu-label">转发</span>
      </div>

      <div class="menu-item" :class="{ disabled: !canPin }" @click="handleAction('pin', canPin)">
        <span class="menu-label">{{ isPinned ? '取消置顶' : '置顶' }}</span>
      </div>

      <div class="menu-divider"></div>

      <div class="menu-item" :class="{ disabled: !canDownload }" @click="handleAction('download', canDownload)">
        <span class="menu-label">下载附件</span>
      </div>

      <div class="menu-divider"></div>

      <div class="menu-item danger" :class="{ disabled: !canDelete }" @click="handleAction('delete', canDelete)">
        <span class="menu-label">删除消息</span>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { watch, onUnmounted } from 'vue'

interface Props {
  visible: boolean
  position: { x: number; y: number }
  canCopy: boolean
  canDownload: boolean
  canDelete: boolean
  canQuote: boolean
  canForward: boolean
  canPin: boolean
  isPinned: boolean
}

interface Emits {
  (e: 'update:visible', value: boolean): void
  (e: 'copy'): void
  (e: 'download'): void
  (e: 'delete'): void
  (e: 'quote'): void
  (e: 'forward'): void
  (e: 'pin'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const handleAction = (
  action: 'copy' | 'download' | 'delete' | 'quote' | 'forward' | 'pin',
  enabled: boolean,
) => {
  if (!enabled) return
  emit(action)
  emit('update:visible', false)
}

// 点击外部关闭菜单
const handleClickOutside = (event: MouseEvent) => {
  if (props.visible) {
    const target = event.target as HTMLElement
    if (!target.closest('.message-context-menu')) {
      emit('update:visible', false)
    }
  }
}

watch(
  () => props.visible,
  (visible) => {
    if (visible) {
      setTimeout(() => document.addEventListener('click', handleClickOutside), 0)
    } else {
      document.removeEventListener('click', handleClickOutside)
    }
  },
)

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped lang="scss">
.message-context-menu {
  position: fixed;
  z-index: 10000;
  background: #ffffff;
  border: 1px solid #e5e5e5;
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  padding: 4px 0;
  min-width: 160px;
  user-select: none;

  .menu-item {
    display: flex;
    align-items: center;
    padding: 10px 16px;
    cursor: pointer;
    transition: background-color 0.2s;

    &.disabled {
      color: #b8bcc6;
      cursor: not-allowed;
    }

    &:not(.disabled):hover {
      background-color: #f5f5f5;
    }

    &.danger {
      color: #ff4d4f;

      &:not(.disabled):hover {
        background-color: #fff1f0;
      }
    }

    .menu-label {
      font-size: 14px;
    }
  }

  .menu-divider {
    height: 1px;
    background-color: #e5e5e5;
    margin: 4px 0;
  }
}
</style>
