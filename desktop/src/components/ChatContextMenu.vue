<template>
  <Teleport to="body">
    <div
      v-if="visible"
      class="chat-context-menu"
      :style="{ left: position.x + 'px', top: position.y + 'px' }"
      @click.stop
    >
      <div class="menu-item" @click="handlePin">
        <span class="menu-label">{{ chat?.isTop ? '取消置顶' : '置顶' }}</span>
      </div>
      <div class="menu-item" @click="handleMute">
        <span class="menu-label">{{ chat?.chatStatus === 1 ? '允许消息通知' : '消息免打扰' }}</span>
      </div>
      <div class="menu-divider"></div>
      <div class="menu-item danger" @click="handleDelete">
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

    &:hover {
      background-color: #f5f5f5;
    }

    &.danger {
      color: #ff4d4f;

      &:hover {
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
