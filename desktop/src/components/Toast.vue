<template>
  <Teleport to="body">
    <Transition name="toast-fade">
      <div v-if="visible" class="toast-container">
        <div class="toast-content">
          <div class="toast-icon" v-if="showIcon">
            <svg v-if="type === 'error'" viewBox="0 0 24 24" width="16" height="16">
              <path fill="currentColor" d="M12,2C17.53,2 22,6.47 22,12C22,17.53 17.53,22 12,22C6.47,22 2,17.53 2,12C2,6.47 6.47,2 12,2M15.59,7L12,10.59L8.41,7L7,8.41L10.59,12L7,15.59L8.41,17L12,13.41L15.59,17L17,15.59L13.41,12L17,8.41L15.59,7Z" />
            </svg>
            <svg v-else-if="type === 'success'" viewBox="0 0 24 24" width="16" height="16">
              <path fill="currentColor" d="M12,2A10,10 0 0,1 22,12A10,10 0 0,1 12,22A10,10 0 0,1 2,12A10,10 0 0,1 12,2M11,16.5L18,9.5L16.59,8.09L11,13.67L7.91,10.59L6.5,12L11,16.5Z" />
            </svg>
            <svg v-else-if="type === 'warning'" viewBox="0 0 24 24" width="16" height="16">
              <path fill="currentColor" d="M13,13H11V7H13M12,17.3A1.3,1.3 0 0,1 10.7,16A1.3,1.3 0 0,1 12,14.7A1.3,1.3 0 0,1 13.3,16A1.3,1.3 0 0,1 12,17.3M15.73,3H8.27L3,8.27V15.73L8.27,21H15.73L21,15.73V8.27L15.73,3Z" />
            </svg>
            <svg v-else viewBox="0 0 24 24" width="16" height="16">
              <path fill="currentColor" d="M13,9H11V7H13M13,17H11V11H13M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z" />
            </svg>
          </div>
          <div class="toast-message">{{ message }}</div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'

interface Props {
  message: string
  type?: 'info' | 'success' | 'warning' | 'error'
  duration?: number
  visible?: boolean
  showIcon?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  type: 'info',
  duration: 3000,
  visible: false,
  showIcon: false
})

const emits = defineEmits(['close'])

const visible = ref(props.visible)

const typeClass = computed(() => {
  return `toast-${props.type}`
})

let timer: number | null = null

onMounted(() => {
  visible.value = true
  
  if (props.duration && props.duration > 0) {
    timer = window.setTimeout(() => {
      close()
    }, props.duration)
  }
})

function close() {
  visible.value = false
  if (timer) {
    clearTimeout(timer)
    timer = null
  }
  
  // 等待动画完成后触发关闭事件
  setTimeout(() => {
    emits('close')
  }, 300)
}

// 暴露方法给父组件
defineExpose({
  close
})
</script>

<style scoped lang="scss">
.toast-container {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 9999;
  pointer-events: none; // 不阻止用户其他操作
}

.toast-content {
  background: rgba(0, 0, 0, 0.8);
  color: white;
  padding: 12px 20px;
  border-radius: 20px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  display: flex;
  align-items: center;
  gap: 8px;
  max-width: 280px;
  min-width: 120px;
  backdrop-filter: blur(10px);
  pointer-events: auto; // 内容区域可以接收事件（如果需要）
}

.toast-icon {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}

.toast-message {
  font-size: 14px;
  line-height: 1.4;
  color: white;
  word-break: break-word;
  text-align: center;
  flex: 1;
}

// 动画
.toast-fade-enter-active,
.toast-fade-leave-active {
  transition: all 0.3s ease;
}

.toast-fade-enter-from {
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.8);
}

.toast-fade-leave-to {
  opacity: 0;
  transform: translate(-50%, -50%) scale(0.8);
}

.toast-fade-enter-to,
.toast-fade-leave-from {
  opacity: 1;
  transform: translate(-50%, -50%) scale(1);
}
</style>
