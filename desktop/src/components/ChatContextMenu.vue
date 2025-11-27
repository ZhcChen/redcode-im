<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="chat-context-menu"
      :style="menuStyle"
      @click.stop
    >
      <div class="menu-item" @click="handlePin">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 17v5M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z"/>
        </svg>
        <span class="menu-label">{{ chat?.isTop ? '取消置顶' : '置顶' }}</span>
      </div>
      <div class="menu-item" @click="handleMute">
        <svg v-if="chat?.chatStatus === 1" class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
          <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
        </svg>
        <svg v-else class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
          <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
          <line x1="1" y1="1" x2="23" y2="23"/>
        </svg>
        <span class="menu-label">{{ chat?.chatStatus === 1 ? '允许消息通知' : '消息免打扰' }}</span>
      </div>
      <div class="menu-divider"></div>
      <div class="menu-item danger" @click="handleDelete">
        <svg class="menu-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M3 6h18M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>
          <line x1="10" y1="11" x2="10" y2="17"/>
          <line x1="14" y1="11" x2="14" y2="17"/>
        </svg>
        <span class="menu-label">删除对话</span>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'

interface ChatItem {
  id: string
  groupId: string
  name: string
  isTop: boolean
  chatStatus: number
}

interface Props {
  visible: boolean
  position: { x: number; y: number }
  chat: ChatItem | null
}

interface Emits {
  (e: 'update:visible', value: boolean): void
  (e: 'pin', chat: ChatItem): void
  (e: 'mute', chat: ChatItem): void
  (e: 'delete', chat: ChatItem): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

// 计算菜单实际位置，防止超出视口
const menuStyle = computed(() => {
  const menuWidth = 180
  const menuHeight = 140
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

const handlePin = () => {
  if (props.chat) {
    emit('pin', props.chat)
  }
  emit('update:visible', false)
}

const handleMute = () => {
  if (props.chat) {
    emit('mute', props.chat)
  }
  emit('update:visible', false)
}

const handleDelete = () => {
  if (props.chat) {
    emit('delete', props.chat)
  }
  emit('update:visible', false)
}

// 点击外部关闭菜单
const handleClickOutside = (event: MouseEvent) => {
  if (props.visible) {
    const target = event.target as HTMLElement
    if (!target.closest('.chat-context-menu')) {
      emit('update:visible', false)
    }
  }
}

// 监听 visible 变化，添加/移除事件监听
watch(() => props.visible, (newVisible) => {
  if (newVisible) {
    // 延迟添加监听，避免立即触发
    setTimeout(() => {
      document.addEventListener('click', handleClickOutside)
    }, 0)
  } else {
    document.removeEventListener('click', handleClickOutside)
  }
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped lang="scss">
.chat-context-menu {
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

    &:hover {
      background-color: rgba(0, 0, 0, 0.04);
    }

    &:active {
      background-color: rgba(0, 0, 0, 0.08);
    }

    &.danger {
      color: #ff4d4f;

      .menu-icon {
        stroke: #ff4d4f;
      }

      &:hover {
        background-color: rgba(255, 77, 79, 0.08);
      }

      &:active {
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
