<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="message-context-menu"
      :style="menuStyle"
      @click.stop
    >
      <div class="menu-item" :class="{ disabled: !canCopy }" @click="handleAction('copy', canCopy)">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
          <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
        </svg>
        <span class="menu-label">复制</span>
      </div>

      <div class="menu-item" :class="{ disabled: !canQuote }" @click="handleAction('quote', canQuote)">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 21c3 0 7-1 7-8V5c0-1.25-.756-2.017-2-2H4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .008-1 1.031V21"/>
          <path d="M15 21c3 0 7-1 7-8V5c0-1.25-.757-2.017-2-2h-4c-1.25 0-2 .75-2 1.972V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3"/>
        </svg>
        <span class="menu-label">引用</span>
      </div>

      <div class="menu-item" :class="{ disabled: !canForward }" @click="handleAction('forward', canForward)">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z"/>
        </svg>
        <span class="menu-label">转发</span>
      </div>

      <div class="menu-item" :class="{ disabled: !canPin }" @click="handleAction('pin', canPin)">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 17v5M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>
        </svg>
        <span class="menu-label">{{ isPinned ? '取消置顶' : '置顶' }}</span>
      </div>

      <div class="menu-divider"></div>

      <div class="menu-item" @click="handleAction('reaction', true)">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M14 9V5a3 3 0 0 0-6 0v4M7 9h10a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z"/>
        </svg>
        <span class="menu-label">添加反应</span>
      </div>

      <div v-if="canEdit" class="menu-divider"></div>

      <div v-if="canEdit" class="menu-item" @click="handleAction('edit', canEdit)">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
          <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
        </svg>
        <span class="menu-label">编辑</span>
      </div>

      <div v-if="canDownload" class="menu-divider"></div>

      <div v-if="canDownload" class="menu-item" @click="handleAction('download', canDownload)">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
          <polyline points="7 10 12 15 17 10"/>
          <line x1="12" y1="15" x2="12" y2="3"/>
        </svg>
        <span class="menu-label">下载附件</span>
      </div>

      <div v-if="canDelete" class="menu-divider"></div>

      <div v-if="canDelete" class="menu-item danger" @click="handleAction('delete', canDelete)">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 6h18M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>
          <line x1="10" y1="11" x2="10" y2="17"/>
          <line x1="14" y1="11" x2="14" y2="17"/>
        </svg>
        <span class="menu-label">删除消息</span>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { watch, onUnmounted, computed, ref, onMounted } from 'vue'

interface Props {
  visible: boolean
  position: { x: number; y: number }
  canCopy: boolean
  canDownload: boolean
  canDelete: boolean
  canQuote: boolean
  canForward: boolean
  canPin: boolean
  canEdit: boolean
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
  (e: 'edit'): void
  (e: 'reaction'): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

// 计算菜单实际位置，防止超出视口
const menuStyle = computed(() => {
  const menuWidth = 160
  const menuHeight = 280 // 估算最大高度
  const padding = 8

  let x = props.position.x
  let y = props.position.y

  // 检查右侧是否超出
  if (x + menuWidth + padding > window.innerWidth) {
    x = window.innerWidth - menuWidth - padding
  }

  // 检查底部是否超出
  if (y + menuHeight + padding > window.innerHeight) {
    y = window.innerHeight - menuHeight - padding
  }

  // 确保不会超出左侧和顶部
  x = Math.max(padding, x)
  y = Math.max(padding, y)

  return {
    left: `${x}px`,
    top: `${y}px`
  }
})

const handleAction = (
  action: 'copy' | 'download' | 'delete' | 'quote' | 'forward' | 'pin' | 'edit' | 'reaction',
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
  background: rgba(255, 255, 255, 0.98);
  border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12), 0 2px 8px rgba(0, 0, 0, 0.08);
  padding: 6px 0;
  min-width: 160px;
  user-select: none;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(0, 0, 0, 0.06);
  animation: menuFadeIn 0.15s ease-out;

  .menu-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 16px;
    cursor: pointer;
    transition: background-color 0.15s;
    color: #333;

    &.disabled {
      color: #c0c4cc;
      cursor: not-allowed;

      .menu-icon {
        stroke: #c0c4cc;
      }
    }

    &:not(.disabled):hover {
      background-color: rgba(0, 0, 0, 0.04);
    }

    &:not(.disabled):active {
      background-color: rgba(0, 0, 0, 0.08);
    }

    &.danger {
      color: #ff4d4f;

      .menu-icon {
        stroke: #ff4d4f;
      }

      &:not(.disabled):hover {
        background-color: rgba(255, 77, 79, 0.08);
      }

      &:not(.disabled):active {
        background-color: rgba(255, 77, 79, 0.12);
      }
    }

    .menu-icon {
      flex-shrink: 0;
      stroke: #666;
    }

    .menu-label {
      font-size: 14px;
      white-space: nowrap;
    }
  }

  .menu-divider {
    height: 1px;
    background-color: rgba(0, 0, 0, 0.06);
    margin: 4px 12px;
  }
}

@keyframes menuFadeIn {
  from {
    opacity: 0;
    transform: scale(0.95);
  }
  to {
    opacity: 1;
    transform: scale(1);
  }
}
</style>
